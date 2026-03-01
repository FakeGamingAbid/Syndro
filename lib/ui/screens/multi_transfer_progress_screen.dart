import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../core/models/device.dart';
import '../../core/models/transfer.dart';
import '../../core/providers/transfer_provider.dart';

/// Screen for tracking multiple simultaneous transfers
class MultiTransferProgressScreen extends ConsumerStatefulWidget {
  final List<String> transferIds;
  final List<Device> recipients;
  final List<TransferItem> items;
  final Map<String, String>? initialErrors;

  const MultiTransferProgressScreen({
    super.key,
    required this.transferIds,
    required this.recipients,
    required this.items,
    this.initialErrors,
  });

  @override
  ConsumerState<MultiTransferProgressScreen> createState() => _MultiTransferProgressScreenState();
}

class _MultiTransferProgressScreenState extends ConsumerState<MultiTransferProgressScreen> {
  final Map<String, Transfer> _transfers = {};
  final Map<String, String> _errors = {};
  StreamSubscription<Transfer>? _transferSubscription;
  
  int _completedCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize errors from widget
    if (widget.initialErrors != null) {
      _errors.addAll(widget.initialErrors!);
      _failedCount = _errors.length;
    }
    
    _listenToTransfers();
  }

  @override
  void dispose() {
    _transferSubscription?.cancel();
    super.dispose();
  }

  void _listenToTransfers() {
    final transferService = ref.read(transferServiceProvider);
    
    _transferSubscription = transferService.transferStream.listen((transfer) {
      if (widget.transferIds.contains(transfer.id)) {
        setState(() {
          _transfers[transfer.id] = transfer;
          
          // Update counts
          _completedCount = _transfers.values
              .where((t) => t.status == TransferStatus.completed)
              .length;
          _failedCount = _transfers.values
              .where((t) => t.status == TransferStatus.failed)
              .length;
          _failedCount += _errors.length;
        });
      }
    });
  }

  bool get _allCompleted {
    return _completedCount + _failedCount >= widget.transferIds.length;
  }

  double get _overallProgress {
    if (_transfers.isEmpty) return 0;
    
    double totalProgress = 0;
    for (final transfer in _transfers.values) {
      totalProgress += transfer.progress.percentage;
    }
    
    // Add completed for failed transfers
    totalProgress += _failedCount * 100;
    
    return totalProgress / widget.transferIds.length;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allCompleted,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildOverallProgress(),
                Expanded(
                  child: _buildTransferList(),
                ),
                if (_allCompleted) _buildDoneButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.logoGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.devices,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sending to ${widget.recipients.length} devices',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${widget.items.length} file${widget.items.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
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
    Color color;
    String text;
    IconData icon;

    if (_allCompleted) {
      if (_failedCount > 0 && _completedCount == 0) {
        color = AppTheme.errorColor;
        text = 'All Failed';
        icon = Icons.error;
      } else if (_failedCount > 0) {
        color = AppTheme.warningColor;
        text = 'Partial';
        icon = Icons.warning;
      } else {
        color = AppTheme.successColor;
        text = 'Complete';
        icon = Icons.check_circle;
      }
    } else {
      color = AppTheme.primaryColor;
      text = 'Sending...';
      icon = Icons.upload;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${_overallProgress.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _overallProgress / 100,
              backgroundColor: AppTheme.cardColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                _failedCount > 0 && _completedCount > 0
                    ? AppTheme.warningColor
                    : AppTheme.primaryColor,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCountChip('Completed', _completedCount, AppTheme.successColor),
              const SizedBox(width: 12),
              _buildCountChip('Failed', _failedCount, AppTheme.errorColor),
              const SizedBox(width: 12),
              _buildCountChip('Remaining', 
                  widget.transferIds.length - _completedCount - _failedCount, 
                  AppTheme.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.recipients.length,
      itemBuilder: (context, index) {
        final recipient = widget.recipients[index];
        final transferId = index < widget.transferIds.length 
            ? widget.transferIds[index] 
            : null;
        final transfer = transferId != null ? _transfers[transferId] : null;
        final error = _errors[recipient.name];

        return _TransferProgressCard(
          recipient: recipient,
          transfer: transfer,
          error: error,
          items: widget.items,
        );
      },
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card showing progress for a single transfer
class _TransferProgressCard extends StatelessWidget {
  final Device recipient;
  final Transfer? transfer;
  final String? error;
  final List<TransferItem> items;

  const _TransferProgressCard({
    required this.recipient,
    this.transfer,
    this.error,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();
    final progress = transfer?.progress.percentage ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.color.withOpacity(0.3),
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
                  color: recipient.platform.iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  recipient.platform.icon,
                  color: recipient.platform.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${items.length} file${items.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              _buildStatusIcon(status),
            ],
          ),
          if (status != TransferItemStatus.pending) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status == TransferItemStatus.failed ? 0 : progress / 100,
                backgroundColor: AppTheme.surfaceColor,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStatusText(status, progress),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: status.color,
                      ),
                ),
                if (transfer != null && status == TransferItemStatus.transferring)
                  Text(
                    '${transfer!.progress.bytesTransferredFormatted} / ${transfer!.progress.totalBytesFormatted}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(TransferItemStatus status) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        status.icon,
        size: 16,
        color: status.color,
      ),
    );
  }

  TransferItemStatus _getStatus() {
    if (error != null) return TransferItemStatus.failed;
    if (transfer == null) return TransferItemStatus.pending;
    
    switch (transfer!.status) {
      case TransferStatus.pending:
        return TransferItemStatus.pending;
      case TransferStatus.connecting:
        return TransferItemStatus.pending;
      case TransferStatus.transferring:
        return TransferItemStatus.transferring;
      case TransferStatus.paused:
        return TransferItemStatus.pending;
      case TransferStatus.completed:
        return TransferItemStatus.completed;
      case TransferStatus.failed:
        return TransferItemStatus.failed;
      case TransferStatus.cancelled:
        return TransferItemStatus.cancelled;
    }
  }

  String _getStatusText(TransferItemStatus status, double progress) {
    switch (status) {
      case TransferItemStatus.pending:
        return 'Waiting...';
      case TransferItemStatus.transferring:
        return '${progress.toStringAsFixed(1)}%';
      case TransferItemStatus.completed:
        return 'Completed';
      case TransferItemStatus.failed:
        return error ?? 'Failed';
      case TransferItemStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Status for transfer items
enum TransferItemStatus {
  pending,
  transferring,
  completed,
  failed,
  cancelled,
}

extension TransferItemStatusExtension on TransferItemStatus {
  Color get color {
    switch (this) {
      case TransferItemStatus.pending:
        return AppTheme.textTertiary;
      case TransferItemStatus.transferring:
        return AppTheme.primaryColor;
      case TransferItemStatus.completed:
        return AppTheme.successColor;
      case TransferItemStatus.failed:
        return AppTheme.errorColor;
      case TransferItemStatus.cancelled:
        return AppTheme.warningColor;
    }
  }

  IconData get icon {
    switch (this) {
      case TransferItemStatus.pending:
        return Icons.schedule;
      case TransferItemStatus.transferring:
        return Icons.upload;
      case TransferItemStatus.completed:
        return Icons.check_circle;
      case TransferItemStatus.failed:
        return Icons.error;
      case TransferItemStatus.cancelled:
        return Icons.cancel;
    }
  }
}
