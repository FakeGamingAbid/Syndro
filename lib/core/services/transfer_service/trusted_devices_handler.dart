import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Handles trusted device storage and management
class TrustedDevicesHandler {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _trustedDevicesKey = 'syndro_trusted_devices';

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
    await saveTrustedDevices();
  }

  Future<void> clearTrustedDevices() async {
    _trustedDevices.clear();
    await saveTrustedDevices();
  }

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
