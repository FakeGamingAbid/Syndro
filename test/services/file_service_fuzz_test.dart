import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/file_service.dart';

void main() {
  late FileService fileService;

  setUp(() {
    fileService = FileService();
  });

  group('FileService.sanitizeFilename Fuzz Tests', () {
    test('should handle Unicode characters safely', () {
      // Test various Unicode characters
      final unicodeInputs = [
        'ファイル.txt', // Japanese
        '파일.txt', // Korean
        'Файл.txt', // Cyrillic
        '𝄞𝄢𝄭𝄮𝄯𝄰𝄱𝄲.txt', // Musical symbols
        '🔥🚒💎💀.txt', // Emoji
      ];

      for (final input in unicodeInputs) {
        expect(
          () => fileService.sanitizeFilename(input),
          returnsNormally,
          reason: 'sanitizeFilename should not crash on Unicode: $input',
        );
      }
    });

    test('should prevent path traversal attacks', () {
      // Test path traversal attempts
      final pathTraversalInputs = [
        '../../../etc/passwd',
        '..\\..\\..\\windows\\system32\\config\\sam',
        './../secret.txt',
        'foo/../../../bar',
        'foo/..\\bar',
        '....//....//etc/passwd',
        '....\\\\....\\\\windows\\\\system32',
      ];

      for (final input in pathTraversalInputs) {
        final result = fileService.sanitizeFilename(input);
        
        // Should not contain path traversal patterns
        expect(result, isNot(contains('..')));
        expect(result, isNot(startsWith('/')));
        expect(result, isNot(startsWith('\\')));
      }
    });

    test('should handle very long filenames (200+ chars)', () {
      // Test exactly 200 characters
      final long200 = 'a' * 200;
      expect(
        () => fileService.sanitizeFilename(long200),
        returnsNormally,
      );
      expect(fileService.sanitizeFilename(long200).length, lessThanOrEqualTo(200));

      // Test 201 characters (should truncate)
      final long201 = 'a' * 201;
      expect(
        () => fileService.sanitizeFilename(long201),
        returnsNormally,
      );
      expect(fileService.sanitizeFilename(long201).length, lessThanOrEqualTo(200));

      // Test very long filename (1000 chars)
      final long1000 = '${'a' * 1000}.txt';
      expect(
        () => fileService.sanitizeFilename(long1000),
        returnsNormally,
      );
      expect(fileService.sanitizeFilename(long1000).length, lessThanOrEqualTo(200));

      // Test with extension preservation
      final longWithExt = '${'a' * 250}.mp4';
      final result = fileService.sanitizeFilename(longWithExt);
      expect(result, endsWith('.mp4'));
    });

    test('should handle edge case filenames', () {
      // Test empty string - should throw
      expect(
        () => fileService.sanitizeFilename(''),
        throwsA(isA<FileServiceException>()),
      );

      // Test only dots and spaces
      expect(
        fileService.sanitizeFilename('...'),
        isNotEmpty,
      );
      expect(
        fileService.sanitizeFilename('   '),
        isNotEmpty,
      );

      // Test only invalid characters
      expect(
        fileService.sanitizeFilename('<>:"|?*'),
        isNotEmpty,
      );

      // Test null character injection
      const withNull = 'file\x00name.txt';
      final result = fileService.sanitizeFilename(withNull);
      expect(result, isNot(contains('\x00')));
    });

    test('should handle Unicode path separator lookalikes', () {
      // Test Unicode characters that look like slashes
      final slashLookalikes = [
        'file⁄name.txt', // U+2044 fraction slash
        'file∕name.txt', // U+2215 division slash
        'file＼name.txt', // U+FF3C fullwidth reverse solidus
        'file／name.txt', // U+FF0F fullwidth solidus
      ];

      for (final input in slashLookalikes) {
        final result = fileService.sanitizeFilename(input);
        // These should be replaced with underscores
        expect(result, isNot(contains('⁄')));
        expect(result, isNot(contains('∕')));
        expect(result, isNot(contains('＼')));
        expect(result, isNot(contains('／')));
      }
    });

    test('should handle all invalid characters', () {
      const invalidChars = '<>:"|?*\\/\x00\x01\x1F';
      final result = fileService.sanitizeFilename('test$invalidChars.txt');
      
      // Should not contain any invalid characters
      for (final char in '<>:"|?*\\/\x00\x01\x1F'.split('')) {
        expect(result, isNot(contains(char)));
      }
    });

    test('should preserve valid file extensions', () {
      final testCases = [
        ('document.pdf', '.pdf'),
        ('archive.tar.gz', '.tar.gz'),
        ('image.png', '.png'),
        ('music.mp3', '.mp3'),
        ('video.mkv', '.mkv'),
        ('code.dart', '.dart'),
      ];

      for (final (input, expectedExt) in testCases) {
        final result = fileService.sanitizeFilename(input);
        expect(result, endsWith(expectedExt));
      }
    });
  });
}
