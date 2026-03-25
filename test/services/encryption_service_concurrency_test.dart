import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/encryption_service.dart';

void main() {
  group('Security Tests - NONCE MUTEX DEADLOCK', () {
    test('should handle 50+ concurrent encryption operations without deadlock', () async {
      final encryptionService = EncryptionService();
      
      // Generate key pair for shared secret
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      // Run 50+ concurrent encryption operations
      const numOperations = 50;
      final operations = <Future<void>>[];
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < numOperations; i++) {
        operations.add(
          encryptionService.encryptChunk(
            Uint8List.fromList([i, i + 1, i + 2]),
            sharedSecret,
          ),
        );
      }
      
      // Wait for all to complete
      await Future.wait(operations);
      
      stopwatch.stop();
      
      // All operations should complete successfully
      expect(stopwatch.elapsed.inSeconds, lessThan(30),
          reason: '50 concurrent operations should complete in reasonable time');
    });

    test('should handle 100 concurrent encryptions without deadlock', () async {
      final encryptionService = EncryptionService();
      
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      // Run 100 concurrent encryption operations
      const numOperations = 100;
      final operations = <Future<void>>[];
      
      for (int i = 0; i < numOperations; i++) {
        final data = Uint8List.fromList(List.generate(100, (j) => (i + j) % 256));
        operations.add(
          encryptionService.encryptChunk(data, sharedSecret),
        );
      }
      
      // All operations should complete without throwing
      await expectLater(
        Future.wait(operations),
        completes,
        reason: '100 concurrent operations should complete without deadlock',
      );
    });

    test('should produce unique nonces under concurrent load', () async {
      final encryptionService = EncryptionService();
      
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      const numOperations = 50;
      final encryptedResults = <List<int>>[];
      
      // Run concurrent encryptions
      final operations = List.generate(numOperations, (i) {
        final data = Uint8List.fromList(List.generate(100, (j) => (i + j) % 256));
        return encryptionService.encryptChunk(data, sharedSecret);
      });
      
      final results = await Future.wait(operations);
      encryptedResults.addAll(results);
      
      // All encrypted results should be unique (different nonces)
      final uniqueResults = encryptedResults.map((e) => e.toString()).toSet();
      expect(uniqueResults.length, equals(numOperations),
          reason: 'Each encryption should produce unique ciphertext due to unique nonces');
    });

    test('should maintain data integrity under concurrent load', () async {
      final encryptionService = EncryptionService();
      
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      const numOperations = 30;
      final testData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      
      // Encrypt same data concurrently
      final operations = List.generate(numOperations, (_) {
        return encryptionService.encryptChunk(testData, sharedSecret);
      });
      
      final encryptedResults = await Future.wait(operations);
      
      // All should decrypt back to original
      for (final encrypted in encryptedResults) {
        final decrypted = await encryptionService.decryptChunk(encrypted, sharedSecret);
        expect(decrypted, equals(testData),
            reason: 'All concurrent encryptions should decrypt correctly');
      }
    });
  });
}
