import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'core/database/database_helper.dart';
import 'core/providers/device_provider.dart';
import 'core/providers/transfer_provider.dart';
import 'core/providers/incoming_files_provider.dart';
import 'core/services/system_tray_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/services/desktop_notification_service.dart';
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

      const windowOptions = WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'Syndro',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

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
  ShareMode _shareMode = ShareMode.appToApp;

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
      // Try graceful cleanup before fallback exit
      try {
        await DatabaseHelper.instance.close();
        await SystemTrayService.dispose();
      } catch (_) {
        // Ignore cleanup errors in fallback
      }
      // Use dart:io exit only as last resort
      exit(0);
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

    return MaterialApp(
      title: 'Syndro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
      if (_shareMode == ShareMode.browserShare) {
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

    // Skip copying - just use the URIs directly
    // Get the file paths from URIs
    final paths = _sharedFilesFromIntent!.map((f) => f.uri).toList();
    
    // Set the files FIRST - this triggers the state to show QuickSendScreen
    try {
      await ref.read(incomingFilesProvider.notifier).setFilesFromPaths(paths);
      debugPrint('Set ${paths.length} files for QuickSendScreen');
    } catch (e) {
      debugPrint('Error setting incoming files: $e');
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

    // Skip copying - just use the URIs directly
    final paths = _sharedFilesFromIntent!.map((f) => f.uri).toList();

    // Convert URI strings to File objects
    final files = paths.map((path) => File(path)).toList();

    // Clear share intent and set browser share files
    ShareIntentService().clearSharedFiles();
    
    setState(() {
      _hasShareIntent = false;
      _browserShareFiles = files;
    });
  }
}
