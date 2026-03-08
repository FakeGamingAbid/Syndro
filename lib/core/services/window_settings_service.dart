import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Window bounds data class
class WindowBounds {
  final double width;
  final double height;
  final double? x;
  final double? y;
  final bool maximized;

  const WindowBounds({
    required this.width,
    required this.height,
    this.x,
    this.y,
    this.maximized = false,
  });

  @override
  String toString() =>
      'WindowBounds(width: $width, height: $height, x: $x, y: $y, maximized: $maximized)';
}

/// Service for persisting and restoring desktop window size and position.
///
/// This service uses SharedPreferences to store window bounds and restores
/// them when the application launches.
class WindowSettingsService {
  static const String _keyWindowWidth = 'window_width';
  static const String _keyWindowHeight = 'window_height';
  static const String _keyWindowX = 'window_x';
  static const String _keyWindowY = 'window_y';
  static const String _keyWindowMaximized = 'window_maximized';

  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save current window bounds
  ///
  /// [size] - Current window size
  /// [position] - Current window position (can be null for centered)
  /// [maximized] - Whether the window is maximized
  static Future<void> saveWindowBounds({
    required Size size,
    Offset? position,
    bool maximized = false,
  }) async {
    if (_prefs == null) await initialize();

    try {
      await _prefs!.setDouble(_keyWindowWidth, size.width);
      await _prefs!.setDouble(_keyWindowHeight, size.height);
      await _prefs!.setBool(_keyWindowMaximized, maximized);

      if (position != null) {
        await _prefs!.setDouble(_keyWindowX, position.dx);
        await _prefs!.setDouble(_keyWindowY, position.dy);
      } else {
        // Clear position if not provided
        await _prefs!.remove(_keyWindowX);
        await _prefs!.remove(_keyWindowY);
      }

      debugPrint('✅ Window bounds saved: ${size.width}x${size.height}, maximized: $maximized');
    } catch (e) {
      debugPrint('❌ Failed to save window bounds: $e');
    }
  }

  /// Load saved window bounds
  ///
  /// Returns [WindowBounds] if saved settings exist, null otherwise
  static Future<WindowBounds?> loadWindowBounds() async {
    if (_prefs == null) await initialize();

    try {
      final width = _prefs!.getDouble(_keyWindowWidth);
      final height = _prefs!.getDouble(_keyWindowHeight);
      final maximized = _prefs!.getBool(_keyWindowMaximized) ?? false;

      if (width == null || height == null) {
        debugPrint('ℹ️ No saved window bounds found');
        return null;
      }

      final x = _prefs!.getDouble(_keyWindowX);
      final y = _prefs!.getDouble(_keyWindowY);

      final bounds = WindowBounds(
        width: width,
        height: height,
        x: x,
        y: y,
        maximized: maximized,
      );

      debugPrint('✅ Window bounds loaded: $bounds');
      return bounds;
    } catch (e) {
      debugPrint('❌ Failed to load window bounds: $e');
      return null;
    }
  }

  /// Get default window size for the platform
  static Size getDefaultSize() {
    // Default window size - reasonable starting point
    return const Size(1200, 800);
  }

  /// Get minimum window size
  static Size getMinimumSize() {
    return const Size(800, 600);
  }

  /// Get maximum window size (null means unlimited)
  static Size? getMaximumSize() {
    // No maximum on desktop
    return null;
  }

  /// Clear all saved window settings
  static Future<void> clearSettings() async {
    if (_prefs == null) await initialize();

    try {
      await _prefs!.remove(_keyWindowWidth);
      await _prefs!.remove(_keyWindowHeight);
      await _prefs!.remove(_keyWindowX);
      await _prefs!.remove(_keyWindowY);
      await _prefs!.remove(_keyWindowMaximized);

      debugPrint('✅ Window settings cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear window settings: $e');
    }
  }

  /// Check if window settings exist
  static Future<bool> hasSettings() async {
    if (_prefs == null) await initialize();

    return _prefs!.containsKey(_keyWindowWidth) &&
           _prefs!.containsKey(_keyWindowHeight);
  }
}
