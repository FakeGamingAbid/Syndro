import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing Android Live Activities during file transfers.
///
/// This service provides real-time transfer progress on the Android lock screen
/// using Android's ActivityKit Live Activities API.
class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('syndro/live_activity');

  static bool _isInitialized = false;
  static String? _currentActivityId;

  /// Initialize the Live Activity service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if platform supports Live Activities
      final isSupported = await _channel.invokeMethod<bool>('isSupported');
      if (isSupported == true) {
        _isInitialized = true;
        debugPrint('✅ Live Activity service initialized');
      } else {
        debugPrint('ℹ️ Live Activities not supported on this platform');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize Live Activity service: $e');
    }
  }

  /// Check if Live Activities are supported
  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start a new transfer Live Activity
  ///
  /// [fileName] - Name of the file being transferred
  /// [totalBytes] - Total size of the file in bytes
  /// [senderName] - Name of the sender/recipient
  /// [isIncoming] - Whether this is an incoming transfer
  static Future<String?> startTransferActivity({
    required String fileName,
    required int totalBytes,
    required String senderName,
    required bool isIncoming,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      debugPrint('⚠️ Live Activity not available');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startTransferActivity',
        {
          'fileName': fileName,
          'totalBytes': totalBytes,
          'senderName': senderName,
          'isIncoming': isIncoming,
        },
      );

      if (result != null) {
        _currentActivityId = result['activityId'] as String?;
        return _currentActivityId;
      }
    } catch (e) {
      debugPrint('❌ Failed to start Live Activity: $e');
    }

    return null;
  }

  /// Update the progress of an active Live Activity
  ///
  /// [bytesTransferred] - Number of bytes transferred so far
  /// [speed] - Current transfer speed in bytes per second
  static Future<void> updateProgress({
    required int bytesTransferred,
    required double speed,
  }) async {
    if (_currentActivityId == null || !_isInitialized) return;

    try {
      await _channel.invokeMethod('updateProgress', {
        'activityId': _currentActivityId,
        'bytesTransferred': bytesTransferred,
        'speed': speed,
      });
    } catch (e) {
      debugPrint('❌ Failed to update Live Activity progress: $e');
    }
  }

  /// Update with full transfer state
  static Future<void> updateTransferState({
    required int bytesTransferred,
    required int totalBytes,
    required double speed,
    String? eta,
  }) async {
    if (_currentActivityId == null || !_isInitialized) return;

    try {
      final progress = totalBytes > 0 ? (bytesTransferred / totalBytes * 100) : 0.0;
      
      await _channel.invokeMethod('updateTransferState', {
        'activityId': _currentActivityId,
        'bytesTransferred': bytesTransferred,
        'totalBytes': totalBytes,
        'progress': progress,
        'speed': speed,
        'eta': eta,
      });
    } catch (e) {
      debugPrint('❌ Failed to update Live Activity state: $e');
    }
  }

  /// End the current Live Activity
  ///
  /// [success] - Whether the transfer completed successfully
  /// [message] - Optional message to display (e.g., "Transfer Complete" or error message)
  static Future<void> endActivity({
    required bool success,
    String? message,
  }) async {
    if (_currentActivityId == null) return;

    try {
      await _channel.invokeMethod('endActivity', {
        'activityId': _currentActivityId,
        'success': success,
        'message': message,
      });
    } catch (e) {
      debugPrint('❌ Failed to end Live Activity: $e');
    } finally {
      _currentActivityId = null;
    }
  }

  /// Cancel the current Live Activity
  static Future<void> cancelActivity() async {
    await endActivity(success: false, message: 'Transfer cancelled');
  }

  /// Check if there's an active Live Activity
  static bool get hasActiveActivity => _currentActivityId != null;

  /// Get the current activity ID
  static String? get currentActivityId => _currentActivityId;
}
