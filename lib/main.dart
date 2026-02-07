import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'core/providers/device_provider.dart';
import 'core/providers/transfer_provider.dart';
import 'core/providers/incoming_files_provider.dart';
import 'core/services/system_tray_service.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/quick_send_screen.dart';
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
  }

  // Create the ProviderContainer to pre-initialize services
  final container = ProviderContainer();
  
  // PRE-INITIALIZE device discovery service BEFORE app loads
  debugPrint('🚀 Pre-initializing device discovery...');
  final deviceService = container.read(deviceDiscoveryServiceProvider);
  await deviceService.initialize();
  debugPrint('✅ Device discovery initialized!');

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Add window listener for desktop
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
    }

    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    SystemTrayService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Initialize system tray for desktop
    if (Platform.isWindows || Platform.isLinux) {
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
    }

    // Handle incoming files from command line
    if (widget.incomingFiles != null && widget.incomingFiles!.isNotEmpty) {
      await ref
          .read(incomingFilesProvider.notifier)
          .setFilesFromPaths(widget.incomingFiles!);
    }

    // Initialize transfer server for discovery
    try {
      debugPrint('🚀 Starting transfer server...');
      final transferService = ref.read(transferServiceProvider);
      await transferService.startServer(8765); // Default port
      debugPrint('✅ Transfer server started on port 8765');
    } catch (e) {
      debugPrint('❌ Failed to start transfer server: $e');
    }

    setState(() => _initialized = true);
  }

  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && SystemTrayService.isInitialized) {
      await SystemTrayService.minimizeToTray();
    } else {
      await windowManager.destroy();
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
    // If we have incoming files, show quick send screen
    if (incomingFilesState.hasFiles && _initialized) {
      return QuickSendScreen(
        files: incomingFilesState.files,
        onComplete: () {
          ref.read(incomingFilesProvider.notifier).clear();
        },
      );
    }

    // Normal app flow
    if (widget.showOnboarding) {
      return const OnboardingScreen();
    }

    return const MainNavigationScreen();
  }
}
