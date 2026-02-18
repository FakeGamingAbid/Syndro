import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/streaming_hash_service.dart';

void main() {
  group('StreamingHashService', () {
    test('should calculate bytes hash correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash = StreamingHashService.calculateBytesHash(bytes);
      
      expect(hash, isNotNull);
      expect(hash.length, equals(64)); // SHA256 produces 64 hex characters
    });

    test('should produce consistent hash for same bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      final hash1 = StreamingHashService.calculateBytesHash(bytes);
      final hash2 = StreamingHashService.calculateBytesHash(bytes);
      
      expect(hash1, equals(hash2));
    });

    test('should produce different hash for different bytes', () {
      final bytes1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytes2 = Uint8List.fromList([5, 4, 3, 2, 1]);
      
      final hash1 = StreamingHashService.calculateBytesHash(bytes1);
      final hash2 = StreamingHashService.calculateBytesHash(bytes2);
      
      expect(hash1, isNot(equals(hash2)));
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
