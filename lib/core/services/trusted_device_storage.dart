import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/device.dart';

/// Secure storage for trusted device credentials
/// 
/// Uses flutter_secure_storage to encrypt and store sensitive device information
/// such as authentication tokens, encryption keys, and device certificates.
class TrustedDeviceStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accountName: 'syndro_trusted_devices',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Key prefixes for storage
  static const String _trustedDeviceKeyPrefix = 'trusted_device_';
  static const String _deviceTokenKeyPrefix = 'device_token_';
  static const String _deviceCertificatePrefix = 'device_cert_';
  static const String _trustedDevicesListKey = 'trusted_devices_list';

  /// Store a trusted device with its credentials
  Future<void> storeTrustedDevice(Device device, {String? authToken, String? certificate}) async {
    if (!device.trusted) {
      throw ArgumentError('Cannot store untrusted device');
    }

    // Store device data
    final deviceKey = '$_trustedDeviceKeyPrefix${device.id}';
    await _storage.write(
      key: deviceKey,
      value: jsonEncode(device.toJson()),
    );

    // Store auth token if provided
    if (authToken != null) {
      await _storage.write(
        key: '$_deviceTokenKeyPrefix${device.id}',
        value: authToken,
      );
    }

    // Store certificate if provided
    if (certificate != null) {
      await _storage.write(
        key: '$_deviceCertificatePrefix${device.id}',
        value: certificate,
      );
    }

    // Update the list of trusted device IDs
    await _addToTrustedDevicesList(device.id);
  }

  /// Retrieve a trusted device by ID
  Future<Device?> getTrustedDevice(String deviceId) async {
    final deviceKey = '$_trustedDeviceKeyPrefix$deviceId';
    final deviceJson = await _storage.read(key: deviceKey);
    
    if (deviceJson == null) return null;
    
    try {
      final Map<String, dynamic> json = jsonDecode(deviceJson);
      return Device.fromJson(json);
    } catch (e) {
      // If parsing fails, remove corrupted data
      await removeTrustedDevice(deviceId);
      return null;
    }
  }

  /// Get authentication token for a trusted device
  Future<String?> getDeviceAuthToken(String deviceId) async {
    return await _storage.read(key: '$_deviceTokenKeyPrefix$deviceId');
  }

  /// Get certificate for a trusted device
  Future<String?> getDeviceCertificate(String deviceId) async {
    return await _storage.read(key: '$_deviceCertificatePrefix$deviceId');
  }

  /// Get all trusted devices
  Future<List<Device>> getAllTrustedDevices() async {
    final deviceIds = await _getTrustedDevicesList();
    final devices = <Device>[];

    for (final deviceId in deviceIds) {
      final device = await getTrustedDevice(deviceId);
      if (device != null) {
        devices.add(device);
      }
    }

    return devices;
  }

  /// Remove a trusted device and all its credentials
  Future<void> removeTrustedDevice(String deviceId) async {
    // Remove device data
    await _storage.delete(key: '$_trustedDeviceKeyPrefix$deviceId');
    
    // Remove auth token
    await _storage.delete(key: '$_deviceTokenKeyPrefix$deviceId');
    
    // Remove certificate
    await _storage.delete(key: '$_deviceCertificatePrefix$deviceId');

    // Update the list
    await _removeFromTrustedDevicesList(deviceId);
  }

  /// Update an existing trusted device (preserves credentials)
  Future<void> updateTrustedDevice(Device device) async {
    if (!device.trusted) {
      // If device is no longer trusted, remove it from storage
      await removeTrustedDevice(device.id);
      return;
    }

    // Preserve existing credentials
    final existingToken = await getDeviceAuthToken(device.id);
    final existingCert = await getDeviceCertificate(device.id);

    await storeTrustedDevice(
      device,
      authToken: existingToken,
      certificate: existingCert,
    );
  }

  /// Check if a device is trusted (exists in secure storage)
  Future<bool> isDeviceTrusted(String deviceId) async {
    final device = await getTrustedDevice(deviceId);
    return device?.trusted ?? false;
  }

  /// Clear all trusted devices and credentials
  Future<void> clearAllTrustedDevices() async {
    final deviceIds = await _getTrustedDevicesList();
    
    for (final deviceId in deviceIds) {
      await _storage.delete(key: '$_trustedDeviceKeyPrefix$deviceId');
      await _storage.delete(key: '$_deviceTokenKeyPrefix$deviceId');
      await _storage.delete(key: '$_deviceCertificatePrefix$deviceId');
    }

    await _storage.delete(key: _trustedDevicesListKey);
  }

  /// Get the list of trusted device IDs
  Future<List<String>> _getTrustedDevicesList() async {
    final listJson = await _storage.read(key: _trustedDevicesListKey);
    if (listJson == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(listJson);
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Add a device ID to the trusted devices list
  Future<void> _addToTrustedDevicesList(String deviceId) async {
    final currentList = await _getTrustedDevicesList();
    if (!currentList.contains(deviceId)) {
      currentList.add(deviceId);
      await _storage.write(
        key: _trustedDevicesListKey,
        value: jsonEncode(currentList),
      );
    }
  }

  /// Remove a device ID from the trusted devices list
  Future<void> _removeFromTrustedDevicesList(String deviceId) async {
    final currentList = await _getTrustedDevicesList();
    currentList.remove(deviceId);
    await _storage.write(
      key: _trustedDevicesListKey,
      value: jsonEncode(currentList),
    );
  }

  /// Export trusted devices for backup (encrypted)
  Future<String?> exportTrustedDevices() async {
    final devices = await getAllTrustedDevices();
    if (devices.isEmpty) return null;

    final exportData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'devices': devices.map((d) => d.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Import trusted devices from backup
  Future<int> importTrustedDevices(String exportJson) async {
    try {
      final Map<String, dynamic> data = jsonDecode(exportJson);
      final List<dynamic> devices = data['devices'];
      
      int importedCount = 0;
      for (final deviceJson in devices) {
        final device = Device.fromJson(deviceJson);
        if (device.trusted) {
          await storeTrustedDevice(device);
          importedCount++;
        }
      }

      return importedCount;
    } catch (e) {
      return 0;
    }
  }
}
