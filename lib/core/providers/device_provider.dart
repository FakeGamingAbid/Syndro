import 'dart:async';

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

  ref.onDispose(() {
    // FIX: Don't await in onDispose - just call dispose
    // The service's dispose method handles cleanup internally
    service.dispose();
  });

  return service;
});

// ============================================
// CURRENT DEVICE PROVIDER
// ============================================

final currentDeviceProvider = Provider<Device>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  // FIX (Bug #10): Check if service is initialized before returning device
  if (!service.isInitialized) {
    return Device(
      id: '',
      name: 'Initializing...',
      platform: DevicePlatform.unknown,
      ipAddress: '0.0.0.0',
      port: 8765,
      lastSeen: DateTime.now(),
    );
  }
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
// MULTI-SELECT DEVICES PROVIDER
// ============================================

/// Provider for selecting multiple devices for batch transfer
final selectedDevicesProvider = StateProvider<Set<Device>>((ref) => {});

/// Provider to check if multi-select mode is enabled
final isMultiSelectModeProvider = Provider<bool>((ref) {
  return ref.watch(selectedDevicesProvider).isNotEmpty;
});

// ============================================
// SERVICE STATUS PROVIDERS
// ============================================

final isDeviceServiceInitializedProvider = Provider<bool>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isInitialized;
});

// FIX (Bug #14): Use StreamProvider for reactive scanning state
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
    try {
      state = await _service.getNickname(_deviceId);
    } catch (e) {
      debugPrint('Error loading nickname: $e');
      state = null;
    }
  }

  Future<bool> setNickname(String nickname) async {
    try {
      final success = await _service.saveNickname(_deviceId, nickname);
      if (success) {
        state = nickname.isEmpty ? null : nickname;
      }
      return success;
    } catch (e) {
      debugPrint('Error setting nickname: $e');
      return false;
    }
  }

  Future<bool> clearNickname() async {
    try {
      final success = await _service.deleteNickname(_deviceId);
      if (success) {
        state = null;
      }
      return success;
    } catch (e) {
      debugPrint('Error clearing nickname: $e');
      return false;
    }
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
  bool _isDisposed = false;

  // FIX (Bug #6): Type the subscription properly
  StreamSubscription<List<Device>>? _subscription;

  DeviceDiscoveryNotifier(this._service) : super([]) {
    // Listen to the service's device stream
    _subscription = _service.devicesStream.listen(
      (devices) {
        if (!_isDisposed) {
          state = devices;
        }
      },
      onError: (e) {
        debugPrint('Device stream error: $e');
      },
    );
  }

  bool get isScanning => _isScanning;

  Future<void> startDiscovery() async {
    if (_isScanning || _isDisposed) return;

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
      if (!_isDisposed) {
        _isScanning = false;
      }
    }
  }

  Future<void> stopDiscovery() async {
    _isScanning = false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

final deviceDiscoveryProvider =
    StateNotifierProvider<DeviceDiscoveryNotifier, List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return DeviceDiscoveryNotifier(service);
});

// ============================================
// FIX: Add a reactive scanning state provider
// ============================================

/// A provider that exposes whether discovery is currently scanning
/// This can be used by UI to show scanning indicators
final isDiscoveryScanningProvider = Provider<bool>((ref) {
  final notifier = ref.watch(deviceDiscoveryProvider.notifier);
  return notifier.isScanning;
});
