import 'dart:io';

import 'package:flutter/services.dart';

class BackgroundTransferService {
  static const MethodChannel _channel = MethodChannel('com.syndro.app/transfer');

  /// Start background transfer notification (ALL PLATFORMS)
  static Future<void> startBackgroundTransfer({
    required String title,
    String fileName = '',
  }) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startBackgroundTransfer', {
          'title': title,
          'fileName': fileName,
        });
      } catch (e) {
        print('Error starting background transfer (Android): $e');
      }
    } else if (Platform.isWindows) {
      await _showWindowsNotification(
        title: title,
        body: fileName.isNotEmpty ? 'File: $fileName' : 'Starting transfer...',
      );
    } else if (Platform.isLinux) {
      await _showLinuxNotification(
        title: title,
        body: fileName.isNotEmpty ? 'File: $fileName' : 'Starting transfer...',
      );
    }
  }

  /// Update transfer progress in notification (ALL PLATFORMS)
  static Future<void> updateProgress({
    required String title,
    required String fileName,
    required int progress,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('updateTransferProgress', {
          'title': title,
          'fileName': fileName,
          'progress': progress,
        });
      } catch (e) {
        print('Error updating transfer progress (Android): $e');
      }
    } else if (Platform.isWindows) {
      if (progress % 10 == 0) {
        await _showWindowsNotification(
          title: title,
          body: '$fileName - $progress% complete',
        );
      }
    } else if (Platform.isLinux) {
      if (progress % 10 == 0) {
        await _showLinuxNotification(
          title: title,
          body: '$fileName - $progress% complete',
        );
      }
    }
  }

  /// Stop background transfer notification (ALL PLATFORMS)
  static Future<void> stopBackgroundTransfer() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopBackgroundTransfer');
      } catch (e) {
        print('Error stopping background transfer (Android): $e');
      }
    } else if (Platform.isWindows) {
      print('Transfer notification cleared (Windows)');
    } else if (Platform.isLinux) {
      print('Transfer notification cleared (Linux)');
    }
  }

  /// Show transfer request notification (ALL PLATFORMS)
  static Future<void> showTransferRequest({
    required String senderName,
    required int fileCount,
    required int totalSize,
  }) async {
    final sizeStr = _formatBytes(totalSize);
    const String title = 'Incoming Transfer Request';
    final String body = '$senderName wants to send $fileCount file(s) ($sizeStr)';

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('showTransferRequest', {
          'senderName': senderName,
          'fileCount': fileCount,
          'totalSize': totalSize,
        });
      } catch (e) {
        print('Error showing transfer request (Android): $e');
      }
    } else if (Platform.isWindows) {
      await _showWindowsNotification(title: title, body: body);
    } else if (Platform.isLinux) {
      await _showLinuxNotification(title: title, body: body);
    }
  }

  /// Show transfer complete notification (ALL PLATFORMS)
  static Future<void> showTransferComplete({
    required String fileName,
    required String filePath,
  }) async {
    const String title = 'Transfer Complete';
    final String body = fileName.isNotEmpty ? 'Received: $fileName' : 'All files received';

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('showTransferComplete', {
          'fileName': fileName,
          'filePath': filePath,
        });
      } catch (e) {
        print('Error showing transfer complete (Android): $e');
      }
    } else if (Platform.isWindows) {
      await _showWindowsNotification(title: title, body: body);
    } else if (Platform.isLinux) {
      await _showLinuxNotification(title: title, body: body);
    }
  }

  /// Show Windows notification using PowerShell
  static Future<void> _showWindowsNotification({
    required String title,
    required String body,
  }) async {
    try {
      final script = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

\$template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$title</text>
            <text id="2">$body</text>
        </binding>
    </visual>
</toast>
"@

\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml(\$template)
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Syndro").Show(\$toast)
''';

      await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', script],
        runInShell: true,
      );
    } catch (e) {
      print('Notification: $title - $body');
    }
  }

  /// Show Linux notification using notify-send
  static Future<void> _showLinuxNotification({
    required String title,
    required String body,
  }) async {
    try {
      await Process.run(
        'notify-send',
        [
          '--app-name=Syndro',
          '--urgency=normal',
          '--icon=folder',
          title,
          body,
        ],
      );
    } catch (e) {
      print('Notification: $title - $body');
    }
  }

  /// Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
