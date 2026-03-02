import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Represents an encryption session between two devices
class EncryptionSession extends Equatable {
  final String sessionId;
  final String localDeviceId;
  final String remoteDeviceId;
  final Uint8List sharedSecret;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const EncryptionSession({
    required this.sessionId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.sharedSecret,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [sessionId, localDeviceId, remoteDeviceId, createdAt];
}

/// Encrypted chunk with metadata for decryption
class EncryptedChunk {
  final Uint8List nonce;        // 12 bytes for AES-GCM
  final Uint8List ciphertext;   // Encrypted data
  final Uint8List mac;          // 16 bytes authentication tag

  const EncryptedChunk({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Total size of encrypted chunk
  int get totalSize => nonce.length + ciphertext.length + mac.length;

  /// Serialize for transmission: [nonce (12) | ciphertext | mac (16)]
  Uint8List toBytes() {
    final result = Uint8List(totalSize);
    int offset = 0;
    
    result.setRange(offset, offset + nonce.length, nonce);
    offset += nonce.length;
    
    result.setRange(offset, offset + ciphertext.length, ciphertext);
    offset += ciphertext.length;
    
    result.setRange(offset, offset + mac.length, mac);
    
    return result;
  }

  /// Deserialize from transmission bytes
  factory EncryptedChunk.fromBytes(Uint8List bytes) {
    if (bytes.length < 28) {
      throw FormatException('Encrypted chunk too small: ${bytes.length} bytes');
    }

    final nonce = Uint8List.fromList(bytes.sublist(0, 12));
    final mac = Uint8List.fromList(bytes.sublist(bytes.length - 16));
    final ciphertext = Uint8List.fromList(bytes.sublist(12, bytes.length - 16));

    return EncryptedChunk(
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }
}

/// Public key for key exchange
class PublicKeyData {
  final String deviceId;
  final Uint8List publicKey;  // 32 bytes X25519 public key
  final DateTime createdAt;

  const PublicKeyData({
    required this.deviceId,
    required this.publicKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'publicKey': publicKey.toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory PublicKeyData.fromJson(Map<String, dynamic> json) {
    return PublicKeyData(
      deviceId: json['deviceId'] as String,
      publicKey: Uint8List.fromList(List<int>.from(json['publicKey'])),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
