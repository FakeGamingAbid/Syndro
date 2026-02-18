import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/file_service.dart';
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

    group('sanitizeFilename', () {
      test('should remove dangerous characters', () {
        final result = fileService.sanitizeFilename('file<>:"/\\|?*name.txt');
        expect(result, equals('file_________name.txt'));
      });

      test('should preserve valid file names', () {
        final result = fileService.sanitizeFilename('valid_file-name.txt');
        expect(result, equals('valid_file-name.txt'));
      });

      test('should handle empty filename', () {
        expect(
          () => fileService.sanitizeFilename(''),
          throwsA(isA<FileServiceException>()),
        );
      });

      test('should handle path separators', () {
        final result = fileService.sanitizeFilename('folder/file.txt');
        expect(result.contains('/'), isFalse);
      });

      test('should handle parent directory references', () {
        final result = fileService.sanitizeFilename('../secret.txt');
        expect(result.contains('..'), isFalse);
      });
    });

    group('isPathWithinDirectory', () {
      test('should return true for path within directory', () {
        final result = fileService.isPathWithinDirectory(
          '/home/user/downloads/file.txt',
          '/home/user/downloads',
        );
        expect(result, isTrue);
      });

      test('should return false for path outside directory', () {
        final result = fileService.isPathWithinDirectory(
          '/home/user/other/file.txt',
          '/home/user/downloads',
        );
        expect(result, isFalse);
      });

      test('should return false for path traversal attempt', () {
        final result = fileService.isPathWithinDirectory(
          '/home/user/downloads/../../../etc/passwd',
          '/home/user/downloads',
        );
        expect(result, isFalse);
      });
    });

    group('getSafeFilePath', () {
      test('should return safe path for valid filename', () async {
        final safePath = await fileService.getSafeFilePath('test_file.txt');
        expect(safePath, contains('test_file.txt'));
      });

      test('should throw for empty filename', () async {
        expect(
          () => fileService.getSafeFilePath(''),
          throwsA(isA<FileServiceException>()),
        );
      });

      test('should sanitize dangerous filename', () async {
        final safePath = await fileService.getSafeFilePath('file<>name.txt');
        expect(safePath, isNot(contains('<')));
        expect(safePath, isNot(contains('>')));
      });
    });

    group('getDownloadDirectory', () {
      test('should return non-empty path', () async {
        final downloadDir = await fileService.getDownloadDirectory();
        expect(downloadDir, isNotEmpty);
      });
    });

    group('getUniqueFilePath', () {
      test('should return same path if file does not exist', () {
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

    group('copyFileStreaming', () {
      test('should copy file successfully', () async {
        final sourceFile = File(path.join(tempDir.path, 'source.txt'));
        await sourceFile.writeAsString('Source content');
        
        final destPath = path.join(tempDir.path, 'dest.txt');
        await fileService.copyFileStreaming(
          sourcePath: sourceFile.path,
          destinationPath: destPath,
        );
        
        final destFile = File(destPath);
        expect(await destFile.exists(), isTrue);
        expect(await destFile.readAsString(), equals('Source content'));
        
        await sourceFile.delete();
        await destFile.delete();
      });

      test('should report progress during copy', () async {
        final sourceFile = File(path.join(tempDir.path, 'large_source.txt'));
        // Create a 100KB file
        final sink = sourceFile.openWrite();
        for (int i = 0; i < 100; i++) {
          sink.add(List.filled(1024, 0));
        }
        await sink.close();
        
        final progressValues = <double>[];
        final destPath = path.join(tempDir.path, 'large_dest.txt');
        
        await fileService.copyFileStreaming(
          sourcePath: sourceFile.path,
          destinationPath: destPath,
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
