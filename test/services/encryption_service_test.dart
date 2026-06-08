import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('should generate valid key pair', () async {
      final keyPair = await encryptionService.generateKeyPair();
      expect(keyPair, isNotNull);
      
      final publicKey = await encryptionService.getPublicKey(keyPair);
      expect(publicKey, isNotNull);
      expect(publicKey.bytes.length, equals(32)); // X25519 public key is 32 bytes
    });

    test('should derive shared secret from key pairs', () async {
      // Generate two key pairs (simulating two devices)
      final aliceKeyPair = await encryptionService.generateKeyPair();
      final bobKeyPair = await encryptionService.generateKeyPair();
      
      final alicePublicKey = await encryptionService.getPublicKey(aliceKeyPair);
      final bobPublicKey = await encryptionService.getPublicKey(bobKeyPair);
      
      // Both should derive the same shared secret
      final aliceSharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: aliceKeyPair,
        theirPublicKey: bobPublicKey,
      );
      
      final bobSharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: bobKeyPair,
        theirPublicKey: alicePublicKey,
      );
      
      // Extract bytes to compare
      final aliceBytes = await aliceSharedSecret.extractBytes();
      final bobBytes = await bobSharedSecret.extractBytes();
      
      expect(aliceBytes, equals(bobBytes));
      expect(aliceBytes.length, equals(32)); // 256 bits
    });

    test('should encrypt and decrypt data correctly', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );
      
      final originalData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      
      final encrypted = await encryptionService.encryptChunk(originalData, sharedSecret);
      expect(encrypted, isNot(equals(originalData)));
      
      final decrypted = await encryptionService.decryptChunk(encrypted, sharedSecret);
      expect(decrypted, equals(originalData));
    });

    test('should handle large data encryption', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);
      
      final sharedSecret = await encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: publicKey,
      );
      
      // Create 1MB of data
      final originalData = Uint8List(1024 * 1024);
      for (int i = 0; i < originalData.length; i++) {
        originalData[i] = i % 256;
      }
      
      final encrypted = await encryptionService.encryptChunk(originalData, sharedSecret);
      final decrypted = await encryptionService.decryptChunk(encrypted, sharedSecret);
      
      expect(decrypted, equals(originalData));
    });
  });

  group('TOFU Pin Verification', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('deriveBoundToken produces deterministic HMAC', () async {
      const token = 'my-sender-token';
      const pubKey = 'dGVzdC1wdWJsaWMta2V5'; // base64url("test-public-key")

      final bound1 = await EncryptionService.deriveBoundToken(
        senderToken: token,
        pinnedPubKeyBase64Url: pubKey,
      );
      final bound2 = await EncryptionService.deriveBoundToken(
        senderToken: token,
        pinnedPubKeyBase64Url: pubKey,
      );

      expect(bound1, equals(bound2));
      expect(bound1.length, greaterThan(0));
    });

    test('deriveBoundToken produces different tokens for different keys', () async {
      const token = 'my-sender-token';

      final bound1 = await EncryptionService.deriveBoundToken(
        senderToken: token,
        pinnedPubKeyBase64Url: 'key-a',
      );
      final bound2 = await EncryptionService.deriveBoundToken(
        senderToken: token,
        pinnedPubKeyBase64Url: 'key-b',
      );

      expect(bound1, isNot(equals(bound2)));
    });

    test('deriveBoundToken produces different tokens for different tokens', () async {
      const pubKey = 'dGVzdC1wdWJsaWMta2V5';

      final bound1 = await EncryptionService.deriveBoundToken(
        senderToken: 'token-a',
        pinnedPubKeyBase64Url: pubKey,
      );
      final bound2 = await EncryptionService.deriveBoundToken(
        senderToken: 'token-b',
        pinnedPubKeyBase64Url: pubKey,
      );

      expect(bound1, isNot(equals(bound2)));
    });

    test('verifyPinnedKey succeeds when key matches', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);

      // Should not throw
      await EncryptionService.verifyPinnedKey(
        deviceId: 'test-device',
        presentedPubKeyBytes: publicKey.bytes,
        pinnedPubKeyBase64Url: base64Url.encode(publicKey.bytes),
      );
    });

    test('verifyPinnedKey throws SecurityException on key mismatch', () async {
      final keyPair1 = await encryptionService.generateKeyPair();
      final publicKey1 = await encryptionService.getPublicKey(keyPair1);

      final keyPair2 = await encryptionService.generateKeyPair();
      final publicKey2 = await encryptionService.getPublicKey(keyPair2);

      expect(
        () => EncryptionService.verifyPinnedKey(
          deviceId: 'test-device',
          presentedPubKeyBytes: publicKey2.bytes,
          pinnedPubKeyBase64Url: base64Url.encode(publicKey1.bytes),
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('verifyPinnedKey passes when pinnedPubKeyBase64Url is null', () async {
      final keyPair = await encryptionService.generateKeyPair();
      final publicKey = await encryptionService.getPublicKey(keyPair);

      // Should not throw — null pin means no pin check
      await EncryptionService.verifyPinnedKey(
        deviceId: 'test-device',
        presentedPubKeyBytes: publicKey.bytes,
        pinnedPubKeyBase64Url: null,
      );
    });
  });
}
