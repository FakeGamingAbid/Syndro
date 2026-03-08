import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../encryption_service.dart';
import 'models.dart';

/// Handles encryption operations for file transfers
class TransferEncryptionHandler {
  final AesGcm _aesGcm = AesGcm.with256bits();
  final X25519 _keyExchange = X25519();
  SimpleKeyPair? _encryptionKeyPair;
  final Map<String, EncryptionSession> _encryptionSessions = {};
  
  Timer? _sessionCleanupTimer;
  bool encryptionEnabled = true;
  
  static const Duration sessionMaxAge = Duration(hours: 1);

  bool get isEncryptionReady => _encryptionKeyPair != null;
  Map<String, EncryptionSession> get sessions => _encryptionSessions;

  Future<void> initialize() async {
    try {
      _encryptionKeyPair = await _keyExchange.newKeyPair();
      debugPrint('🔐 Encryption initialized (X25519 + AES-256-GCM)');
    } catch (e) {
      debugPrint('❌ Failed to initialize encryption: $e');
      encryptionEnabled = false;
    }
  }

  Future<Uint8List?> getPublicKey() async {
    if (_encryptionKeyPair == null) return null;
    final publicKey = await _encryptionKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  Future<SecretKey> performKeyExchange(Uint8List theirPublicKeyBytes) async {
    if (_encryptionKeyPair == null) {
      throw EncryptionException('Encryption not initialized');
    }

    final theirPublicKey = SimplePublicKey(
      theirPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: _encryptionKeyPair!,
      remotePublicKey: theirPublicKey,
    );

    return sharedSecret;
  }

  void storeSession(String deviceId, EncryptionSession session) {
    _encryptionSessions[deviceId] = session;
  }

  EncryptionSession? getSession(String deviceId) {
    return _encryptionSessions[deviceId];
  }

  Future<Uint8List> encryptChunk(
      Uint8List plaintext, SecretKey secretKey) async {
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final result = Uint8List(12 + secretBox.cipherText.length + 16);
    int offset = 0;
    result.setRange(offset, offset + 12, nonce);
    offset += 12;
    result.setRange(
        offset, offset + secretBox.cipherText.length, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    result.setRange(offset, offset + 16, secretBox.mac.bytes);

    return result;
  }

  Future<Uint8List> decryptChunk(
      Uint8List encryptedData, SecretKey secretKey) async {
    if (encryptedData.length < 28) {
      throw EncryptionException(
          'Data too small to decrypt: ${encryptedData.length} bytes');
    }

    final nonce = encryptedData.sublist(0, 12);
    final mac = encryptedData.sublist(encryptedData.length - 16);
    final ciphertext = encryptedData.sublist(12, encryptedData.length - 16);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    try {
      final plaintext = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(plaintext);
    } catch (e) {
      throw EncryptionException('Decryption failed: Authentication error',
          originalError: e);
    }
  }

  Future<String> calculateHashFromFile(File file) async {
    final digest = await crypto_hash.sha256.bind(file.openRead()).last;
    return digest.toString();
  }

  void startSessionCleanup() {
    _sessionCleanupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => cleanupExpiredSessions(),
    );
  }

  void cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _encryptionSessions.entries) {
      if (now.difference(entry.value.createdAt) > sessionMaxAge) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      _encryptionSessions.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      debugPrint(
          '🧹 Cleaned up ${expiredIds.length} expired encryption sessions');
    }
  }

  void dispose() {
    _sessionCleanupTimer?.cancel();
    _encryptionSessions.clear();
  }
}
