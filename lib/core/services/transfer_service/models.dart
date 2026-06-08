import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../models/transfer.dart';

/// Custom exception for transfer errors
class TransferException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  TransferException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'TransferException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Pending transfer request model
class PendingTransferRequest {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderToken;
  final List<TransferItem> items;
  final DateTime timestamp;
  final Uint8List? senderPublicKey;
  
  /// Whether this is a parallel transfer request (for large files)
  final bool isParallelTransfer;
  
  /// Original parallel transfer data (used when approving parallel transfer)
  final Map<String, dynamic>? parallelData;
  
  /// Whether the sender is a trusted device
  final bool isTrusted;

  PendingTransferRequest({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderToken,
    required this.items,
    required this.timestamp,
    this.senderPublicKey,
    this.isParallelTransfer = false,
    this.parallelData,
    this.isTrusted = false,
  });

  int get fileCount => items.length;
  int get totalSize => items.fold<int>(0, (sum, item) => sum + item.size);
}

/// Trusted device with verification token and optional TOFU pin
///
/// `pinnedPubKey` is the base64url-encoded X25519 public key that was
/// pinned during the first QR pairing handshake. When set, every key
/// exchange must present this exact public key; a mismatch aborts the
/// connection (MITM detection).
///
/// `pendingRepin` is a flag set by `rotatePinnedKey()`. It signals that
/// the next successful QR pairing scan from this device should overwrite
/// the (now-invalid) pin with the freshly scanned public key.
class TrustedDevice {
  final String senderId;
  final String senderName;
  final String token;
  final DateTime trustedAt;

  /// Base64url-encoded X25519 public key pinned via TOFU.
  ///
  /// `null` when the device has not been QR-paired yet or when a pin
  /// rotation was triggered (see [pendingRepin]).
  final String? pinnedPubKey;

  /// `true` when the user has pressed "Reset trust" and we are waiting
  /// for the next QR re-pairing to re-pin a new key.
  final bool pendingRepin;

  TrustedDevice({
    required this.senderId,
    required this.senderName,
    required this.token,
    required this.trustedAt,
    this.pinnedPubKey,
    this.pendingRepin = false,
  });

  /// Returns `true` if a pinned public key is set and rotation is NOT
  /// pending — i.e. we expect key-exchange responses to match [pinnedPubKey].
  bool get hasActivePin => pinnedPubKey != null && pinnedPubKey!.isNotEmpty && !pendingRepin;

  TrustedDevice copyWith({
    String? senderId,
    String? senderName,
    String? token,
    DateTime? trustedAt,
    bool clearPin = false,
    String? pinnedPubKey,
    bool? pendingRepin,
  }) {
    return TrustedDevice(
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      token: token ?? this.token,
      trustedAt: trustedAt ?? this.trustedAt,
      pinnedPubKey: clearPin ? null : (pinnedPubKey ?? this.pinnedPubKey),
      pendingRepin: pendingRepin ?? this.pendingRepin,
    );
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'token': token,
        'trustedAt': trustedAt.toIso8601String(),
        if (pinnedPubKey != null) 'pinnedPubKey': pinnedPubKey,
        if (pendingRepin) 'pendingRepin': true,
      };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) {
    DateTime trustedAt;
    try {
      trustedAt = DateTime.parse(json['trustedAt'] as String);
    } catch (e) {
      // Fallback to current time if parsing fails
      trustedAt = DateTime.now();
    }

    return TrustedDevice(
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      token: json['token'] as String,
      trustedAt: trustedAt,
      pinnedPubKey: json['pinnedPubKey'] as String?,
      pendingRepin: json['pendingRepin'] as bool? ?? false,
    );
  }
}

/// Encryption session for a transfer
class EncryptionSession {
  final String sessionId;
  final SecretKey sharedSecret;
  final DateTime createdAt;

  EncryptionSession({
    required this.sessionId,
    required this.sharedSecret,
    required this.createdAt,
  });
}
