 import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/app_settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = 'Loading...';
  bool _autoAcceptTrusted = false;
  int _autoDeleteDays = 30;
  final AppSettingsService _settingsService = AppSettingsService();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoAccept = await _settingsService.getAutoAcceptTrusted();
    final autoDeleteDays = await _settingsService.getAutoDeleteHistoryDays();
    if (mounted) {
      setState(() {
        _autoAcceptTrusted = autoAccept;
        _autoDeleteDays = autoDeleteDays;
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
                  // Language selector
                  Consumer(
                    builder: (context, ref, child) {
                      final currentLocale = ref.watch(localeProvider);
                      final currentAppLocale = currentLocale == null 
                          ? null 
                          : supportedLocales.firstWhere(
                              (l) => l.code == currentLocale.languageCode,
                              orElse: () => supportedLocales.first,
                            );
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.language,
                            color: AppTheme.infoColor,
                            size: 24,
                          ),
                        ),
                        title: const Text('Language'),
                        subtitle: Text(
                          currentAppLocale?.name ?? 'System Default',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: DropdownButton<String>(
                          value: currentAppLocale?.code ?? 'system',
                          underline: const SizedBox(),
                          dropdownColor: AppTheme.cardColor,
                          items: [
                            const DropdownMenuItem(
                              value: 'system',
                              child: Text('System Default'),
                            ),
                            ...supportedLocales.map((locale) => DropdownMenuItem(
                              value: locale.code,
                              child: Text(locale.name),
                            )),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            
                            final localeNotifier = ref.read(localeProvider.notifier);
                            if (value == 'system') {
                              await localeNotifier.setLocale(null);
                            } else {
                              final selectedLocale = supportedLocales.firstWhere(
                                (l) => l.code == value,
                              );
                              await localeNotifier.setLocale(selectedLocale);
                            }
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Language changed. Restart app to fully apply.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 60),
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
                  const Divider(height: 1, indent: 60),
                  // Auto-delete history setting
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_delete_outlined,
                        color: AppTheme.warningColor,
                        size: 24,
                      ),
                    ),
                    title: const Text('Auto-delete history'),
                    subtitle: Text(
                      _autoDeleteDays == 0
                          ? 'Disabled'
                          : 'Delete transfers older than $_autoDeleteDays days',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButton<int>(
                      value: _autoDeleteDays,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Disabled')),
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                        DropdownMenuItem(value: 90, child: Text('90 days')),
                        DropdownMenuItem(value: 365, child: Text('1 year')),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          final messenger = ScaffoldMessenger.of(context);
                          
                          await _settingsService.setAutoDeleteHistoryDays(value);
                          
                          // Also delete old transfers now
                          if (value > 0) {
                            await DatabaseHelper.instance.deleteOldTransfers(olderThanDays: value);
                          }
                          
                          if (mounted) {
                            setState(() {
                              _autoDeleteDays = value;
                            });
                            
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  value == 0
                                      ? 'Auto-delete disabled'
                                      : 'History older than $value days will be deleted',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ============================================
            // TRUSTED DEVICES SECTION
            // ============================================
            _buildSectionHeader('Trusted Devices'),
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
              child: Consumer(
                builder: (context, ref, child) {
                  final trustedDevices = ref.watch(trustedDevicesProvider);
                  
                  if (trustedDevices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 48,
                            color: AppTheme.textTertiary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No trusted devices',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accept transfers to add trusted devices',
                            style: TextStyle(
                              color: AppTheme.textTertiary.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: [
                      ...trustedDevices.map((device) => ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            color: AppTheme.successColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          device.senderName.isNotEmpty 
                              ? device.senderName 
                              : 'Unknown Device',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Trusted since ${_formatDate(device.trustedAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Revoke trust',
                              onPressed: () async {
                                // FIXED: Capture ScaffoldMessenger before async gap
                                final messenger = ScaffoldMessenger.of(context);
                                
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.surfaceColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text('Revoke Trust?'),
                                    content: Text(
                                      'Are you sure you want to remove "${device.senderName.isNotEmpty ? device.senderName : 'this device'}" from trusted devices?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true) {
                                  final service = ref.read(transferServiceProvider);
                                  await service.revokeTrust(device.senderId);
                                  
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Device removed from trusted list'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      )),
                      if (trustedDevices.isNotEmpty) ...[
                        const Divider(height: 1, indent: 60),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Clear All Trusted Devices',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () async {
                            // FIXED: Capture ScaffoldMessenger before async gap
                            final messenger = ScaffoldMessenger.of(context);
                            
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppTheme.surfaceColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text('Clear All Trusted Devices?'),
                                content: const Text(
                                  'This will remove all devices from your trusted list. You will need to re-accept transfers from them.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Clear All'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                              final service = ref.read(transferServiceProvider);
                              await service.clearTrustedSenders();
                              
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('All trusted devices cleared'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  );
                },
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }
} 
