import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/transfer.dart';
import '../models/folder_structure.dart';

/// Custom exception for file service errors
class FileServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  FileServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'FileServiceException: $message${code != null ? ' (code: $code)' : ''}';
}

class FileService {
  /// Sanitize filename to prevent path traversal attacks
  /// Removes dangerous characters and path components
  String sanitizeFilename(String filename) {
    if (filename.isEmpty) {
      throw FileServiceException('Filename cannot be empty', code: 'EMPTY_FILENAME');
    }

    // Remove any path separators (both Unix and Windows style)
    String sanitized = filename
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(RegExp(r'\.\.+'), '_')  // Remove .. sequences
        .replaceAll(RegExp(r'^\.'), '_');    // Remove leading dots

    // Remove other dangerous characters for cross-platform compatibility
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');

    // Trim whitespace and dots from ends
    sanitized = sanitized.trim();
    while (sanitized.endsWith('.')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    // Ensure filename is not empty after sanitization
    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }

    // Limit filename length (255 is common filesystem limit)
    if (sanitized.length > 200) {
      final ext = path.extension(sanitized);
      final nameWithoutExt = path.basenameWithoutExtension(sanitized);
      sanitized = '${nameWithoutExt.substring(0, 200 - ext.length)}$ext';
    }

    return sanitized;
  }

  /// Validate that a path is within an allowed directory (prevent path traversal)
  bool isPathWithinDirectory(String filePath, String allowedDirectory) {
    try {
      final normalizedFile = path.normalize(path.absolute(filePath));
      final normalizedDir = path.normalize(path.absolute(allowedDirectory));
      return normalizedFile.startsWith(normalizedDir);
    } catch (e) {
      print('Error validating path: $e');
      return false;
    }
  }

  /// Get a safe file path within the download directory
  Future<String> getSafeFilePath(String filename) async {
    final sanitizedName = sanitizeFilename(filename);
    final downloadDir = await getDownloadDirectory();
    final filePath = path.join(downloadDir, sanitizedName);
    
    // Double-check the path is within allowed directory
    if (!isPathWithinDirectory(filePath, downloadDir)) {
      throw FileServiceException(
        'Invalid filename: path traversal detected',
        code: 'PATH_TRAVERSAL',
      );
    }
    
    return filePath;
  }

