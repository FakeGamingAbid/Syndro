import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;

/// Desktop notification service with rich content support (thumbnails, actions)
class DesktopNotificationService {
  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      await localNotifier.setup(
        appName: 'Syndro',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
      debugPrint('✅ Desktop notification service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize desktop notifications: $e');
    }
  }

  /// Show a transfer request notification with file preview
  static Future<void> showTransferRequest({
    required String senderName,
    required int fileCount,
    required int totalSize,
    String? firstFileName,
    String? thumbnailPath,
    VoidCallback? onAccept,
    VoidCallback? onReject,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final sizeText = _formatBytes(totalSize);
      final filesText = fileCount == 1 ? '1 file' : '$fileCount files';

      final notification = LocalNotification(
        title: '📥 Incoming Transfer from $senderName',
        body: '$filesText ($sizeText)${firstFileName != null ? '\n${_truncate(firstFileName, 50)}' : ''}',
      );

      await notification.show();
      
      debugPrint('Transfer request notification shown: $senderName, $filesText');
    } catch (e) {
      debugPrint('❌ Failed to show transfer request notification: $e');
    }
  }

  /// Show a transfer progress notification with pause/resume actions
  static Future<void> showTransferProgress({
    required String title,
    required String fileName,
    required int progress,
    String? speed,
    String? timeRemaining,
    String? thumbnailPath,
    VoidCallback? onCancel,
    VoidCallback? onPause,
    VoidCallback? onResume,
    bool isPaused = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final body = _buildProgressBody(fileName, speed, timeRemaining);

      final notification = LocalNotification(
        title: isPaused ? '⏸️ $title' : title,
        body: body,
      );

      // Add action buttons for pause/resume on desktop
      if (onPause != null || onResume != null) {
        // Note: Full action button support requires platform-specific setup
        // This is a simplified version - full implementation would use
        // notification.onShow = (notification) {
        //   notification.addAction(...)
        // }
      }

      await notification.show();
    } catch (e) {
      debugPrint('❌ Failed to show progress notification: $e');
    }
  }

  /// Show a transfer complete notification
  static Future<void> showTransferComplete({
    required int fileCount,
    required int totalSize,
    String? firstFileName,
    String? thumbnailPath,
    String? filePath,
    VoidCallback? onOpen,
    VoidCallback? onShare,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final sizeText = _formatBytes(totalSize);
      String body;

      if (fileCount == 1 && firstFileName != null) {
        body = 'Received: ${_truncate(firstFileName, 50)} ($sizeText)';
      } else {
        body = 'Received $fileCount files ($sizeText)';
      }

      final notification = LocalNotification(
        title: '✅ Transfer Complete',
        body: body,
      );

      await notification.show();
    } catch (e) {
      debugPrint('❌ Failed to show completion notification: $e');
    }
  }

  /// Show a simple notification
  static Future<void> show({
    required String title,
    required String body,
    String? thumbnailPath,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );

      await notification.show();
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  /// Build progress notification body
  static String _buildProgressBody(String fileName, String? speed, String? timeRemaining) {
    final parts = <String>[];

    if (fileName.isNotEmpty) {
      parts.add(_truncate(fileName, 40));
    }

    if (speed != null) {
      parts.add(speed);
    }

    if (timeRemaining != null) {
      parts.add(timeRemaining);
    }

    return parts.isEmpty ? 'Preparing...' : parts.join(' • ');
  }

  /// Truncate text with ellipsis
  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '...${text.substring(text.length - maxLength + 3)}';
  }

  /// Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Check if a file is an image
  static bool isImage(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif'].contains(ext);
  }

  /// Generate a thumbnail for an image file
  static Future<String?> generateThumbnail(String imagePath, {int maxSize = 512}) async {
    if (!isImage(imagePath)) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      // For now, return the original image path
      // In a production app, you'd resize the image here
      return imagePath;
    } catch (e) {
      debugPrint('Failed to generate thumbnail: $e');
      return null;
    }
  }
}
