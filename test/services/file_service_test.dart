import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/file_service.dart';
import 'package:syndro/core/models/transfer.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  group('FileService', () {
    late FileService fileService;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await getTemporaryDirectory();
    });

    setUp(() {
      fileService = FileService();
    });

    group('getFileInfo', () {
      test('should return correct file info for existing file', () async {
        final testFile = File(path.join(tempDir.path, 'test_file.txt'));
        await testFile.writeAsString('Test content');
        
        final info = await fileService.getFileInfo(testFile.path);
        
        expect(info, isNotNull);
        expect(info.fileName, equals('test_file.txt'));
        expect(info.fileSize, greaterThan(0));
        expect(info.isDirectory, isFalse);
        
        await testFile.delete();
      });

      test('should return correct info for directory', () async {
        final testDir = Directory(path.join(tempDir.path, 'test_dir'));
        await testDir.create();
        
        final info = await fileService.getFileInfo(testDir.path);
        
        expect(info, isNotNull);
        expect(info.fileName, equals('test_dir'));
        expect(info.isDirectory, isTrue);
        
        await testDir.delete();
      });

      test('should throw for non-existent file', () async {
        expect(
          () => fileService.getFileInfo('/non/existent/file.txt'),
          throwsA(isA<FileServiceException>()),
        );
      });
    });

    group('validatePath', () {
      test('should accept valid paths', () {
        expect(
          () => fileService.validatePath('/valid/path/to/file.txt'),
          returnsNormally,
        );
      });

      test('should reject path traversal attempts', () {
        expect(
          () => fileService.validatePath('/valid/path/../../../etc/passwd'),
          throwsA(isA<FileServiceException>()),
        );
      });

      test('should reject null bytes in path', () {
        expect(
          () => fileService.validatePath('/valid/path\u0000file.txt'),
          throwsA(isA<FileServiceException>()),
        );
      });
    });

    group('sanitizeFileName', () {
      test('should remove dangerous characters', () {
        final result = fileService.sanitizeFileName('file<>:"/\\|?*name.txt');
        expect(result, equals('file_________name.txt'));
      });

      test('should preserve valid file names', () {
        final result = fileService.sanitizeFileName('valid_file-name.txt');
        expect(result, equals('valid_file-name.txt'));
      });

      test('should handle empty filename', () {
        final result = fileService.sanitizeFileName('');
        expect(result, equals('unnamed_file'));
      });
    });

    group('formatFileSize', () {
      test('should format bytes correctly', () {
        expect(fileService.formatFileSize(500), equals('500 B'));
        expect(fileService.formatFileSize(0), equals('0 B'));
      });

      test('should format kilobytes correctly', () {
        expect(fileService.formatFileSize(1024), equals('1.0 KB'));
        expect(fileService.formatFileSize(1536), equals('1.5 KB'));
      });

      test('should format megabytes correctly', () {
        expect(fileService.formatFileSize(1024 * 1024), equals('1.0 MB'));
        expect(fileService.formatFileSize(2.5 * 1024 * 1024), equals('2.5 MB'));
      });

      test('should format gigabytes correctly', () {
        expect(fileService.formatFileSize(1024 * 1024 * 1024), equals('1.0 GB'));
      });
    });

    group('getUniqueFilePath', () {
      test('should return same path if file does not exist', () async {
        final uniquePath = fileService.getUniqueFilePath(
          path.join(tempDir.path, 'unique_file.txt'),
        );
        
        expect(uniquePath, equals(path.join(tempDir.path, 'unique_file.txt')));
      });

      test('should append (1) if file exists', () async {
        final existingFile = File(path.join(tempDir.path, 'existing_file.txt'));
        await existingFile.writeAsString('content');
        
        final uniquePath = fileService.getUniqueFilePath(
          path.join(tempDir.path, 'existing_file.txt'),
        );
        
        expect(uniquePath, equals(path.join(tempDir.path, 'existing_file (1).txt')));
        
        await existingFile.delete();
      });

      test('should increment number for multiple duplicates', () async {
        final file1 = File(path.join(tempDir.path, 'multi_file.txt'));
        final file2 = File(path.join(tempDir.path, 'multi_file (1).txt'));
        await file1.writeAsString('content');
        await file2.writeAsString('content');
        
        final uniquePath = fileService.getUniqueFilePath(
          path.join(tempDir.path, 'multi_file.txt'),
        );
        
        expect(uniquePath, equals(path.join(tempDir.path, 'multi_file (2).txt')));
        
        await file1.delete();
        await file2.delete();
      });
    });

    group('copyFile', () {
      test('should copy file successfully', () async {
        final sourceFile = File(path.join(tempDir.path, 'source.txt'));
        await sourceFile.writeAsString('Source content');
        
        final destPath = path.join(tempDir.path, 'dest.txt');
        await fileService.copyFile(sourceFile.path, destPath);
        
        final destFile = File(destPath);
        expect(await destFile.exists(), isTrue);
        expect(await destFile.readAsString(), equals('Source content'));
        
        await sourceFile.delete();
        await destFile.delete();
      });

      test('should report progress during copy', () async {
        final sourceFile = File(path.join(tempDir.path, 'large_source.txt'));
        // Create a 1MB file
        final sink = sourceFile.openWrite();
        for (int i = 0; i < 100; i++) {
          sink.add(List.filled(10240, 0));
        }
        await sink.close();
        
        final progressValues = <double>[];
        final destPath = path.join(tempDir.path, 'large_dest.txt');
        
        await fileService.copyFile(
          sourceFile.path,
          destPath,
          onProgress: (current, total) {
            progressValues.add(current / total);
          },
        );
        
        expect(progressValues, isNotEmpty);
        expect(progressValues.last, closeTo(1.0, 0.01));
        
        await sourceFile.delete();
        await File(destPath).delete();
      });
    });
  });
}
