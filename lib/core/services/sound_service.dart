import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to play notification sounds
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Play sound for incoming transfer request
  Future<void> playRequestSound() async {
    await _playNotificationSound();
  }

  /// Play sound for completed transfer
  Future<void> playCompleteSound() async {
    await _playNotificationSound();
  }

  Future<void> _playNotificationSound() async {
    if (Platform.isAndroid) {
      try {
        // Play default Android notification sound using ToneGenerator
        const channel = MethodChannel('com.syndro.app/sound');
        await channel.invokeMethod('playNotificationSound');
      } catch (e) {
        debugPrint('Could not play notification sound: $e');
      }
    }
  }
}
