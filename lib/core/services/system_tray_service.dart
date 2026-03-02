import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService {
  static final SystemTray _systemTray = SystemTray();
  static bool _initialized = false;
  static VoidCallback? _onShowWindow;
  static VoidCallback? _onToggleServer;
  static VoidCallback? _onExit;

  /// Initialize system tray for desktop platforms
  static Future<void> initialize({
    VoidCallback? onShowWindow,
    VoidCallback? onToggleServer,
    VoidCallback? onExit,
  }) async {
    // Allow retry if previously failed, but skip if already initialized successfully
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isLinux) return;

    _onShowWindow = onShowWindow;
    _onToggleServer = onToggleServer;
    _onExit = onExit;

    try {
      await windowManager.ensureInitialized();

      // Window manager options
      await windowManager.setPreventClose(true);

      // Initialize system tray
      String iconPath;
      if (Platform.isWindows) {
        // Use .ico for Windows - check multiple possible locations
        final possiblePaths = [
          'assets/icon/app_icon.ico',
          'assets/icons/app_icon.ico',
          'assets/icons/app_icon.png', // Fallback to PNG
        ];
        iconPath = possiblePaths.firstWhere(
          (path) => File(path).existsSync(),
          orElse: () => 'assets/icons/app_icon.png',
        );
      } else {
        iconPath = 'assets/icon/app_icon.png';
      }

      await _systemTray.initSystemTray(
        title: 'Syndro',
        iconPath: iconPath,
        toolTip: 'Syndro - Fast File Sharing',
      );

      // Build context menu
      await _buildContextMenu();

      // Handle tray events
      _systemTray.registerSystemTrayEventHandler((eventName) async {
        debugPrint('System tray event: $eventName');
        
        if (eventName == kSystemTrayEventClick) {
          // Left click - show window
          await showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          // Right click - show context menu
          await _systemTray.popUpContextMenu();
        }
      });

      _initialized = true;
      debugPrint('✅ System tray initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize system tray: $e');
    }
  }

  /// Whether the system tray has been successfully initialized
  static bool get isInitialized => _initialized;

  /// Build the system tray context menu
  static Future<void> _buildContextMenu({bool isReceiving = false}) async {
    final menu = Menu();
    
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Open Syndro',
        onClicked: (_) async {
          await showWindow();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: isReceiving ? '⏹ Stop Receiving' : '▶ Start Receiving',
        onClicked: (_) {
          _onToggleServer?.call();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (_) async {
          await exit();
        },
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// Update the tray menu (e.g., when server status changes)
  static Future<void> updateMenu({bool isReceiving = false}) async {
    if (!_initialized) return;
    await _buildContextMenu(isReceiving: isReceiving);
  }

  /// Update the tray tooltip
  static Future<void> updateTooltip(String tooltip) async {
    if (!_initialized) return;
    // Note: Some platforms may not support tooltip updates
    try {
      await _systemTray.setToolTip(tooltip);
    } catch (e) {
      debugPrint('Failed to update tooltip: $e');
    }
  }

  /// Show the main window
  static Future<void> showWindow() async {
    if (!_initialized) return;
    
    try {
      await windowManager.show();
      await windowManager.focus();
      _onShowWindow?.call();
    } catch (e) {
      debugPrint('Failed to show window: $e');
    }
  }

  /// Minimize to system tray
  static Future<void> minimizeToTray() async {
    if (!_initialized) {
      // If tray not initialized, just minimize normally
      await windowManager.minimize();
      return;
    }

    try {
      await windowManager.hide();
      debugPrint('✅ Minimized to tray');
    } catch (e) {
      debugPrint('Failed to minimize to tray: $e');
      await windowManager.minimize();
    }
  }

  /// Exit the application
  static Future<void> exit() async {
    _onExit?.call();
    
    try {
      await _systemTray.destroy();
    } catch (e) {
      debugPrint('Error destroying system tray: $e');
    }
    
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Dispose system tray resources
  static Future<void> dispose() async {
    if (!_initialized) return;
    
    try {
      await _systemTray.destroy();
      _initialized = false;
      debugPrint('✅ System tray disposed');
    } catch (e) {
      debugPrint('Error disposing system tray: $e');
    }
  }
}

/// Mixin for handling window close events (minimize to tray)
mixin WindowListenerMixin on WidgetsBindingObserver implements WindowListener {
  @override
  void onWindowClose() async {
    // Minimize to tray instead of closing
    if (SystemTrayService.isInitialized) {
      await SystemTrayService.minimizeToTray();
    }
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}
}
