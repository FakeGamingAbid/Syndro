import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/models/qr_pairing_payload.dart';
import 'package:syndro/core/services/qr_pairing_service.dart';

void main() {
  const testSenderId = 'device-abc-123';
  const testSenderName = 'Test Device';
  const testSenderToken = 'test-sender-token-base64url';
  const testReceiverIp = '192.168.1.100';
  const testReceiverPort = 8080;
  const testReceiverPubKeyB64 =
      'dGVzdC1wdWJsaWMta2V5LWJhc2U2NHVybA'; // base64url("test-public-key-base64url")

  late QrPairingService service;

  setUp(() {
    service = QrPairingService();
  });

  group('QrPairingService', () {
    group('signPayload / verifyPayload', () {
      test('round-trip: sign then verify succeeds', () async {
        final payload = QrPairingPayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
        );

        final signed = await service.signPayload(
          payload: payload,
          senderToken: testSenderToken,
        );

        expect(signed.sig, isNotEmpty);
        expect(signed.sig, isNot(equals('')));

        final verified = await service.verifyPayload(
          payload: signed,
          senderToken: testSenderToken,
        );
        expect(verified, isTrue);
      });

      test('verify fails with wrong sender token', () async {
        final payload = QrPairingPayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
        );

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

      test('verify fails when payload is tampered', () async {
        final payload = QrPairingPayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
        );

        final signed = await service.signPayload(
          payload: payload,
          senderToken: testSenderToken,
        );

        // Tamper with the payload
        final tampered = signed.copyWith(name: 'Tampered Name');
        final verified = await service.verifyPayload(
          payload: tampered,
          senderToken: testSenderToken,
        );
        expect(verified, isFalse);
      });

      test('verify fails with empty sender token', () async {
        final payload = QrPairingPayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
        );

        expect(
          () => service.signPayload(
            payload: payload,
            senderToken: '',
          ),
          throwsA(isA<QrPairingException>()),
        );
      });
    });

    group('generatePayload / decodeAndVerify', () {
      test('generates a valid payload that decodes and verifies', () async {
        final payload = await service.generatePayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
          senderToken: testSenderToken,
        );

        expect(payload.deviceId, equals(testSenderId));
        expect(payload.name, equals(testSenderName));
        expect(payload.ipAddress, equals(testReceiverIp));
        expect(payload.port, equals(testReceiverPort));
        expect(payload.pubKey, equals(testReceiverPubKeyB64));
        expect(payload.sig, isNotEmpty);
        expect(payload.issuedAt, isNotNull);

        // Encode as QR would see it (JSON)
        final encoded = payload.encode();
        final decoded = QrPairingPayload.decode(encoded);
        expect(decoded.deviceId, equals(testSenderId));

        final verified = await service.decodeAndVerify(
          encoded: encoded,
          senderToken: testSenderToken,
        );
        expect(verified, isNotNull);
        expect(verified!.deviceId, equals(testSenderId));
      });

      test('decodeAndVerify returns null for invalid JSON', () async {
        final result = await service.decodeAndVerify(
          encoded: 'not-valid-json',
          senderToken: testSenderToken,
        );
        expect(result, isNull);
      });

      test('decodeAndVerify returns null for tampered signature', () async {
        final payload = await service.generatePayload(
          deviceId: testSenderId,
          name: testSenderName,
          ipAddress: testReceiverIp,
          port: testReceiverPort,
          pubKey: testReceiverPubKeyB64,
          senderToken: testSenderToken,
        );

        final json = payload.toJson();
        json['sig'] = 'tampered-signature';
        final tampered = jsonEncode(json);

        final result = await service.decodeAndVerify(
          encoded: tampered,
          senderToken: testSenderToken,
        );
        expect(result, isNull);
      });
    });
  });

  group('QrPairingPayload', () {
    test('toJson/fromJson round-trip', () {
      final payload = QrPairingPayload(
        deviceId: testSenderId,
        name: testSenderName,
        ipAddress: testReceiverIp,
        port: testReceiverPort,
        pubKey: testReceiverPubKeyB64,
        sig: 'test-signature',
        issuedAt: DateTime(2025),
      );

      final json = payload.toJson();
      final restored = QrPairingPayload.fromJson(json);

      expect(restored.deviceId, equals(payload.deviceId));
      expect(restored.name, equals(payload.name));
      expect(restored.ipAddress, equals(payload.ipAddress));
      expect(restored.port, equals(payload.port));
      expect(restored.pubKey, equals(payload.pubKey));
      expect(restored.sig, equals(payload.sig));
    });

    test('encode/decode round-trip', () {
      final payload = QrPairingPayload(
        deviceId: testSenderId,
        name: testSenderName,
        ipAddress: testReceiverIp,
        port: testReceiverPort,
        pubKey: testReceiverPubKeyB64,
        sig: 'test-sig',
      );

      final encoded = payload.encode();
      final decoded = QrPairingPayload.decode(encoded);

      expect(decoded.deviceId, equals(payload.deviceId));
      expect(decoded.name, equals(payload.name));
      expect(decoded.pubKey, equals(payload.pubKey));
    });

    test('schema version defaults to 1', () {
      final payload = QrPairingPayload(
        deviceId: testSenderId,
        name: testSenderName,
        ipAddress: testReceiverIp,
        port: testReceiverPort,
        pubKey: testReceiverPubKeyB64,
      );

      expect(payload.schemaVersion, equals(1));
    });

    test('canonicalSigningInput is deterministic', () {
      final payload = QrPairingPayload(
        deviceId: testSenderId,
        name: testSenderName,
        ipAddress: testReceiverIp,
        port: testReceiverPort,
        pubKey: testReceiverPubKeyB64,
      );

      final input1 = payload.canonicalSigningInput();
      final input2 = payload.canonicalSigningInput();
      expect(input1, equals(input2));
      expect(input1, equals('$testSenderId:$testReceiverPubKeyB64'));
    });
  });
}
