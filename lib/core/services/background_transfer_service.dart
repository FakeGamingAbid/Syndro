import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sound_service.dart';
import 'desktop_notification_service.dart';

class BackgroundTransferService {
  static const MethodChannel _channel =
      MethodChannel('com.syndro.app/transfer');
  static const EventChannel _eventChannel =
      EventChannel('com.syndro.app/transfer_events');

  // Track transfer for speed calculations
  static int _lastBytesTransferred = 0;
  static DateTime? _lastUpdateTime;

  // Stream for listening to notification actions
  static Stream<Map<String, dynamic>>? _eventStream;

  /// Get stream of transfer events from notification actions
  static Stream<Map<String, dynamic>> get transferEvents {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      // FIX: Safe casting with error handling
      try {
        if (event is Map) {
          return Map<String, dynamic>.from(event);
        }
        return <String, dynamic>{};
      } catch (e) {
        debugPrint('Error parsing transfer event: $e');
        return <String, dynamic>{};
      }
    });
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
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('startBackgroundTransfer', {
          'title': title,
          'fileName': fileName,
        });
      } on PlatformException catch (e) {
        debugPrint('Platform error starting background transfer: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error starting background transfer (Android): $e');
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

            // FIX: Cap ETA at reasonable value
            if (secondsRemaining < 86400) {
              // Less than 24 hours
              timeRemaining =
                  _formatDuration(Duration(seconds: secondsRemaining.round()));
            }
          }
        }
      }

      _lastBytesTransferred = bytesTransferred;
      _lastUpdateTime = now;
    }

    if (Platform.isAndroid) {
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('updateTransferProgress', {
          'title': title,
          'fileName': fileName,
          'progress': progress.clamp(0, 100), // FIX: Clamp progress
          'speed': speed,
          'timeRemaining': timeRemaining,
          'bytesTransferred': bytesTransferred,
          'totalBytes': totalBytes,
        });
      } on PlatformException catch (e) {
        debugPrint('Platform error updating progress: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error updating transfer progress (Android): $e');
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
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('stopBackgroundTransfer');
      } on PlatformException catch (e) {
        debugPrint('Platform error stopping transfer: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error stopping background transfer (Android): $e');
      }
    } else if (Platform.isWindows) {
      debugPrint('Transfer notification cleared (Windows)');
    } else if (Platform.isLinux) {
      debugPrint('Transfer notification cleared (Linux)');
    }
  }

  /// Show transfer request notification with Accept/Reject buttons
  static Future<void> showTransferRequest({
    required String senderName,
    required int fileCount,
    required int totalSize,
    String requestId = '',
    String? thumbnailPath,
    String? firstFileName,
  }) async {
    // Play notification sound for incoming transfer request
    SoundService().playRequestSound();

    if (Platform.isAndroid) {
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('showTransferRequest', {
          'senderName': senderName,
          'fileCount': fileCount,
          'totalSize': totalSize,
          'requestId': requestId,
          'thumbnailPath': thumbnailPath,
          'firstFileName': firstFileName,
        });
      } on PlatformException catch (e) {
        debugPrint('Platform error showing request: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error showing transfer request (Android): $e');
      }
    } else if (Platform.isWindows || Platform.isLinux) {
      // Use desktop notification service with thumbnail support
      await DesktopNotificationService.showTransferRequest(
        senderName: senderName,
        fileCount: fileCount,
        totalSize: totalSize,
        firstFileName: firstFileName,
        thumbnailPath: thumbnailPath,
      );
    }
  }

  /// Dismiss transfer request notification
  static Future<void> dismissTransferRequest() async {
    if (Platform.isAndroid) {
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('dismissTransferRequest');
      } on PlatformException catch (e) {
        debugPrint('Platform error dismissing request: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error dismissing transfer request (Android): $e');
      }
    }
  }

  /// Show transfer complete notification with Open/Share buttons
  static Future<void> showTransferComplete({
    required String fileName,
    required String filePath,
    int fileCount = 1,
    int totalSize = 0,
    String? thumbnailPath,
  }) async {
    // Play notification sound for completed transfer (received)
    SoundService().playCompleteSound();

    if (Platform.isAndroid) {
      // FIX: Wrap in try-catch
      try {
        await _channel.invokeMethod('showTransferComplete', {
          'fileName': fileName,
          'filePath': filePath,
          'fileCount': fileCount,
          'totalSize': totalSize,
          'thumbnailPath': thumbnailPath,
        });
      } on PlatformException catch (e) {
        debugPrint('Platform error showing complete: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Plugin not available: $e');
      } catch (e) {
        debugPrint('Error showing transfer complete (Android): $e');
      }
    } else if (Platform.isWindows || Platform.isLinux) {
      // Use desktop notification service with thumbnail support
      await DesktopNotificationService.showTransferComplete(
        fileCount: fileCount,
        totalSize: totalSize,
        firstFileName: fileName,
        thumbnailPath: thumbnailPath,
        filePath: filePath,
      );
    }
  }

  /// Format bytes per second to human readable speed
  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';

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

  /// Show Windows notification using PowerShell
  static Future<void> _showWindowsNotification({
    required String title,
    required String body,
    bool isImportant = false,
  }) async {
    try {
      // FIX: Better escaping for PowerShell
      final escapedTitle = _escapeForPowerShell(title);
      final escapedBody = _escapeForPowerShell(body);

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
      debugPrint('Windows notification error: $e');
      debugPrint('Notification: $title - $body');
    }
  }

  // FIX: Proper PowerShell escaping
  static String _escapeForPowerShell(String input) {
    return input
        .replaceAll('`', '``')
        .replaceAll('"', '`"')
        .replaceAll("'", "`'")
        .replaceAll('\$', '`\$')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
  }

  /// Show Linux notification using notify-send
  static Future<void> _showLinuxNotification({
    required String title,
    required String body,
    String urgency = 'normal',
    bool playSound = false,
  }) async {
    try {
      // FIX: Sanitize inputs to prevent command injection
      final sanitizedTitle = _sanitizeForShell(title);
      final sanitizedBody = _sanitizeForShell(body);

      await Process.run(
        'notify-send',
        [
          '--app-name=Syndro',
          '--urgency=$urgency',
          '--icon=folder',
          '--expire-time=${urgency == 'critical' ? '0' : '5000'}',
          sanitizedTitle,
          sanitizedBody,
        ],
      );

      // Play sound on Linux using paplay or aplay
      if (playSound || urgency == 'critical') {
        await _playLinuxSound();
      }
    } catch (e) {
      debugPrint('Linux notification error: $e');
      debugPrint('Notification: $title - $body');
    }
  }

  // FIX: Sanitize strings for shell commands
  static String _sanitizeForShell(String input) {
    // Remove any potentially dangerous characters
    return input
        .replaceAll(RegExp(r'[`\$\(\)\[\]\{\}\\;|&<>]'), '')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
  }

  /// Play notification sound on Linux
  static Future<void> _playLinuxSound() async {
    try {
      // Check multiple possible sound file locations
      final soundPaths = [
        '/usr/share/sounds/freedesktop/stereo/complete.oga',
        '/usr/share/sounds/gnome/default/sounds/complete.ogg',
        '/usr/share/sounds/ui/sounds.conf',
      ];

      String? validSoundPath;
      for (final path in soundPaths) {
        if (await File(path).exists()) {
          validSoundPath = path;
          break;
        }
      }

      if (validSoundPath == null) {
        debugPrint('No system sound file found, skipping sound playback');
        return;
      }

      // Try paplay first (PulseAudio)
      var result = await Process.run('which', ['paplay']);
      if (result.exitCode == 0) {
        await Process.run('paplay', [validSoundPath]);
        return;
      }

      // Fallback to aplay (ALSA)
      result = await Process.run('which', ['aplay']);
      if (result.exitCode == 0) {
        await Process.run('aplay', [validSoundPath]);
      }
    } catch (e) {
      // Sound playback failed, ignore
    }
  }

  /// Open file location on Windows (show in Explorer)
  static Future<void> openFileLocation(String filePath) async {
    if (!Platform.isWindows) return;
    
    try {
      // FIX: Validate file path to prevent command injection
      if (!_isValidWindowsPath(filePath)) {
        debugPrint('Invalid file path: $filePath');
        return;
      }

      // FIX: Check if file exists before opening
      final file = File(filePath);
      if (!await file.exists()) {
        // Try opening parent directory
        final parentDir = file.parent;
        if (await parentDir.exists()) {
          await Process.run(
            'explorer',
            [parentDir.path],
            runInShell: false, // FIX: Don't use shell
          );
        }
        return;
      }

      await Process.run(
        'explorer',
        ['/select,', filePath],
        runInShell: false, // FIX: Don't use shell
      );
    } catch (e) {
      debugPrint('Error opening file location: $e');
    }
  }

  // FIX: Validate Windows path to prevent injection
  static bool _isValidWindowsPath(String path) {
    if (path.isEmpty) return false;

    // Check for dangerous characters that could be used for injection
    final dangerousChars = RegExp(r'[<>"|?*\x00-\x1F]');
    if (dangerousChars.hasMatch(path)) {
      return false;
    }

    // Check for command injection attempts
    final injectionPatterns = ['&&', '||', ';', '|', '`', '\$', '%'];
    for (final pattern in injectionPatterns) {
      if (path.contains(pattern)) {
        return false;
      }
    }

    return true;
  }

  /// Open file location on Linux (show in file manager)
  static Future<void> openFileLocationLinux(String filePath) async {
    try {
      // FIX: Validate path
      if (!_isValidLinuxPath(filePath)) {
        debugPrint('Invalid file path: $filePath');
        return;
      }

      final file = File(filePath);
      final directory =
          await file.exists() ? file.parent.path : Directory.current.path;

      await Process.run('xdg-open', [directory]);
    } catch (e) {
      debugPrint('Error opening file location: $e');
    }
  }

  // FIX: Validate Linux path
  static bool _isValidLinuxPath(String path) {
    if (path.isEmpty) return false;

    // Check for dangerous characters
    final dangerousChars = RegExp(r'[\x00]');
    if (dangerousChars.hasMatch(path)) {
      return false;
    }

    // Check for command injection attempts
    final injectionPatterns = ['&&', '||', ';', '|', '`', '\$', '..'];
    for (final pattern in injectionPatterns) {
      if (path.contains(pattern)) {
        return false;
      }
    }

    return true;
  }

  /// Dispose static resources (call on app exit)
  static void dispose() {
    _eventStream = null;
    _lastUpdateTime = null;
    _lastBytesTransferred = 0;
  }
}
