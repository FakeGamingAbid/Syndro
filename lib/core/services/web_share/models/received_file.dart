import 'dart:io';

/// Status of a pending/received file
enum FileReceiveStatus {
  pending,    // File received but not yet saved
  saving,     // Currently being saved
  saved,      // Successfully saved to final location
  discarded,  // User discarded the file
  error,      // Error occurred during save
}

/// Model for received files with pending/save functionality
class ReceivedFile {
  final String name;
  final String tempPath;      // Temporary storage path
  String? finalPath;          // Final saved path (null until saved)
  final int size;
  final DateTime receivedAt;
  FileReceiveStatus status;
  String? errorMessage;

  ReceivedFile({
    required this.name,
    required this.tempPath,
    this.finalPath,
    required this.size,
    required this.receivedAt,
    this.status = FileReceiveStatus.pending,
    this.errorMessage,
  });

  /// Check if file is an image
  bool get isImage {
    final ext = name.split('.').last.toLowerCase();
    const imageExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg'
    ];
    return imageExtensions.contains(ext);
  }

  /// Check if file is a video
  bool get isVideo {
    final ext = name.split('.').last.toLowerCase();
    const videoExtensions = [
      'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp', 'wmv'
    ];
    return videoExtensions.contains(ext);
  }

  /// Check if file is media (image or video)
  bool get isMedia => isImage || isVideo;

  /// Get file type for icon display
  String get fileType {
    final ext = name.split('.').last.toLowerCase();
    
    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg'];
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp', 'wmv'];
    const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'];
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'];
    const spreadsheetExts = ['xls', 'xlsx', 'csv', 'ods'];
    const presentationExts = ['ppt', 'pptx', 'odp'];
    const archiveExts = ['zip', 'rar', '7z', 'tar', 'gz'];
    const codeExts = ['dart', 'js', 'py', 'java', 'cpp', 'html', 'css', 'json', 'xml'];
    const apkExts = ['apk', 'apks', 'apkm', 'xapk'];
    const exeExts = ['exe', 'msi'];

    if (imageExts.contains(ext)) return 'image';
    if (videoExts.contains(ext)) return 'video';
    if (audioExts.contains(ext)) return 'audio';
    if (docExts.contains(ext)) return 'document';
    if (spreadsheetExts.contains(ext)) return 'spreadsheet';
    if (presentationExts.contains(ext)) return 'presentation';
    if (archiveExts.contains(ext)) return 'archive';
    if (codeExts.contains(ext)) return 'code';
    if (apkExts.contains(ext)) return 'apk';
    if (exeExts.contains(ext)) return 'executable';
    return 'file';
  }

  /// Get the temp file reference
  File get tempFile => File(tempPath);

  /// Check if temp file exists
  Future<bool> get tempFileExists => tempFile.exists();

  /// Formatted file size string
  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Check if file can be saved (is pending)
  bool get canSave => status == FileReceiveStatus.pending;

  /// Check if file can be discarded
  bool get canDiscard => 
      status == FileReceiveStatus.pending || 
      status == FileReceiveStatus.error;

  /// Check if file is already processed
  bool get isProcessed => 
      status == FileReceiveStatus.saved || 
      status == FileReceiveStatus.discarded;

  @override
  String toString() {
    return 'ReceivedFile(name: $name, size: $sizeFormatted, status: $status)';
  }
}