  Future<List<TransferItem>> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null) return [];

      final items = <TransferItem>[];

      for (final file in result.files) {
        if (file.path != null) {
          final fileInfo = File(file.path!);
          final stat = await fileInfo.stat();

          items.add(TransferItem(
            name: file.name,
            path: file.path!,
            size: stat.size,
            isDirectory: false,
          ));
        }
      }

      return items;
    } catch (e) {
      print('Error picking files: $e');
      throw FileServiceException('Failed to pick files', originalError: e);
    }
  }

  // Pick a folder for scanning
  Future<String?> pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      print('Error picking folder: $e');
      throw FileServiceException('Failed to pick folder', originalError: e);
    }
  }

  // Scan folder and create structure
  Future<FolderStructure> scanFolder(String folderPath) async {
    final directory = Directory(folderPath);
    
    if (!await directory.exists()) {
      throw FileServiceException('Directory does not exist: $folderPath', code: 'DIR_NOT_FOUND');
    }
    
    final rootName = path.basename(folderPath);

    final items = <TransferItem>[];
    final hierarchy = <String, List<String>>{};

    await _scanDirectoryRecursive(
      directory,
      folderPath,
      '',
      items,
      hierarchy,
    );

    return FolderStructure(
      rootPath: folderPath,
      rootName: rootName,
      items: items,
      hierarchy: hierarchy,
    );
  }

  Future<void> _scanDirectoryRecursive(
    Directory directory,
    String rootPath,
    String relativePath,
    List<TransferItem> items,
    Map<String, List<String>> hierarchy,
  ) async {
    try {
      final entities = directory.listSync();
      final children = <String>[];

      for (final entity in entities) {
        final entityName = path.basename(entity.path);
        final entityRelativePath =
            relativePath.isEmpty ? entityName : '$relativePath/$entityName';

        if (entity is File) {
          final stat = await entity.stat();
          items.add(TransferItem(
            name: entityName,
            path: entity.path,
            size: stat.size,
            isDirectory: false,
            parentPath: relativePath,
          ));
          children.add(entityRelativePath);
        } else if (entity is Directory) {
          // Count files in this directory
          final fileCount = await _countFilesInDirectory(entity);
          items.add(TransferItem(
            name: entityName,
            path: entity.path,
            size: 0,
            isDirectory: true,
            parentPath: relativePath,
            itemCount: fileCount,
          ));
          children.add(entityRelativePath);

          // Recursively scan subdirectory
          await _scanDirectoryRecursive(
            entity,
            rootPath,
            entityRelativePath,
            items,
            hierarchy,
          );
        }
      }

      hierarchy[relativePath] = children;
    } catch (e) {
      print('Error scanning directory: $e');
      throw FileServiceException('Failed to scan directory: $relativePath', originalError: e);
    }
  }

  Future<int> _countFilesInDirectory(Directory directory) async {
    int count = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) count++;
      }
    } catch (e) {
      print('Error counting files in directory: $e');
      // Return 0 instead of throwing - this is a non-critical operation
    }
    return count;
  }

  // Get all files from a folder structure (flattened)
  List<TransferItem> getAllFilesInFolder(FolderStructure structure) {
    return structure.items.where((item) => !item.isDirectory).toList();
  }

  // Recreate folder structure on receiver
  Future<void> recreateFolderStructure(
    String basePath,
    FolderStructure structure,
  ) async {
    // Validate base path
    final downloadDir = await getDownloadDirectory();
    if (!isPathWithinDirectory(basePath, downloadDir)) {
      throw FileServiceException('Invalid base path', code: 'PATH_TRAVERSAL');
    }

    // Create all directories first
    for (final item in structure.directories) {
      // Sanitize the relative path components
      final sanitizedRelPath = item.relativePath
          .split('/')
          .map((part) => sanitizeFilename(part))
          .join(Platform.pathSeparator);
      
      final dirPath = path.join(basePath, sanitizeFilename(structure.rootName), sanitizedRelPath);
      
      // Verify path is still within allowed directory
      if (!isPathWithinDirectory(dirPath, downloadDir)) {
        throw FileServiceException(
          'Path traversal detected in folder structure',
          code: 'PATH_TRAVERSAL',
        );
      }
      
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  // Save file with relative path (for folder transfers)
  Future<File> saveFileWithPath(
      String basePath, String relativePath, List<int> bytes) async {
    try {
      // Sanitize path components
      final sanitizedRelPath = relativePath
          .split('/')
          .map((part) => sanitizeFilename(part))
          .join(Platform.pathSeparator);
      
      final filePath = path.join(basePath, sanitizedRelPath);
      
      // Verify path is within allowed directory
      final downloadDir = await getDownloadDirectory();
      if (!isPathWithinDirectory(filePath, downloadDir)) {
        throw FileServiceException(
          'Invalid file path: path traversal detected',
          code: 'PATH_TRAVERSAL',
        );
      }

      // Ensure parent directory exists
      final parentDir = Directory(path.dirname(filePath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      if (e is FileServiceException) rethrow;
      print('Error saving file with path: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  Future<String> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        return directory?.path ?? '/storage/emulated/0/Download';
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return '$userProfile\\Downloads';
        }
        // Fallback if USERPROFILE is not set
        return 'C:\\Users\\Public\\Downloads';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return '$home/Downloads';
        }
        // Fallback if HOME is not set
        return '/tmp';
      }
    } catch (e) {
      print('Error getting download directory: $e');
    }

    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> saveFile(String fileName, List<int> bytes) async {
    try {
      // Sanitize filename to prevent path traversal
      final sanitizedName = sanitizeFilename(fileName);
      final downloadDir = await getDownloadDirectory();
      final filePath = '$downloadDir${Platform.pathSeparator}$sanitizedName';
      
      // Double-check path is within download directory
      if (!isPathWithinDirectory(filePath, downloadDir)) {
        throw FileServiceException(
          'Invalid filename: path traversal detected',
          code: 'PATH_TRAVERSAL',
        );
      }
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      if (e is FileServiceException) rethrow;
      print('Error saving file: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      print('Error getting file size: $e');
      throw FileServiceException('Failed to get file size', originalError: e);
    }
  }

  Future<List<int>> readFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileServiceException('File does not exist: $filePath', code: 'FILE_NOT_FOUND');
      }
      return await file.readAsBytes();
    } catch (e) {
      if (e is FileServiceException) rethrow;
      print('Error reading file: $e');
      throw FileServiceException('Failed to read file', originalError: e);
    }
  }

  String getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return '';
    return fileName.substring(lastDot + 1).toLowerCase();
  }

  String getMimeType(String fileName) {
    final extension = getFileExtension(fileName);

    const mimeTypes = {
      // Images
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',

      // Videos
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'flv': 'video/x-flv',

      // Audio
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',

      // Documents
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',

      // Archives
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',

      // Text
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'dart': 'text/plain',

      // Executables
      'apk': 'application/vnd.android.package-archive',
      'exe': 'application/x-msdownload',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }
}
