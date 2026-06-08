import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/qr_pairing_payload.dart';
import 'transfer_service/http_response_helper.dart';

/// Custom exception for QR pairing errors
class QrPairingException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  QrPairingException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'QrPairingException: $message'
      '${code != null ? ' (code: $code)' : ''}';
}

/// Custom exception for security failures that must abort a connection.
///
/// Thrown by [EncryptionService.verifyPinnedKey] when a key-exchange
/// endpoint receives a public key that does not match the TOFU pin
/// stored for that device, and by [KeyExchangeService.exchangeKeys]
/// when the local pin check fails.
///
/// Surfaced to the UI so the user can decide to "Reset trust" for the
/// affected device.
class SecurityException implements Exception {
  final String message;
  final String? deviceId;
  final String? code;

  SecurityException(this.message, {this.deviceId, this.code});

  @override
  String toString() => 'SecurityException: $message'
      '${deviceId != null ? ' [device=$deviceId]' : ''}'
      '${code != null ? ' (code: $code)' : ''}';
}

/// Builds, signs and verifies [QrPairingPayload] objects for the
/// out-of-band QR pairing handshake.
///
/// All crypto uses the `cryptography` package's [Hmac.sha256] (no
/// additional dependencies) and the wire format is documented on
/// [QrPairingPayload].
///
/// The signing/verification key is the device's existing static
/// `senderToken` (base64url string). It is converted to UTF-8 bytes
/// for use as the HMAC key.
class QrPairingService {
  static const String _sigAlgorithm = 'HMAC-SHA256';

  /// The HMAC primitive. Reused across calls (the algorithm is stateless
  /// and safe to share between instances, matching the `AesGcm` static
  /// instance pattern in `EncryptionService`).
  static final Hmac _hmac = Hmac.sha256();

  /// Sign a payload. Returns a new payload with `sig` populated.
  ///
  /// The HMAC key is `utf8.encode(senderToken)`. Throws [QrPairingException]
  /// if signing fails.
  Future<QrPairingPayload> signPayload({
    required QrPairingPayload payload,
    required String senderToken,
  }) async {
    if (senderToken.isEmpty) {
      throw QrPairingException(
        'Cannot sign QR payload with empty sender token',
        code: 'EMPTY_TOKEN',
      );
    }

    try {
      final keyBytes = utf8.encode(senderToken);
      final secretKey = SecretKey(keyBytes);
      final message = QrPairingPayload.canonicalSigningInput(
        deviceId: payload.deviceId,
        pubKeyBase64Url: payload.pubKeyBase64Url,
      );

      final mac = await _hmac.calculateMac(
        message,
        secretKey: secretKey,
      );

      return QrPairingPayload(
        version: payload.version,
        deviceId: payload.deviceId,
        name: payload.name,
        ipAddress: payload.ipAddress,
        port: payload.port,
        pubKeyBase64Url: payload.pubKeyBase64Url,
        signatureBase64Url: base64Url.encode(mac.bytes),
        issuedAt: payload.issuedAt,
      );
    } on QrPairingException {
      rethrow;
    } catch (e) {
      throw QrPairingException(
        'Failed to sign QR payload',
        code: 'SIGN_FAILED',
        originalError: e,
      );
    }
  }

  /// Convenience: build + sign a payload from raw inputs.
  Future<QrPairingPayload> generatePayload({
    required String deviceId,
    required String name,
    required String ipAddress,
    required int port,
    required Uint8List publicKey,
    required String senderToken,
    DateTime? issuedAt,
  }) async {
    final payload = QrPairingPayload(
      version: QrPairingPayload.currentVersion,
      deviceId: deviceId,
      name: name,
      ipAddress: ipAddress,
      port: port,
      pubKeyBase64Url: QrPairingPayload.encodePubKey(publicKey),
      signatureBase64Url: '', // filled by signPayload
      issuedAt: issuedAt ?? DateTime.now(),
    );

    return signPayload(payload: payload, senderToken: senderToken);
  }

  /// Verify a payload's HMAC signature in constant time.
  ///
  /// Returns `true` only if every byte of the recomputed MAC matches
  /// the bytes encoded in [QrPairingPayload.signatureBase64Url].
  /// Length-mismatched signatures fail fast (`false`).
  Future<bool> verifyPayload({
    required QrPairingPayload payload,
    required String senderToken,
  }) async {
    if (senderToken.isEmpty) {
      return false;
    }
    if (payload.signatureBase64Url.isEmpty) {
      return false;
    }

    Uint8List expectedMac;
    try {
      expectedMac = base64Url.decode(payload.signatureBase64Url);
    } catch (_) {
      return false;
    }
    if (expectedMac.length != 32) {
      return false;
    }

    try {
      final keyBytes = utf8.encode(senderToken);
      final secretKey = SecretKey(keyBytes);
      final message = QrPairingPayload.canonicalSigningInput(
        deviceId: payload.deviceId,
        pubKeyBase64Url: payload.pubKeyBase64Url,
      );

      final mac = await _hmac.calculateMac(
        message,
        secretKey: secretKey,
      );

      return HttpResponseHelper.secureBytesCompare(
        Uint8List.fromList(mac.bytes),
        expectedMac,
      );
    } catch (_) {
      return false;
    }
  }

  /// One-shot: decode the on-the-wire string and verify the signature.
  /// Returns `null` on parse error or signature failure.
  Future<QrPairingPayload?> decodeAndVerify({
    required String data,
    required String senderToken,
  }) async {
    try {
      QrPairingPayload.decode(data);
    } catch (_) {
      return null;
    }
    // Re-decode cleanly so the caller gets the same object regardless
    // of branch.
    final payload = QrPairingPayload.decode(data);
    if (!await verifyPayload(payload: payload, senderToken: senderToken)) {
      return null;
    }
    return payload;
  }

  /// The HMAC algorithm used (informational / for logging / tests).
  String get algorithm => _sigAlgorithm;
}
