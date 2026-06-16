import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'http_response_helper.dart';
import 'models.dart';

/// Handles trusted device storage and management
class TrustedDevicesHandler {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _trustedDevicesKey = 'syndro_trusted_devices';

  /// Namespace prefix for per-device TOFU public-key pins in secure storage.
  static const String _pinKeyPrefix = 'syndro.pin.';

  final Map<String, TrustedDevice> _trustedDevices = {};
  final Map<String, PendingTransferRequest> _pendingRequests = {};

  final _pendingRequestsController =
      StreamController<List<PendingTransferRequest>>.broadcast();

  Timer? _pendingRequestsCleanupTimer;

  List<TrustedDevice> get trustedDevices => _trustedDevices.values.toList();
  List<PendingTransferRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  Stream<List<PendingTransferRequest>> get pendingRequestsStream =>
      _pendingRequestsController.stream;

  bool isTrusted(String senderId) => _trustedDevices.containsKey(senderId);

  TrustedDevice? getTrustedDevice(String senderId) =>
      _trustedDevices[senderId];

  void addPendingRequest(PendingTransferRequest request) {
    _pendingRequests[request.requestId] = request;
    _notifyPendingRequestsChanged();
  }

  PendingTransferRequest? getPendingRequest(String requestId) =>
      _pendingRequests[requestId];

  void removePendingRequest(String requestId) {
    _pendingRequests.remove(requestId);
    _notifyPendingRequestsChanged();
  }

  void _notifyPendingRequestsChanged() {
    if (!_pendingRequestsController.isClosed) {
      _pendingRequestsController.add(_pendingRequests.values.toList());
    }
  }

  Future<void> loadTrustedDevices() async {
    try {
      final jsonString = await _secureStorage.read(key: _trustedDevicesKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        for (final json in jsonList) {
          final device = TrustedDevice.fromJson(json as Map<String, dynamic>);
          _trustedDevices[device.senderId] = device;
        }
        debugPrint('✅ Loaded ${_trustedDevices.length} trusted devices');
      }
    } catch (e) {
      debugPrint('Error loading trusted devices: $e');
    }
  }

  Future<void> saveTrustedDevices() async {
    try {
      final jsonList = _trustedDevices.values.map((d) => d.toJson()).toList();
      await _secureStorage.write(
        key: _trustedDevicesKey,
        value: jsonEncode(jsonList),
      );
      debugPrint('✅ Saved ${_trustedDevices.length} trusted devices');
    } catch (e) {
      debugPrint('Error saving trusted devices: $e');
    }
  }

  Future<void> trustDevice(TrustedDevice device) async {
    _trustedDevices[device.senderId] = device;
    await saveTrustedDevices();
  }

  Future<void> revokeTrust(String senderId) async {
    _trustedDevices.remove(senderId);
    // Also remove the persisted TOFU pin for this device
    try {
      await _secureStorage.delete(key: '$_pinKeyPrefix$senderId');
    } catch (e) {
      debugPrint('Error removing pinned key: $e');
    }
    await saveTrustedDevices();
  }

  Future<void> clearTrustedDevices() async {
    // Remove all namespaced pin keys
    final keys = _trustedDevices.keys.toList();
    for (final id in keys) {
      try {
        await _secureStorage.delete(key: '$_pinKeyPrefix$id');
      } catch (e) {
        debugPrint('Error removing pinned key for $id: $e');
      }
    }
    _trustedDevices.clear();
    await saveTrustedDevices();
  }

  // ─────────────────────────────────────────────
  //  TOFU public-key pinning
  // ─────────────────────────────────────────────

  /// Persist the base64url-encoded X25519 public key for [deviceId].
  ///
  /// The pin is stored in `syndro.pin.{deviceId}` in
  /// `flutter_secure_storage`, separate from the JSON list in
  /// `syndro_trusted_devices`. This avoids bloating the JSON blob and
  /// keeps the pin on its own lifecycle.
  Future<void> pinKey(String deviceId, String pubKeyBase64Url) async {
    try {
      await _secureStorage.write(
        key: '$_pinKeyPrefix$deviceId',
        value: pubKeyBase64Url,
      );
    } catch (e) {
      debugPrint('Error persisting pinned key: $e');
    }
    // Also update the in-memory TrustedDevice (if present)
    final existing = _trustedDevices[deviceId];
    if (existing != null) {
      _trustedDevices[deviceId] = existing.copyWith(
        pinnedPubKey: pubKeyBase64Url,
        pendingRepin: false,
      );
      await saveTrustedDevices();
    }
  }

  /// Verify that the presented public key matches the stored TOFU pin.
  ///
  /// Returns `true` when:
  /// - No pin is stored (first use → caller should pin), OR
  /// - The presented key matches the stored pin exactly (constant-time).
  ///
  /// Returns `false` when a pin IS stored but the keys differ (MITM).
  Future<bool> verifyPin(String deviceId, String presentedPubKeyBase64Url) async {
    final stored = await _secureStorage.read(key: '$_pinKeyPrefix$deviceId');
    if (stored == null || stored.isEmpty) {
      return true; // first use — OK to pin
    }
    return HttpResponseHelper.secureTokenCompare(stored, presentedPubKeyBase64Url);
  }

  /// Rotate the pinned key for a device, setting `pendingRepin = true`.
  ///
  /// The next QR re-pairing scan from this device will overwrite the
  /// pin and clear the pending flag. Call this from a "Reset trust"
  /// UI action.
  Future<void> rotatePinnedKey(String deviceId) async {
    try {
      await _secureStorage.delete(key: '$_pinKeyPrefix$deviceId');
    } catch (e) {
      debugPrint('Error removing pinned key during rotation: $e');
    }
    final existing = _trustedDevices[deviceId];
    if (existing != null) {
      _trustedDevices[deviceId] = existing.copyWith(
        clearPin: true,
        pendingRepin: true,
      );
      await saveTrustedDevices();
    }
  }

  /// Consume a pending re-pin: returns `true` if the device had
  /// `pendingRepin` set (and clears it so the flag is one-shot).
  Future<bool> consumePendingRepin(String deviceId) async {
    final existing = _trustedDevices[deviceId];
    if (existing == null || !existing.pendingRepin) return false;
    _trustedDevices[deviceId] = existing.copyWith(pendingRepin: false);
    await saveTrustedDevices();
    return true;
  }

  /// Return the stored TOFU public key for [deviceId], or `null` if
  /// no pin exists yet.
  Future<String?> getPinnedKey(String deviceId) async {
    return await _secureStorage.read(key: '$_pinKeyPrefix$deviceId');
  }

  // ─────────────────────────────────────────────
  //  Pending-requests management
  // ─────────────────────────────────────────────

  void startPendingRequestsCleanup() {
    _pendingRequestsCleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => cleanupExpiredPendingRequests(),
    );
  }

  void cleanupExpiredPendingRequests() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _pendingRequests.entries) {
      if (now.difference(entry.value.timestamp).inMinutes > 5) {
        expiredIds.add(entry.key);
      }
    }

    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _pendingRequests.remove(id);
      }
      _notifyPendingRequestsChanged();
      debugPrint(
          '🧹 Cleaned up ${expiredIds.length} expired pending requests');
    }
  }

  void dispose() {
    _pendingRequestsCleanupTimer?.cancel();
    _pendingRequestsController.close();
  }
}
