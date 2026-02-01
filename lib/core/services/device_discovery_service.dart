import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/device.dart';
import 'trusted_device_storage.dart';

/// Enhanced Device Discovery Service with Trusted Device Persistence
/// 
/// This service now:
/// - Loads trusted devices from secure storage on initialization
/// - Persists trusted devices to both SQLite and secure storage
/// - Merges discovered devices with trusted devices (preserving trust status)
/// - Provides methods to trust/untrust devices
class DeviceDiscoveryService {
  static const int _defaultPort = 8765;
  static const List<int> _scanPorts = [8765, 50500, 50050];

  final _uuid = const Uuid();
  final _networkInfo = NetworkInfo();
  final _db = DatabaseHelper.instance;
  final _secureStorage = TrustedDeviceStorage();

  final _deviceController = StreamController<List<Device>>.broadcast();
  final _trustedDevicesController = StreamController<List<Device>>.broadcast();
  bool _hasEmitted = false;

  Device _currentDevice = Device(
    id: 'initializing',
    name: 'Discovering...',
    platform: DevicePlatform.unknown,
    ipAddress: '0.0.0.0',
    port: 8765,
    lastSeen: DateTime.now(),
  );

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isDisposed = false;

  // Discovered devices (from network scan)
  final Map<String, Device> _discoveredDevices = {};
  
  // Trusted devices (loaded from persistent storage)
  final Map<String, Device> _trustedDevices = {};

  Timer? _cleanupTimer;
  Timer? _scanTimer;

  String? _localIp;
  String? _subnet;

  // ==================== Public API ====================

  /// Stream of all discovered devices (online + offline trusted)
  Stream<List<Device>> get devicesStream {
    if (!_hasEmitted) {
      Future.microtask(() {
        if (!_isDisposed) {
          _emitDeviceList();
          _hasEmitted = true;
        }
      });
    }
    return _deviceController.stream;
  }

  /// Stream of only trusted devices
  Stream<List<Device>> get trustedDevicesStream => _trustedDevicesController.stream;

  Device get currentDevice => _currentDevice;
  
  /// All discovered devices (combines online discovered + offline trusted)
  List<Device> get discoveredDevices => _getMergedDeviceList();
  
  /// Only trusted devices
  List<Device> get trustedDevices => _trustedDevices.values.toList();
  
  /// Only online devices
  List<Device> get onlineDevices => _discoveredDevices.values.where((d) => d.isOnline).toList();

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  
  /// Number of trusted devices
  int get trustedDeviceCount => _trustedDevices.length;

  // ==================== Initialization ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // First, load trusted devices from persistent storage
      await _loadTrustedDevices();

      final deviceId = _uuid.v4();
      final deviceName = await _getDeviceName();
      final platform = _getCurrentPlatform();

      String ipAddress = '0.0.0.0';
      try {
        ipAddress = await _getLocalIpAddress().timeout(
          const Duration(seconds: 3),
          onTimeout: () => '0.0.0.0',
        );
        _localIp = ipAddress;
        _subnet = _getSubnetFromIp(ipAddress);
      } catch (e) {
        print('Error getting IP: $e');
      }

      _currentDevice = Device(
        id: deviceId,
        name: deviceName,
        platform: platform,
        ipAddress: ipAddress,
        port: _defaultPort,
        lastSeen: DateTime.now(),
      );

      _isInitialized = true;
      _emitDeviceList();
      _hasEmitted = true;

