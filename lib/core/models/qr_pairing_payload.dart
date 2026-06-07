import 'dart:convert';
import 'dart:typed_data';

/// QR code payload for out-of-band device pairing
///
/// Encodes the device identity (id, name, address) and the device's
/// current X25519 public key, plus an HMAC-SHA256 signature so the
/// scanner can detect a QR that wasn't produced by the claimed device.
///
/// ## Wire format
/// JSON object with these fields:
///   - `v`        : schema version (currently 1)
///   - `deviceId` : unique device identifier (UUID v4)
///   - `name`     : human-friendly device name (sanitized)
///   - `ipAddress`: LAN IP of the device (validated)
///   - `port`     : transfer server port
///   - `pubKey`   : 32-byte X25519 public key, base64url-encoded
///   - `sig`      : 32-byte HMAC-SHA256 over `(deviceId || ":" || pubKey)`,
///                  base64url-encoded; key = sender token bytes
///   - `issuedAt` : ISO 8601 timestamp (informational)
///
/// ## Security
/// - The signature prevents trivially forged QR codes (an attacker would
///   need the device's `senderToken` to produce a valid `sig`).
/// - On its own, the signature does NOT provide authentication: a MITM that
///   captures both the QR and the underlying token can still forge one.
///   True authentication comes from the TOFU pin in
///   `TrustedDevicesHandler.pinnedPubKey` which is verified on every
///   subsequent key exchange.
class QrPairingPayload {
  static const int currentVersion = 1;
  static const String fieldVersion = 'v';
  static const String fieldDeviceId = 'deviceId';
  static const String fieldName = 'name';
  static const String fieldIpAddress = 'ipAddress';
  static const String fieldPort = 'port';
  static const String fieldPubKey = 'pubKey';
  static const String fieldSig = 'sig';
  static const String fieldIssuedAt = 'issuedAt';

  final int version;
  final String deviceId;
  final String name;
  final String ipAddress;
  final int port;

  /// 32-byte X25519 public key, base64url-encoded (no padding)
  final String pubKeyBase64Url;

  /// 32-byte HMAC-SHA256 signature, base64url-encoded (no padding)
  final String signatureBase64Url;

  final DateTime issuedAt;

  const QrPairingPayload({
    required this.version,
    required this.deviceId,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.pubKeyBase64Url,
    required this.signatureBase64Url,
    required this.issuedAt,
  });

  /// Build the canonical byte string that was HMAC'd:
  /// `<deviceId>:<pubKeyBase64Url>` (UTF-8).
  ///
  /// Exposed for testing and for the verifier side.
  static Uint8List canonicalSigningInput({
    required String deviceId,
    required String pubKeyBase64Url,
  }) {
    final s = '$deviceId:$pubKeyBase64Url';
    return Uint8List.fromList(utf8.encode(s));
  }

  /// Encode the 32-byte public key as base64url (unpadded, URL-safe).
  static String encodePubKey(Uint8List publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError(
        'X25519 public key must be 32 bytes, got ${publicKey.length}',
      );
    }
    return base64Url.encode(publicKey);
  }

  /// Decode a base64url-encoded public key.
  static Uint8List decodePubKey(String pubKeyBase64Url) {
    final bytes = base64Url.decode(pubKeyBase64Url);
    if (bytes.length != 32) {
      throw FormatException(
        'X25519 public key must be 32 bytes, got ${bytes.length}',
      );
    }
    return Uint8List.fromList(bytes);
  }

  Map<String, dynamic> toJson() => {
        fieldVersion: version,
        fieldDeviceId: deviceId,
        fieldName: name,
        fieldIpAddress: ipAddress,
        fieldPort: port,
        fieldPubKey: pubKeyBase64Url,
        fieldSig: signatureBase64Url,
        fieldIssuedAt: issuedAt.toIso8601String(),
      };

  /// Parse JSON to a [QrPairingPayload]. Does NOT verify the signature —
  /// use [QrPairingService.verifyPayload] for that.
  factory QrPairingPayload.fromJson(Map<String, dynamic> json) {
    final deviceId = json[fieldDeviceId] as String?;
    final name = json[fieldName] as String?;
    final ipAddress = json[fieldIpAddress] as String?;
    final port = json[fieldPort];
    final pubKey = json[fieldPubKey] as String?;
    final sig = json[fieldSig] as String?;
    final issuedAtRaw = json[fieldIssuedAt] as String?;

    if (deviceId == null ||
        name == null ||
        ipAddress == null ||
        port is! int ||
        pubKey == null ||
        sig == null) {
      throw const FormatException('QR pairing payload missing required fields');
    }

    if (deviceId.isEmpty || deviceId.length > 100) {
      throw const FormatException('Invalid deviceId in QR payload');
    }

    if (name.isEmpty || name.length > 100) {
      throw const FormatException('Invalid name in QR payload');
    }

    if (port <= 0 || port > 65535) {
      throw FormatException('Invalid port in QR payload: $port');
    }

    DateTime issuedAt;
    if (issuedAtRaw == null) {
      issuedAt = DateTime.now();
    } else {
      try {
        issuedAt = DateTime.parse(issuedAtRaw);
      } catch (_) {
        issuedAt = DateTime.now();
      }
    }

    return QrPairingPayload(
      version: json[fieldVersion] as int? ?? currentVersion,
      deviceId: deviceId,
      name: name,
      ipAddress: ipAddress,
      port: port,
      pubKeyBase64Url: pubKey,
      signatureBase64Url: sig,
      issuedAt: issuedAt,
    );
  }

  /// Encode the payload to the on-the-wire string (compact JSON, UTF-8).
  String encode() => jsonEncode(toJson());

  /// Decode the on-the-wire string to a [QrPairingPayload]. Does NOT
  /// verify the signature.
  factory QrPairingPayload.decode(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR pairing payload must be a JSON object');
    }
    return QrPairingPayload.fromJson(decoded);
  }

  @override
  String toString() =>
      'QrPairingPayload(deviceId: $deviceId, name: $name, ip: $ipAddress, '
      'port: $port, v: $version)';
}
