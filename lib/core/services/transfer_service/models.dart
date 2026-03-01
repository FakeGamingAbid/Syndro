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

/// Trusted device with verification token
class TrustedDevice {
  final String senderId;
  final String senderName;
  final String token;
  final DateTime trustedAt;

  TrustedDevice({
    required this.senderId,
    required this.senderName,
    required this.token,
    required this.trustedAt,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'token': token,
        'trustedAt': trustedAt.toIso8601String(),
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
