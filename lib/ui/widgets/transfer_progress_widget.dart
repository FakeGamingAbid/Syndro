import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/models/transfer.dart';

class TransferProgressWidget extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TransferProgressWidget({
    super.key,
    required this.transfer,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (transfer.status == TransferStatus.transferring &&
                    onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                    color: AppTheme.errorColor,
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // File names
            Text(
              _getFileNames(),
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),

            // Progress bar
            if (transfer.status == TransferStatus.transferring ||
                transfer.status == TransferStatus.connecting) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: transfer.progress.percentage / 100,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceColor,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 12),

              // Progress info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    transfer.progress.progressFormatted,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${transfer.progress.percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Speed and ETA
              if (transfer.progress.speed > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transfer.progress.speedFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accentColor,
                          ),
                    ),
                    if (transfer.progress.eta != null)
                      Text(
                        'ETA: ${_formatDuration(transfer.progress.eta!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
            ],

            // Completed status
            if (transfer.status == TransferStatus.completed)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.successColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Transfer completed',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.successColor,
                        ),
                  ),
                ],
              ),

            // Failed status with Retry button
            if (transfer.status == TransferStatus.failed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error,
                          color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Transfer failed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.errorColor,
                            ),
                      ),
                    ],
                  ),
                  // FIX (Bug #4): Safe null check before accessing errorMessage
                  if (transfer.errorMessage != null && transfer.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      transfer.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.errorColor,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Retry button
                  if (onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry Transfer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),

            // Cancelled status with Retry button
            if (transfer.status == TransferStatus.cancelled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel,
                          color: AppTheme.warningColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Transfer cancelled',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.warningColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Retry button for cancelled transfers too
                  if (onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Again'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.connecting:
        return 'Connecting...';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getFileNames() {
    if (transfer.items.isEmpty) return 'No files';
    if (transfer.items.length == 1) {
      return transfer.items.first.name;
    }
    return '${transfer.items.first.name} and ${transfer.items.length - 1} more';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
