import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/file_service.dart';

void main() {
  group('FileService', () {
    late FileService fileService;

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
    });
  });
}
