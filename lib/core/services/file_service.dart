import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/transfer.dart';
import '../models/folder_structure.dart';

/// Custom exception for file service errors
///
/// Thrown when file operations fail, including:
/// - File not found
/// - Invalid paths
/// - Permission denied
/// - Path traversal attempts
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
///
/// Called periodically during file streaming operations
/// with the current progress.
///
/// Parameters:
/// - [bytesProcessed]: Number of bytes processed so far
/// - [totalBytes]: Total bytes to process (may be 0 if unknown)
typedef ProgressCallback = void Function(int bytesProcessed, int totalBytes);

/// File service for file operations
///
/// Provides cross-platform file operations including:
/// - File and folder picking
/// - Directory scanning
/// - Safe file path handling
/// - Streaming file read/write
/// - Path validation and sanitization
class FileService {
  /// Default chunk size for streaming (1MB)
  static const int defaultChunkSize = 1024 * 1024;

  /// Maximum file size allowed for non-streaming read (10MB)
  static const int maxDirectReadSize = 10 * 1024 * 1024;

  /// Sanitize filename to prevent path traversal attacks
  ///
  /// This method removes or replaces:
  /// - Path separators (/ \)
  /// - Parent directory references (..)
  /// - Hidden files (starting with .)
  /// - Invalid characters (< > : " | ? *)
  /// - Control characters
  ///
  /// Also truncates filenames longer than 200 characters
  /// while preserving the file extension.
  ///
  /// Parameters:
  /// - [filename]: The original filename to sanitize
  ///
  /// Returns a safe filename that can be used without risk.
  ///
  /// Throws [FileServiceException] if filename is empty.
  String sanitizeFilename(String filename) {
    if (filename.isEmpty) {
      throw FileServiceException('Filename cannot be empty',
          code: 'EMPTY_FILENAME');
    }

    // FIX (Bug #9): Handle Unicode characters that look like path separators
    // Characters like U+2044 (⁄) and U+2215 (∕) look like slashes
    String sanitized = filename;
    
    // Replace Unicode characters that look like path separators
    sanitized = sanitized.replaceAll('⁄', '_');  // U+2044 (fraction slash)
    sanitized = sanitized.replaceAll('∕', '_');  // U+2215 (division slash)
    sanitized = sanitized.replaceAll('＼', '_');  // U+FF3C (fullwidth reverse solidus)
    sanitized = sanitized.replaceAll('／', '_');  // U+FF0F (fullwidth solidus)
    
    // Replace actual path separators and parent directory references
    sanitized = sanitized
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('..', '_')
        .replaceAll(RegExp(r'^\.'), '_');

    // FIX: Simplified regex for invalid characters
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
      // Safe UTF-8 truncation - use runes to avoid cutting multi-byte characters
      final maxNameLength = 200 - ext.length;
      if (maxNameLength > 0) {
        final runes = nameWithoutExt.runes.toList();
        final truncatedRunes = runes.take(maxNameLength).toList();
        sanitized = '${String.fromCharCodes(truncatedRunes)}$ext';
      } else {
        // Extension too long, just truncate the whole string
        final runes = sanitized.runes.toList();
        sanitized = String.fromCharCodes(runes.take(200));
      }
    }

