import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/services/transfer_service/models.dart';
import 'package:syndro/core/services/transfer_service/trusted_devices_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustedDevicesHandler', () {
    late TrustedDevicesHandler handler;

    setUp(() {
      // We'll test the in-memory behavior by directly manipulating
      // the handler's internal state through the public API.
      handler = TrustedDevicesHandler();
    });

    tearDown(() {
      handler.dispose();
    });

    group('trustDevice / isTrusted / getTrustedDevice', () {
      test('trusted device is retrievable', () async {
        final device = TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
        );

        await handler.trustDevice(device);

        expect(handler.isTrusted('device-1'), isTrue);
        expect(handler.getTrustedDevice('device-1'), isNotNull);
        expect(handler.getTrustedDevice('device-1')!.senderName, equals('Alice'));
      });

      test('untrusted device returns false', () {
        expect(handler.isTrusted('unknown'), isFalse);
        expect(handler.getTrustedDevice('unknown'), isNull);
      });

      test('trustedDevices returns all trusted devices', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
        ));
        await handler.trustDevice(TrustedDevice(
          senderId: 'd2',
          senderName: 'Bob',
          token: 't2',
          trustedAt: DateTime(2025),
        ));

        expect(handler.trustedDevices.length, equals(2));
      });
    });

    group('revokeTrust', () {
      test('removes device from trusted list', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
        ));

        await handler.revokeTrust('device-1');

        expect(handler.isTrusted('device-1'), isFalse);
      });
    });

    group('clearTrustedDevices', () {
      test('removes all trusted devices', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
        ));
        await handler.trustDevice(TrustedDevice(
          senderId: 'd2',
          senderName: 'Bob',
          token: 't2',
          trustedAt: DateTime(2025),
        ));

        await handler.clearTrustedDevices();

        expect(handler.trustedDevices, isEmpty);
      });
    });

    group('TOFU pinning', () {
      test('pinKey updates the in-memory TrustedDevice', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
        ));

        await handler.pinKey('device-1', 'base64url-pubkey');

        final device = handler.getTrustedDevice('device-1');
        expect(device, isNotNull);
        expect(device!.pinnedPubKey, equals('base64url-pubkey'));
        expect(device.hasActivePin, isTrue);
      });

      test('rotatePinnedKey clears the pin and sets pendingRepin', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
          pinnedPubKey: 'existing-key',
        ));

        await handler.rotatePinnedKey('device-1');

        final device = handler.getTrustedDevice('device-1');
        expect(device, isNotNull);
        expect(device!.pinnedPubKey, isNull);
        expect(device.pendingRepin, isTrue);
        expect(device.hasActivePin, isFalse);
      });

      test('consumePendingRepin returns true and clears flag', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
        ));
        await handler.rotatePinnedKey('device-1');

        final consumed = await handler.consumePendingRepin('device-1');
        expect(consumed, isTrue);

        final device = handler.getTrustedDevice('device-1');
        expect(device!.pendingRepin, isFalse);
      });

      test('consumePendingRepin returns false when no pending repin', () async {
        await handler.trustDevice(TrustedDevice(
          senderId: 'device-1',
          senderName: 'Alice',
          token: 'token-abc',
          trustedAt: DateTime(2025),
        ));

        final consumed = await handler.consumePendingRepin('device-1');
        expect(consumed, isFalse);
      });

      test('consumePendingRepin returns false for unknown device', () async {
        final consumed = await handler.consumePendingRepin('unknown');
        expect(consumed, isFalse);
      });
    });

    group('Pending requests', () {
      test('addPendingRequest and getPendingRequest', () {
        final request = PendingTransferRequest(
          requestId: 'req-1',
          senderId: 'device-1',
          senderName: 'Alice',
          senderToken: 'token-abc',
          items: [],
          timestamp: DateTime(2025),
        );

        handler.addPendingRequest(request);
        final retrieved = handler.getPendingRequest('req-1');

        expect(retrieved, isNotNull);
        expect(retrieved!.senderName, equals('Alice'));
      });

      test('removePendingRequest removes the request', () {
        final request = PendingTransferRequest(
          requestId: 'req-1',
          senderId: 'device-1',
          senderName: 'Alice',
          senderToken: 'token-abc',
          items: [],
          timestamp: DateTime(2025),
        );

        handler.addPendingRequest(request);
        handler.removePendingRequest('req-1');

        expect(handler.getPendingRequest('req-1'), isNull);
      });

      test('cleanupExpiredPendingRequests removes old requests', () {
        final oldRequest = PendingTransferRequest(
          requestId: 'req-old',
          senderId: 'device-1',
          senderName: 'Alice',
          senderToken: 'token-abc',
          items: [],
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        );
        final freshRequest = PendingTransferRequest(
          requestId: 'req-fresh',
          senderId: 'device-2',
          senderName: 'Bob',
          senderToken: 'token-def',
          items: [],
          timestamp: DateTime.now(),
        );

        handler.addPendingRequest(oldRequest);
        handler.addPendingRequest(freshRequest);

        handler.cleanupExpiredPendingRequests();

        expect(handler.getPendingRequest('req-old'), isNull);
        expect(handler.getPendingRequest('req-fresh'), isNotNull);
      });
    });

    group('TrustedDevice model', () {
      test('hasActivePin is true only when pinnedPubKey is set and pendingRepin is false', () {
        final device = TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
          pinnedPubKey: 'key-abc',
        );

        expect(device.hasActivePin, isTrue);

        final unpinned = device.copyWith(clearPin: true);
        expect(unpinned.hasActivePin, isFalse);

        final repinning = device.copyWith(pendingRepin: true);
        expect(repinning.hasActivePin, isFalse);
      });

      test('copyWith preserves non-specified fields', () {
        final device = TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
          pinnedPubKey: 'key-abc',
        );

        final updated = device.copyWith(senderName: 'Bob');
        expect(updated.senderId, equals('d1'));
        expect(updated.senderName, equals('Bob'));
        expect(updated.token, equals('t1'));
        expect(updated.pinnedPubKey, equals('key-abc'));
      });

      test('toJson/fromJson round-trip', () {
        final device = TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
          pinnedPubKey: 'key-abc',
        );

        final json = device.toJson();
        final restored = TrustedDevice.fromJson(json);

        expect(restored.senderId, equals(device.senderId));
        expect(restored.senderName, equals(device.senderName));
        expect(restored.token, equals(device.token));
        expect(restored.pinnedPubKey, equals(device.pinnedPubKey));
      });

      test('toJson/fromJson without pinnedPubKey (backward compat)', () {
        final device = TrustedDevice(
          senderId: 'd1',
          senderName: 'Alice',
          token: 't1',
          trustedAt: DateTime(2025),
        );

        final json = device.toJson();
        final restored = TrustedDevice.fromJson(json);

        expect(restored.senderId, equals(device.senderId));
        expect(restored.pinnedPubKey, isNull);
        expect(restored.hasActivePin, isFalse);
      });
    });
  });
}
