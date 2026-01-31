import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/device_discovery_service.dart';

// Main service provider
final deviceDiscoveryServiceProvider = Provider<DeviceDiscoveryService>((ref) {
  final service = DeviceDiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Current device provider
final currentDeviceProvider = Provider<Device>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.currentDevice;
});

// Discovered devices stream provider
final discoveredDevicesProvider = StreamProvider<List<Device>>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.devicesStream;
});

// Selected device state provider
final selectedDeviceProvider = StateProvider<Device?>((ref) => null);

// ✅ Check if service is initialized
final isDeviceServiceInitializedProvider = Provider<bool>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isInitialized;
});

// ✅ Check if currently scanning
final isScanningProvider = Provider<bool>((ref) {
  final service = ref.watch(deviceDiscoveryServiceProvider);
  return service.isScanning;
});