      // Start background scanning
      _startPeriodicScanning();
      _startCleanup();
    } catch (e) {
      print('Error initializing device discovery: $e');
      _isInitialized = true;
      _emitDeviceList();
      _hasEmitted = true;
    }
  }

  /// Load trusted devices from persistent storage
  Future<void> _loadTrustedDevices() async {
    try {
      // Load from SQLite database
      final dbDevices = await _db.getTrustedDevices();
      
      // Also load from secure storage (for credentials)
      final secureDevices = await _secureStorage.getAllTrustedDevices();

      // Merge devices (prefer secure storage data for trusted flag)
      final deviceMap = <String, Device>{};
      
      for (final device in dbDevices) {
        deviceMap[device.id] = device;
      }
      
      for (final device in secureDevices) {
        // If device exists in both, keep the one with more recent trust timestamp
        final existing = deviceMap[device.id];
        if (existing == null || 
            (device.trustedAt != null && 
             existing.trustedAt != null && 
             device.trustedAt!.isAfter(existing.trustedAt!))) {
          deviceMap[device.id] = device;
        }
      }

      _trustedDevices.addAll(deviceMap);
      
      // Mark all as offline initially (will be updated by scan)
      for (final entry in _trustedDevices.entries) {
        _trustedDevices[entry.key] = entry.value.copyWith(isOnline: false);
      }

      print('Loaded ${_trustedDevices.length} trusted devices from storage');
      _emitTrustedDeviceList();
    } catch (e) {
      print('Error loading trusted devices: $e');
    }
  }

  // ==================== Trust Management ====================

  /// Mark a device as trusted
  Future<void> trustDevice(String deviceId) async {
    // Find device in discovered or trusted list
    Device? device = _discoveredDevices[deviceId] ?? _trustedDevices[deviceId];
    
    if (device == null) {
      throw ArgumentError('Device not found: $deviceId');
    }

    // Mark as trusted
    final trustedDevice = device.markTrusted();

    // Update in-memory caches
    if (_discoveredDevices.containsKey(deviceId)) {
      _discoveredDevices[deviceId] = trustedDevice;
    }
    _trustedDevices[deviceId] = trustedDevice;

    // Persist to storage
    await _db.saveTrustedDevice(trustedDevice);
    await _secureStorage.storeTrustedDevice(trustedDevice);

    // Emit updates
    _emitDeviceList();
    _emitTrustedDeviceList();

    print('Device trusted: ${trustedDevice.name} (${trustedDevice.id})');
  }

  /// Remove trust from a device
  Future<void> untrustDevice(String deviceId) async {
    final device = _trustedDevices[deviceId];
    if (device == null) return;

    // Mark as untrusted
    final untrustedDevice = device.markUntrusted();

    // Update in-memory caches
    if (_discoveredDevices.containsKey(deviceId)) {
      _discoveredDevices[deviceId] = untrustedDevice;
    }
    _trustedDevices.remove(deviceId);

    // Remove from persistent storage
    await _db.deleteTrustedDevice(deviceId);
    await _secureStorage.removeTrustedDevice(deviceId);

    // Emit updates
    _emitDeviceList();
    _emitTrustedDeviceList();

    print('Device untrusted: ${device.name} (${device.id})');
  }

  /// Check if a device is trusted
  bool isDeviceTrusted(String deviceId) {
    return _trustedDevices.containsKey(deviceId) && 
           _trustedDevices[deviceId]!.trusted;
  }

  /// Toggle trust status for a device
  Future<void> toggleTrust(String deviceId) async {
    if (isDeviceTrusted(deviceId)) {
      await untrustDevice(deviceId);
    } else {
      await trustDevice(deviceId);
    }
  }

  /// Set auto-accept transfers for a trusted device
  Future<void> setAutoAcceptTransfers(String deviceId, bool autoAccept) async {
    if (!isDeviceTrusted(deviceId)) {
      throw ArgumentError('Cannot set auto-accept for untrusted device');
    }

    await _db.setAutoAcceptTransfers(deviceId, autoAccept);
  }

  /// Get auto-accept status for a device
  Future<bool> getAutoAcceptTransfers(String deviceId) async {
    return await _db.getAutoAcceptTransfers(deviceId);
  }

  // ==================== Device Discovery ====================

  DevicePlatform _getCurrentPlatform() {
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isLinux) return DevicePlatform.linux;
    return DevicePlatform.unknown;
  }

  /// Get actual device name based on platform
  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidDeviceName();
      } else if (Platform.isWindows) {
        return _getWindowsDeviceName();
      } else if (Platform.isLinux) {
        return _getLinuxDeviceName();
      }
    } catch (e) {
      print('Error getting device name: $e');
    }
    return 'Syndro Device';
  }

  /// Get Android device model name using MethodChannel
  Future<String> _getAndroidDeviceName() async {
    try {
      const platform = MethodChannel('com.syndro.app/device_info');
      
      try {
        final String? deviceName = await platform.invokeMethod('getDeviceName');
        if (deviceName != null && deviceName.isNotEmpty) {
          return deviceName;
        }
      } catch (e) {
        print('Platform channel not available: $e');
      }

      try {
        final result = await Process.run('getprop', ['ro.product.model']);
        if (result.exitCode == 0) {
          final model = result.stdout.toString().trim();
          if (model.isNotEmpty) return model;
        }
      } catch (e) {
        print('Could not get model from getprop: $e');
      }

      try {
        final result = await Process.run('getprop', ['ro.product.manufacturer']);
        final result2 = await Process.run('getprop', ['ro.product.model']);
        
        if (result.exitCode == 0 && result2.exitCode == 0) {
          final manufacturer = result.stdout.toString().trim();
          final model = result2.stdout.toString().trim();
          
          if (manufacturer.isNotEmpty && model.isNotEmpty) {
            final capitalizedManufacturer = manufacturer[0].toUpperCase() + 
                manufacturer.substring(1).toLowerCase();
            return '$capitalizedManufacturer $model';
          } else if (model.isNotEmpty) {
            return model;
          }
        }
      } catch (e) {
        print('Could not get manufacturer/model: $e');
      }

      return 'Android Device';
    } catch (e) {
      print('Error getting Android device name: $e');
      return 'Android Device';
    }
  }

  /// Get Windows computer name
  String _getWindowsDeviceName() {
    final computerName = Platform.environment['COMPUTERNAME'];
    if (computerName != null && computerName.isNotEmpty) {
      return computerName;
    }

    final userDomain = Platform.environment['USERDOMAIN'];
    if (userDomain != null && userDomain.isNotEmpty) {
      return userDomain;
    }

    final userName = Platform.environment['USERNAME'];
    if (userName != null && userName.isNotEmpty) {
      return "$userName's PC";
    }

    return 'Windows PC';
  }

  /// Get Linux hostname
  String _getLinuxDeviceName() {
    final hostname = Platform.environment['HOSTNAME'];
    if (hostname != null && hostname.isNotEmpty) {
      return hostname;
    }

    try {
      final file = File('/etc/hostname');
      if (file.existsSync()) {
        final name = file.readAsStringSync().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (e) {
      print('Could not read /etc/hostname: $e');
    }

    final user = Platform.environment['USER'];
    if (user != null && user.isNotEmpty) {
      return "$user's Linux";
    }

    return 'Linux PC';
  }

  Future<String> _getLocalIpAddress() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && _isPrivateIP(wifiIP)) {
        return wifiIP;
      }
    } catch (e) {
      print('Error getting WiFi IP: $e');
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && _isPrivateIP(addr.address)) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP from interfaces: $e');
    }

    return '0.0.0.0';
  }

  /// Check if IP is a private network IP
  bool _isPrivateIP(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);

      if (a == 10) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
      if (a == 192 && b == 168) return true;
      if (a == 169 && b == 254) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get subnet from IP address
  String? _getSubnetFromIp(String ip) {
    if (ip == '0.0.0.0') return null;

    final parts = ip.split('.');
    if (parts.length != 4) return null;

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  void _startPeriodicScanning() {
    if (_isDisposed) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _performScan();
      }
    });

    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isDisposed) {
        _performScan();
      }
    });
  }

  Future<void> _performScan() async {
    if (_isScanning || _isDisposed) return;

    if (_localIp == null || _localIp == '0.0.0.0') {
      _localIp = await _getLocalIpAddress();
      _subnet = _getSubnetFromIp(_localIp!);

      if (_localIp == '0.0.0.0') {
        print('No valid IP address, skipping scan');
        return;
      }
    }

    _isScanning = true;

    try {
      await _scanNetwork();
    } catch (e) {
      print('Scan error: $e');
    } finally {
      _isScanning = false;
    }
  }

  /// Scan network for Syndro devices
  Future<void> _scanNetwork() async {
    if (_subnet == null || _isDisposed) return;

    final thisDevice = int.tryParse(_localIp!.split('.').last) ?? 0;

    final ipsToScan = <String>[];
    for (int i = 1; i <= 254; i++) {
      if (i != thisDevice) {
        ipsToScan.add('$_subnet.$i');
      }
    }

    const batchSize = 50;
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      if (_isDisposed) return;

      final batch = ipsToScan.skip(i).take(batchSize);
      await Future.wait(
        batch.map((ip) => _checkDevice(ip)),
        eagerError: false,
      );
    }

    if (!_isDisposed) {
      _emitDeviceList();
    }
  }

  /// Check if a device at the given IP is running Syndro
  Future<void> _checkDevice(String ip) async {
    if (_isDisposed) return;

    for (final port in _scanPorts) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 500),
        );
        socket.destroy();

        final device = await _fetchDeviceInfo(ip, port);
        if (device != null && device.id != _currentDevice.id && !_isDisposed) {
          // Check if this device is trusted
          final isTrusted = _trustedDevices.containsKey(device.id);
          
          // Merge with trusted device data if available
          final mergedDevice = isTrusted
              ? device.copyWith(
                  trusted: true,
                  trustedAt: _trustedDevices[device.id]!.trustedAt,
                )
              : device;

          _discoveredDevices[device.id] = mergedDevice;

          // If trusted, also update the trusted devices list with new IP
          if (isTrusted) {
            _trustedDevices[device.id] = mergedDevice;
            // Update database with new IP/status
            await _db.updateDeviceStatus(
              device.id,
              isOnline: true,
              ipAddress: ip,
              port: port,
            );
          }
        }
        return;
      } catch (e) {
        // Port not open, try next
      }
    }
  }

  /// Fetch device info from syndro.json endpoint
  Future<Device?> _fetchDeviceInfo(String ip, int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:$port/syndro.json'))
          .timeout(const Duration(milliseconds: 800));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        return Device(
          id: data['id'] ?? '$ip:$port',
          name: data['name'] ?? 'Syndro Device',
          platform: _parsePlatform(data['os'] ?? data['platform']),
          ipAddress: ip,
          port: port,
          lastSeen: DateTime.now(),
          trusted: false, // Will be set by _checkDevice if trusted
        );
      }
    } catch (e) {
      // Device doesn't have syndro.json
    }

    return null;
  }

  /// Parse platform string to DevicePlatform enum
  DevicePlatform _parsePlatform(String? platform) {
    if (platform == null) return DevicePlatform.unknown;

    final lower = platform.toLowerCase();
    if (lower.contains('android')) return DevicePlatform.android;
    if (lower.contains('windows')) return DevicePlatform.windows;
    if (lower.contains('linux')) return DevicePlatform.linux;

    return DevicePlatform.unknown;
  }

  // ==================== Device List Management ====================

  /// Get merged list of all devices (online discovered + offline trusted)
  List<Device> _getMergedDeviceList() {
    final merged = <String, Device>{};

    // Add all discovered devices (online)
    for (final entry in _discoveredDevices.entries) {
      merged[entry.key] = entry.value;
    }

    // Add trusted devices that aren't currently discovered (offline)
    for (final entry in _trustedDevices.entries) {
      if (!merged.containsKey(entry.key)) {
        // Show as offline
        merged[entry.key] = entry.value.copyWith(isOnline: false);
      }
    }

    return merged.values.toList()
      ..sort((a, b) {
        // Sort by: online first, then trusted, then by name
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        if (a.trusted != b.trusted) {
          return a.trusted ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
  }

  void _emitDeviceList() {
    if (!_isDisposed) {
      _deviceController.add(_getMergedDeviceList());
    }
  }

  void _emitTrustedDeviceList() {
    if (!_isDisposed) {
      _trustedDevicesController.add(_trustedDevices.values.toList());
    }
  }

  // ==================== Cleanup & Refresh ====================

  Future<void> refreshDevices() async {
    _discoveredDevices.clear();
    
    // Reload trusted devices to get any updates
    _trustedDevices.clear();
    await _loadTrustedDevices();

    if (!_isDisposed) {
      _emitDeviceList();
    }

    await _performScan();
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDisposed) return;

      final now = DateTime.now();
      final stale = _discoveredDevices.entries
          .where((e) => now.difference(e.value.lastSeen).inSeconds > 60)
          .map((e) => e.key)
          .toList();

      for (final id in stale) {
        final device = _discoveredDevices.remove(id);
        // If device was trusted, mark as offline in trusted list
        if (device != null && device.trusted && _trustedDevices.containsKey(id)) {
          _trustedDevices[id] = device.copyWith(isOnline: false);
          // Update database
          _db.updateDeviceStatus(id, isOnline: false);
        }
      }

      if (stale.isNotEmpty && !_isDisposed) {
        _emitDeviceList();
        _emitTrustedDeviceList();
      }
    });
  }

  void updateDeviceStatus(String deviceId, bool isOnline) {
    if (_isDisposed) return;

    final device = _discoveredDevices[deviceId];
    if (device != null) {
      _discoveredDevices[deviceId] = device.copyWith(
        isOnline: isOnline,
        lastSeen: DateTime.now(),
      );
      _emitDeviceList();
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _scanTimer?.cancel();
    _cleanupTimer?.cancel();

    if (!_deviceController.isClosed) {
      await _deviceController.close();
    }
    if (!_trustedDevicesController.isClosed) {
      await _trustedDevicesController.close();
    }
  }
}
