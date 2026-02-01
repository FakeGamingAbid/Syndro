import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/trusted_devices_provider.dart';
import '../../core/models/device.dart';
import '../widgets/device_list_tile.dart';

/// Screen showing trusted devices with management options
class TrustedDevicesScreen extends ConsumerWidget {
  const TrustedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDevicesAsync = ref.watch(allDevicesStreamProvider);
    final trustedDevicesAsync = ref.watch(trustedDevicesStreamProvider);
    final currentDevice = ref.watch(currentDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(trustedDeviceActionsProvider.notifier).refreshDevices();
            },
            tooltip: 'Refresh devices',
          ),
        ],
      ),
      body: allDevicesAsync.when(
        data: (devices) {
          // Separate devices into categories
          final trustedOnline = devices
              .where((d) => d.trusted && d.isOnline && d.id != currentDevice.id)
              .toList();
          final trustedOffline = devices
              .where((d) => d.trusted && !d.isOnline && d.id != currentDevice.id)
              .toList();
          final discovered = devices
              .where((d) => !d.trusted && d.id != currentDevice.id)
              .toList();

          if (devices.isEmpty || (devices.length == 1 && devices.first.id == currentDevice.id)) {
            return _EmptyDevicesView(
              onRefresh: () => ref.read(trustedDeviceActionsProvider.notifier).refreshDevices(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(trustedDeviceActionsProvider.notifier).refreshDevices(),
            child: ListView(
              children: [
                // This Device
                _ThisDeviceTile(device: currentDevice),
                const Divider(),

                // Trusted Online Devices
                if (trustedOnline.isNotEmpty) ...[
                  DeviceSectionHeader(
                    title: 'Trusted Online',
                    count: trustedOnline.length,
                  ),
                  ...trustedOnline.map((device) => DeviceListTile(
                        device: device,
                        onTap: () => _showDeviceOptions(context, ref, device),
                      )),
                  const Divider(),
                ],

                // Trusted Offline Devices
                if (trustedOffline.isNotEmpty) ...[
                  DeviceSectionHeader(
                    title: 'Trusted (Offline)',
                    count: trustedOffline.length,
                  ),
                  ...trustedOffline.map((device) => DeviceListTile(
                        device: device,
                        onTap: () => _showDeviceOptions(context, ref, device),
                      )),
                  const Divider(),
                ],

                // Discovered Devices
                if (discovered.isNotEmpty) ...[
                  DeviceSectionHeader(
                    title: 'Nearby Devices',
                    count: discovered.length,
                    action: TextButton.icon(
                      onPressed: () => _trustAllDiscovered(context, ref, discovered),
                      icon: const Icon(Icons.verified_user, size: 16),
                      label: const Text('Trust All'),
                    ),
                  ),
                  ...discovered.map((device) => DeviceListTile(
                        device: device,
                        onTap: () => _showDeviceOptions(context, ref, device),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.read(trustedDeviceActionsProvider.notifier).refreshDevices(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceOptions(BuildContext context, WidgetRef ref, Device device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(device.platform.icon),
              ),
              title: Text(device.name),
              subtitle: Text('${device.platform.displayName} • ${device.ipAddress}'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                device.trusted ? Icons.verified_user : Icons.shield_outlined,
                color: device.trusted ? Colors.green : null,
              ),
              title: Text(device.trusted ? 'Remove Trust' : 'Trust This Device'),
              subtitle: Text(
                device.trusted
                    ? 'Remove from trusted devices'
                    : 'Automatically accept transfers from this device',
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(trustedDeviceActionsProvider.notifier).toggleTrust(device.id);
              },
            ),
            if (device.trusted)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Send Files'),
                subtitle: const Text('Start a file transfer'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to file picker
                  // Navigator.push(context, MaterialPageRoute(...));
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Device Info'),
              onTap: () {
                Navigator.pop(context);
                _showDeviceInfo(context, device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceInfo(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'ID', value: device.id),
            _InfoRow(label: 'Platform', value: device.platform.displayName),
            _InfoRow(label: 'IP Address', value: device.ipAddress),
            _InfoRow(label: 'Port', value: device.port.toString()),
            _InfoRow(label: 'Status', value: device.isOnline ? 'Online' : 'Offline'),
            _InfoRow(label: 'Trusted', value: device.trusted ? 'Yes' : 'No'),
            if (device.trustedAt != null)
              _InfoRow(
                label: 'Trusted Since',
                value: _formatDate(device.trustedAt!),
              ),
            _InfoRow(
              label: 'Last Seen',
              value: _formatDate(device.lastSeen),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _trustAllDiscovered(BuildContext context, WidgetRef ref, List<Device> devices) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trust All Devices?'),
        content: Text(
          'This will mark all ${devices.length} discovered devices as trusted. '
          'They will be able to send files to you without confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trust All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(trustedDeviceActionsProvider.notifier);
      for (final device in devices) {
        await notifier.trustDevice(device.id);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${devices.length} devices trusted'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ThisDeviceTile extends StatelessWidget {
  final Device device;

  const _ThisDeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          device.platform.icon,
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
      ),
      title: Row(
        children: [
          Text(device.name),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'YOU',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text('${device.platform.displayName} • ${device.ipAddress}:${device.port}'),
    );
  }
}

class _EmptyDevicesView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyDevicesView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure other devices are on the same WiFi network',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
