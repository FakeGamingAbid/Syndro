import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import 'device_nickname_service.dart';

class DeviceDiscoveryService {
  static const int _defaultPort = 8765;
  static const List<int> _scanPorts = [
    8765, 8766, 8767, 8768, 8769, 8770, // Transfer server ports
    50500, 50050 // Legacy/Alt ports
  ];
  static const int _udpPort = 8771; // Dedicated UDP port for discovery
  static const String _deviceIdKey = 'syndro_device_id';

  final _uuid = const Uuid();
  final _networkInfo = NetworkInfo();
  final _deviceController = StreamController<List<Device>>.broadcast();
  final _nicknameService = DeviceNicknameService();

  RawDatagramSocket? _udpSocket;
  Timer? _udpBroadcastTimer;

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

  List<String> _localIps = [];
  List<String> _subnets = [];

  Stream<List<Device>> get devicesStream {
    if (!_hasEmitted) {
      Future.microtask(() {
        if (!_isDisposed && !_deviceController.isClosed) {
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
      // Load or generate persistent device ID
      final deviceId = await _getOrCreateDeviceId();
      
      // Get device name (custom nickname or system default)
      final deviceName = await _getDeviceNameWithNickname(deviceId);
      
      final platform = _getCurrentPlatform();

      String ipAddress = '0.0.0.0';

      try {
        _localIps = await _getAllLocalIps();
        
        if (_localIps.isNotEmpty) {
           // Use the first one as "primary" for now, or prefer WiFi if possible
           // logic inside _getAllLocalIps puts WiFi first
           final primaryIp = _localIps.first;
           _subnets = _localIps.map((ip) => _getSubnetFromIp(ip)).whereType<String>().toSet().toList();
           
           // Update current device with primary IP
           ipAddress = primaryIp;
        }
      } catch (e) {
        debugPrint('Error getting IPs: $e');
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

      if (!_deviceController.isClosed) {
        _deviceController.add([]);
      }
      _hasEmitted = true;

      // Start background scanning (HTTP + UDP)
      _startPeriodicScanning();
      _startUdpDiscovery();
      _startCleanup();
    } catch (e) {
      debugPrint('Error initializing device discovery: $e');
      _isInitialized = false;
      if (!_deviceController.isClosed) {
        _deviceController.add([]);
      }
      _hasEmitted = true;
    }
  }

  DevicePlatform _getCurrentPlatform() {
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isLinux) return DevicePlatform.linux;
    return DevicePlatform.unknown;
  }

  /// Get or create a persistent device ID
  /// This ensures the same device ID is used across app restarts,
  /// which is essential for the trusted devices feature to work correctly.
  Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        // Generate a new device ID and persist it
        deviceId = _uuid.v4();
        await prefs.setString(_deviceIdKey, deviceId);
        debugPrint('✅ Generated new device ID: $deviceId');
      } else {
        debugPrint('✅ Loaded existing device ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      debugPrint('Error with device ID persistence: $e');
      // Fallback to generating a new ID (not persisted)
      return _uuid.v4();
    }
  }

  /// Get device name with custom nickname support
  /// First checks for a user-defined nickname, then falls back to system device name
  Future<String> _getDeviceNameWithNickname(String deviceId) async {
    try {
      // First, check if user has set a custom nickname
      final customNickname = await _nicknameService.getNickname(deviceId);
      if (customNickname != null && customNickname.isNotEmpty) {
        debugPrint('✅ Using custom device nickname: $customNickname');
        return customNickname;
      }
    } catch (e) {
      debugPrint('Error getting custom nickname: $e');
    }

    // Fall back to system device name
    return await _getDeviceName();
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
      debugPrint('Error getting device name: $e');
    }

    return 'Syndro Device';
  }

  /// Get Android device model name using MethodChannel
  Future<String> _getAndroidDeviceName() async {
    try {
      // Try to get device info using platform channel
      const platform = MethodChannel('com.syndro.app/device_info');

      try {
        final String? deviceName =
            await platform.invokeMethod('getDeviceName');
        if (deviceName != null && deviceName.isNotEmpty) {
          return deviceName;
        }
      } catch (e) {
        // Platform channel not available, try alternative method
        debugPrint('Platform channel not available: $e');
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
        debugPrint('Could not get model from getprop: $e');
      }

      // Fallback: Try to get manufacturer and model from build.prop
      try {
        final result =
            await Process.run('getprop', ['ro.product.manufacturer']);
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
        debugPrint('Could not get manufacturer/model: $e');
      }

      // Final fallback
      return 'Android Device';
    } catch (e) {
      debugPrint('Error getting Android device name: $e');
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
      debugPrint('Could not read /etc/hostname: $e');
    }

    // Try USER environment variable
    final user = Platform.environment['USER'];
    if (user != null && user.isNotEmpty) {
      return "$user's Linux";
    }

    return 'Linux PC';
  }

  Future<List<String>> _getAllLocalIps() async {
    final ips = <String>{};

    // 1. Try WiFi IP first (most likely for user)
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && _isPrivateIP(wifiIP)) {
        ips.add(wifiIP);
      }
    } catch (e) {
      debugPrint('Error getting WiFi IP: $e');
    }

