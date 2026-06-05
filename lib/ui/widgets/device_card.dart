import 'dart:async';

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
  final VoidCallback? onLongPress;
  final bool isSelected;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  ConsumerState<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<DeviceCard> {
  bool _isTapped = false;
  Timer? _tapDebounceTimer; // FIXED (Bug #8): Add timer for cleanup

  void _handleTap() {
    if (widget.onTap == null || _isTapped) return;

    setState(() => _isTapped = true);

    // FIXED (Bug #8): Cancel existing timer to prevent conflicts
    _tapDebounceTimer?.cancel();
    
    // FIXED (Bug #8): Reduce delay from 150ms to 100ms for better UX
    _tapDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isTapped = false);
        widget.onTap?.call();
      }
    });
  }

  void _handleLongPress() {
    // If onLongPress callback is provided, use it (for multi-select)
    if (widget.onLongPress != null) {
      widget.onLongPress!();
      return;
    }
    // Otherwise show nickname dialog (default behavior)
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

  // FIXED (Bug #8): Cleanup timer on dispose
  @override
  void dispose() {
    _tapDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(deviceNicknameProvider)[widget.device.id];
    final displayName = nickname ?? widget.device.name;
    final hasNickname = nickname != null;

    final cardColor = widget.isSelected
        ? AppTheme.primaryColor.withOpacity(0.12)
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
        transform: Matrix4.identity()..scale(_isTapped ? 0.97 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor,
                cardColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              borderRadius: BorderRadius.circular(20),
              splashColor: AppTheme.primaryColor.withOpacity(0.15),
              highlightColor: AppTheme.primaryColor.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Platform Icon with enhanced styling
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.device.platform.iconColor.withOpacity(0.2),
                            widget.device.platform.iconColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.device.platform.iconColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          widget.device.platform.icon,
                          size: 30,
                          color: widget.device.platform.iconColor,
                        ),
                      ),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasNickname)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                            ],
                          ),
                          // Show original name if nickname exists
                          if (hasNickname) ...[
                            const SizedBox(height: 4),
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
                          const SizedBox(height: 6),
                          // Platform name with icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  widget.device.platform.icon,
                                  size: 14,
                                  color: widget.device.platform.iconColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.device.platform.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.router_rounded,
                                size: 12,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.device.ipAddress,
                                style:
                                    Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textTertiary,
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Online Indicator with enhanced styling
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: widget.device.isOnline
                                ? AppTheme.successColor
                                : AppTheme.textTertiary,
                            shape: BoxShape.circle,
                            boxShadow: widget.device.isOnline
                                ? [
                                    BoxShadow(
                                      color: AppTheme.successColor.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.device.isOnline
                                    ? AppTheme.successColor
                                    : AppTheme.textTertiary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.device.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.device.isOnline
                                  ? AppTheme.successColor
                                  : AppTheme.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }
}
