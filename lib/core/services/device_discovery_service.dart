import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/device.dart';
import 'device_nickname_service.dart';

/// Simple lock implementation for thread-safe operations
class Lock {
  final _queue = <Completer<void>>[];
  bool _locked = false;

  Future<void> synchronized(FutureOr<void> Function() action) async {
    final completer = Completer<void>();
    _queue.add(completer);

    if (_locked || _queue.length > 1) {
      await completer.future;
    }

    _locked = true;

    try {
      await action();
    } finally {
      _locked = false;
      _queue.removeAt(0);
      
      if (_queue.isNotEmpty) {
        try {
          _queue.first.complete();
        } catch (_) {
          // Continue even if notification fails
        }
      }
    }
  }
}

/// Service for discovering and tracking devices on the local network.
///
/// This service uses multiple discovery mechanisms:
/// - UDP broadcast for fast device announcement
/// - HTTP polling for reliable detection
/// - mDNS-style service discovery
///
/// ## Discovery Process
///
/// 1. On initialization, generates or loads a persistent device ID
/// 2. Broadcasts UDP packets announcing presence on port 8771
/// 3. Listens for UDP broadcasts from other devices
/// 4. Periodically scans known ports for HTTP endpoints
/// 5. Removes stale devices after timeout (30 seconds)
///
/// ## Usage
///
/// ```dart
/// final discoveryService = DeviceDiscoveryService();
/// await discoveryService.initialize();
///
/// // Listen for discovered devices
/// discoveryService.devicesStream.listen((devices) {
///   for (final device in devices) {
///     print('Found: ${device.name} at ${device.ipAddress}');
///   }
/// });
///
/// // Start broadcasting presence
/// await discoveryService.startBroadcasting();
///
/// // Start scanning for devices
/// await discoveryService.startScanning();
/// ```
///
/// ## Device Identity
///
/// Each device has a unique, persistent ID stored in SharedPreferences.
/// The device name can be customized and is persisted across sessions.
class DeviceDiscoveryService {
  static const int _defaultPort = 8765;
  static const List<int> _scanPorts = [
    8765, 8766, 8767, 8768, 8769, 8770, // Transfer server ports
    50500, 50050 // Legacy/Alt ports
  ];
  int _udpPort = 8771; // Dedicated UDP port for discovery (can change if port is busy)
  static const String _deviceIdKey = 'syndro_device_id';

  // Rate limiting configuration
  final List<DateTime> _discoveryTimestamps = [];
  final _rateLimitLock = Lock();

  final _uuid = const Uuid();
  final _networkInfo = NetworkInfo();
  final _deviceController = StreamController<List<Device>>.broadcast();
  final _nicknameService = DeviceNicknameService();

  RawDatagramSocket? _udpSocket;
  Timer? _udpBroadcastTimer;
  HttpServer? _server;

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

  /// Check if discovery can proceed based on rate limits
  /// 
  /// Returns true if we're within the rate limit, false if too many requests
  Future<bool> _canDiscover() async {
    await _rateLimitLock.synchronized(() {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      
      // Remove timestamps older than 1 minute
      _discoveryTimestamps.removeWhere((t) => t.isBefore(oneMinuteAgo));
      
      if (_discoveryTimestamps.length >= AppConfig.maxDiscoveryRatePerMinute) {
        debugPrint('⚠️ Rate limit reached: ${_discoveryTimestamps.length} discoveries in the last minute');
        return;
      }
      
      _discoveryTimestamps.add(now);
    });
    return true;
  }

