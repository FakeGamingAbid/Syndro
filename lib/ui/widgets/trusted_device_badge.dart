import 'package:flutter/material.dart';
import '../../core/models/device.dart';

/// A badge that shows the trust status of a device
class TrustedDeviceBadge extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final bool showLabel;

  const TrustedDeviceBadge({
    super.key,
    required this.device,
    this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!device.trusted) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  'Trust',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                'Trusted',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status indicator showing if device is online/offline
class DeviceStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const DeviceStatusIndicator({
    super.key,
    required this.isOnline,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline 
            ? theme.colorScheme.primary 
            : theme.colorScheme.outline.withOpacity(0.5),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
