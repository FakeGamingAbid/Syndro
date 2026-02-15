import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Core encryption service using AES-256-GCM
///
/// Speed: ~3-5 GB/s on modern devices (hardware accelerated)
/// Overhead: ~2-3% slower than unencrypted
class EncryptionService {
  // AES-256-GCM - Industry standard, hardware accelerated
  final AesGcm _aesGcm = AesGcm.with256bits();

  // X25519 for key exchange (same as Signal, WhatsApp)
  final X25519 _keyExchange = X25519();

  // Chunk size for streaming encryption (1MB)
  static const int chunkSize = 1024 * 1024;

  // FIX (Bug #2): Use bounded circular buffer for nonce tracking to prevent memory leak
  final List<String> _usedNonces = [];
  static const int _maxNonceCache = 10000; // Keep only recent 10k nonces
  int _nonceInsertIndex = 0;

  // FIX: Maximum nonces before requiring new key (2^32 for safety margin)
  static const int _maxNoncesPerKey = 0xFFFFFFFF;
  int _nonceCount = 0;

  /// Generate a new key pair for key exchange
  Future<SimpleKeyPair> generateKeyPair() async {
    return await _keyExchange.newKeyPair();
  }

  /// Extract public key from key pair
  Future<SimplePublicKey> getPublicKey(SimpleKeyPair keyPair) async {
    return await keyPair.extractPublicKey();
  }

  /// Perform X25519 key exchange to derive shared secret
  ///
  /// This creates a shared secret that only sender and receiver know
  Future<SecretKey> deriveSharedSecret({
    required SimpleKeyPair myKeyPair,
    required SimplePublicKey theirPublicKey,
  }) async {
    // FIX: Validate public key
    if (theirPublicKey.bytes.length != 32) {
      throw EncryptionException(
          'Invalid public key length: ${theirPublicKey.bytes.length}');
    }

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );

    // FIX: Reset nonce counter for new shared secret
    _nonceCount = 0;
    _usedNonces.clear();

