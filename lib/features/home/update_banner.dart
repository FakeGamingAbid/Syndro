import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonplex/core/config/remote_config_service.dart';
import 'package:moonplex/core/theme/moon_theme.dart';

// ============== UPDATE BANNER ==============

class UpdateBanner extends StatefulWidget {
  final String version;
  final VoidCallback? onDismiss;

  const UpdateBanner({
    super.key,
    required this.version,
    this.onDismiss,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MoonTheme.accentGlow,
              MoonTheme.accentGlow.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Moon icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Moonplex v${widget.version} is available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to download the latest version',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Download button
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(
                      'https://github.com/moonplex/moonplex/releases');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MoonTheme.accentGlow,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Download',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              // Dismiss button
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== FORCE UPDATE DIALOG ==============

class ForceUpdateDialog extends StatelessWidget {
  final String version;
  final String message;

  const ForceUpdateDialog({
    super.key,
    required this.version,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MoonTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Moon icon with glow
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MoonTheme.accentGlow.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: MoonTheme.accentPrimary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              'Update Required',
              style: TextStyle(
                color: MoonTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MoonTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Moonplex v$version',
              style: const TextStyle(
                color: MoonTheme.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            // Download button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(
                      'https://github.com/moonplex/moonplex/releases');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoonTheme.accentPrimary,
                  foregroundColor: MoonTheme.backgroundPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Download Update',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== UPDATE CHECKER ==============

class UpdateChecker {
  static Future<
      ({
        bool hasUpdate,
        bool isForceUpdate,
        String? version,
        String? message
      })> checkForUpdate() async {
    try {
      final config = await RemoteConfigService.getConfig();

      final currentVersion = config['app_version'] as String? ?? '1.0.0';
      final minVersion = config['min_version'] as String? ?? '1.0.0';
      final updateMessage = config['update_message'] as String?;
      final forceUpdateVersions =
          (config['force_update_versions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

      // Parse versions
      final current = _parseVersion(currentVersion);
      final min = _parseVersion(minVersion);

      // Check if update is needed
      if (_compareVersions(current, min) < 0) {
        return (
          hasUpdate: true,
          isForceUpdate: true,
          version: minVersion,
          message: updateMessage ??
              'This version of Moonplex is no longer supported. Please update to continue using the app.',
        );
      }

      // Check if force update for specific versions
      if (forceUpdateVersions.contains(currentVersion)) {
        return (
          hasUpdate: true,
          isForceUpdate: true,
          version: currentVersion,
          message: updateMessage ??
              'Please update to the latest version of Moonplex.',
        );
      }

      return (
        hasUpdate: false,
        isForceUpdate: false,
        version: null,
        message: null
      );
    } catch (e) {
      return (
        hasUpdate: false,
        isForceUpdate: false,
        version: null,
        message: null
      );
    }
  }

  static List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static int _compareVersions(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) {
        return a[i].compareTo(b[i]);
      }
    }
    return a.length.compareTo(b.length);
  }
}

// ============== SOFT UPDATE BANNER WIDGET ==============

class SoftUpdateBanner extends StatefulWidget {
  const SoftUpdateBanner({super.key});

  @override
  State<SoftUpdateBanner> createState() => _SoftUpdateBannerState();
}

class _SoftUpdateBannerState extends State<SoftUpdateBanner> {
  bool _isDismissed = false;
  String? _updateVersion;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateChecker.checkForUpdate();
    if (result.hasUpdate && !result.isForceUpdate && result.version != null) {
      if (mounted) {
        setState(() {
          _updateVersion = result.version;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || _updateVersion == null) {
      return const SizedBox.shrink();
    }

    return UpdateBanner(
      version: _updateVersion!,
      onDismiss: () {
        setState(() {
          _isDismissed = true;
        });
      },
    );
  }
}
