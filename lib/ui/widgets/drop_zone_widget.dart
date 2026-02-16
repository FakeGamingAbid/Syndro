import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../core/models/transfer.dart';
import '../theme/app_theme.dart';

class DropZoneWidget extends StatefulWidget {
  final Widget child;
  final Function(List<TransferItem> items) onFilesDropped;
  final bool enabled;

  const DropZoneWidget({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.enabled = true,
  });

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // FIXED (Bug #21): Stop animation before disposing
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (!widget.enabled) return;

    final items = <TransferItem>[];

    for (final xFile in details.files) {
      try {
        final path = xFile.path;
        final file = File(path);
        final directory = Directory(path);

        if (await file.exists()) {
          final stat = await file.stat();
          items.add(TransferItem(
            name: xFile.name,
            path: path,
            size: stat.size,
            isDirectory: false,
          ));
        } else if (await directory.exists()) {
          // Calculate folder size
          int folderSize = 0;
          await for (final entity in directory.list(recursive: true)) {
            if (entity is File) {
              folderSize += await entity.length();
            }
          }

          items.add(TransferItem(
            name: xFile.name,
            path: path,
            size: folderSize,
            isDirectory: true,
          ));
        }
      } catch (e) {
        debugPrint('Error processing dropped file: $e');
      }
    }

    if (items.isNotEmpty) {
      widget.onFilesDropped(items);
    }

    // FIXED (Bug #23): Add mounted check before setState
    if (mounted) {
      setState(() => _isDragging = false);
      _animationController.reverse();
    }
  }

  void _handleDragEntered(DropEventDetails details) {
    if (!widget.enabled || !mounted) return;
    setState(() => _isDragging = true);
    _animationController.forward();
  }

  void _handleDragExited(DropEventDetails details) {
    if (!mounted) return;
    setState(() => _isDragging = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Only enable on desktop platforms
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return widget.child;
    }

    return DropTarget(
      onDragDone: _handleDrop,
      onDragEntered: _handleDragEntered,
      onDragExited: _handleDragExited,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              // Main content with scale animation
              Transform.scale(
                scale: _scaleAnimation.value,
                child: widget.child,
              ),

              // Drop overlay
              if (_isDragging)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 3,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.file_download_rounded,
                                size: 64,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Drop files here',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Release to add files for transfer',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A simple drop zone for empty states
class EmptyDropZone extends StatefulWidget {
  final Function(List<TransferItem> items) onFilesDropped;
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;

  const EmptyDropZone({
    super.key,
    required this.onFilesDropped,
    required this.onPickFiles,
    required this.onPickFolder,
  });

  @override
  State<EmptyDropZone> createState() => _EmptyDropZoneState();
}

class _EmptyDropZoneState extends State<EmptyDropZone>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // FIXED (Bug #21): Stop repeating animation before disposing
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final items = <TransferItem>[];

    for (final xFile in details.files) {
      try {
        final path = xFile.path;
        final file = File(path);
        final directory = Directory(path);

        if (await file.exists()) {
          final stat = await file.stat();
          items.add(TransferItem(
            name: xFile.name,
            path: path,
            size: stat.size,
            isDirectory: false,
          ));
        } else if (await directory.exists()) {
          int folderSize = 0;
          await for (final entity in directory.list(recursive: true)) {
            if (entity is File) {
              folderSize += await entity.length();
            }
          }

          items.add(TransferItem(
            name: xFile.name,
            path: path,
            size: folderSize,
            isDirectory: true,
          ));
        }
      } catch (e) {
        debugPrint('Error processing dropped file: $e');
      }
    }

    if (items.isNotEmpty) {
      widget.onFilesDropped(items);
    }

    // FIXED (Bug #23): Add mounted check before setState
    if (mounted) {
      setState(() => _isDragging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _isDragging
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isDragging
              ? AppTheme.primaryColor
              : AppTheme.borderColor.withOpacity(0.3),
          width: _isDragging ? 3 : 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isDragging ? 1.1 : _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDragging
                        ? Icons.file_download_rounded
                        : Icons.folder_open_rounded,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            _isDragging ? 'Drop files here!' : 'No files selected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _isDragging ? AppTheme.primaryColor : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDesktop
                ? 'Drag & drop files here, or use the buttons below'
                : 'Select files or folders to send',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.insert_drive_file_rounded,
                label: 'Files',
                onTap: widget.onPickFiles,
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: Icons.folder_rounded,
                label: 'Folder',
                onTap: widget.onPickFolder,
              ),
            ],
          ),
        ],
      ),
    );

    if (isDesktop) {
      return DropTarget(
        onDragDone: _handleDrop,
        onDragEntered: (_) {
          if (mounted) setState(() => _isDragging = true);
        },
        onDragExited: (_) {
          if (mounted) setState(() => _isDragging = false);
        },
        child: content,
      );
    }

    return content;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
