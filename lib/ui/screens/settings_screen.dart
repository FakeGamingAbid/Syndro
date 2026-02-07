 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';
import '../../core/providers/device_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
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
              autofocus: true,
              maxLength: 30,
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
              onSubmitted: (_) => _saveNickname(dialogContext, controller.text),
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
    );
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
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================================
          // DEVICE SECTION
          // ============================================
          _buildSectionHeader('Device'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDeviceIcon(currentDevice.platform),
                      color: AppTheme.primaryColor,
                    ),
                  ),
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
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Custom',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: _showEditNicknameDialog,
                    tooltip: 'Edit device name',
                  ),
                  onTap: _showEditNicknameDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wifi_rounded,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  title: const Text('IP Address'),
                  subtitle: Text(currentDevice.ipAddress),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
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
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppTheme.accentColor,
                    ),
                  ),
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
                    icon: const Icon(Icons.copy_rounded, size: 20),
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
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ============================================
          // ABOUT SECTION
          // ============================================
          _buildSectionHeader('About'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: const Text('Version'),
                  subtitle: Text(_version),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.share,
                      color: AppTheme.primaryColor,
                    ),
                  ),
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
                Text(
                  'Made by FakeAbid',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '❤️ Built with Flutter',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
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

  IconData _getDeviceIcon(dynamic platform) {
    final platformStr = platform.toString().toLowerCase();
    if (platformStr.contains('android')) return Icons.phone_android;
    if (platformStr.contains('windows')) return Icons.desktop_windows;
    if (platformStr.contains('linux')) return Icons.computer;
    return Icons.devices;
  }
} 