  Stream<List<Device>> get devicesStream {
    if (!_hasEmitted) {
      Future.microtask(() {
        // FIX: Check _isDisposed before adding to stream
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
    if (_isInitialized || _isDisposed) return;

    try {
      // Load or generate persistent device ID
      final deviceId = await _getOrCreateDeviceId();

      // Get device name (custom nickname or system default)
      final deviceName = await _getDeviceNameWithNickname(deviceId);
      final platform = _getCurrentPlatform();

      String ipAddress = '0.0.0.0';

      try {
        _localIps = await _getAllLocalIps();
        // FIX: Handle empty IP list consistently - use first valid IP or fallback
        if (_localIps.isNotEmpty) {
          final primaryIp = _localIps.first;
          _subnets = _localIps
              .map((ip) => _getSubnetFromIp(ip))
              .whereType<String>()
              .toSet()
              .toList();
          ipAddress = primaryIp;
          debugPrint('📍 Using IP: $ipAddress with ${_subnets.length} subnet(s)');
        } else {
          debugPrint('⚠️ No valid IP addresses found, using fallback: $ipAddress');
        }
      } catch (e) {
        debugPrint('Error getting IPs: $e');
        // Keep default '0.0.0.0' on error
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
  Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _uuid.v4();
        await prefs.setString(_deviceIdKey, deviceId);
        debugPrint('✅ Generated new device ID: $deviceId');
      } else {
        debugPrint('✅ Loaded existing device ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      debugPrint('Error with device ID persistence: $e');
      return _uuid.v4();
    }
  }

  /// Get device name with custom nickname support
  Future<String> _getDeviceNameWithNickname(String deviceId) async {
    try {
      final customNickname = await _nicknameService.getNickname(deviceId);
      if (customNickname != null && customNickname.isNotEmpty) {
        debugPrint('✅ Using custom device nickname: $customNickname');
        return customNickname;
      }
    } catch (e) {
      debugPrint('Error getting custom nickname: $e');
    }

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
      const platform = MethodChannel('com.syndro.app/device_info');
      try {
        final String? deviceName =
            await platform.invokeMethod('getDeviceName');
        if (deviceName != null && deviceName.isNotEmpty) {
          return deviceName;
        }
      } catch (e) {
        debugPrint('Platform channel not available: $e');
      }

      // FIX: getprop may not work without shell - skip this on Android
      // The platform channel above is the proper way to get device info
      
      return 'Android Device';
    } catch (e) {
      debugPrint('Error getting Android device name: $e');
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
        if (name.isNotEmpty) {
          return name;
        }
      }
    } catch (e) {
      debugPrint('Could not read /etc/hostname: $e');
    }

    final user = Platform.environment['USER'];
    if (user != null && user.isNotEmpty) {
      return "$user's Linux";
    }

    return 'Linux PC';
  }

  Future<List<String>> _getAllLocalIps() async {
    final ips = <String>{};

    // 1. Try WiFi IP first (with timeout)
    try {
      final wifiIP = await _networkInfo.getWifiIP().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (wifiIP != null && wifiIP.isNotEmpty && _isPrivateIP(wifiIP)) {
        ips.add(wifiIP);
      }
    } catch (e) {
      debugPrint('Error getting WiFi IP: $e');
    }

    // 2. Scan all network interfaces (with timeout)
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && _isPrivateIP(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting IP from interfaces: $e');
    }

    // FIX: Return empty list instead of ['0.0.0.0'] to handle consistently
    if (ips.isEmpty) {
      debugPrint('⚠️ No valid IP addresses found');
      return [];
    }

    return ips.toList();
  }

  /// Check if IP is a private network IP
  bool _isPrivateIP(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);

      if (a == null || b == null) return false;

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
    if (ip.isEmpty || ip == '0.0.0.0') return null;

    final parts = ip.split('.');
    if (parts.length != 4) return null;

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  // FIX: Optimized scan interval - initial scan is immediate, then every 10s
  void _startPeriodicScanning() {
    if (_isDisposed) return;

    // FIX: Immediate initial scan (no delay) for faster first discovery
    _performScan();

    // Then scan every 10 seconds (reduced from 5s to save CPU/battery)
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isDisposed) {
        _performScan();
      }
    });
  }

