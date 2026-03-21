import 'dart:io';

import 'package:flutter/services.dart';

/// Enum representing the different platform types the app can run on.
enum PlatformType {
  /// Android phone and tablet
  mobile,
  
  /// Android TV
  tv,
  
  /// Windows, Linux, macOS desktop
  desktop,
}

/// Detects at runtime whether the app is running on
/// Android phone, Android TV, or Desktop (Win/Linux/Mac).
/// Routes the app to the correct shell UI.
class PlatformDetector {
  static PlatformType? _platformType;
  static bool _isInitialized = false;
  
  static const MethodChannel _channel = MethodChannel('com.moonplex.app/platform');

  /// Initialize the platform detector.
  /// Must be called before accessing [current].
  static Future<void> init() async {
    if (_isInitialized) return;
    
    _platformType = await _detectPlatform();
    _isInitialized = true;
  }

  /// Detects the current platform type.
  static Future<PlatformType> _detectPlatform() async {
    // Check if running on desktop first
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return PlatformType.desktop;
    }
    
    // For Android, we need to check via platform channel
    if (Platform.isAndroid) {
      try {
        final bool isTv = await _channel.invokeMethod('isTvDevice');
        return isTv ? PlatformType.tv : PlatformType.mobile;
      } on PlatformException {
        // Default to mobile if the channel fails
        return PlatformType.mobile;
      }
    }
    
    // Default to mobile for unknown platforms
    return PlatformType.mobile;
  }

  /// Returns the current platform type.
  /// Defaults to [PlatformType.mobile] if not initialized.
  static PlatformType get current {
    return _platformType ?? PlatformType.mobile;
  }

  /// Returns true if running on mobile (Android phone/tablet).
  static bool get isMobile => current == PlatformType.mobile;

  /// Returns true if running on Android TV.
  static bool get isTV => current == PlatformType.tv;

  /// Returns true if running on desktop (Windows, Linux, macOS).
  static bool get isDesktop => current == PlatformType.desktop;

  /// Returns whether the platform detector has been initialized.
  static bool get isInitialized => _isInitialized;
}
