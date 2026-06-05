import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/encryption_service.dart';
import 'package:syndro/core/services/streaming_hash_service.dart';
import 'package:path/path.dart' as path;

void main() {
  group('Integration Tests', () {
    late EncryptionService encryptionService;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('syndro_test_');
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      encryptionService = EncryptionService();
    });

    group('End-to-End File Transfer Simulation', () {
      test('should encrypt, transfer, and decrypt file correctly', () async {
        // 1. Create test file
        final originalFile = File(path.join(tempDir.path, 'original.txt'));
        const originalContent = 'This is sensitive data to transfer';
        await originalFile.writeAsString(originalContent);
        
        // 2. Generate encryption keys (simulating two devices)
        final senderKeyPair = await encryptionService.generateKeyPair();
        final receiverKeyPair = await encryptionService.generateKeyPair();
        
        final senderPublicKey = await encryptionService.getPublicKey(senderKeyPair);
        final receiverPublicKey = await encryptionService.getPublicKey(receiverKeyPair);
        
        // 3. Derive shared secrets
        final senderSharedSecret = await encryptionService.deriveSharedSecret(
          myKeyPair: senderKeyPair,
          theirPublicKey: receiverPublicKey,
        );
        
        final receiverSharedSecret = await encryptionService.deriveSharedSecret(
          myKeyPair: receiverKeyPair,
          theirPublicKey: senderPublicKey,
        );
        
        // Secrets should match (compare bytes)
        final senderBytes = await senderSharedSecret.extractBytes();
        final receiverBytes = await receiverSharedSecret.extractBytes();
        expect(senderBytes, equals(receiverBytes));
        
        // 4. Encrypt file content
        final fileBytes = await originalFile.readAsBytes();
        final encryptedData = await encryptionService.encryptChunk(
          fileBytes,
          senderSharedSecret,
        );
        
        // 5. Simulate transfer (write encrypted data to "transfer" file)
        final transferredFile = File(path.join(tempDir.path, 'transferred.enc'));
        await transferredFile.writeAsBytes(encryptedData);
        
        // 6. Decrypt on receiver side
        final receivedEncryptedData = await transferredFile.readAsBytes();
        final decryptedData = await encryptionService.decryptChunk(
          receivedEncryptedData,
          receiverSharedSecret,
        );
        
        // 7. Write decrypted file
        final decryptedFile = File(path.join(tempDir.path, 'decrypted.txt'));
        await decryptedFile.writeAsBytes(decryptedData);
        
        // 8. Verify content matches
        final decryptedContent = await decryptedFile.readAsString();
        expect(decryptedContent, equals(originalContent));
      });

      test('should validate file integrity after transfer', () async {
        final sourceFile = File(path.join(tempDir.path, 'integrity_source.txt'));
        await sourceFile.writeAsString('Original content for integrity check');
        
        // Compute original hash
        final originalHash = await StreamingHashService.calculateFileHash(sourceFile);
        
        // Copy file manually (simulating transfer)
        final destFile = File(path.join(tempDir.path, 'integrity_dest.txt'));
        await destFile.writeAsBytes(await sourceFile.readAsBytes());
        
        // Compute destination hash
        final destHash = await StreamingHashService.calculateFileHash(destFile);
        
        // Hashes should match
        expect(destHash, equals(originalHash));
      });
    });
  });
}