    // 2. Scan all network interfaces
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        // Filter out obviously wrong interfaces if needed (e.g. 'wsl')
        // But for now, trust _isPrivateIP check
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && _isPrivateIP(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting IP from interfaces: $e');
    }
    
    // If we found IPs from interfaces but no WiFi IP, putting them in list
    // The Set handles duplicates
    
    if (ips.isEmpty) return ['0.0.0.0'];

    return ips.toList();
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

    // Refresh IPs periodically (in case network changed)
    try {
      _localIps = await _getAllLocalIps();
      _localIps.remove('0.0.0.0');
      
      if (_localIps.isEmpty) {
        debugPrint('No valid IP addresses, skipping scan');
        return;
      }
      
      _subnets = _localIps.map((ip) => _getSubnetFromIp(ip)).whereType<String>().toSet().toList();
    } catch (e) {
      debugPrint('Error refreshing IPs: $e');
      return;
    }

    if (_subnets.isEmpty) {
      debugPrint('No valid subnets, skipping scan');
      return;
    }

    _isScanning = true;

    try {
      await _scanNetwork();
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      _isScanning = false;
    }
  }

  /// Scan network for Syndro devices (supports all private networks)
  Future<void> _scanNetwork() async {
    if (_isDisposed) return;

    // Capture subnets locally
    final subnetsToScan = List<String>.from(_subnets);
    
    // Generate full list of IPs to scan across ALL subnets
    final ipsToScan = <String>[];
    
    for (final subnet in subnetsToScan) {
      // Find my IP in this subnet (to exclude self)
      final myIpInSubnet = _localIps.firstWhere(
        (ip) => ip.startsWith(subnet), 
        orElse: () => ''
      );
      final myHostPart = myIpInSubnet.isNotEmpty 
          ? int.tryParse(myIpInSubnet.split('.').last) ?? 0 
          : 0;

      for (int i = 1; i <= 254; i++) {
        if (i != myHostPart) {
          ipsToScan.add('$subnet.$i');
        }
      }
    }
    
    if (ipsToScan.isEmpty) return;

    debugPrint('🔍 Scanning ${ipsToScan.length} IPs across ${subnetsToScan.length} subnets...');

    // Scan in parallel batches
    const batchSize = 100; // Increased batch size slightly
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      if (_isDisposed) return;

      final batch = ipsToScan.skip(i).take(batchSize);
      await Future.wait(
        batch.map((ip) => _checkDevice(ip)),
        eagerError: false,
      );
    }

    // Emit updated device list
    if (!_isDisposed && !_deviceController.isClosed) {
      _deviceController.add(_discoveredDevices.values.toList());
    }
  }

  /// Check if a device at the given IP is running Syndro
  Future<void> _checkDevice(String ip) async {
    if (_isDisposed) return;

    for (final port in _scanPorts) {
      Socket? socket;
      try {
        // First, quick TCP ping to check if port is open
        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 1500), // Increased timeout for reliability
        );

        // Port is open, destroy socket immediately
        socket.destroy();
        socket = null;

        // Try to get device info
        final device = await _fetchDeviceInfo(ip, port);

        if (device != null && device.id != _currentDevice.id && !_isDisposed) {
          _discoveredDevices[device.id] = device;

          // Emit immediately when device found
          if (!_deviceController.isClosed) {
            _deviceController.add(_discoveredDevices.values.toList());
          }
        }
        return; // Found on this port, no need to check other ports
      } catch (e) {
        // Port not open or device not responding, try next port
      } finally {
        // Always destroy socket in finally block
        try {
          socket?.destroy();
        } catch (_) {}
      }
    }
  }

  /// Fetch device info from syndro.json endpoint
  Future<Device?> _fetchDeviceInfo(String ip, int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:$port/syndro.json'))
          .timeout(const Duration(milliseconds: 2000));

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

  /// Refresh devices and also reload the current device name
  /// Call this after changing the device nickname
  Future<void> refreshDevices() async {
    // Reload current device name in case nickname changed
    await _reloadCurrentDeviceName();

    // Clear old devices and rescan
    _discoveredDevices.clear();

    if (!_isDisposed && !_deviceController.isClosed) {
      _deviceController.add([]);
    }

    await _performScan();
  }

  /// Reload the current device name (useful after nickname change)
  Future<void> _reloadCurrentDeviceName() async {
    try {
      final newName = await _getDeviceNameWithNickname(_currentDevice.id);

      if (newName != _currentDevice.name) {
        _currentDevice = _currentDevice.copyWith(name: newName);
        debugPrint('✅ Device name updated to: $newName');
      }
    } catch (e) {
      debugPrint('Error reloading device name: $e');
    }
  }

  /// Public method to update device name after nickname change
  Future<void> updateDeviceName() async {
    await _reloadCurrentDeviceName();
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDisposed) return;

      final now = DateTime.now();

      // Create a copy of keys to avoid concurrent modification
      final keysToRemove = <String>[];

      for (final entry in _discoveredDevices.entries) {
        if (now.difference(entry.value.lastSeen).inSeconds > 60) {
          keysToRemove.add(entry.key);
        }
      }

      // Remove stale devices
      for (final key in keysToRemove) {
        _discoveredDevices.remove(key);
      }

      if (keysToRemove.isNotEmpty &&
          !_isDisposed &&
          !_deviceController.isClosed) {
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

      if (!_deviceController.isClosed) {
        _deviceController.add(_discoveredDevices.values.toList());
      }
    }
  }

  // UDP Discovery Implementation

  Future<void> _startUdpDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
        reuseAddress: true,
      );
      
      _udpSocket?.broadcastEnabled = true;
      debugPrint('🚀 UDP Discovery listening on port $_udpPort');

      _udpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _handleUdpPacket(datagram);
          }
        }
      });

      // Start broadcasting our presence
      _udpBroadcastTimer = Timer.periodic(
        const Duration(seconds: 2), 
        (_) => _sendUdpBroadcast()
      );
      
      // Send immediate broadcast
      _sendUdpBroadcast();
      
    } catch (e) {
      debugPrint('Failed to start UDP discovery: $e');
    }
  }

  void _sendUdpBroadcast() {
    if (_udpSocket == null || _isDisposed) return;
    
    // Construct discovery packet
    final packet = {
      'syndro': true,
      'id': _currentDevice.id,
      'name': _currentDevice.name,
      'os': _currentDevice.platform.toString().split('.').last, // simple string
      'port': _currentDevice.port, // Our HTTP server port
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    final data = utf8.encode(jsonEncode(packet));
    
    try {
      // Broadcast to 255.255.255.255
      _udpSocket?.send(
        data, 
        InternetAddress('255.255.255.255'), 
        _udpPort
      );
      
      // Also try subnet broadcasts if possible
      for (final subnet in _subnets) {
         // rough guess: x.x.x.255
         try {
           _udpSocket?.send(
             data, 
             InternetAddress('$subnet.255'), 
             _udpPort
           );
         } catch (_) {}
      }
    } catch (e) {
      debugPrint('UDP Broadcast error: $e');
    }
  }

  void _handleUdpPacket(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final data = jsonDecode(jsonStr);
      
      if (data is! Map<String, dynamic> || data['syndro'] != true) return;
      
      final senderId = data['id'] as String?;
      if (senderId == null || senderId == _currentDevice.id) return; // Ignore self
      
      // Valid discovery packet!
      final ip = datagram.address.address;
      final port = data['port'] as int? ?? 8765;
      
      debugPrint('📡 UDP Discovered device: $ip:$port (${data['name']})');
      
      // Immediately verify via HTTP (to get full details + encryption key etc)
      // Or just add directly if we trust UDP payload?
      // Safer to check HTTP to confirm connectivity
      _checkDeviceOnSpecificPort(ip, port);
       
    } catch (e) {
      // Invalid packet
    }
  }

  /// Check a specific IP:Port combination (optimized from _checkDevice)
  Future<void> _checkDeviceOnSpecificPort(String ip, int port) async {
      try {
        final device = await _fetchDeviceInfo(ip, port);
        if (device != null && device.id != _currentDevice.id && !_isDisposed) {
          _discoveredDevices[device.id] = device;
          if (!_deviceController.isClosed) {
            _deviceController.add(_discoveredDevices.values.toList());
          }
        }
      } catch (_) {}
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _scanTimer?.cancel();
    _cleanupTimer?.cancel();
    
    _udpBroadcastTimer?.cancel();
    _udpSocket?.close();

    if (!_deviceController.isClosed) {
      await _deviceController.close();
    }
  }
}
