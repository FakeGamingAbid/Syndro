import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  bool _isLoading = false;

  // Permission states
  Map<String, bool> _permissionStatus = {
    'storage': false,
    'notifications': false,
    'wifi': true, // WiFi doesn't need runtime permission
  };

  static final List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.folder_rounded,
      title: 'Storage',
      description: 'Save received files to your device',
      iconColor: AppTheme.primaryColor,
      key: 'storage',
    ),
    _PermissionItem(
      icon: Icons.wifi_rounded,
      title: 'WiFi Access',
      description: 'Discover devices on local network',
      iconColor: AppTheme.secondaryColor,
      key: 'wifi',
    ),
    _PermissionItem(
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      description: 'Show transfer progress & requests',
      iconColor: AppTheme.accentColor,
      key: 'notifications',
    ),
  ];

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  List<String> get _missingPermissions {
    if (!Platform.isAndroid) return [];

    List<String> missing = [];
    if (!(_permissionStatus['storage'] ?? false)) missing.add('Storage');
    if (!(_permissionStatus['notifications'] ?? false)) {
      missing.add('Notifications');
    }
    return missing;
  }

  bool get _allGranted => _missingPermissions.isEmpty;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      final storage = await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
      final notifications = await Permission.notification.isGranted;

      if (!mounted) return;

      setState(() {
        _permissionStatus = {
          'storage': storage,
          'notifications': notifications,
          'wifi': true,
        };
      });
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (_isLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // Request storage permission
      if (!(_permissionStatus['storage'] ?? false)) {
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }
      }

      // Request notification permission
      if (!(_permissionStatus['notifications'] ?? false)) {
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      }

      await _checkPermissions();
    } catch (e) {
      debugPrint('Permission request error: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Auto-continue if all granted
    if (_allGranted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _continue();
    }
  }

  Future<void> _continue() async {
    if (_isLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_onboarding_complete', true);
    } catch (e) {
      debugPrint('Failed to save permissions status: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(),
      ),
    );
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _isDesktop ? 450.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: _isLoading ? null : _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: _buildContent(),
                ),

                // Page indicator (single dot)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 24,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    _isDesktop ? 48 : 32,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: _isDesktop ? 220 : double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (Platform.isAndroid && !_allGranted
                                  ? _requestPermissions
                                  : _continue),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.primaryColor.withOpacity(0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  Platform.isAndroid && !_allGranted
                                      ? 'GRANT PERMISSIONS'
                                      : 'GET STARTED',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      // Missing permissions text
                      if (Platform.isAndroid &&
                          _missingPermissions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Missing: ${_missingPermissions.join(", ")}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon - same style as other onboarding pages
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.security_rounded,
              size: 56,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          const Text(
            'PERMISSIONS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Syndro needs a few permissions to share files seamlessly',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Permissions list
          _buildPermissionsList(),
        ],
      ),
    );
  }

  Widget _buildPermissionsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _permissions.asMap().entries.map((entry) {
          final index = entry.key;
          final permission = entry.value;
          final isLast = index == _permissions.length - 1;
          final isGranted = _permissionStatus[permission.key] ?? false;

          return Column(
            children: [
              _buildPermissionTile(permission, isGranted),
              if (!isLast)
                const Divider(
                  color: AppTheme.surfaceColor,
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionTile(_PermissionItem permission, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: permission.iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              permission.icon,
              color: permission.iconColor,
              size: 20,
            ),
          ),

          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  permission.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          if (Platform.isAndroid)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isGranted
                    ? AppTheme.successColor.withOpacity(0.2)
                    : AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGranted
                    ? Icons.check_rounded
                    : Icons.horizontal_rule_rounded,
                size: 14,
                color: isGranted ? AppTheme.successColor : AppTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final String key;

  _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.key,
  });
}
