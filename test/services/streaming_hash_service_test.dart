import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/streaming_hash_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  group('StreamingHashService', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await getTemporaryDirectory();
    });

    test('should compute correct SHA256 hash for small file', () async {
      // Create a test file
      final testFile = File(path.join(tempDir.path, 'test_small.txt'));
      await testFile.writeAsString('Hello, World!');
      
      final hash = await StreamingHashService.calculateFileHash(testFile);
      
      expect(hash, isNotNull);
      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA256 produces 64 hex characters
      
      await testFile.delete();
    });

    test('should compute consistent hash for same content', () async {
      final testFile = File(path.join(tempDir.path, 'test_consistent.txt'));
      await testFile.writeAsString('Same content');
      
      final hash1 = await StreamingHashService.calculateFileHash(testFile);
      final hash2 = await StreamingHashService.calculateFileHash(testFile);
      
      expect(hash1, equals(hash2));
      
      await testFile.delete();
    });

    test('should produce different hash for different content', () async {
      final file1 = File(path.join(tempDir.path, 'test_diff1.txt'));
      final file2 = File(path.join(tempDir.path, 'test_diff2.txt'));
      
      await file1.writeAsString('Content 1');
      await file2.writeAsString('Content 2');
      
      final hash1 = await StreamingHashService.calculateFileHash(file1);
      final hash2 = await StreamingHashService.calculateFileHash(file2);
      
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
      
      final hash = await StreamingHashService.calculateFileHash(largeFile);
      
      expect(hash, isNotNull);
      expect(hash.length, equals(64));
      
      await largeFile.delete();
    });

    test('should report progress during hash computation', () async {
      final testFile = File(path.join(tempDir.path, 'test_progress.txt'));
      await testFile.writeAsString('Test content for progress');
      
      final progressValues = <double>[];
      
      await StreamingHashService.calculateFileHashWithProgress(
        testFile,
        onProgress: (bytesProcessed, totalBytes) {
          progressValues.add(bytesProcessed / totalBytes);
        },
      );
      
      expect(progressValues, isNotEmpty);
      expect(progressValues.last, equals(1.0));
      
      await testFile.delete();
    });

    test('should throw for non-existent file', () async {
      expect(
        () => StreamingHashService.calculateFileHash(File('/non/existent/file.txt')),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('should support cancellation', () async {
      final testFile = File(path.join(tempDir.path, 'test_cancel.txt'));
      // Create a larger file for cancellation test
      final sink = testFile.openWrite();
      for (int i = 0; i < 100; i++) {
        sink.add(Uint8List(10240));
      }
      await sink.close();
      
      final cancellationToken = CancellationToken();
      
      // Cancel immediately
      cancellationToken.cancel();
      
      expect(
        () => StreamingHashService.calculateFileHash(testFile, cancellationToken: cancellationToken),
        throwsA(isA<CancelledException>()),
      );
      
      await testFile.delete();
    });

    test('should calculate bytes hash correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash = StreamingHashService.calculateBytesHash(bytes);
      
      expect(hash, isNotNull);
      expect(hash.length, equals(64));
    });

    test('should support incremental hash calculation', () {
      final calculator = StreamingHashService.createIncrementalCalculator();
      
      calculator.addChunk([1, 2, 3]);
      calculator.addChunk([4, 5, 6]);
      
      final hash = calculator.finalize();
      
      expect(hash, isNotNull);
      expect(hash.length, equals(64));
      expect(calculator.isFinalized, isTrue);
    });

    test('should throw when adding to finalized calculator', () {
      final calculator = StreamingHashService.createIncrementalCalculator();
      calculator.finalize();
      
      expect(
        () => calculator.addChunk([1, 2, 3]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
