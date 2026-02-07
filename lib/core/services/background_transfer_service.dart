 import 'dart:io';
import 'package:flutter/services.dart';

class BackgroundTransferService {
  static const MethodChannel _channel = MethodChannel('com.syndro.app/transfer');
  static const EventChannel _eventChannel = EventChannel('com.syndro.app/transfer_events');

  // Track transfer for speed calculations
  static int _lastBytesTransferred = 0;
  static DateTime? _lastUpdateTime;
  
  // Stream for listening to notification actions
  static Stream<Map<String, dynamic>>? _eventStream;
  
  /// Get stream of transfer events from notification actions (cancel, accept, reject)
  static Stream<Map<String, dynamic>> get transferEvents {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  /// Start background transfer notification (ALL PLATFORMS)
  static Future<void> startBackgroundTransfer({
    required String title,
    String fileName = '',
  }) async {
    _lastBytesTransferred = 0;
    _lastUpdateTime = DateTime.now();

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

  /// Update transfer progress with speed and ETA (ALL PLATFORMS)
  static Future<void> updateProgress({
    required String title,
    required String fileName,
    required int progress,
    int bytesTransferred = 0,
    int totalBytes = 0,
  }) async {
    // Calculate speed and ETA
    String? speed;
    String? timeRemaining;

    if (bytesTransferred > 0 && totalBytes > 0) {
      final now = DateTime.now();

      // Calculate speed based on recent transfer rate
      if (_lastUpdateTime != null) {
        final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds;
        if (timeDiff > 0) {
          final bytesDiff = bytesTransferred - _lastBytesTransferred;
          final bytesPerSecond = (bytesDiff / timeDiff * 1000).round();

          if (bytesPerSecond > 0) {
            speed = _formatSpeed(bytesPerSecond);

            // Calculate ETA
            final remainingBytes = totalBytes - bytesTransferred;
            final secondsRemaining = remainingBytes / bytesPerSecond;
            timeRemaining = _formatDuration(Duration(seconds: secondsRemaining.round()));
          }
        }
      }

      _lastBytesTransferred = bytesTransferred;
      _lastUpdateTime = now;
    }

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('updateTransferProgress', {
          'title': title,
          'fileName': fileName,
          'progress': progress,
          'speed': speed,
          'timeRemaining': timeRemaining,
          'bytesTransferred': bytesTransferred,
          'totalBytes': totalBytes,
        });
      } catch (e) {
        print('Error updating transfer progress (Android): $e');
      }
    } else if (Platform.isWindows) {
      // Update every 5% to avoid notification spam
      if (progress % 5 == 0) {
        final speedText = speed != null ? ' • $speed' : '';
        final etaText = timeRemaining != null ? ' • $timeRemaining' : '';
        await _showWindowsNotification(
          title: title,
          body: '$fileName - $progress%$speedText$etaText',
        );
      }
    } else if (Platform.isLinux) {
      if (progress % 5 == 0) {
        final speedText = speed != null ? ' • $speed' : '';
        final etaText = timeRemaining != null ? ' • $timeRemaining' : '';
        await _showLinuxNotification(
          title: title,
          body: '$fileName - $progress%$speedText$etaText',
        );
      }
    }
  }

