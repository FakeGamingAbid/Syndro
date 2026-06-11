import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/models/qr_pairing_payload.dart';
import 'package:syndro/core/services/qr_pairing_service.dart';

void main() {
  const testSenderId = 'device-abc-123';
  const testSenderName = 'Test Device';
  const testSenderToken = 'test-sender-token-base64url';
  const testReceiverIp = '192.168.1.100';
  const testReceiverPort = 8080;

  late QrPairingService service;

  setUp(() {
    service = QrPairingService();
  });

  QrPairingPayload _makePayload({
    String? sig,
    String? pubKey,
  }) {
    return QrPairingPayload(
      version: QrPairingPayload.currentVersion,
      deviceId: testSenderId,
      name: testSenderName,
      ipAddress: testReceiverIp,
      port: testReceiverPort,
      pubKeyBase64Url: pubKey ?? 'dGVzdC1wdWJsaWMta2V5LWJhc2U2NHVybA',
      signatureBase64Url: sig ?? '',
      issuedAt: DateTime(2025),
    );
  }

  group('QrPairingService', () {
    group('signPayload / verifyPayload', () {
      test('round-trip: sign then verify succeeds', () async {
        final payload = _makePayload();

        final signed = await service.signPayload(
          payload: payload,
          senderToken: testSenderToken,
        );

        expect(signed.signatureBase64Url, isNotEmpty);

        final verified = await service.verifyPayload(
          payload: signed,
          senderToken: testSenderToken,
        );
        expect(verified, isTrue);
      });

      test('verify fails with wrong sender token', () async {
        final payload = _makePayload();

        final signed = await service.signPayload(
          payload: payload,
          senderToken: testSenderToken,
        );

        final verified = await service.verifyPayload(
          payload: signed,
          senderToken: 'wrong-token',
        );
        expect(verified, isFalse);
      });

      test('verify fails when payload fields are changed', () async {
        final payload = _makePayload();

        final signed = await service.signPayload(
          payload: payload,
          senderToken: testSenderToken,
        );

        final tampered = QrPairingPayload(
          version: signed.version,
          deviceId: 'different-device',
          name: signed.name,
          ipAddress: signed.ipAddress,
          port: signed.port,
          pubKeyBase64Url: signed.pubKeyBase64Url,
          signatureBase64Url: signed.signatureBase64Url,
          issuedAt: signed.issuedAt,
        );

        final verified = await service.verifyPayload(
          payload: tampered,
          senderToken: testSenderToken,
        );
        expect(verified, isFalse);
      });

      test('verify fails with empty sender token', () async {
        final payload = _makePayload();

        expect(
          () => service.signPayload(
            payload: payload,
            senderToken: '',
          ),
          throwsA(isA<QrPairingException>()),
        );
      });

      test('verify returns false for empty signature', () async {
        final payload = _makePayload(sig: '');

        final verified = await service.verifyPayload(
          payload: payload,
          senderToken: testSenderToken,
        );
        expect(verified, isFalse);
      });
    });

    group('generatePayload / decodeAndVerify', () {
      test('generates a valid payload that decodes and verifies', () async {
        final keyBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) keyBytes[i] = i;

        final payload = await service.generatePayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          publicKey: keyBytes,
          senderToken: testSenderToken,
        );

        expect(payload.deviceId, equals(testSenderId));
        expect(payload.name, equals(testSenderName));
        expect(payload.ipAddress, equals(testReceiverIp));
        expect(payload.port, equals(testReceiverPort));
        expect(payload.signatureBase64Url, isNotEmpty);

        final encoded = payload.encode();
        final decoded = QrPairingPayload.decode(encoded);
        expect(decoded.deviceId, equals(testSenderId));

        final verified = await service.decodeAndVerify(
          data: encoded,
          senderToken: testSenderToken,
        );
        expect(verified, isNotNull);
        expect(verified!.deviceId, equals(testSenderId));
      });

      test('decodeAndVerify returns null for invalid JSON', () async {
        final result = await service.decodeAndVerify(
          data: 'not-valid-json',
          senderToken: testSenderToken,
        );
        expect(result, isNull);
      });

      test('decodeAndVerify returns null for tampered signature', () async {
        final keyBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) keyBytes[i] = i;

        final payload = await service.generatePayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          publicKey: keyBytes,
          senderToken: testSenderToken,
        );

        final json = payload.toJson();
        json['sig'] = 'tampered-signature';
        final tampered = jsonEncode(json);

        final result = await service.decodeAndVerify(
          data: tampered,
          senderToken: testSenderToken,
        );
        expect(result, isNull);
      });
    });
  });

  group('QrPairingPayload', () {
    test('toJson/fromJson round-trip', () {
      final payload = _makePayload(sig: 'test-signature');

      final json = payload.toJson();
      final restored = QrPairingPayload.fromJson(json);

      expect(restored.deviceId, equals(payload.deviceId));
      expect(restored.name, equals(payload.name));
      expect(restored.ipAddress, equals(payload.ipAddress));
      expect(restored.port, equals(payload.port));
      expect(restored.pubKeyBase64Url, equals(payload.pubKeyBase64Url));
      expect(restored.signatureBase64Url, equals(payload.signatureBase64Url));
    });

    test('encode/decode round-trip', () {
      final payload = _makePayload(sig: 'test-sig');

      final encoded = payload.encode();
      final decoded = QrPairingPayload.decode(encoded);

      expect(decoded.deviceId, equals(payload.deviceId));
      expect(decoded.name, equals(payload.name));
      expect(decoded.pubKeyBase64Url, equals(payload.pubKeyBase64Url));
    });

    test('version defaults to currentVersion', () {
      final payload = _makePayload();
      expect(payload.version, equals(QrPairingPayload.currentVersion));
    });

    test('canonicalSigningInput is deterministic', () {
      const pubKey = 'dGVzdC1wdWJsaWMta2V5LWJhc2U2NHVybA';

      final input1 = QrPairingPayload.canonicalSigningInput(
        deviceId: testSenderId,
        pubKeyBase64Url: pubKey,
      );
      final input2 = QrPairingPayload.canonicalSigningInput(
        deviceId: testSenderId,
        pubKeyBase64Url: pubKey,
      );
      expect(input1, equals(input2));
      expect(
        utf8.decode(input1),
        equals('$testSenderId:$pubKey'),
      );
    });

    test('encodePubKey / decodePubKey round-trip', () {
      final key = Uint8List(32);
      for (int i = 0; i < 32; i++) key[i] = i * 7;

      final encoded = QrPairingPayload.encodePubKey(key);
      final decoded = QrPairingPayload.decodePubKey(encoded);

      expect(decoded, equals(key));
    });

    test('encodePubKey throws on wrong length', () {
      expect(
        () => QrPairingPayload.encodePubKey(Uint8List(16)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decodePubKey throws on wrong length after decode', () {
      // Encode 32 bytes, then manually tamper the base64 to decode to 16 bytes
      final key32 = Uint8List(32);
      final b64 = base64Url.encode(key32);
      // Take only first 10 chars of base64 — decodes to fewer than 32 bytes
      final shortB64 = b64.substring(0, 10);
      expect(
        () => QrPairingPayload.decodePubKey(shortB64),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on missing required fields', () {
      expect(
        () => QrPairingPayload.fromJson({'deviceId': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on invalid port', () {
      expect(
        () => QrPairingPayload.fromJson({
          'deviceId': 'd1',
          'name': 'n',
          'ipAddress': '1.2.3.4',
          'port': 99999,
          'pubKey': 'k',
          'sig': 's',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
