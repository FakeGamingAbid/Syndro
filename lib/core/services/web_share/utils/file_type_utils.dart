import 'dart:io';

/// Utility class for file type detection and content types
class FileTypeUtils {
  // Supported image extensions for thumbnails
  static const List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'
  ];

  static const List<String> videoExtensions = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'
  ];

  static const List<String> audioExtensions = [
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'
  ];

  static const List<String> documentExtensions = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'
  ];

  static const List<String> archiveExtensions = [
    'zip', 'rar', '7z', 'tar', 'gz'
  ];

  static const List<String> codeExtensions = [
    'dart', 'js', 'py', 'java', 'cpp', 'html', 'css', 'json', 'xml'
  ];

  static const List<String> apkExtensions = ['apk', 'apks', 'apkm', 'xapk'];
  static const List<String> executableExtensions = ['exe', 'msi'];

  /// Get file type category from filename
  static String getFileType(String filename) {
    final ext = filename.split('.').last.toLowerCase();

    if (imageExtensions.contains(ext)) return 'image';
    if (videoExtensions.contains(ext)) return 'video';
    if (audioExtensions.contains(ext)) return 'audio';
    if (documentExtensions.contains(ext)) return 'document';
    if (archiveExtensions.contains(ext)) return 'archive';
    if (codeExtensions.contains(ext)) return 'code';
    if (apkExtensions.contains(ext)) return 'apk';
    if (executableExtensions.contains(ext)) return 'executable';

    return 'file';
  }

  /// Check if file is an image
  static bool isImage(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  /// Get image content type from extension
  static ContentType getImageContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'png':
        return ContentType('image', 'png');
      case 'gif':
        return ContentType('image', 'gif');
      case 'webp':
        return ContentType('image', 'webp');
      case 'bmp':
        return ContentType('image', 'bmp');
      case 'svg':
        return ContentType('image', 'svg+xml');
      default:
        return ContentType('image', 'jpeg');
    }
  }
}
