import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../core/models/device.dart';
import '../../core/providers/device_nickname_provider.dart';
import 'device_nickname_dialog.dart';

/// Device card with nickname support
class DeviceCard extends ConsumerStatefulWidget {
  final Device device;
  final VoidCallback? onTap;
  final bool isSelected;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.isSelected = false,
  });

  @override
  ConsumerState<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<DeviceCard> {
  bool _isTapped = false;

  void _handleTap() {
    if (widget.onTap == null) return;

    setState(() => _isTapped = true);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isTapped = false);
        widget.onTap?.call();
      }
    });
  }

  void _handleLongPress() {
    showDialog(
      context: context,
      builder: (context) {
        final nickname = ref.read(deviceNicknameProvider)[widget.device.id];
        return DeviceNicknameDialog(
          deviceName: widget.device.name,
          currentNickname: nickname,
          onSave: (newNickname) async {
            await ref
                .read(deviceNicknameProvider.notifier)
                .setNickname(widget.device.id, newNickname ?? '');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(deviceNicknameProvider)[widget.device.id];
    final displayName = nickname ?? widget.device.name;
    final hasNickname = nickname != null;

    final cardColor = widget.isSelected
        ? const Color(0x337B5EF2)
        : AppTheme.cardColor;
    final borderColor = widget.isSelected
        ? AppTheme.primaryColor
        : Colors.transparent;

    return Semantics(
      label:
          '$displayName, ${widget.device.platform.displayName}, ${widget.device.isOnline ? "Online" : "Offline"}',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isTapped ? 0.98 : 1.0),
        child: Card(
          elevation: widget.isSelected ? 8 : (_isTapped ? 4 : 0),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: borderColor,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppTheme.primaryColor.withOpacity(0.1),
            highlightColor: AppTheme.primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Platform Icon (Changed from emoji to Icon)
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.device.platform.iconColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.device.platform.iconColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            widget.device.platform.icon,
                            size: 28,
                            color: widget.device.platform.iconColor,
                          ),
                        ),
                      ),
                      // Tap feedback overlay
                      if (_isTapped)
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Device Info with nickname support
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display name (nickname or original)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasNickname)
                              const Icon(
                                Icons.edit,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                          ],
                        ),
                        // Show original name if nickname exists
                        if (hasNickname) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.device.name,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Platform name with icon
                        Row(
                          children: [
                            Icon(
                              widget.device.platform.icon,
                              size: 14,
                              color: widget.device.platform.iconColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.device.platform.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.device.ipAddress,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Online Indicator with label
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: widget.device.isOnline
                              ? AppTheme.successColor
                              : AppTheme.textTertiary,
                          shape: BoxShape.circle,
                          boxShadow: widget.device.isOnline
                              ? [
                                  BoxShadow(
                                    color:
                                        AppTheme.successColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.device.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.device.isOnline
                              ? AppTheme.successColor
                              : AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
