import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/device_discovery_service.dart';

/// Provider for the device discovery service
final deviceDiscoveryServiceProvider = Provider<DeviceDiscoveryService>((ref) {
  final service = DeviceDiscoveryService();
  
  // Initialize when provider is first accessed
  service.initialize();
  
  // Dispose when provider is disposed
  ref.onDispose(() => service.dispose());
  
  return service;
});

/// Stream provider for all devices (discovered + trusted)
final allDevicesStreamProvider = StreamProvider<List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.devicesStream;
});

/// Stream provider for trusted devices only
final trustedDevicesStreamProvider = StreamProvider<List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.trustedDevicesStream;
});

/// Provider for current device info
final currentDeviceProvider = Provider<Device>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.currentDevice;
});

/// Provider for trusted device count
final trustedDeviceCountProvider = Provider<int>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.trustedDeviceCount;
});

/// Provider for checking if a specific device is trusted
final isDeviceTrustedProvider = Provider.family<bool, String>((ref, deviceId) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isDeviceTrusted(deviceId);
});

/// Notifier for trusted device actions
class TrustedDeviceNotifier extends StateNotifier<AsyncValue<void>> {
  final DeviceDiscoveryService _service;
  
  TrustedDeviceNotifier(this._service) : super(const AsyncValue.data(null));
  
  Future<void> trustDevice(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      await _service.trustDevice(deviceId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> untrustDevice(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      await _service.untrustDevice(deviceId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> toggleTrust(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      await _service.toggleTrust(deviceId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> refreshDevices() async {
    state = const AsyncValue.loading();
    try {
      await _service.refreshDevices();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for trusted device actions
final trustedDeviceActionsProvider = StateNotifierProvider<TrustedDeviceNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return TrustedDeviceNotifier(service);
});
