 import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';
import '../../core/providers/device_provider.dart';
import '../../core/services/app_settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = 'Loading...';
  bool _autoAcceptTrusted = false;
  final AppSettingsService _settingsService = AppSettingsService();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoAccept = await _settingsService.getAutoAcceptTrusted();
    if (mounted) {
      setState(() {
        _autoAcceptTrusted = autoAccept;
      });
    }
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'Unknown';
        });
      }
    }
  }

  void _showEditNicknameDialog() {
    final currentDevice = ref.read(currentDeviceProvider);
    final currentNickname = ref.read(currentDeviceNicknameProvider);

    final controller = TextEditingController(
      text: currentNickname ?? currentDevice.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Edit Device Name'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This name will be visible to other devices on the network.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: !Platform.isAndroid, // FIXED (Bug #14): Disable on Android to prevent keyboard trap
              maxLength: 30,
              textInputAction: TextInputAction.done, // FIXED (Bug #13): Add text input action
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[<>:"/\\|?*]')),
              ],
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: 'Enter a custom name',
                prefixIcon: const Icon(Icons.devices_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) {
                // FIXED (Bug #13): Dismiss keyboard on submit
                FocusScope.of(dialogContext).unfocus();
                _saveNickname(dialogContext, controller.text);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Original name: ${currentDevice.name}',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(currentDeviceNicknameProvider.notifier)
                  .clearNickname();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device name reset to default'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveNickname(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      // FIXED (Bug #12): Dispose controller when dialog closes
      controller.dispose();
    });
  }

  Future<void> _saveNickname(
      BuildContext dialogContext, String nickname) async {
    final trimmedName = nickname.trim();

    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device name cannot be empty'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (trimmedName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device name must be at least 2 characters'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final success = await ref
        .read(currentDeviceNicknameProvider.notifier)
        .setNickname(trimmedName);

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device name changed to "$trimmedName"'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        ref.read(deviceDiscoveryServiceProvider).refreshDevices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save device name'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final customNickname = ref.watch(currentDeviceNicknameProvider);

    final displayName = customNickname ?? currentDevice.name;
    final hasCustomNickname =
        customNickname != null && customNickname.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.logoGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Settings'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ============================================
            // DEVICE SECTION
            // ============================================
            _buildSectionHeader('Device'),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.cardColor.withOpacity(0.8),
                    AppTheme.surfaceColor.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.devices_rounded,
                    iconColor: AppTheme.primaryColor,
                    iconBgColor: AppTheme.primaryColor.withOpacity(0.15),
                    title: Row(
                      children: [
                        const Text('Device Name'),
                        if (hasCustomNickname) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.logoGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Custom',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(displayName),
                    trailing: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 18),
                      ),
                      onPressed: _showEditNicknameDialog,
                      tooltip: 'Edit device name',
                    ),
                    onTap: _showEditNicknameDialog,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingsTile(
                    icon: Icons.wifi_rounded,
                    iconColor: AppTheme.secondaryColor,
                    iconBgColor: AppTheme.secondaryColor.withOpacity(0.15),
                    title: const Text('IP Address'),
                    subtitle: Text(currentDevice.ipAddress),
                    trailing: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 18),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: currentDevice.ipAddress),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('IP address copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy IP address',
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingsTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: AppTheme.accentColor,
                    iconBgColor: AppTheme.accentColor.withOpacity(0.15),
                    title: const Text('Device ID'),
                    subtitle: Text(
                      currentDevice.id.length > 20
                          ? '${currentDevice.id.substring(0, 20)}...'
                          : currentDevice.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 18),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: currentDevice.id),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy device ID',
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.successColor,
                        size: 24,
                      ),
                    ),
                    title: const Text('Auto-accept from trusted devices'),
                    subtitle: const Text(
                      'Automatically accept transfers from devices you trust',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _autoAcceptTrusted,
                    onChanged: (value) async {
                      // FIXED: Capture ScaffoldMessenger before async gap
                      final messenger = ScaffoldMessenger.of(context);
                      
                      await _settingsService.setAutoAcceptTrusted(value);
                      
                      if (mounted) {
                        setState(() {
                          _autoAcceptTrusted = value;
                        });
                        
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Auto-accept enabled for trusted devices'
                                  : 'Will always ask for approval',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ============================================
            // ABOUT SECTION
            // ============================================
            _buildSectionHeader('About'),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.cardColor.withOpacity(0.8),
                    AppTheme.surfaceColor.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    iconColor: AppTheme.primaryColor,
                    iconBgColor: AppTheme.primaryColor.withOpacity(0.15),
                    title: const Text('Version'),
                    subtitle: Text(_version),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSettingsTile(
                    icon: Icons.share,
                    iconColor: AppTheme.primaryColor,
                    iconBgColor: AppTheme.primaryColor.withOpacity(0.15),
                    title: const Text('Syndro'),
                    subtitle: const Text('Fast & secure file sharing'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Developer Credit
            Center(
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Made by ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                      Text(
                        'FakeAbid',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.logoGradient,
                      borderRadius: BorderRadius.circular(20),
                      // ignore: prefer_const_literals_to_create_immutables
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Built with Flutter',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Widget title,
    required Widget subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withOpacity(0.2),
                      iconColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
      ),
    );
  }
} 
