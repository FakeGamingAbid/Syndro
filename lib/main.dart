import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'core/database/database_helper.dart';
import 'core/models/transfer.dart';
import 'core/providers/device_provider.dart';
import 'core/providers/transfer_provider.dart';
import 'core/providers/incoming_files_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/system_tray_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/services/desktop_notification_service.dart';
import 'core/services/window_settings_service.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/quick_send_screen.dart';
import 'ui/screens/browser_share_screen.dart';
import 'ui/theme/app_theme.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for desktop platforms
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  // Parse incoming file arguments (for right-click send)
  List<String>? incomingFiles;
  if (args.isNotEmpty) {
    incomingFiles = args.where((arg) {
      // Filter out Flutter/Dart internal arguments
      if (arg.startsWith('--') || arg.startsWith('-')) {
        return false;
      }
      // Check if path exists
      return File(arg).existsSync() || Directory(arg).existsSync();
    }).toList();

    if (incomingFiles.isNotEmpty) {
      debugPrint('📥 Received ${incomingFiles.length} file(s) from command line');
      for (final file in incomingFiles) {
        debugPrint('  - $file');
      }
    }
  }

  // Initialize window manager for desktop
  if (Platform.isWindows || Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();

      // Load saved window settings
      await WindowSettingsService.initialize();
      final savedBounds = await WindowSettingsService.loadWindowBounds();

      // Configure window options
      final windowSize = savedBounds != null 
          ? Size(savedBounds.width, savedBounds.height) 
          : WindowSettingsService.getDefaultSize();
      final windowOptions = WindowOptions(
        size: windowSize,
        minimumSize: WindowSettingsService.getMinimumSize(),
        center: savedBounds == null || savedBounds.x == null || savedBounds.y == null,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'Syndro',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        // Apply saved maximized state
        if (savedBounds?.maximized == true) {
          await windowManager.maximize();
        }
        
        // If we have saved position and not centered, apply it
        if (savedBounds?.x != null && savedBounds?.y != null) {
          await windowManager.setPosition(Offset(savedBounds!.x!, savedBounds.y!));
        }
        
        await windowManager.show();
        await windowManager.focus();
      });

      // Listen for window events to save settings
      // Window bounds are now saved in _SyndroAppState.onWindowClose()

      // Initialize desktop notification service
      await DesktopNotificationService.initialize();
      debugPrint('✅ Desktop notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Window manager initialization failed: $e');
      // Continue without window manager - app will still work
    }
  }

  // Create the ProviderContainer to pre-initialize services
  final container = ProviderContainer();

  // PRE-INITIALIZE device discovery service BEFORE app loads
  debugPrint('🚀 Pre-initializing device discovery...');

  try {
    final deviceService = container.read(deviceDiscoveryServiceProvider);
    await deviceService.initialize();
    debugPrint('✅ Device discovery initialized!');
  } catch (e) {
    debugPrint('❌ Device discovery initialization failed: $e');
    // Continue anyway - the app can retry later
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: SyndroApp(
        showOnboarding: !onboardingComplete,
        incomingFiles: incomingFiles,
      ),
    ),
  );
}

class SyndroApp extends ConsumerStatefulWidget {
  final bool showOnboarding;
  final List<String>? incomingFiles;

  const SyndroApp({
    super.key,
    required this.showOnboarding,
    this.incomingFiles,
  });

  @override
  ConsumerState<SyndroApp> createState() => _SyndroAppState();
}