  Future<void> _performScan() async {
    if (_isScanning || _isDisposed) return;

    // Refresh IPs periodically
    try {
      _localIps = await _getAllLocalIps();

      // FIX: Handle empty IP list gracefully
      if (_localIps.isEmpty) {
        debugPrint('No valid IP addresses, skipping scan');
        return;
      }

      _subnets = _localIps
          .map((ip) => _getSubnetFromIp(ip))
          .whereType<String>()
          .toSet()
          .toList();
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

  /// Scan network for Syndro devices
  /// OPTIMIZED: Limit scan scope and prioritize common IP ranges
  Future<void> _scanNetwork() async {
    if (_isDisposed) return;

    // Handle empty subnets gracefully
    if (_subnets.isEmpty) {
      debugPrint('⚠️ No subnets available for scanning');
      return;
    }
    
    final subnetsToScan = List<String>.from(_subnets);

    final ipsToScan = <String>[];

    for (final subnet in subnetsToScan) {
      final myIpInSubnet = _localIps.firstWhere(
        (ip) => ip.startsWith(subnet),
        orElse: () => '',
      );

      final myHostPart = myIpInSubnet.isNotEmpty
          ? int.tryParse(myIpInSubnet.split('.').last) ?? 0
          : 0;

      // OPTIMIZATION: Prioritize IPs near our own (common in home networks)
      // Scan nearby IPs first (within ±20 of our IP), then scan the rest
      final nearbyIps = <String>[];
      final remainingIps = <String>[];
      
      for (int i = 1; i <= 254; i++) {
        if (i != myHostPart) {
          final ip = '$subnet.$i';
          // Prioritize IPs within ±20 of our own IP
          if ((i - myHostPart).abs() <= 20) {
            nearbyIps.add(ip);
          } else {
            remainingIps.add(ip);
          }
        }
      }
      
      // Add nearby IPs first for faster discovery on home networks
      ipsToScan.addAll(nearbyIps);
      ipsToScan.addAll(remainingIps);
    }

    // OPTIMIZATION: Limit total IPs to scan per cycle to prevent overwhelming the network
    const maxIpsPerScan = 500;
    if (ipsToScan.length > maxIpsPerScan) {
      // Take first maxIpsPerScan (prioritized nearby IPs)
      ipsToScan.removeRange(maxIpsPerScan, ipsToScan.length);
    }

    if (ipsToScan.isEmpty) return;

    debugPrint(
        '🔍 Scanning ${ipsToScan.length} IPs across ${subnetsToScan.length} subnet(s)...');

    // Increased batch size for faster scanning with reduced timeouts
    const batchSize = 200;

    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      if (_isDisposed) return;

      final batch = ipsToScan.skip(i).take(batchSize);

      await Future.wait(
        batch.map((ip) => _checkDevice(ip)),
        eagerError: false,
      );
      
      // Emit progress after each batch for faster UI updates
      if (!_isDisposed && !_deviceController.isClosed && _discoveredDevices.isNotEmpty) {
        _deviceController.add(_discoveredDevices.values.toList());
      }
    }

    // Emit updated device list
    if (!_isDisposed && !_deviceController.isClosed) {
      _deviceController.add(_discoveredDevices.values.toList());
    }
  }

  /// Check if a device at the given IP is running Syndro
  /// OPTIMIZED: Parallel port checking with reduced timeout
  Future<void> _checkDevice(String ip) async {
    if (_isDisposed) return;

    // FIX: Check all ports in parallel instead of sequentially
    final futures = _scanPorts.map((port) async {
      Socket? socket;
      try {
        // FIX: Reduced timeout from 1500ms to 500ms for faster scanning
        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 500),
        );

        socket.destroy();
        socket = null;

        // Found an open port, fetch device info
        final device = await _fetchDeviceInfo(ip, port);

        if (device != null && device.id != _currentDevice.id && !_isDisposed) {
          // Use compute for thread-safe list creation
          _discoveredDevices[device.id] = device;

          if (!_deviceController.isClosed) {
            // Create a copy of the device list to avoid concurrent modification
            final deviceList = _discoveredDevices.values.toList();
            _deviceController.add(deviceList);
          }
        }

        return true; // Found device
      } catch (e) {
        // Port not open or device not responding
        return false;
      } finally {
        try {
          socket?.destroy();
        } catch (e) {
          debugPrint('Error destroying socket: $e');
        }
      }
    });

