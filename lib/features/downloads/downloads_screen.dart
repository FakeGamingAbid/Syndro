import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/downloads/download_manager.dart';
import '../../core/platform/platform_detector.dart';

/// Downloads screen - shows active and completed downloads
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show on Android TV
    if (PlatformDetector.isTV) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: Text(
            'Downloads not available on TV',
            style: TextStyle(color: Color(0xFFE8EDF2)),
          ),
        ),
      );
    }

    final downloadState = ref.watch(downloadManagerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A),
        title: const Text(
          'Downloads',
          style: TextStyle(
            color: Color(0xFFE8EDF2),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Storage usage bar
          _buildStorageBar(downloadState.totalSizeBytes),
          
          // Downloads list
          Expanded(
            child: _buildDownloadsList(context, ref, downloadState),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBar(int usedBytes) {
    final usedGB = usedBytes / (1024 * 1024 * 1024);
    // Assume 32GB available for demo
    final availableGB = 32.0;
    final usedPercent = (usedGB / availableGB).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: ${usedGB.toStringAsFixed(1)} GB',
                style: const TextStyle(
                  color: Color(0xFFE8EDF2),
                  fontSize: 14,
                ),
              ),
              Text(
                'Available: ${(availableGB - usedGB).toStringAsFixed(1)} GB',
                style: const TextStyle(
                  color: Color(0xFF8B9BB0),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPercent,
              backgroundColor: const Color(0xFF2A3A50),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4A6FA5)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(
    BuildContext context,
    WidgetRef ref,
    DownloadManagerState state,
  ) {
    final activeDownloads = state.activeDownloads;
    final completedDownloads = state.completedDownloads;

    if (activeDownloads.isEmpty && completedDownloads.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active downloads
        if (activeDownloads.isNotEmpty) ...[
          const Text(
            'Downloading',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...activeDownloads.map((item) => _buildActiveDownloadItem(context, ref, item)),
        ],

        // Completed downloads
        if (completedDownloads.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Completed',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...completedDownloads.map((item) => _buildCompletedDownloadItem(context, ref, item)),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_outlined,
            color: Color(0xFF8B9BB0),
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'No downloads yet',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download movies and shows to watch offline',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadItem(BuildContext context, WidgetRef ref, DownloadItem item) {
    final progress = (item.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Row(
        children: [
          // Poster thumbnail
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3A50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.posterUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.movie,
                        color: Color(0xFF8B9BB0),
                      ),
                    ),
                  )
                : const Icon(Icons.movie, color: Color(0xFF8B9BB0)),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF2),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A6FA5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.quality.label,
                        style: const TextStyle(
                          color: Color(0xFFE8EDF2),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        color: Color(0xFF8B9BB0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: const Color(0xFF2A3A50),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4A6FA5)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          
          // Controls
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.pause, color: Color(0xFFE8EDF2)),
                onPressed: () {
                  ref.read(downloadManagerProvider.notifier).pauseDownload(item.id);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFFFF6B6B)),
                onPressed: () {
                  ref.read(downloadManagerProvider.notifier).cancelDownload(item.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedDownloadItem(BuildContext context, WidgetRef ref, DownloadItem item) {
    final fileSize = item.fileSizeBytes ?? 0;
    final sizeStr = fileSize < 1024 * 1024
        ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
        : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Row(
        children: [
          // Poster thumbnail
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3A50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.posterUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.movie,
                        color: Color(0xFF8B9BB0),
                      ),
                    ),
                  )
                : const Icon(Icons.movie, color: Color(0xFF8B9BB0)),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF2),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.quality.label,
                        style: const TextStyle(
                          color: Color(0xFF0A0A0F),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sizeStr,
                      style: const TextStyle(
                        color: Color(0xFF8B9BB0),
                        fontSize: 12,
                      ),
                    ),
                    if (item.subtitlePath != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.subtitles,
                        color: Color(0xFF8B9BB0),
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Controls
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFF4ECDC4)),
                onPressed: () {
                  // Open video player with local file
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                onPressed: () {
                  _showDeleteDialog(context, ref, item);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, DownloadItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A28),
        title: const Text(
          'Delete Download',
          style: TextStyle(color: Color(0xFFE8EDF2)),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}"?',
          style: const TextStyle(color: Color(0xFF8B9BB0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8B9BB0)),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadManagerProvider.notifier).deleteDownload(item.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }
}