class _SyndroAppState extends ConsumerState<SyndroApp>
    with WidgetsBindingObserver, WindowListener {
  bool _initialized = false;
  String? _initError;
  bool _windowListenerAdded = false;

  // Share intent state
  List<SharedFile>? _sharedFilesFromIntent;
  List<File>? _browserShareFiles;
  bool _hasShareIntent = false;
  AndroidShareMode _shareMode = AndroidShareMode.appToApp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Add window listener for desktop
    if (Platform.isWindows || Platform.isLinux) {
      try {
        windowManager.addListener(this);
        _windowListenerAdded = true;
      } catch (e) {
        debugPrint('⚠️ Could not add window listener: $e');
      }
    }

    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Only remove listener if we added it
    if (_windowListenerAdded) {
      try {
        windowManager.removeListener(this);
      } catch (e) {
        debugPrint('⚠️ Could not remove window listener: $e');
      }
    }

    SystemTrayService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Initialize system tray for desktop
    if (Platform.isWindows || Platform.isLinux) {
      try {
        await SystemTrayService.initialize(
          onShowWindow: () {
            debugPrint('Window shown from tray');
          },
          onToggleServer: () {
            debugPrint('Toggle server from tray');
          },
          onExit: () {
            debugPrint('Exit from tray');
          },
        );
      } catch (e) {
        debugPrint('⚠️ System tray initialization failed: $e');
        // Continue without system tray
      }
    }

    // Initialize share intent service (Android)
    if (Platform.isAndroid) {
      try {
        final shareIntentService = ShareIntentService();
        await shareIntentService.initialize();
        
        // Listen for share intents
        shareIntentService.sharedFilesStream.listen((files) {
          if (files.isNotEmpty && mounted) {
            debugPrint('📥 Received ${files.length} file(s) from share intent');
            // Get the share mode from the service
            final mode = shareIntentService.lastShareMode;
            debugPrint('📱 Share mode: $mode');
            
            setState(() {
              _sharedFilesFromIntent = files;
              _hasShareIntent = true;
              _shareMode = mode;
            });
          }
        });
        
        // Also listen for share mode changes
        shareIntentService.shareModeStream.listen((mode) {
          if (mounted) {
            debugPrint('📱 Share mode changed to: $mode');
            setState(() {
              _shareMode = mode;
            });
          }
        });
      } catch (e) {
        debugPrint('⚠️ Share intent service initialization failed: $e');
      }
    }

    // Handle incoming files from command line
    if (widget.incomingFiles != null && widget.incomingFiles!.isNotEmpty) {
      try {
        await ref
            .read(incomingFilesProvider.notifier)
            .setFilesFromPaths(widget.incomingFiles!);
      } catch (e) {
        debugPrint('⚠️ Error setting incoming files: $e');
      }
    }

    // Initialize transfer server for discovery
    try {
      debugPrint('🚀 Starting transfer server...');
      final transferService = ref.read(transferServiceProvider);

      // Initialize encryption and trusted devices before starting server
      await transferService.initialize();

      try {
        await transferService.startServer(8765);
        debugPrint('✅ Transfer server started');
      } catch (e) {
        debugPrint('❌ Failed to start transfer server: $e');
        _initError = 'Could not start transfer server';
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize transfer service: $e');
      _initError = 'Transfer service error: $e';
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void onWindowClose() async {
    // Save window bounds before closing
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final maximized = await windowManager.isMaximized();
      
      await WindowSettingsService.saveWindowBounds(
        size: size,
        position: position,
        maximized: maximized,
      );
    } catch (e) {
      debugPrint('❌ Error saving window bounds on close: $e');
    }

    try {
      final isPreventClose = await windowManager.isPreventClose();

      if (isPreventClose && SystemTrayService.isInitialized) {
        await SystemTrayService.minimizeToTray();
      } else {
        // FIXED: Properly dispose resources before exiting
        debugPrint('🧹 Cleaning up resources before exit...');
        
        // FIX (Bug #8): Close database before exiting
        try {
          await DatabaseHelper.instance.close();
          debugPrint('✅ Database closed');
        } catch (e) {
          debugPrint('⚠️ Error closing database: $e');
        }
        
        // Dispose system tray
        await SystemTrayService.dispose();
        
        // Give services time to cleanup
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Now destroy window
        await windowManager.destroy();
      }
    } catch (e) {
      debugPrint('⚠️ Error handling window close: $e');
      // Try graceful cleanup before fallback
      try {
        await DatabaseHelper.instance.close();
        debugPrint('✅ Database closed in fallback');
      } catch (dbError) {
        debugPrint('⚠️ Database close error in fallback: $dbError');
      }
      try {
        await SystemTrayService.dispose();
        debugPrint('✅ System tray disposed in fallback');
      } catch (trayError) {
        debugPrint('⚠️ System tray dispose error in fallback: $trayError');
      }
      // Give a brief moment for cleanup to complete
      await Future.delayed(const Duration(milliseconds: 100));
      // Use windowManager.destroy() instead of exit(0) for proper Flutter lifecycle
      try {
        await windowManager.destroy();
      } catch (destroyError) {
        debugPrint('⚠️ Error destroying window: $destroyError');
        // Only use exit(0) as absolute last resort when window manager is unavailable
        // This ensures the app still terminates even if window manager is corrupted
      }
    }
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}

  @override
  Widget build(BuildContext context) {
    final incomingFilesState = ref.watch(incomingFilesProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Syndro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: supportedLocales.map((l) => l.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _buildHome(incomingFilesState),
    );
  }

  Widget _buildHome(IncomingFilesState incomingFilesState) {
    // Show loading screen while initializing
    if (!_initialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Starting Syndro...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show error if initialization failed critically
    if (_initError != null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.errorColor,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Initialization Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                      _initialized = false;
                    });
                    _initializeApp();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If we have incoming files, show quick send screen
    if (incomingFilesState.hasFiles && _initialized) {
      return QuickSendScreen(
        files: incomingFilesState.files,
        onComplete: () {
          ref.read(incomingFilesProvider.notifier).clear();
        },
      );
    }

    // If we have browser share files, show browser share screen
    if (_browserShareFiles != null && _browserShareFiles!.isNotEmpty && _initialized) {
      final files = _browserShareFiles!;
      _browserShareFiles = null; // Clear after use
      return BrowserShareScreen(
        files: files,
      );
    }

    // Show share intent dialog if app was opened from another app
    if (_hasShareIntent && _sharedFilesFromIntent != null && _initialized) {
      return _buildShareIntentScreen();
    }

    // Normal app flow
    if (widget.showOnboarding) {
      return const OnboardingScreen();
    }

    return const MainNavigationScreen();
  }

  // Build screen for handling share intents from other apps
  // On Android, directly navigates based on share mode (no dialog)
  Widget _buildShareIntentScreen() {
    // Directly handle based on share mode - no dialog needed
    // The mode was set by the activity-alias selected in Android share sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shareMode == AndroidShareMode.browserShare) {
        _handleBrowserShare();
      } else {
        _handleAppToAppShare();
      }
    });

    // Show loading while processing
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Preparing share...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAppToAppShare() async {
    debugPrint('App to App share selected with ${_sharedFilesFromIntent?.length ?? 0} files');
    
    if (_sharedFilesFromIntent == null || _sharedFilesFromIntent!.isEmpty) {
      setState(() {
        _hasShareIntent = false;
      });
      return;
    }

    // On Android, content:// URIs need to be copied to actual files
    // Use the copyContentUri method from ShareIntentService via platform channel
    final items = <TransferItem>[];
    
    for (final sharedFile in _sharedFilesFromIntent!) {
      final uri = sharedFile.uri;
      
      if (uri.startsWith('content://')) {
        // Copy content URI to temp file
        try {
          final tempDir = await getTemporaryDirectory();
          final result = await ShareIntentService().copyContentUri(
            uri: uri,
            tempDir: tempDir.path,
            fileName: sharedFile.name,
          );
          
          if (result != null) {
            // Use the original name from the share intent, not the temp file name
            final fileName = sharedFile.name ?? result.split('/').last;
            items.add(TransferItem(
              name: fileName,
              path: result,
              size: sharedFile.size,
              isDirectory: false,
            ));
            debugPrint('✅ Copied content URI to: $result (name: $fileName, size: ${sharedFile.size})');
          } else {
            debugPrint('⚠️ Failed to copy content URI: $uri');
          }
        } catch (e) {
          debugPrint('❌ Error copying content URI: $e');
        }
      } else {
        // Regular file path - use the name from share intent
        final fileName = sharedFile.name ?? uri.split('/').last;
        items.add(TransferItem(
          name: fileName,
          path: uri,
          size: sharedFile.size,
          isDirectory: false,
        ));
      }
    }
    
    debugPrint('Processed ${items.length} files:');
    for (final item in items) {
      debugPrint('  - ${item.name} (${item.size} bytes)');
    }
    
    // Set the files directly - this triggers the state to show QuickSendScreen
    if (items.isNotEmpty) {
      ref.read(incomingFilesProvider.notifier).setFiles(items);
      debugPrint('Set ${items.length} files for QuickSendScreen');
    }

    // Clear the share intent from Android
    ShareIntentService().clearSharedFiles();
    
    // NOW change state to close dialog and trigger rebuild
    // The rebuild will see incomingFilesState.hasFiles is true and show QuickSendScreen
    if (mounted) {
      setState(() {
        _hasShareIntent = false;
      });
    }
  }

  void _handleBrowserShare() async {
    debugPrint('Browser share selected with ${_sharedFilesFromIntent?.length ?? 0} files');
    
    if (_sharedFilesFromIntent == null || _sharedFilesFromIntent!.isEmpty) {
      setState(() {
        _hasShareIntent = false;
      });
      return;
    }

    // On Android, content:// URIs need to be copied to actual files
    // Same as _handleAppToAppShare - we need proper file paths for thumbnails and file info
    final files = <File>[];
    
    for (final sharedFile in _sharedFilesFromIntent!) {
      final uri = sharedFile.uri;
      
      if (uri.startsWith('content://')) {
        // Copy content URI to temp file
        try {
          final tempDir = await getTemporaryDirectory();
          final result = await ShareIntentService().copyContentUri(
            uri: uri,
            tempDir: tempDir.path,
            fileName: sharedFile.name,
          );
          
          if (result != null) {
            files.add(File(result));
            debugPrint('✅ Copied content URI to: $result (name: ${sharedFile.name}, size: ${sharedFile.size})');
          } else {
            debugPrint('⚠️ Failed to copy content URI: $uri');
          }
        } catch (e) {
          debugPrint('❌ Error copying content URI: $e');
        }
      } else {
        // Regular file path
        files.add(File(uri));
      }
    }

    // Clear share intent and set browser share files
    ShareIntentService().clearSharedFiles();
    
    setState(() {
      _hasShareIntent = false;
      _browserShareFiles = files;
    });
  }
}

