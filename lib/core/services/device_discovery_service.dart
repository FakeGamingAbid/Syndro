import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';

class DeviceDiscoveryService {
  static const int _defaultPort = 8765;
  static const List<int> _scanPorts = [8765, 50500, 50050];

  final _uuid = const Uuid();
  final _networkInfo = NetworkInfo();

  final _deviceController = StreamController<List<Device>>.broadcast();
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

  final Map<String, Device> _discoveredDevices = {};

  Timer? _cleanupTimer;
  Timer? _scanTimer;

  String? _localIp;
  String? _subnet;

  Stream<List<Device>> get devicesStream {
    if (!_hasEmitted) {
      Future.microtask(() {
        if (!_isDisposed) {
          _deviceController.add(_discoveredDevices.values.toList());
          _hasEmitted = true;
        }
      });
    }
    return _deviceController.stream;
  }

  Device get currentDevice => _currentDevice;
  List<Device> get discoveredDevices => _discoveredDevices.values.toList();
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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
      _deviceController.add([]);
      _hasEmitted = true;

      // Start background scanning
      _startPeriodicScanning();
      _startCleanup();
    } catch (e) {
      print('Error initializing device discovery: $e');
      _isInitialized = true;
      _deviceController.add([]);
      _hasEmitted = true;
    }
  }

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
      // Try to get device info using platform channel
      const platform = MethodChannel('com.syndro.app/device_info');
      
      try {
        final String? deviceName = await platform.invokeMethod('getDeviceName');
        if (deviceName != null && deviceName.isNotEmpty) {
          return deviceName;
        }
      } catch (e) {
        // Platform channel not available, try alternative method
        print('Platform channel not available: $e');
      }

      // Fallback: Try to read from system properties using shell
      try {
        final result = await Process.run('getprop', ['ro.product.model']);
        if (result.exitCode == 0) {
          final model = result.stdout.toString().trim();
          if (model.isNotEmpty) {
            return model;
          }
        }
      } catch (e) {
        print('Could not get model from getprop: $e');
      }

      // Fallback: Try to get manufacturer and model from build.prop
      try {
        final result = await Process.run('getprop', ['ro.product.manufacturer']);
        final result2 = await Process.run('getprop', ['ro.product.model']);
        
        if (result.exitCode == 0 && result2.exitCode == 0) {
          final manufacturer = result.stdout.toString().trim();
          final model = result2.stdout.toString().trim();
          
          if (manufacturer.isNotEmpty && model.isNotEmpty) {
            // Capitalize first letter of manufacturer
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

      // Final fallback
      return 'Android Device';
    } catch (e) {
      print('Error getting Android device name: $e');
      return 'Android Device';
    }
  }

  /// Get Windows computer name
  String _getWindowsDeviceName() {
    // Try COMPUTERNAME first (most common)
    final computerName = Platform.environment['COMPUTERNAME'];
    if (computerName != null && computerName.isNotEmpty) {
      return computerName;
    }

    // Try USERDOMAIN as fallback
    final userDomain = Platform.environment['USERDOMAIN'];
    if (userDomain != null && userDomain.isNotEmpty) {
      return userDomain;
    }

    // Try USERNAME as last resort
    final userName = Platform.environment['USERNAME'];
    if (userName != null && userName.isNotEmpty) {
      return "$userName's PC";
    }

    return 'Windows PC';
  }

  /// Get Linux hostname
  String _getLinuxDeviceName() {
    // Try HOSTNAME first
    final hostname = Platform.environment['HOSTNAME'];
    if (hostname != null && hostname.isNotEmpty) {
      return hostname;
    }

    // Try reading /etc/hostname
    try {
      final file = File('/etc/hostname');
      if (file.existsSync()) {
        final name = file.readAsStringSync().trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
    } catch (e) {
      print('Could not read /etc/hostname: $e');
    }

    // Try USER environment variable
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

    // Fallback: try to get from network interfaces
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
  /// Supports: 192.168.x.x, 10.x.x.x, 172.16.x.x - 172.31.x.x
  bool _isPrivateIP(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);

      // 10.0.0.0 - 10.255.255.255 (Class A private)
      if (a == 10) return true;

      // 172.16.0.0 - 172.31.255.255 (Class B private)
      if (a == 172 && b >= 16 && b <= 31) return true;

      // 192.168.0.0 - 192.168.255.255 (Class C private)
      if (a == 192 && b == 168) return true;

      // 169.254.0.0 - 169.254.255.255 (Link-local)
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

    // Initial scan after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _performScan();
      }
    });

    // Then scan every 5 seconds
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isDisposed) {
        _performScan();
      }
    });
  }

  Future<void> _performScan() async {
    if (_isScanning || _isDisposed) return;

    if (_localIp == null || _localIp == '0.0.0.0') {
      // Try to get IP again
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

  /// Scan network for Syndro devices (supports all private networks)
  Future<void> _scanNetwork() async {
    if (_subnet == null || _isDisposed) return;

    final thisDevice = int.tryParse(_localIp!.split('.').last) ?? 0;

    // Generate list of IPs to scan (1-254, excluding this device)
    final ipsToScan = <String>[];
    for (int i = 1; i <= 254; i++) {
      if (i != thisDevice) {
        ipsToScan.add('$_subnet.$i');
      }
    }

    // Scan in parallel batches (to avoid too many concurrent connections)
    const batchSize = 50;
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      if (_isDisposed) return;

      final batch = ipsToScan.skip(i).take(batchSize);
      await Future.wait(
        batch.map((ip) => _checkDevice(ip)),
        eagerError: false,
      );
    }

    // Emit updated device list
    if (!_isDisposed) {
      _deviceController.add(_discoveredDevices.values.toList());
    }
  }

  /// Check if a device at the given IP is running Syndro
  Future<void> _checkDevice(String ip) async {
    if (_isDisposed) return;

    for (final port in _scanPorts) {
      try {
        // First, quick TCP ping to check if port is open
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 500),
        );
        socket.destroy();

        // Port is open, try to get device info
        final device = await _fetchDeviceInfo(ip, port);
        if (device != null && device.id != _currentDevice.id && !_isDisposed) {
          _discoveredDevices[device.id] = device;

          // Emit immediately when device found
          _deviceController.add(_discoveredDevices.values.toList());
        }
        return; // Found on this port, no need to check other ports
      } catch (e) {
        // Port not open or device not responding, try next port
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
        );
      }
    } catch (e) {
      // Device doesn't have syndro.json, might be a different app
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

  Future<void> refreshDevices() async {
    // Clear old devices and rescan
    _discoveredDevices.clear();

    if (!_isDisposed) {
      _deviceController.add([]);
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
        _discoveredDevices.remove(id);
      }

      if (stale.isNotEmpty && !_isDisposed) {
        _deviceController.add(_discoveredDevices.values.toList());
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
      _deviceController.add(_discoveredDevices.values.toList());
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _scanTimer?.cancel();
    _cleanupTimer?.cancel();

    if (!_deviceController.isClosed) {
      await _deviceController.close();
    }
  }
}
