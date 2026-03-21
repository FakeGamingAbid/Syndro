import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moonplex/core/platform/platform_detector.dart';
import 'package:moonplex/core/database/app_database.dart';
import 'package:moonplex/core/theme/moon_theme.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/shells/mobile_shell.dart';
import 'package:moonplex/shells/tv_shell.dart';
import 'package:moonplex/shells/desktop_shell.dart';
import 'package:moonplex/features/profiles/profiles_screen.dart';
import 'package:moonplex/features/home/update_banner.dart';

// ============== GLOBAL PROVIDERS ==============

final profilesProvider = FutureProvider<List<Profile>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getAllProfiles();
});

final activeProfileProvider = FutureProvider<Profile?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.activeProfile;
});

// ============== MOONPLEX APP ==============

class MoonplexApp extends ConsumerStatefulWidget {
  const MoonplexApp({super.key});

  @override
  ConsumerState<MoonplexApp> createState() => _MoonplexAppState();
}

class _MoonplexAppState extends ConsumerState<MoonplexApp> {
  bool _isInitialized = false;
  bool _showProfilePicker = false;
  bool _forceUpdateShown = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize media_kit
    MediaKit.ensureInitialized();

    // Initialize platform detection
    await PlatformDetector.init();

    // Initialize database
    final db = ref.read(appDatabaseProvider);
    await db.init();

    // Fetch remote config silently
    // Check for profile
    final profiles = await db.getAllProfiles();
    final hasMultipleProfiles = profiles.length > 1;
    final hasActiveProfile = await db.activeProfile != null;

    // Check for force update
    final updateResult = await UpdateChecker.checkForUpdate();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _showProfilePicker = hasMultipleProfiles || !hasActiveProfile;
        if (updateResult.isForceUpdate && !_forceUpdateShown) {
          _forceUpdateShown = true;
          // Show force update dialog - will block the app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showForceUpdateDialog(
                updateResult.version!, updateResult.message!);
          });
        }
      });
    }
  }

  void _showForceUpdateDialog(String version, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ForceUpdateDialog(
        version: version,
        message: message,
      ),
    );
  }

  void _onProfileSelected() {
    setState(() {
      _showProfilePicker = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildSplashScreen();
    }

    if (_showProfilePicker) {
      return MaterialApp(
        title: 'Moonplex',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(false),
        home: ProfilesScreen(
          onProfileSelected: _onProfileSelected,
        ),
      );
    }

    return _buildMainApp();
  }

  Widget _buildSplashScreen() {
    return MaterialApp(
      title: 'Moonplex',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      home: Scaffold(
        backgroundColor: MoonTheme.backgroundPrimary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated moon logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            MoonTheme.accentPrimary,
                            MoonTheme.accentGlow,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MoonTheme.accentGlow.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.nightlight_round,
                        size: 64,
                        color: MoonTheme.backgroundPrimary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // App name
              const Text(
                'Moonplex',
                style: TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Streaming reimagined',
                style: TextStyle(
                  color: MoonTheme.textSecondary,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: MoonTheme.accentPrimary,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainApp() {
    final platformType = PlatformDetector.current;

    Widget shell;
    switch (platformType) {
      case PlatformType.tv:
        shell = const TVShell();
        break;
      case PlatformType.desktop:
        shell = const DesktopShell();
        break;
      case PlatformType.mobile:
      default:
        shell = const MobileShell();
    }

    return MaterialApp(
      title: 'Moonplex',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: ThemeMode.dark,
      home: shell,
    );
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MoonTheme.backgroundPrimary,
      primaryColor: MoonTheme.accentPrimary,
      colorScheme: const ColorScheme.dark(
        primary: MoonTheme.accentPrimary,
        secondary: MoonTheme.accentSecondary,
        surface: MoonTheme.backgroundCard,
        error: MoonTheme.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MoonTheme.backgroundSecondary,
        foregroundColor: MoonTheme.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: MoonTheme.backgroundCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MoonTheme.cardBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MoonTheme.backgroundSecondary,
        selectedItemColor: MoonTheme.accentPrimary,
        unselectedItemColor: MoonTheme.textMuted,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: MoonTheme.textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: MoonTheme.textMuted,
          fontSize: 12,
        ),
      ),
      iconTheme: const IconThemeData(
        color: MoonTheme.textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: MoonTheme.cardBorder,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MoonTheme.backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoonTheme.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoonTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoonTheme.accentGlow, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MoonTheme.accentPrimary,
          foregroundColor: MoonTheme.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MoonTheme.textPrimary,
          side: const BorderSide(color: MoonTheme.textSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MoonTheme.accentPrimary;
          }
          return MoonTheme.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MoonTheme.accentGlow;
          }
          return MoonTheme.cardBorder;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MoonTheme.backgroundCard,
        selectedColor: MoonTheme.accentGlow,
        labelStyle: const TextStyle(color: MoonTheme.textSecondary),
        side: const BorderSide(color: MoonTheme.cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MoonTheme.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MoonTheme.backgroundCard,
        contentTextStyle: TextStyle(color: MoonTheme.textPrimary),
      ),
    );
  }
}

// ============== MAIN ==============

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on mobile
  if (PlatformDetector.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    const ProviderScope(
      child: MoonplexApp(),
    ),
  );
}