  /// Stop background transfer notification (ALL PLATFORMS)
  static Future<void> stopBackgroundTransfer() async {
    _lastBytesTransferred = 0;
    _lastUpdateTime = null;

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

  /// Show transfer request notification with Accept/Reject buttons (ALL PLATFORMS)
  static Future<void> showTransferRequest({
    required String senderName,
    required int fileCount,
    required int totalSize,
    String requestId = '',
  }) async {
    final sizeStr = _formatBytes(totalSize);
    const String title = '📥 Incoming Transfer Request';
    final String body = '$senderName wants to send $fileCount file(s) ($sizeStr)';

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('showTransferRequest', {
          'senderName': senderName,
          'fileCount': fileCount,
          'totalSize': totalSize,
          'requestId': requestId,
        });
      } catch (e) {
        print('Error showing transfer request (Android): $e');
      }
    } else if (Platform.isWindows) {
      await _showWindowsNotification(
        title: title,
        body: body,
        isImportant: true,  // 🔊 Sound enabled
      );
    } else if (Platform.isLinux) {
      await _showLinuxNotification(
        title: title,
        body: body,
        urgency: 'critical',
      );
    }
  }

  /// Dismiss transfer request notification
  static Future<void> dismissTransferRequest() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('dismissTransferRequest');
      } catch (e) {
        print('Error dismissing transfer request (Android): $e');
      }
    }
  }

  /// Show transfer complete notification with Open/Share buttons (ALL PLATFORMS)
  static Future<void> showTransferComplete({
    required String fileName,
    required String filePath,
    int fileCount = 1,
    int totalSize = 0,
  }) async {
    const String title = '✅ Transfer Complete';
    final String body = fileCount == 1 && fileName.isNotEmpty
        ? 'Received: $fileName'
        : 'Received $fileCount file(s) (${_formatBytes(totalSize)})';

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('showTransferComplete', {
          'fileName': fileName,
          'filePath': filePath,
          'fileCount': fileCount,
          'totalSize': totalSize,
        });
      } catch (e) {
        print('Error showing transfer complete (Android): $e');
      }
    } else if (Platform.isWindows) {
      await _showWindowsNotification(
        title: title,
        body: body,
        isImportant: true,  // 🔊 Sound enabled for completion!
      );
      // Open file location on Windows
      if (filePath.isNotEmpty) {
        _openFileLocationWindows(filePath);
      }
    } else if (Platform.isLinux) {
      await _showLinuxNotification(
        title: title,
        body: body,
        urgency: 'normal',
        playSound: true,  // 🔊 Request sound on Linux
      );
    }
  }

  /// Format bytes per second to human readable speed
  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  /// Format duration to human readable string
  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m left';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s left';
    } else if (duration.inSeconds > 5) {
      return '${duration.inSeconds}s left';
    } else {
      return 'Almost done...';
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

  /// Show Windows notification using PowerShell
  static Future<void> _showWindowsNotification({
    required String title,
    required String body,
    bool isImportant = false,
  }) async {
    try {
      final escapedTitle = title
          .replaceAll('"', '`"')
          .replaceAll("'", "`'")
          .replaceAll('\n', ' ');
      final escapedBody = body
          .replaceAll('"', '`"')
          .replaceAll("'", "`'")
          .replaceAll('\n', ' ');

      final script = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

\$template = @"
<toast duration="${isImportant ? 'long' : 'short'}">
    <visual>
        <binding template="ToastText02">
            <text id="1">$escapedTitle</text>
            <text id="2">$escapedBody</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
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
      print('Windows notification error: $e');
      print('Notification: $title - $body');
    }
  }

  /// Show Linux notification using notify-send
  static Future<void> _showLinuxNotification({
    required String title,
    required String body,
    String urgency = 'normal',
    bool playSound = false,
  }) async {
    try {
      await Process.run(
        'notify-send',
        [
          '--app-name=Syndro',
          '--urgency=$urgency',
          '--icon=folder',
          '--expire-time=${urgency == 'critical' ? '0' : '5000'}',
          title,
          body,
        ],
      );
      
      // Play sound on Linux using paplay or aplay
      if (playSound || urgency == 'critical') {
        _playLinuxSound();
      }
    } catch (e) {
      print('Linux notification error: $e');
      print('Notification: $title - $body');
    }
  }

  /// Play notification sound on Linux
  static Future<void> _playLinuxSound() async {
    try {
      // Try paplay first (PulseAudio)
      final result = await Process.run('which', ['paplay']);
      if (result.exitCode == 0) {
        await Process.run('paplay', [
          '/usr/share/sounds/freedesktop/stereo/complete.oga'
        ]);
        return;
      }
      
      // Fallback to aplay (ALSA)
      await Process.run('aplay', [
        '/usr/share/sounds/freedesktop/stereo/complete.oga'
      ]);
    } catch (e) {
      // Sound playback failed, ignore
    }
  }

  /// Open file location on Windows (show in Explorer)
  static Future<void> _openFileLocationWindows(String filePath) async {
    try {
      await Process.run(
        'explorer',
        ['/select,', filePath],
        runInShell: true,
      );
    } catch (e) {
      print('Error opening file location: $e');
    }
  }

  /// Open file location on Linux (show in file manager)
  static Future<void> openFileLocationLinux(String filePath) async {
    try {
      final directory = File(filePath).parent.path;
      await Process.run('xdg-open', [directory]);
    } catch (e) {
      print('Error opening file location: $e');
    }
  }
} 