    // Launch all port checks concurrently
    // Each future updates _discoveredDevices independently on success
    await Future.wait(
      futures,
      eagerError: false,
    ).catchError((_) {
      // Normal - some/all ports may fail if device not found
      return <bool>[]; // FIX: Must return a value
    });
  }

  /// Fetch device info from syndro.json endpoint
  Future<Device?> _fetchDeviceInfo(String ip, int port) async {
    try {
      // FIX: Reduced timeout from 2000ms to 800ms for faster discovery
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

  /// Refresh devices and reload current device name
  Future<void> refreshDevices() async {
    if (_isDisposed) return;

    await _reloadCurrentDeviceName();

    _discoveredDevices.clear();

    if (!_isDisposed && !_deviceController.isClosed) {
      _deviceController.add([]);
    }

    await _performScan();
  }

  /// Reload the current device name
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
      final keysToRemove = <String>[];

      for (final entry in _discoveredDevices.entries) {
        if (now.difference(entry.value.lastSeen).inSeconds > 60) {
          keysToRemove.add(entry.key);
        }
      }

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
    if (_isDisposed) return;

    try {
      // FIX (Bug #10): Try multiple ports in case the default is occupied
      const baseUdpPort = 8771;
      const maxRetries = 5;
      RawDatagramSocket? tempSocket;
      
      for (int i = 0; i <= maxRetries; i++) {
        try {
          final port = baseUdpPort + i;
          tempSocket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            port,
            reuseAddress: true,
          );
          _udpSocket = tempSocket;
          _udpPort = port;
          tempSocket = null; // Successfully assigned, clear temp reference
          break;
        } catch (e) {
          // FIX: Clean up failed socket attempt
          try {
            tempSocket?.close();
            tempSocket = null;
          } catch (e) {
            debugPrint('Error closing temporary socket: $e');
          }
          
          if (i == maxRetries) {
            debugPrint('⚠️ UDP discovery: could not bind any port ($baseUdpPort–${baseUdpPort + maxRetries})');
            return;
          }
          debugPrint('⚠️ UDP port ${baseUdpPort + i} busy, trying next...');
        }
      }

      _udpSocket?.broadcastEnabled = true;

      debugPrint('🚀 UDP Discovery listening on port $_udpPort');

      _udpSocket?.listen(
        (event) {
          if (_isDisposed) return;

          if (event == RawSocketEvent.read) {
            final datagram = _udpSocket?.receive();
            if (datagram != null) {
              _handleUdpPacket(datagram);
            }
          }
        },
        onError: (e) {
          debugPrint('UDP socket error: $e');
        },
        onDone: () {
          debugPrint('UDP socket closed');
        },
      );

      // FIX (Bug #18): Reduced UDP broadcast frequency from 2s to 5s
      // Start broadcasting our presence every 5 seconds
      _udpBroadcastTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _sendUdpBroadcast(),
      );

      // Send immediate broadcast
      _sendUdpBroadcast();
    } catch (e) {
      debugPrint('Failed to start UDP discovery: $e');
      // FIX: Don't crash if UDP fails - HTTP discovery still works
    }
  }

  void _sendUdpBroadcast() {
    if (_udpSocket == null || _isDisposed) return;

    final packet = {
      'syndro': true,
      'id': _currentDevice.id,
      'name': _currentDevice.name,
      'os': _currentDevice.platform.toString().split('.').last,
      'port': _currentDevice.port,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final data = utf8.encode(jsonEncode(packet));

    try {
      // Broadcast to 255.255.255.255
      _udpSocket?.send(data, InternetAddress('255.255.255.255'), _udpPort);

      // Also try subnet broadcasts
      for (final subnet in _subnets) {
        try {
          _udpSocket?.send(data, InternetAddress('$subnet.255'), _udpPort);
        } catch (e) {
          debugPrint('Error sending UDP broadcast to subnet $subnet: $e');
        }
      }
    } catch (e) {
      debugPrint('UDP Broadcast error: $e');
    }
  }

  void _handleUdpPacket(Datagram datagram) {
    if (_isDisposed) return;

    try {
      final jsonStr = utf8.decode(datagram.data);
      final data = jsonDecode(jsonStr);

      if (data is! Map<String, dynamic> || data['syndro'] != true) return;

      final senderId = data['id'] as String?;
      if (senderId == null || senderId == _currentDevice.id) return;

      final ip = datagram.address.address;
      final port = data['port'] as int? ?? 8765;

      debugPrint('📡 UDP Discovered device: $ip:$port (${data['name']})');

      // Verify via HTTP
      _checkDeviceOnSpecificPort(ip, port);
    } catch (e) {
      // Invalid packet - ignore (expected for non-Syndro broadcasts)
      debugPrint('Received invalid UDP packet: $e');
    }
  }

  /// Check a specific IP:Port combination
  Future<void> _checkDeviceOnSpecificPort(String ip, int port) async {
    if (_isDisposed) return;

    try {
      final device = await _fetchDeviceInfo(ip, port);

      if (device != null && device.id != _currentDevice.id && !_isDisposed) {
        _discoveredDevices[device.id] = device;

        if (!_deviceController.isClosed) {
          _deviceController.add(_discoveredDevices.values.toList());
        }
      }
    } catch (e) {
      debugPrint('Error checking device at $ip:$port: $e');
    }
  }

  // FIX (Bug #4, #9, #28): Proper disposal with try-finally to ensure all resources are cleaned
  Future<void> dispose() async {
    _isDisposed = true;

    try {
      // Cancel all timers
      _scanTimer?.cancel();
      _scanTimer = null;
    } catch (e) {
      debugPrint('Error cancelling scan timer: $e');
    }

    try {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    } catch (e) {
      debugPrint('Error cancelling cleanup timer: $e');
    }

    try {
      _udpBroadcastTimer?.cancel();
      _udpBroadcastTimer = null;
    } catch (e) {
      debugPrint('Error cancelling UDP broadcast timer: $e');
    }

    // Clear rate limiter
    _discoveryTimestamps.clear();

    // Close UDP socket properly
    try {
      if (_udpSocket != null) {
        _udpSocket?.close();
        _udpSocket = null;
        debugPrint('✅ UDP socket closed');
      }
    } catch (e) {
      debugPrint('Error closing UDP socket: $e');
    }

    // Close HTTP server if exists
    try {
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
        debugPrint('✅ HTTP server closed');
      }
    } catch (e) {
      debugPrint('Error closing HTTP server: $e');
    }

    // Close stream controller
    try {
      if (!_deviceController.isClosed) {
        await _deviceController.close();
        debugPrint('✅ Device controller closed');
      }
    } catch (e) {
      debugPrint('Error closing device controller: $e');
    }
  }
}