    return sharedSecret;
  }

  /// Encrypt a single chunk of data
  ///
  /// Returns: [nonce (12 bytes) | ciphertext | mac (16 bytes)]
  Future<Uint8List> encryptChunk(
      Uint8List plaintext, SecretKey secretKey) async {
    // FIX: Check nonce counter
    if (_nonceCount >= _maxNoncesPerKey) {
      throw EncryptionException(
          'Nonce limit reached. Generate new key pair for security.');
    }

    // FIX (Bug #2): Generate nonce with bounded circular buffer to prevent memory leak
    List<int> nonce;
    String nonceHex;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      nonce = _aesGcm.newNonce();
      nonceHex = _bytesToHex(Uint8List.fromList(nonce));
      attempts++;

      if (attempts > maxAttempts) {
        throw EncryptionException(
            'Failed to generate unique nonce after $maxAttempts attempts');
      }
    } while (_usedNonces.contains(nonceHex));

    // Use circular buffer to prevent unbounded growth
    if (_usedNonces.length < _maxNonceCache) {
      _usedNonces.add(nonceHex);
    } else {
      // Overwrite oldest nonce in circular fashion
      _usedNonces[_nonceInsertIndex] = nonceHex;
      _nonceInsertIndex = (_nonceInsertIndex + 1) % _maxNonceCache;
    }
    
    _nonceCount++;

    // Encrypt with authentication
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine: nonce + ciphertext + mac
    final result = Uint8List(12 + secretBox.cipherText.length + 16);
    int offset = 0;

    // Nonce (12 bytes)
    result.setRange(offset, offset + 12, nonce);
    offset += 12;

    // Ciphertext
    result.setRange(
        offset, offset + secretBox.cipherText.length, secretBox.cipherText);
    offset += secretBox.cipherText.length;

    // MAC (16 bytes)
    result.setRange(offset, offset + 16, secretBox.mac.bytes);

    return result;
  }

  /// Decrypt a single chunk of data
  ///
  /// Input format: [nonce (12 bytes) | ciphertext | mac (16 bytes)]
  Future<Uint8List> decryptChunk(
      Uint8List encryptedData, SecretKey secretKey) async {
    // FIX: Enhanced size validation
    if (encryptedData.length < 28) {
      throw EncryptionException(
          'Data too small to decrypt: ${encryptedData.length} bytes (minimum 28)');
    }

    // FIX: Sanity check on maximum size (prevent memory issues)
    const maxChunkSize = 100 * 1024 * 1024; // 100MB max
    if (encryptedData.length > maxChunkSize) {
      throw EncryptionException(
          'Chunk too large: ${encryptedData.length} bytes (max $maxChunkSize)');
    }

    // Extract components
    final nonce = encryptedData.sublist(0, 12);
    final mac = encryptedData.sublist(encryptedData.length - 16);
    final ciphertext = encryptedData.sublist(12, encryptedData.length - 16);

    // Create SecretBox for decryption
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    // Decrypt and verify authentication
    try {
      final plaintext = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (e) {
      throw EncryptionException(
        'Decryption failed: Authentication error - data may be corrupted or tampered',
        originalError: e,
      );
    } catch (e) {
      throw EncryptionException(
        'Decryption failed: ${e.runtimeType}',
        originalError: e,
      );
    }
  }

  /// Encrypt a stream of data (for large files)
  ///
  /// Each chunk is independently encrypted with a unique nonce
  Stream<Uint8List> encryptStream(
    Stream<List<int>> input,
    SecretKey secretKey, {
    void Function(int bytesProcessed)? onProgress,
  }) async* {
    int totalBytes = 0;

    await for (final chunk in input) {
      // FIX: Validate chunk
      if (chunk.isEmpty) continue;

      try {
        final encrypted = await encryptChunk(
          Uint8List.fromList(chunk),
          secretKey,
        );

        totalBytes += chunk.length;
        onProgress?.call(totalBytes);

        yield encrypted;
      } catch (e) {
        debugPrint('Error encrypting chunk: $e');
        rethrow;
      }
    }
  }

  /// Decrypt a stream of encrypted chunks
  Stream<Uint8List> decryptStream(
    Stream<Uint8List> input,
    SecretKey secretKey, {
    void Function(int bytesProcessed)? onProgress,
  }) async* {
    int totalBytes = 0;

    await for (final encryptedChunk in input) {
      // FIX: Validate chunk
      if (encryptedChunk.isEmpty) continue;

      try {
        final decrypted = await decryptChunk(encryptedChunk, secretKey);

        totalBytes += decrypted.length;
        onProgress?.call(totalBytes);

        yield decrypted;
      } catch (e) {
        debugPrint('Error decrypting chunk: $e');
        rethrow;
      }
    }
  }

  /// Generate a random secret key (for testing or local encryption)
  Future<SecretKey> generateRandomKey() async {
    return await _aesGcm.newSecretKey();
  }

  /// Convert SecretKey to bytes (for storage/transmission)
  Future<Uint8List> secretKeyToBytes(SecretKey key) async {
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Create SecretKey from bytes
  SecretKey secretKeyFromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw EncryptionException(
          'Invalid key length: ${bytes.length} (expected 32)');
    }
    return SecretKey(bytes);
  }

  /// Convert public key to bytes for transmission
  Future<Uint8List> publicKeyToBytes(SimplePublicKey publicKey) async {
    final bytes = publicKey.bytes;
    return Uint8List.fromList(bytes);
  }

  /// Create public key from bytes
  SimplePublicKey publicKeyFromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw EncryptionException(
          'Invalid public key length: ${bytes.length} (expected 32)');
    }
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  // FIX: Helper to convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Reset the encryption service (clear nonce tracking)
  void reset() {
    _usedNonces.clear();
    _nonceCount = 0;
  }

  /// Get current nonce count (for monitoring)
  int get nonceCount => _nonceCount;

  /// Check if key rotation is recommended
  bool get shouldRotateKey => _nonceCount > _maxNoncesPerKey ~/ 2;
}

/// Custom exception for encryption errors
class EncryptionException implements Exception {
  final String message;
  final dynamic originalError;

  EncryptionException(this.message, {this.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'EncryptionException: $message (caused by: $originalError)';
    }
    return 'EncryptionException: $message';
  }
}
