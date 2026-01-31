import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ui/theme/app_theme.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'core/providers/device_provider.dart';
import 'core/providers/transfer_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // Initialize SQLite for desktop platforms
  if (Platform.isWindows || Platform.isLinux) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('✅ SQLite initialized successfully');
    } catch (e) {
      debugPrint('❌ SQLite init failed: $e');
    }
  }

  runApp(const ProviderScope(child: SyndroApp()));
}

class SyndroApp extends ConsumerStatefulWidget {
  const SyndroApp({super.key});

  @override
  ConsumerState<SyndroApp> createState() => _SyndroAppState();
}

class _SyndroAppState extends ConsumerState<SyndroApp> with WidgetsBindingObserver {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    // Unregister app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cleanup services
    _cleanupServices();
    
    debugPrint('🧹 SyndroApp disposed');
    super.dispose();
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - refreshing services');
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached - cleaning up');
        _cleanupServices();
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  /// Called when app comes back to foreground
  void _onAppResumed() {
    try {
      // Refresh device discovery when app resumes
      final deviceDiscovery = ref.read(deviceDiscoveryServiceProvider);
      if (deviceDiscovery.isInitialized) {
        deviceDiscovery.refreshDevices();
      }
    } catch (e) {
      debugPrint('Error on app resume: $e');
    }
  }

  /// Called when app goes to background
  void _onAppPaused() {
    // Optional: Stop scanning when app is in background to save battery
    // Uncomment if you want this behavior:
    // try {
    //   final deviceDiscovery = ref.read(deviceDiscoveryServiceProvider);
    //   deviceDiscovery.stopScanning();
    // } catch (e) {
    //   debugPrint('Error on app pause: $e');
    // }
  }

  /// Cleanup all services
  void _cleanupServices() {
    try {
      // Services are disposed via Riverpod's onDispose
      // This is called when the provider is no longer used
      debugPrint('🧹 Services cleanup initiated');
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  Future<void> _initializeServices() async {
    try {
      debugPrint('🚀 Starting initialization...');

      // Add overall timeout to prevent infinite hang
      await Future.any([
        _doInitialization(),
        Future.delayed(const Duration(seconds: 10), () {
          debugPrint('⚠️ Initialization timed out, continuing anyway');
        }),
      ]);

      debugPrint('✅ Initialization complete');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Service initialization failed: $e');
      // Don't show error, just continue with defaults
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _doInitialization() async {
    await _initDeviceDiscovery();
    await _initTransferService();
  }

  Future<void> _initDeviceDiscovery() async {
    try {
      debugPrint('📡 Initializing device discovery...');
      final deviceDiscovery = ref.read(deviceDiscoveryServiceProvider);
      await deviceDiscovery.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⚠️ Device discovery init timed out');
        },
      );
      debugPrint('✅ Device discovery initialized');
    } catch (e) {
      debugPrint('❌ Device discovery error: $e');
    }
  }

  Future<void> _initTransferService() async {
    try {
      debugPrint('📤 Initializing transfer service...');

      // Get device info from discovery service
      final deviceDiscovery = ref.read(deviceDiscoveryServiceProvider);
      final currentDevice = deviceDiscovery.currentDevice;

      final transferService = ref.read(transferServiceProvider);

      // Set device info so syndro.json returns correct ID
      transferService.setDeviceInfo(
        id: currentDevice.id,
        name: currentDevice.name,
        platform: currentDevice.platform.name,
      );

      await transferService.startServer(8765).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Transfer service init timed out');
        },
      );

      debugPrint('✅ Transfer service initialized');
    } catch (e) {
      debugPrint('❌ Transfer service error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syndro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    // Show error screen if initialization failed
    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                      _isInitialized = false;
                    });
                    _initializeServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading screen while initializing
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF682CA8).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.share,
                  color: Color(0xFF682CA8),
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: Color(0xFF682CA8),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Initializing Syndro...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Setting up network services',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show main app after initialization complete
    return const MainNavigationScreen();
  }
}
