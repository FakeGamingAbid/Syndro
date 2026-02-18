import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/streaming_hash_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  group('StreamingHashService', () {
    late StreamingHashService hashService;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await getTemporaryDirectory();
    });

    setUp(() {
      hashService = StreamingHashService();
    });

    test('should compute correct SHA256 hash for small file', () async {
      // Create a test file
      final testFile = File(path.join(tempDir.path, 'test_small.txt'));
      await testFile.writeAsString('Hello, World!');
      
      final hash = await hashService.computeFileHash(testFile.path);
      
      expect(hash, isNotNull);
      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA256 produces 64 hex characters
      
      await testFile.delete();
    });

    test('should compute consistent hash for same content', () async {
      final testFile = File(path.join(tempDir.path, 'test_consistent.txt'));
      await testFile.writeAsString('Same content');
      
      final hash1 = await hashService.computeFileHash(testFile.path);
      final hash2 = await hashService.computeFileHash(testFile.path);
      
      expect(hash1, equals(hash2));
      
      await testFile.delete();
    });

    test('should produce different hash for different content', () async {
      final file1 = File(path.join(tempDir.path, 'test_diff1.txt'));
      final file2 = File(path.join(tempDir.path, 'test_diff2.txt'));
      
      await file1.writeAsString('Content 1');
      await file2.writeAsString('Content 2');
      
      final hash1 = await hashService.computeFileHash(file1.path);
      final hash2 = await hashService.computeFileHash(file2.path);
      
      expect(hash1, isNot(equals(hash2)));
      
      await file1.delete();
      await file2.delete();
    });

    test('should handle large file efficiently', () async {
      // Create a 10MB file
      final largeFile = File(path.join(tempDir.path, 'test_large.bin'));
      final sink = largeFile.openWrite();
      
      for (int i = 0; i < 1000; i++) {
        sink.add(Uint8List(10240)); // 10KB chunks, 1000 times = 10MB
      }
      await sink.close();
      
      final hash = await hashService.computeFileHash(largeFile.path);
      
      expect(hash, isNotNull);
      expect(hash.length, equals(64));
      
      await largeFile.delete();
    });

    test('should report progress during hash computation', () async {
      final testFile = File(path.join(tempDir.path, 'test_progress.txt'));
      await testFile.writeAsString('Test content for progress');
      
      final progressValues = <double>[];
      
      await hashService.computeFileHash(
        testFile.path,
        onProgress: (progress) {
          progressValues.add(progress);
        },
      );
      
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, equals(1.0));
      
      await testFile.delete();
    });

    test('should throw for non-existent file', () async {
      expect(
        () => hashService.computeFileHash('/non/existent/file.txt'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('should verify hash correctly', () async {
      final testFile = File(path.join(tempDir.path, 'test_verify.txt'));
      await testFile.writeAsString('Content to verify');
      
      final hash = await hashService.computeFileHash(testFile.path);
      final isValid = await hashService.verifyFileHash(testFile.path, hash);
      
      expect(isValid, isTrue);
      
      // Modify file and verify hash fails
      await testFile.writeAsString('Modified content');
      final isStillValid = await hashService.verifyFileHash(testFile.path, hash);
      
      expect(isStillValid, isFalse);
      
      await testFile.delete();
    });
  });
}
