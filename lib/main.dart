import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'core/providers/device_provider.dart';
import 'core/providers/transfer_provider.dart';
import 'core/providers/incoming_files_provider.dart';
import 'core/services/system_tray_service.dart';
import 'core/services/share_intent_service.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/quick_send_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/share_intent_dialog.dart';

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
  bool _hasShareIntent = false;

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
            setState(() {
              _sharedFilesFromIntent = files;
              _hasShareIntent = true;
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
        
        // Dispose system tray
        await SystemTrayService.dispose();
        
        // Give services time to cleanup
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Now destroy window
        await windowManager.destroy();
      }
    } catch (e) {
      debugPrint('⚠️ Error handling window close: $e');
      // FIXED: Use proper exit instead of SystemNavigator.pop()
      // SystemNavigator.pop() doesn't cleanup resources properly on desktop
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
  Widget _buildShareIntentScreen() {
    return Builder(
      builder: (context) {
        // Show dialog immediately when build is called
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareIntentDialog(context);
        });

        // Show loading while dialog is shown
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
      },
    );
  }

  void _showShareIntentDialog(BuildContext context) {
    if (!_hasShareIntent || _sharedFilesFromIntent == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareIntentDialog(
        fileCount: _sharedFilesFromIntent!.length,
        onAppToApp: () => _handleAppToAppShare(),
        onBrowserShare: () => _handleBrowserShare(),
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

    // Copy files from content URIs to app storage
    final copiedPaths = await _copySharedFilesToAppStorage(_sharedFilesFromIntent!);
    
    if (copiedPaths.isEmpty) {
      debugPrint('Failed to copy shared files');
      setState(() {
        _hasShareIntent = false;
      });
      ShareIntentService().clearSharedFiles();
      return;
    }

    // Set the files FIRST - this triggers the state to show QuickSendScreen
    try {
      await ref.read(incomingFilesProvider.notifier).setFilesFromPaths(copiedPaths);
      debugPrint('Set ${copiedPaths.length} files for QuickSendScreen');
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

    // Copy files from content URIs to app storage
    final copiedPaths = await _copySharedFilesToAppStorage(_sharedFilesFromIntent!);
    
    if (copiedPaths.isEmpty) {
      debugPrint('Failed to copy shared files for browser share');
      setState(() {
        _hasShareIntent = false;
      });
      ShareIntentService().clearSharedFiles();
      return;
    }

    setState(() {
      _hasShareIntent = false;
    });

    // Clear the share intent
    ShareIntentService().clearSharedFiles();
    
    // Navigate to BrowserShareScreen with the copied files
    // TODO: Implement passing files to browser share screen
  }

  Future<List<String>> _copySharedFilesToAppStorage(List<SharedFile> sharedFiles) async {
    final List<String> copiedPaths = [];
    
    // Create a temporary directory for shared files
    final tempDir = Directory.systemTemp.createTempSync('syndro_share_');
    
    for (final sharedFile in sharedFiles) {
      try {
        // For Android content URIs, we need to use platform channel to copy
        if (Platform.isAndroid && sharedFile.uri.startsWith('content://')) {
          final copiedPath = await _copyContentUriToFile(sharedFile.uri, tempDir.path, sharedFile.name);
          if (copiedPath != null) {
            copiedPaths.add(copiedPath);
          }
        } else if (sharedFile.uri.startsWith('file://')) {
          // Direct file path
          final filePath = sharedFile.uri.replaceFirst('file://', '');
          if (File(filePath).existsSync()) {
            copiedPaths.add(filePath);
          }
        }
      } catch (e) {
        debugPrint('Error copying file ${sharedFile.name}: $e');
      }
    }
    
    return copiedPaths;
  }

  Future<String?> _copyContentUriToFile(String contentUri, String tempDir, String? fileName) async {
    try {
      const channel = MethodChannel('com.syndro.app/share_intent');
      final result = await channel.invokeMethod<String>('copyContentUri', {
        'uri': contentUri,
        'tempDir': tempDir,
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      debugPrint('Error copying content URI: $e');
      return null;
    }
  }
}
