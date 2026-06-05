import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Platform-specific path utilities
class PlatformPaths {
  /// Get default download directory based on platform
  static Future<String> getDefaultDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Use the public Downloads folder directly
        // This is accessible to all apps and visible in file managers
        const publicDownload = '/storage/emulated/0/Download';
        final downloadDir = Directory(publicDownload);
        
        // Check if we can access it
        if (await downloadDir.exists()) {
          // Try to create a test file to verify write permission
          try {
            final testFile = File('$publicDownload/.syndro_test');
            await testFile.writeAsString('test');
            await testFile.delete();
            debugPrint('✅ Using public Downloads folder: $publicDownload');
            return publicDownload;
          } catch (e) {
            debugPrint('⚠️ Cannot write to public Downloads: $e');
          }
        }

        // Fallback: Create Syndro folder in public Downloads
        const syndroDownload = '/storage/emulated/0/Download/Syndro';
        final syndroDir = Directory(syndroDownload);
        try {
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }
          debugPrint('✅ Using Syndro Downloads folder: $syndroDownload');
          return syndroDownload;
        } catch (e) {
          debugPrint('⚠️ Cannot create Syndro folder: $e');
        }

        // Fallback: Try external storage directory
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          debugPrint('⚠️ Falling back to app storage: ${extDir.path}');
          return extDir.path;
        }

        // Last resort
        return publicDownload;
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final downloadPath = '$userProfile\\Downloads';
          final downloadDir = Directory(downloadPath);
          if (await downloadDir.exists()) {
            return downloadPath;
          }
        }
        return 'C:\\Users\\Public\\Downloads';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return '$home/Downloads';
        }
        return '/tmp';
      }
    } catch (e) {
      debugPrint('Error getting download directory: $e');
    }

    // Final fallback - use app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'Syndro', 'Received');
  }
}
