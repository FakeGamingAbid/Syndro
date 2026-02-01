import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/device.dart';
import '../../core/providers/trusted_devices_provider.dart';
import 'trusted_device_badge.dart';

/// A list tile for displaying a device with trust actions
class DeviceListTile extends ConsumerWidget {
  final Device device;
  final VoidCallback? onTap;
  final bool showTrustAction;

  const DeviceListTile({
    super.key,
    required this.device,
    this.onTap,
    this.showTrustAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actionsNotifier = ref.read(trustedDeviceActionsProvider.notifier);

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: device.trusted
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              device.platform.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DeviceStatusIndicator(isOnline: device.isOnline),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              device.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: device.trusted ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showTrustAction)
            TrustedDeviceBadge(
              device: device,
              onTap: () => _toggleTrust(context, ref, actionsNotifier),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${device.platform.displayName} • ${device.ipAddress}:${device.port}',
            style: theme.textTheme.bodySmall,
          ),
          if (device.trusted && device.trustedAt != null)
            Text(
              'Trusted ${_formatTimeAgo(device.trustedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: onTap,
      enabled: device.isOnline,
    );
  }

  Future<void> _toggleTrust(
    BuildContext context,
    WidgetRef ref,
    TrustedDeviceNotifier notifier,
  ) async {
    if (device.trusted) {
      // Show confirmation dialog before untrusting
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Trust?'),
          content: Text(
            'Are you sure you want to remove ${device.name} from your trusted devices?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await notifier.untrustDevice(device.id);
      }
    } else {
      // Trust the device
      await notifier.trustDevice(device.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name} is now trusted'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => notifier.untrustDevice(device.id),
            ),
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      return '${diff.inDays ~/ 365}y ago';
    } else if (diff.inDays > 30) {
      return '${diff.inDays ~/ 30}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}

/// Section header for device lists
class DeviceSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? action;

  const DeviceSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
