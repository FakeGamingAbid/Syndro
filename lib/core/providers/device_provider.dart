import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/device_discovery_service.dart';
import '../services/device_nickname_service.dart';

// ============================================
// DEVICE NICKNAME SERVICE PROVIDER
// ============================================

final deviceNicknameServiceProvider = Provider<DeviceNicknameService>((ref) {
  return DeviceNicknameService();
});

// ============================================
// DEVICE DISCOVERY SERVICE PROVIDER
// ============================================

final deviceDiscoveryServiceProvider = Provider<DeviceDiscoveryService>((ref) {
  final service = DeviceDiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ============================================
// CURRENT DEVICE PROVIDER (async - for instant loading)
// ============================================

final currentDeviceProvider = Provider<Device>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.currentDevice;
});

// ============================================
// DISCOVERED DEVICES PROVIDER
// ============================================

final discoveredDevicesProvider = StreamProvider<List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.devicesStream;
});

// ============================================
// SELECTED DEVICE PROVIDER
// ============================================

final selectedDeviceProvider = StateProvider<Device?>((ref) => null);

// ============================================
// SERVICE STATUS PROVIDERS
// ============================================

final isDeviceServiceInitializedProvider = Provider<bool>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isInitialized;
});

final isScanningProvider = Provider<bool>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isScanning;
});

// ============================================
// DEVICE NICKNAME STATE NOTIFIER
// ============================================

class DeviceNicknameNotifier extends StateNotifier<String?> {
  final DeviceNicknameService _service;
  final String _deviceId;

  DeviceNicknameNotifier(this._service, this._deviceId) : super(null) {
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    state = await _service.getNickname(_deviceId);
  }

  Future<bool> setNickname(String nickname) async {
    final success = await _service.saveNickname(_deviceId, nickname);
    if (success) {
      state = nickname.isEmpty ? null : nickname;
    }
    return success;
  }

  Future<bool> clearNickname() async {
    final success = await _service.deleteNickname(_deviceId);
    if (success) {
      state = null;
    }
    return success;
  }
}

// Provider for current device nickname
final currentDeviceNicknameProvider =
    StateNotifierProvider<DeviceNicknameNotifier, String?>((ref) {
  final service = ref.watch(deviceNicknameServiceProvider);
  final device = ref.watch(currentDeviceProvider);
  return DeviceNicknameNotifier(service, device.id);
});

// ============================================
// DEVICE DISCOVERY PROVIDER (for QuickSendScreen)
// ============================================

class DeviceDiscoveryNotifier extends StateNotifier<List<Device>> {
  final DeviceDiscoveryService _service;
  bool _isScanning = false;

  DeviceDiscoveryNotifier(this._service) : super([]) {
    // Listen to the service's device stream
    _service.devicesStream.listen((devices) {
      state = devices;
    });
  }

  bool get isScanning => _isScanning;

  Future<void> startDiscovery() async {
    if (_isScanning) return;

    _isScanning = true;
    try {
      // Initialize if not already done, then refresh
      if (!_service.isInitialized) {
        await _service.initialize();
      }
      await _service.refreshDevices();
    } catch (e) {
      debugPrint('Discovery error: $e');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> stopDiscovery() async {
    _isScanning = false;
  }
}

final deviceDiscoveryProvider =
    StateNotifierProvider<DeviceDiscoveryNotifier, List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return DeviceDiscoveryNotifier(service);
});
