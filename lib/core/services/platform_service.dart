import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Centralized platform detection and platform-specific operations
/// 
/// FIXED: Abstracts all platform-specific code to single location
/// This makes testing easier and reduces duplication
class PlatformService {
  // Platform detection
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  
  /// Get platform name as string
  static String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
  
  /// Get appropriate path separator for current platform
  static String get pathSeparator => Platform.pathSeparator;
  
  /// Get platform-specific download directory
  static Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Android: Use external storage downloads
      try {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          return directory;
        }
      } catch (e) {
        // Fallback to app directory
      }
      // Fallback to app-specific external storage
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadDir = Directory('${externalDir.path}/Download');
          if (await downloadDir.exists()) {
            return downloadDir;
          }
        }
      } catch (e) {
        // Fallback to documents directory
      }
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloadsDir = Directory('$userProfile\\Downloads');
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
      }
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final downloadsDir = Directory('$home/Downloads');
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
      }
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }
  
  /// Get platform-specific documents directory
  static Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }
  
  /// Get platform-specific temp directory
  static Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }
  
  /// Check if platform supports system tray
  static bool get supportsSystemTray => isDesktop;
  
  /// Check if platform supports window management
  static bool get supportsWindowManagement => isDesktop;
  
  /// Check if platform supports file picker
  static bool get supportsFilePicker => true;
  
  /// Check if platform supports notifications
  static bool get supportsNotifications => true;
  
  /// Get max recommended parallel connections for platform
  static int get recommendedParallelConnections {
    if (isDesktop) return 8;
    if (isAndroid || isIOS) return 4;
    return 2;
  }
  
  /// Get recommended chunk size for platform (in bytes)
  static int get recommendedChunkSize {
    if (isDesktop) return 2 * 1024 * 1024; // 2MB
    if (isAndroid || isIOS) return 1 * 1024 * 1024; // 1MB
    return 512 * 1024; // 512KB
  }
  
  /// Execute platform-specific initialization
  static Future<void> initialize() async {
    // Add any platform-specific initialization here
    if (isAndroid) {
      // Android-specific init
    } else if (isIOS) {
      // iOS-specific init
    } else if (isWindows) {
      // Windows-specific init
    } else if (isLinux) {
      // Linux-specific init
    }
  }
  
  /// Get environment variable safely
  static String? getEnv(String key) {
    try {
      return Platform.environment[key];
    } catch (e) {
      return null;
    }
  }
  
  /// Check if running in debug mode
  static bool get isDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }
}
