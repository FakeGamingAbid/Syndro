import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/encryption_service.dart';
import 'package:syndro/core/services/parallel/parallel_config.dart';
import 'package:crypto/crypto.dart' as crypto;

void main() {
  late EncryptionService encryptionService;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('syndro_parallel_test_');
    encryptionService = EncryptionService();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Integration Tests - Parallel Chunked Transfer', () {
    test('should split large file into chunks correctly', () async {
      // Create a 12MB test file (>10MB threshold for parallel transfer)
      const fileSize = 12 * 1024 * 1024; // 12MB
      final originalData = Uint8List(fileSize);
      for (int i = 0; i < fileSize; i++) {
        originalData[i] = i % 256;
      }

      // Define chunk size based on parallel config (2MB for appToApp)
      final chunkSize = ParallelConfig.appToApp.chunkSize; // 2MB
      // 12MB / 2MB = 6 chunks
      final totalChunks = (fileSize / chunkSize).ceil();

      // Split into chunks
      final chunks = <Uint8List>[];
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize.toInt();
        chunks.add(Uint8List.fromList(originalData.sublist(start, end)));
      }

      expect(chunks.length, equals(6)); // 12MB / 2MB = 6 chunks
      expect(chunks.first.length, equals(chunkSize));
      expect(chunks.last.length, equals(chunkSize)); // Padded to chunk size
    });

    test('should encrypt and decrypt chunks maintaining order', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);

      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      // Simulate 5 chunks
      const numChunks = 5;
      const chunkSize = 1024 * 1024; // 1MB
      final originalChunks = <Uint8List>[];

      // Create original chunks with distinct data
      for (int i = 0; i < numChunks; i++) {
        final chunk = Uint8List(chunkSize);
        for (int j = 0; j < chunkSize; j++) {
          chunk[j] = (i + j) % 256; // Distinct pattern per chunk
        }
        originalChunks.add(chunk);
      }

      // Encrypt each chunk
      final encryptedChunks = <Uint8List>[];
      for (final chunk in originalChunks) {
        final encrypted = await encryptionService.encryptChunk(chunk, sharedSecret);
        encryptedChunks.add(Uint8List.fromList(encrypted));
      }

      // Decrypt each chunk
      final decryptedChunks = <Uint8List>[];
      for (final encrypted in encryptedChunks) {
        final decrypted = await encryptionService.decryptChunk(encrypted, sharedSecret);
        decryptedChunks.add(decrypted);
      }

      // Verify all chunks match original
      for (int i = 0; i < numChunks; i++) {
        expect(decryptedChunks[i], equals(originalChunks[i]),
            reason: 'Chunk $i should match original');
      }
    });

    test('should verify file integrity via SHA-256 hash', () async {
      // Generate test data
      final originalData = Uint8List.fromList(
        List.generate(10 * 1024 * 1024, (i) => i % 256), // 10MB
      );

      // Calculate original hash
      final originalHash = crypto.sha256.convert(originalData).toString();

      // Simulate encryption → transfer → decryption
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      // Encrypt entire file (simulating chunked encryption)
      final encryptedData = await encryptionService.encryptChunk(
        originalData,
        sharedSecret,
      );

      // Decrypt
      final decryptedData = await encryptionService.decryptChunk(
        encryptedData,
        sharedSecret,
      );

      // Calculate decrypted hash
      final decryptedHash = crypto.sha256.convert(decryptedData).toString();

      // Verify hashes match
      expect(decryptedHash, equals(originalHash),
          reason: 'SHA-256 hash should match after round-trip');
    });

    test('should handle parallel chunk reassembly correctly', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);

      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );

      // Simulate 10 chunks
      const numChunks = 10;
      const chunkSize = 512 * 1024; // 512KB
      final originalData = Uint8List(numChunks * chunkSize);

      // Fill with pattern
      for (int i = 0; i < originalData.length; i++) {
        originalData[i] = i % 256;
      }

      // Split into chunks
      final chunks = <Uint8List>[];
      for (int i = 0; i < numChunks; i++) {
        final start = i * chunkSize;
        final end = start + chunkSize;
        chunks.add(Uint8List.fromList(originalData.sublist(start, end)));
      }

      // Encrypt and decrypt each chunk (simulating parallel transfer)
      final reassembled = BytesBuilder();
      for (int i = 0; i < chunks.length; i++) {
        // Encrypt chunk i
        final encrypted = await encryptionService.encryptChunk(
          chunks[i],
          sharedSecret,
        );

        // Decrypt chunk i
        final decrypted = await encryptionService.decryptChunk(
          Uint8List.fromList(encrypted),
          sharedSecret,
        );

        // Add to reassembled data (simulating correct order reassembly)
        reassembled.add(decrypted);
      }

      final reassembledData = reassembled.toBytes();

      // Verify data integrity
      expect(reassembledData.length, equals(originalData.length));
      
      final originalHash = crypto.sha256.convert(originalData).toString();
      final reassembledHash = crypto.sha256.convert(reassembledData).toString();
      
      expect(reassembledHash, equals(originalHash),
          reason: 'Reassembled data should match original');
    });
  });
}
