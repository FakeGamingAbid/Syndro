import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
  String toString() =>
      'FileServiceException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Progress callback for streaming operations
typedef ProgressCallback = void Function(int bytesProcessed, int totalBytes);

class FileService {
  /// Default chunk size for streaming (1MB)
  static const int defaultChunkSize = 1024 * 1024;

  /// Maximum file size allowed for non-streaming read (10MB)
  static const int maxDirectReadSize = 10 * 1024 * 1024;

  /// Sanitize filename to prevent path traversal attacks
  String sanitizeFilename(String filename) {
    if (filename.isEmpty) {
      throw FileServiceException('Filename cannot be empty',
          code: 'EMPTY_FILENAME');
    }

    String sanitized = filename
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(RegExp(r'\.\.+'), '_')
        .replaceAll(RegExp(r'^\.'), '_');

    sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
    sanitized = sanitized.trim();

    while (sanitized.endsWith('.')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }

    if (sanitized.length > 200) {
      final ext = path.extension(sanitized);
      final nameWithoutExt = path.basenameWithoutExtension(sanitized);
      sanitized = '${nameWithoutExt.substring(0, 200 - ext.length)}$ext';
    }

    return sanitized;
  }

  /// Validate that a path is within an allowed directory
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

  Future<String?> pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      print('Error picking folder: $e');
      throw FileServiceException('Failed to pick folder', originalError: e);
    }
  }

  Future<FolderStructure> scanFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      throw FileServiceException('Directory does not exist: $folderPath',
          code: 'DIR_NOT_FOUND');
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
      throw FileServiceException('Failed to scan directory: $relativePath',
          originalError: e);
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
    }
    return count;
  }

  List<TransferItem> getAllFilesInFolder(FolderStructure structure) {
    return structure.items.where((item) => !item.isDirectory).toList();
  }

  Future<void> recreateFolderStructure(
    String basePath,
    FolderStructure structure,
  ) async {
    final downloadDir = await getDownloadDirectory();

    if (!isPathWithinDirectory(basePath, downloadDir)) {
      throw FileServiceException('Invalid base path', code: 'PATH_TRAVERSAL');
    }

    for (final item in structure.directories) {
      final sanitizedRelPath = item.relativePath
          .split('/')
          .map((part) => sanitizeFilename(part))
          .join(Platform.pathSeparator);

      final dirPath = path.join(
          basePath, sanitizeFilename(structure.rootName), sanitizedRelPath);

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

  Stream<List<int>> readFileStream(String filePath,
      {int chunkSize = defaultChunkSize}) {
    final file = File(filePath);
    return file.openRead();
  }

  Future<void> streamFileWithProgress({
    required String filePath,
    required Future<void> Function(List<int> chunk) onChunk,
    ProgressCallback? onProgress,
    int chunkSize = defaultChunkSize,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileServiceException('File does not exist: $filePath',
          code: 'FILE_NOT_FOUND');
    }

    final fileSize = await file.length();
    int bytesRead = 0;

    try {
      final stream = file.openRead();
      await for (final chunk in stream) {
        await onChunk(chunk);
        bytesRead += chunk.length;
        onProgress?.call(bytesRead, fileSize);
      }
    } catch (e) {
      print('Error streaming file: $e');
      throw FileServiceException('Failed to stream file', originalError: e);
    }
  }

  Future<File> saveFileFromStream({
    required String fileName,
    required Stream<List<int>> dataStream,
    int? expectedSize,
    ProgressCallback? onProgress,
  }) async {
    final sanitizedName = sanitizeFilename(fileName);
    final downloadDir = await getDownloadDirectory();
    final finalPath = '$downloadDir${Platform.pathSeparator}$sanitizedName';
    final tempPath = '$finalPath.tmp';

    if (!isPathWithinDirectory(finalPath, downloadDir)) {
      throw FileServiceException('Invalid filename: path traversal detected',
          code: 'PATH_TRAVERSAL');
    }

    final dir = Directory(downloadDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    IOSink? sink;
    try {
      final tempFile = File(tempPath);
      sink = tempFile.openWrite();

      int bytesWritten = 0;
      await for (final chunk in dataStream) {
        sink.add(chunk);
        bytesWritten += chunk.length;
        onProgress?.call(bytesWritten, expectedSize ?? bytesWritten);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final finalFile = File(finalPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await File(tempPath).rename(finalPath);
      return File(finalPath);
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      print('Error saving file from stream: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  Future<File> copyFileStreaming({
    required String sourcePath,
    required String destinationPath,
    ProgressCallback? onProgress,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileServiceException('Source file not found: $sourcePath',
          code: 'FILE_NOT_FOUND');
    }

    final fileSize = await sourceFile.length();
    final tempPath = '$destinationPath.tmp';

    IOSink? sink;
    try {
      final destDir = Directory(path.dirname(destinationPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final tempFile = File(tempPath);
      sink = tempFile.openWrite();

      int bytesCopied = 0;
      final stream = sourceFile.openRead();
      await for (final chunk in stream) {
        sink.add(chunk);
        bytesCopied += chunk.length;
        onProgress?.call(bytesCopied, fileSize);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final destFile = File(destinationPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }

      await File(tempPath).rename(destinationPath);
      return File(destinationPath);
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      print('Error copying file: $e');
      throw FileServiceException('Failed to copy file', originalError: e);
    }
  }

  Future<File> saveFileWithPath(
      String basePath, String relativePath, List<int> bytes) async {
    try {
      final sanitizedRelPath = relativePath
          .split('/')
          .map((part) => sanitizeFilename(part))
          .join(Platform.pathSeparator);

      final filePath = path.join(basePath, sanitizedRelPath);
      final downloadDir = await getDownloadDirectory();

      if (!isPathWithinDirectory(filePath, downloadDir)) {
        throw FileServiceException(
          'Invalid file path: path traversal detected',
          code: 'PATH_TRAVERSAL',
        );
      }

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

  Future<File> saveFileWithPathFromStream({
    required String basePath,
    required String relativePath,
    required Stream<List<int>> dataStream,
    int? expectedSize,
    ProgressCallback? onProgress,
  }) async {
    final sanitizedRelPath = relativePath
        .split('/')
        .map((part) => sanitizeFilename(part))
        .join(Platform.pathSeparator);

    final filePath = path.join(basePath, sanitizedRelPath);
    final downloadDir = await getDownloadDirectory();

    if (!isPathWithinDirectory(filePath, downloadDir)) {
      throw FileServiceException(
        'Invalid file path: path traversal detected',
        code: 'PATH_TRAVERSAL',
      );
    }

    final tempPath = '$filePath.tmp';

    IOSink? sink;
    try {
      final parentDir = Directory(path.dirname(filePath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final tempFile = File(tempPath);
      sink = tempFile.openWrite();

      int bytesWritten = 0;
      await for (final chunk in dataStream) {
        sink.add(chunk);
        bytesWritten += chunk.length;
        onProgress?.call(bytesWritten, expectedSize ?? bytesWritten);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await File(tempPath).rename(filePath);
      return File(filePath);
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      if (e is FileServiceException) rethrow;
      print('Error saving file from stream: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  /// Get download directory - FIXED FOR ANDROID
  Future<String> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Use public Downloads folder that user can access
        final syndroDir = Directory('/storage/emulated/0/Download/Syndro');

        try {
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
            debugPrint('📁 Created Syndro folder in Downloads');
          }

          // Test if we can write to it
          final testFile = File('${syndroDir.path}/.test');
          await testFile.writeAsString('test');
          await testFile.delete();

          debugPrint('📁 Using download directory: ${syndroDir.path}');
          return syndroDir.path;
        } catch (e) {
          debugPrint('⚠️ Cannot write to Downloads/Syndro: $e');

          // Fallback to app-specific directory
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            debugPrint('📁 Fallback to: ${directory.path}');
            return directory.path;
          }
        }

        return '/storage/emulated/0/Download/Syndro';
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final syndroDir = Directory('$userProfile\\Downloads\\Syndro');
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }
          return syndroDir.path;
        }
        return 'C:\\Users\\Public\\Downloads';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final syndroDir = Directory('$home/Downloads/Syndro');
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }
          return syndroDir.path;
        }
        return '/tmp';
      }
    } catch (e) {
      debugPrint('Error getting download directory: $e');
    }

    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> saveFile(String fileName, List<int> bytes) async {
    try {
      final sanitizedName = sanitizeFilename(fileName);
      final downloadDir = await getDownloadDirectory();
      final filePath = '$downloadDir${Platform.pathSeparator}$sanitizedName';

      if (!isPathWithinDirectory(filePath, downloadDir)) {
        throw FileServiceException(
          'Invalid filename: path traversal detected',
          code: 'PATH_TRAVERSAL',
        );
      }

      // Ensure directory exists
      final dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      print('✅ File saved to: $filePath');
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
        throw FileServiceException('File does not exist: $filePath',
            code: 'FILE_NOT_FOUND');
      }

      final fileSize = await file.length();
      if (fileSize > maxDirectReadSize) {
        throw FileServiceException(
          'File too large for direct read ($fileSize bytes). Use readFileStream() instead.',
          code: 'FILE_TOO_LARGE',
        );
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
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'flv': 'video/x-flv',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
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
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'dart': 'text/plain',
      'apk': 'application/vnd.android.package-archive',
      'exe': 'application/x-msdownload',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }
}