    return sanitized;
  }

  /// Generate a unique filename by appending a counter suffix if the file exists
  ///
  /// Example: file.pdf -> file (1).pdf -> file (2).pdf
  ///
  /// Parameters:
  /// - [filename]: The desired filename
  /// - [directory]: The directory to check for existing files
  ///
  /// Returns a unique filename that doesn't conflict with existing files
  Future<String> getUniqueFilename(String filename, String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      return filename;
    }

    // Check if the original filename already exists
    final originalPath = path.join(directory, filename);
    if (!await File(originalPath).exists()) {
      return filename;
    }

    // Extract name and extension
    final nameWithoutExt = path.basenameWithoutExtension(filename);
    final extension = path.extension(filename);

    // Try incrementing counter until we find a unique name
    int counter = 1;
    String newFilename;
    do {
      newFilename = '$nameWithoutExt ($counter)$extension';
      counter++;
    } while (await File(path.join(directory, newFilename)).exists());

    return newFilename;
  }

  /// Validate that a path is within an allowed directory
  ///
  /// Resolves symlinks to prevent symlink attacks (TOCTOU mitigation).
  /// This ensures that even if a symlink is created, we validate
  /// the final resolved path.
  ///
  /// Parameters:
  /// - [filePath]: The file path to validate
  /// - [allowedDirectory]: The directory the file must be within
  ///
  /// Returns true if the file is within the allowed directory,
  /// false otherwise.
  bool isPathWithinDirectory(String filePath, String allowedDirectory) {
    try {
      // FIX: Use canonical path for more reliable comparison
      final file = File(filePath);
      final allowedDir = Directory(allowedDirectory);

      // Get canonical paths - this resolves symlinks
      String resolvedFilePath;
      String resolvedAllowedDir;

      try {
        resolvedFilePath = file.resolveSymbolicLinksSync();
      } catch (e) {
        // If file doesn't exist, resolve parent directory
        resolvedFilePath = filePath;
      }

      try {
        resolvedAllowedDir = allowedDir.resolveSymbolicLinksSync();
      } catch (e) {
        resolvedAllowedDir = allowedDirectory;
      }

      final normalizedFile = path.normalize(path.absolute(resolvedFilePath));
      final normalizedDir = path.normalize(path.absolute(resolvedAllowedDir));

      return normalizedFile.startsWith(normalizedDir + Platform.pathSeparator) ||
          normalizedFile == normalizedDir;
    } catch (e) {
      debugPrint('Error validating path: $e');
      return false;
    }
  }

  /// Get a safe file path within the download directory
  ///
  /// Combines [sanitizeFilename] with path validation to ensure
  /// the resulting path is safe. This is the recommended way to
  /// generate file paths for received files.
  ///
  /// Parameters:
  /// - [filename]: The desired filename
  ///
  /// Returns the full path within the download directory.
  ///
  /// Throws [FileServiceException] if:
  /// - Download directory is not available
  /// - The filename would result in path traversal
  /// - The filename contains null bytes (security risk)
  Future<String> getSafeFilePath(String filename) async {
    if (filename.isEmpty) {
      throw FileServiceException('Filename cannot be empty', code: 'EMPTY_FILENAME');
    }
    
    // Security check: Null bytes can be used to truncate strings unexpectedly
    // This is a common attack vector in C-based file systems
    if (filename.contains('\x00')) {
      throw FileServiceException(
        'Invalid filename: contains null bytes',
        code: 'NULL_BYTE_IN_FILENAME',
      );
    }
    
    final sanitizedName = sanitizeFilename(filename);
    final downloadDir = await getDownloadDirectory();
    
    if (downloadDir.isEmpty) {
      throw FileServiceException('Download directory not available', code: 'DIR_NOT_AVAILABLE');
    }
    
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
            createdAt: stat.accessed, // Best approximation for creation time
            modifiedAt: stat.modified,
          ));
        }
      }

      return items;
    } catch (e) {
      debugPrint('Error picking files: $e');
      throw FileServiceException('Failed to pick files', originalError: e);
    }
  }

  /// Pick only media files (images and videos) - similar to browser share
  Future<List<TransferItem>> pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media, // This picks images and videos
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
            createdAt: stat.accessed, // Best approximation for creation time
            modifiedAt: stat.modified,
          ));
        }
      }

      return items;
    } catch (e) {
      debugPrint('Error picking media: $e');
      throw FileServiceException('Failed to pick media', originalError: e);
    }
  }

  Future<String?> pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      debugPrint('Error picking folder: $e');
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
        final entityRelativePath = relativePath.isEmpty
            ? entityName
            : '$relativePath/$entityName';

        if (entity is File) {
          final stat = await entity.stat();

          items.add(TransferItem(
            name: entityName,
            path: entity.path,
            size: stat.size,
            isDirectory: false,
            parentPath: relativePath,
            createdAt: stat.accessed,
            modifiedAt: stat.modified,
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
      debugPrint('Error scanning directory: $e');
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
      debugPrint('Error counting files in directory: $e');
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

  /// FIX: Now properly uses chunkSize parameter for chunked reading
  Stream<List<int>> readFileStream(String filePath,
      {int chunkSize = defaultChunkSize}) async* {
    final file = File(filePath);
    final raf = await file.open(mode: FileMode.read);
    try {
      while (true) {
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;
        yield chunk;
      }
    } finally {
      await raf.close();
    }
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
      debugPrint('Error streaming file: $e');
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
        } catch (closeError) {
          debugPrint('Error closing sink during cleanup: $closeError');
        }
      }

      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (deleteError) {
        debugPrint('Error deleting temp file during cleanup: $deleteError');
      }

      debugPrint('Error saving file from stream: $e');
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
        } catch (closeError) {
          debugPrint('Error closing sink during copy cleanup: $closeError');
        }
      }

      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (deleteError) {
        debugPrint('Error deleting temp file during copy cleanup: $deleteError');
      }

      debugPrint('Error copying file: $e');
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
      debugPrint('Error saving file with path: $e');
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
        } catch (closeError) {
          debugPrint('Error closing sink during save cleanup: $closeError');
        }
      }

      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (deleteError) {
        debugPrint('Error deleting temp file during save cleanup: $deleteError');
      }

      if (e is FileServiceException) rethrow;
      debugPrint('Error saving file from stream: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  /// Get download directory
  Future<String> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final possiblePaths = [
          '/storage/emulated/0/Download/Syndro',
          '/sdcard/Download/Syndro',
        ];

        for (final downloadPath in possiblePaths) {
          try {
            final syndroDir = Directory(downloadPath);

            if (!await syndroDir.exists()) {
              await syndroDir.create(recursive: true);
            }

            // Test if we can write to it
            final testFile = File('${syndroDir.path}/.write_test');
            await testFile.writeAsString('test');
            await testFile.delete();

            debugPrint('📁 Using download directory: ${syndroDir.path}');
            return syndroDir.path;
          } catch (e) {
            debugPrint('⚠️ Cannot use $downloadPath: $e');
            continue;
          }
        }

        // Fallback to app-specific external storage
        try {
          final externalDir = await getExternalStorageDirectory();

          if (externalDir != null) {
            final syndroDir = Directory('${externalDir.path}/Syndro');

            if (!await syndroDir.exists()) {
              await syndroDir.create(recursive: true);
            }

            debugPrint('📁 Fallback to app external: ${syndroDir.path}');
            return syndroDir.path;
          }
        } catch (e) {
          debugPrint('⚠️ Cannot use external storage: $e');
        }

        // Last resort - app documents directory
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final syndroDir = Directory('${docsDir.path}/Syndro');

          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }

          debugPrint('📁 Fallback to app docs: ${syndroDir.path}');
          return syndroDir.path;
        } catch (e) {
          debugPrint('⚠️ Cannot use app documents: $e');
        }

        throw FileServiceException(
          'Could not find a writable directory on this device',
          code: 'NO_WRITABLE_DIR',
        );
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];

        if (userProfile != null && userProfile.isNotEmpty) {
          final syndroDir =
              Directory(path.join(userProfile, 'Downloads', 'Syndro'));

          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }

          return syndroDir.path;
        }

        // Fallback for Windows
        final docsDir = await getApplicationDocumentsDirectory();
        final syndroDir = Directory(path.join(docsDir.path, 'Syndro'));

        if (!await syndroDir.exists()) {
          await syndroDir.create(recursive: true);
        }

        return syndroDir.path;
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];

        if (home != null && home.isNotEmpty) {
          final syndroDir = Directory('$home/Downloads/Syndro');

          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }

          return syndroDir.path;
        }

        // Fallback for Linux
        final docsDir = await getApplicationDocumentsDirectory();
        final syndroDir = Directory(path.join(docsDir.path, 'Syndro'));

        if (!await syndroDir.exists()) {
          await syndroDir.create(recursive: true);
        }

        return syndroDir.path;
      }
    } catch (e) {
      debugPrint('Error getting download directory: $e');
      if (e is FileServiceException) rethrow;
    }

    // Final fallback for any platform
    final directory = await getApplicationDocumentsDirectory();
    final syndroDir = Directory(path.join(directory.path, 'Syndro'));

    if (!await syndroDir.exists()) {
      await syndroDir.create(recursive: true);
    }

    return syndroDir.path;
  }

  Future<File> saveFile(String fileName, List<int> bytes) async {
    try {
      final sanitizedName = sanitizeFilename(fileName);
      final downloadDir = await getDownloadDirectory();
      
      // F-03: Get unique filename to prevent silent file overwrite
      final uniqueName = await getUniqueFilename(sanitizedName, downloadDir);
      final filePath = '$downloadDir${Platform.pathSeparator}$uniqueName';

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

      debugPrint('✅ File saved to: $filePath');
      return file;
    } catch (e) {
      if (e is FileServiceException) rethrow;
      debugPrint('Error saving file: $e');
      throw FileServiceException('Failed to save file', originalError: e);
    }
  }

  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      throw FileServiceException('Failed to get file size', originalError: e);
    }
  }

  // FIX: This method now properly warns about large files
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
      debugPrint('Error reading file: $e');
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
      'apks': 'application/vnd.android.package-archive',
      'apkm': 'application/vnd.android.package-archive',
      'xapk': 'application/vnd.android.package-archive',
      'exe': 'application/x-msdownload',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }
}
