import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/transfer.dart';
import '../models/folder_structure.dart';

class FileService {
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
      return [];
    }
  }

  // Pick a folder for scanning
  Future<String?> pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      print('Error picking folder: $e');
      return null;
    }
  }

  // Scan folder and create structure
  Future<FolderStructure> scanFolder(String folderPath) async {
    final directory = Directory(folderPath);
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
  }

  Future<int> _countFilesInDirectory(Directory directory) async {
    int count = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) count++;
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
    // Create all directories first
    for (final item in structure.directories) {
      final dirPath =
          path.join(basePath, structure.rootName, item.relativePath);
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
      final filePath = path.join(basePath, relativePath);

      // Ensure parent directory exists
      final parentDir = Directory(path.dirname(filePath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Error saving file with path: $e');
      rethrow;
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
      final downloadDir = await getDownloadDirectory();
      final filePath = '$downloadDir${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Error saving file: $e');
      rethrow;
    }
  }

  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  Future<List<int>> readFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.readAsBytes();
    } catch (e) {
      print('Error reading file: $e');
      rethrow;
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
