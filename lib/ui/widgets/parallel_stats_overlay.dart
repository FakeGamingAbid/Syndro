import 'package:flutter/material.dart';
import '../../core/models/transfer.dart';

/// Widget that displays real-time parallel transfer statistics
/// Shows chunk count and bytes per connection during parallel transfers
class ParallelStatsOverlay extends StatelessWidget {
  final ParallelTransferStats stats;
  final bool isExpanded;

  const ParallelStatsOverlay({
    super.key,
    required this.stats,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!stats.isParallel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.stream,
                color: Colors.cyan,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Parallel Transfer',
                style: TextStyle(
                  color: Colors.cyan.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chunk progress
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chunks:',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${stats.completedChunks}/${stats.totalChunks}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: stats.chunkProgress,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan.shade400),
              minHeight: 4,
            ),
          ),

          if (isExpanded) ...[
            const SizedBox(height: 8),

            // Per-connection stats
            Text(
              'Connections:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),

            // Bytes per connection
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: stats.bytesPerConnection.asMap().entries.map((entry) {
                final connectionId = entry.key;
                final bytes = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'C$connectionId: ${_formatBytes(bytes)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Compact version of parallel stats for inline display
class ParallelStatsCompact extends StatelessWidget {
  final ParallelTransferStats stats;

  const ParallelStatsCompact({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (!stats.isParallel) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.stream,
          color: Colors.cyan.shade400,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          '${stats.completedChunks}/${stats.totalChunks} chunks',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
