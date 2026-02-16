import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../core/models/device.dart';
import '../../core/models/transfer.dart';
import '../../core/providers/transfer_provider.dart';

class TransferProgressScreen extends ConsumerStatefulWidget {
  final String transferId;
  final Device? remoteDevice;
  final bool isSender;
  final List<TransferItem> items;

  const TransferProgressScreen({
    super.key,
    required this.transferId,
    this.remoteDevice,
    required this.isSender,
    required this.items,
  });

  @override
  ConsumerState<TransferProgressScreen> createState() =>
      _TransferProgressScreenState();
}

class _TransferProgressScreenState extends ConsumerState<TransferProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<Transfer>? _transferSubscription;
  Transfer? _currentTransfer;
  int _currentFileIndex = 0;
  int _lastBytes = 0;
  double _speed = 0;
  Timer? _speedTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _listenToTransfer();

    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateSpeed();
    });
  }

  void _listenToTransfer() {
    final transferService = ref.read(transferServiceProvider);

    _transferSubscription = transferService.transferStream.listen((transfer) {
      if (transfer.id == widget.transferId && mounted) {
        setState(() {
          _currentTransfer = transfer;

          int totalSize = 0;
          for (int i = 0; i < widget.items.length; i++) {
            totalSize += widget.items[i].size;
            if (transfer.progress.bytesTransferred < totalSize) {
              _currentFileIndex = i;
              break;
            }
            if (i == widget.items.length - 1) {
              _currentFileIndex = i;
            }
          }
        });

        if (transfer.status == TransferStatus.completed) {
          _onTransferComplete();
        }
      }
    });
  }

  // FIXED (Bug #6): Prevent speed overflow by clamping to safe int range  
  void _calculateSpeed() {
    if (_currentTransfer == null || !mounted) return;

    final currentBytes = _currentTransfer!.progress.bytesTransferred;
    final bytesPerSecond = (currentBytes - _lastBytes).clamp(0, double.maxFinite);
    _lastBytes = currentBytes;

    if (mounted) {
      setState(() {
        // FIXED: Clamp speed to prevent overflow (max ~2GB/s which is realistic)
        _speed = bytesPerSecond.toDouble().clamp(0, 2147483647);
      });
    }
  }

  void _onTransferComplete() {
    // Show completion message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.items.length == 1
                ? 'Transfer complete: ${widget.items.first.name}'
                : 'Transfer complete: ${widget.items.length} files',
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    // FIXED (Bug #7): Enhanced auto-pop with dual mounted checks
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && context.mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _cancelTransfer() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Cancel Transfer?'),
        content: const Text('Are you sure you want to cancel this transfer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final transferService = ref.read(transferServiceProvider);
              transferService.cancelTransfer(widget.transferId);
              Navigator.of(context).pop(false);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // FIXED (Bug #3, #5, #6): Ensure all resources are properly disposed with try-catch
  @override
  void dispose() {
    // FIXED (Bug #5): Stop animation BEFORE disposing
    try {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.dispose();
    } catch (e) {
      debugPrint('Error disposing pulse controller: $e');
    }
    
    try {
      _transferSubscription?.cancel();
      _transferSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling transfer subscription: $e');
    }
    
    try {
      _speedTimer?.cancel();
      _speedTimer = null;
    } catch (e) {
      debugPrint('Error cancelling speed timer: $e');
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX (Bug #17): Improved PopScope with proper state handling
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final status = _currentTransfer?.status;
        
        // Allow immediate pop for completed/failed/cancelled transfers
        if (status == TransferStatus.completed ||
            status == TransferStatus.failed ||
            status == TransferStatus.cancelled) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
        
        // For active transfers, show confirmation dialog
        if (status == TransferStatus.transferring ||
            status == TransferStatus.connecting ||
            status == TransferStatus.pending) {
          final shouldCancel = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text('Cancel Transfer?'),
              content: const Text('Are you sure you want to cancel this transfer?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Continue Transfer'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  child: const Text('Cancel Transfer'),
                ),
              ],
            ),
          );
          
          if (shouldCancel == true && context.mounted) {
            _cancelTransfer();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(widget.isSender ? 'Sending Files' : 'Receiving Files'),
          backgroundColor: AppTheme.backgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final status = _currentTransfer?.status;
              
              if (status == TransferStatus.completed ||
                  status == TransferStatus.failed ||
                  status == TransferStatus.cancelled) {
                Navigator.of(context).pop();
              } else {
                // Show confirmation for active transfers
                final shouldCancel = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    title: const Text('Cancel Transfer?'),
                    content: const Text('Are you sure you want to cancel this transfer?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Continue Transfer'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                        child: const Text('Cancel Transfer'),
                      ),
                    ],
                  ),
                );
                
                if (shouldCancel == true && mounted) {
                  _cancelTransfer();
                }
              }
            },
          ),
        ),
        body: Container(
          // FIX: Removed const - AppTheme.backgroundGradient is not a compile-time constant
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildDeviceCard(),
                  const SizedBox(height: 32),
                  Expanded(child: _buildProgressSection()),
                  _buildActionButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardColor.withOpacity(0.9),
            AppTheme.surfaceColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (widget.isSender
                  ? AppTheme.primaryColor
                  : AppTheme.successColor)
              .withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.isSender
                    ? AppTheme.primaryColor
                    : AppTheme.successColor)
                .withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (widget.isSender
                          ? AppTheme.primaryColor
                          : AppTheme.successColor)
                      .withOpacity(0.25),
                  (widget.isSender
                          ? AppTheme.primaryColor
                          : AppTheme.successColor)
                      .withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (widget.isSender
                        ? AppTheme.primaryColor
                        : AppTheme.successColor)
                    .withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.isSender ? Icons.upload_rounded : Icons.download_rounded,
              color: widget.isSender
                  ? AppTheme.primaryColor
                  : AppTheme.successColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSender ? 'Sending to' : 'Receiving from',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.remoteDevice?.name ?? 'Unknown Device',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _currentTransfer?.status ?? TransferStatus.connecting;

    Color color;
    String text;

    switch (status) {
      case TransferStatus.connecting:
        color = AppTheme.warningColor;
        text = 'Connecting';
        break;
      case TransferStatus.pending:
        color = AppTheme.warningColor;
        text = 'Waiting';
        break;
      case TransferStatus.transferring:
        color = AppTheme.primaryColor;
        text = 'Transferring';
        break;
      case TransferStatus.completed:
        color = AppTheme.successColor;
        text = 'Completed';
        break;
      case TransferStatus.failed:
        color = AppTheme.errorColor;
        text = 'Failed';
        break;
      case TransferStatus.cancelled:
        color = AppTheme.textTertiary;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final status = _currentTransfer?.status ?? TransferStatus.connecting;

    switch (status) {
      case TransferStatus.connecting:
      case TransferStatus.pending:
        return _buildWaitingState();
      case TransferStatus.transferring:
        return _buildTransferringState();
      case TransferStatus.completed:
        return _buildCompletedState();
      case TransferStatus.failed:
        return _buildFailedState();
      case TransferStatus.cancelled:
        return _buildCancelledState();
    }
  }

  Widget _buildWaitingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor
                    .withOpacity(0.1 + _pulseController.value * 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isSender ? Icons.upload_rounded : Icons.download_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          _currentTransfer?.status == TransferStatus.pending
              ? 'Waiting for approval...'
              : 'Connecting...',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: AppTheme.primaryColor),
      ],
    );
  }

  Widget _buildTransferringState() {
    final progress = _currentTransfer?.progress;
    final percentage = progress?.percentage ?? 0;
    final bytesTransferred = progress?.bytesTransferred ?? 0;
    final totalBytes = progress?.totalBytes ?? 1;

    final currentFile = _currentFileIndex < widget.items.length
        ? widget.items[_currentFileIndex]
        : widget.items.last;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getFileIcon(currentFile.name),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentFile.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'File ${_currentFileIndex + 1} of ${widget.items.length}',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 12,
                  backgroundColor: AppTheme.cardColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatSize(bytesTransferred)} / ${_formatSize(totalBytes)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.speed,
                label: 'Speed',
                value: '${_formatSize(_speed.toInt())}/s',
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_outlined,
                label: 'Remaining',
                value: _calculateRemainingTime(),
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppTheme.cardColor,
        ),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final isCompleted = index < _currentFileIndex;
          final isCurrent = index == _currentFileIndex;

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.successColor.withOpacity(0.2)
                    : isCurrent
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : _getFileIcon(item.name),
                color: isCompleted
                    ? AppTheme.successColor
                    : isCurrent
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                size: 20,
              ),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                color: isCompleted || isCurrent
                    ? AppTheme.textPrimary
                    : AppTheme.textTertiary,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              item.sizeFormatted,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Transfer Complete!',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.items.length} file${widget.items.length == 1 ? '' : 's'} ${widget.isSender ? 'sent' : 'received'} successfully',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.errorColor,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Transfer Failed',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _currentTransfer?.errorMessage ?? 'An unknown error occurred',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.textTertiary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cancel_outlined,
            size: 80,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Transfer Cancelled',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    final status = _currentTransfer?.status ?? TransferStatus.connecting;

    if (status == TransferStatus.completed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (status == TransferStatus.failed ||
        status == TransferStatus.cancelled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cardColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Close',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _cancelTransfer,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: const BorderSide(color: AppTheme.errorColor),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Cancel Transfer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _calculateRemainingTime() {
    if (_speed <= 0) return '--:--';

    final progress = _currentTransfer?.progress;
    if (progress == null) return '--:--';

    final remainingBytes = progress.totalBytes - progress.bytesTransferred;
    final seconds = remainingBytes / _speed;

    if (seconds.isInfinite || seconds.isNaN) return '--:--';

    final duration = Duration(seconds: seconds.toInt());

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg'];
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    const archiveExts = ['zip', 'rar', '7z', 'tar', 'gz'];

    if (imageExts.contains(ext)) return Icons.image;
    if (videoExts.contains(ext)) return Icons.video_file;
    if (audioExts.contains(ext)) return Icons.audio_file;
    if (docExts.contains(ext)) return Icons.description;
    if (archiveExts.contains(ext)) return Icons.folder_zip;

    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
