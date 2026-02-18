import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/file_service.dart';
import 'package:syndro/core/services/encryption_service.dart';
import 'package:syndro/core/services/streaming_hash_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  group('Integration Tests', () {
    late FileService fileService;
    late EncryptionService encryptionService;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await getTemporaryDirectory();
    });

    setUp(() {
      fileService = FileService();
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
        
        // Cleanup
        await originalFile.delete();
        await transferredFile.delete();
        await decryptedFile.delete();
      });

      test('should handle large file transfer with progress', () async {
        // Create 5MB file
        final largeFile = File(path.join(tempDir.path, 'large_file.bin'));
        final sink = largeFile.openWrite();
        for (int i = 0; i < 500; i++) {
          sink.add(List.filled(10240, i % 256));
        }
        await sink.close();
        
        final fileSize = await largeFile.length();
        var lastProgress = 0.0;
        
        // Copy with progress tracking
        final destFile = File(path.join(tempDir.path, 'large_file_copy.bin'));
        await fileService.copyFileStreaming(
          sourcePath: largeFile.path,
          destinationPath: destFile.path,
          onProgress: (current, total) {
            lastProgress = current / total;
          },
        );
        
        // Verify progress reached 100%
        expect(lastProgress, equals(1.0));
        
        // Verify file sizes match
        final destSize = await destFile.length();
        expect(destSize, equals(fileSize));
        
        // Cleanup
        await largeFile.delete();
        await destFile.delete();
      });

      test('should handle multiple concurrent transfers', () async {
        final files = <File>[];
        final transferFutures = <Future>[];
        
        // Create 10 test files
        for (int i = 0; i < 10; i++) {
          final file = File(path.join(tempDir.path, 'concurrent_$i.txt'));
          await file.writeAsString('Content $i');
          files.add(file);
        }
        
        // Simulate concurrent transfers (copy operations)
        for (int i = 0; i < files.length; i++) {
          transferFutures.add(
            fileService.copyFileStreaming(
              sourcePath: files[i].path,
              destinationPath: path.join(tempDir.path, 'concurrent_${i}_copy.txt'),
            ),
          );
        }
        
        // Wait for all transfers
        await Future.wait(transferFutures);
        
        // Verify all copies exist
        for (int i = 0; i < 10; i++) {
          final copyFile = File(path.join(tempDir.path, 'concurrent_${i}_copy.txt'));
          expect(await copyFile.exists(), isTrue);
          expect(await copyFile.readAsString(), equals('Content $i'));
        }
        
        // Cleanup
        for (final file in files) {
          await file.delete();
          await File(path.join(tempDir.path, '${path.basenameWithoutExtension(file.path)}_copy.txt')).delete();
        }
      });
    });

    group('Error Recovery Tests', () {
      test('should handle network interruption gracefully', () async {
        // Simulate a transfer that gets interrupted
        final sourceFile = File(path.join(tempDir.path, 'source.txt'));
        await sourceFile.writeAsString('Data to transfer');
        
        // Create a partial copy (simulating interrupted transfer)
        final partialFile = File(path.join(tempDir.path, 'partial.txt'));
        final bytes = await sourceFile.readAsBytes();
        await partialFile.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));
        
        // Verify partial file is smaller
        final sourceSize = await sourceFile.length();
        final partialSize = await partialFile.length();
        expect(partialSize, lessThan(sourceSize));
        
        // Resume transfer (complete the copy)
        await partialFile.writeAsBytes(bytes.sublist(bytes.length ~/ 2), mode: FileMode.append);
        
        // Verify completed transfer
        final completedSize = await partialFile.length();
        expect(completedSize, equals(sourceSize));
        
        // Cleanup
        await sourceFile.delete();
        await partialFile.delete();
      });

      test('should validate file integrity after transfer', () async {
        final sourceFile = File(path.join(tempDir.path, 'integrity_source.txt'));
        await sourceFile.writeAsString('Original content for integrity check');
        
        // Compute original hash
        final originalHash = await StreamingHashService.calculateFileHash(sourceFile);
        
        // Copy file
        final destFile = File(path.join(tempDir.path, 'integrity_dest.txt'));
        await fileService.copyFileStreaming(
          sourcePath: sourceFile.path,
          destinationPath: destFile.path,
        );
        
        // Compute destination hash
        final destHash = await StreamingHashService.calculateFileHash(destFile);
        
        // Hashes should match
        expect(destHash, equals(originalHash));
        
        // Cleanup
        await sourceFile.delete();
        await destFile.delete();
      });
    });
  });
}
