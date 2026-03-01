import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum DevicePlatform {
  android,
  windows,
  linux,
  unknown;

  String get displayName {
    switch (this) {
      case DevicePlatform.android:
        return 'Android';
      case DevicePlatform.windows:
        return 'Windows';
      case DevicePlatform.linux:
        return 'Linux';
      case DevicePlatform.unknown:
        return 'Unknown';
    }
  }

  /// Get the icon for the platform
  IconData get icon {
    switch (this) {
      case DevicePlatform.android:
        return Icons.android;
      case DevicePlatform.windows:
        return Icons.desktop_windows;
      case DevicePlatform.linux:
        return Icons.computer;
      case DevicePlatform.unknown:
        return Icons.devices_other;
    }
  }

  /// Get the color for the platform icon
  Color get iconColor {
    switch (this) {
      case DevicePlatform.android:
        return const Color(0xFF3DDC84); // Android green
      case DevicePlatform.windows:
        return const Color(0xFF00A4EF); // Windows blue
      case DevicePlatform.linux:
        return const Color(0xFFFCC624); // Linux yellow/orange
      case DevicePlatform.unknown:
        return const Color(0xFF94A3B8); // Gray
    }
  }
}

class Device extends Equatable {
  final String id;
  final String name;
  final DevicePlatform platform;
  final String ipAddress;
  final int port;
  final bool isOnline;
  final DateTime lastSeen;

  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.port,
    this.isOnline = true,
    required this.lastSeen,
  });

  factory Device.empty() {
    return Device(
      id: 'empty',
      name: 'No Device',
      platform: DevicePlatform.unknown,
      ipAddress: '0.0.0.0',
      port: 8765,
      lastSeen: DateTime.now(),
    );
  }

  // FIX: Validate IP address format
  static bool isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    // Allow 0.0.0.0 as a special case for "any"
    if (ip == '0.0.0.0') return true;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  // FIX: Validate port number
  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  // FIX: Validate device name (no control characters, reasonable length)
  static bool isValidName(String name) {
    if (name.isEmpty || name.length > 100) return false;

    // Check for control characters
    for (int i = 0; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (char < 32 && char != 9 && char != 10 && char != 13) {
        return false;
      }
    }

    return true;
  }

  // FIX: Add validation to copyWith
  Device copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    final newIp = ipAddress ?? this.ipAddress;
    final newPort = port ?? this.port;
    final newName = name ?? this.name;

    // FIX: Validate new values
    if (!isValidIpAddress(newIp)) {
      throw ArgumentError('Invalid IP address: $newIp');
    }

    if (!isValidPort(newPort)) {
      throw ArgumentError('Invalid port: $newPort');
    }

    if (!isValidName(newName)) {
      throw ArgumentError('Invalid device name: $newName');
    }

    return Device(
      id: id ?? this.id,
      name: newName,
      platform: platform ?? this.platform,
      ipAddress: newIp,
      port: newPort,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform.name,
      'ipAddress': ipAddress,
      'port': port,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  // FIX: Add validation to fromJson with error handling
  factory Device.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? 'Unknown Device';
    final ipAddress = json['ipAddress'] as String? ?? '0.0.0.0';
    final port = json['port'] as int? ?? 8765;

    // FIX: Validate values from JSON
    if (id.isEmpty) {
      throw const FormatException('Device ID cannot be empty');
    }

    if (!isValidIpAddress(ipAddress)) {
      throw FormatException('Invalid IP address in JSON: $ipAddress');
    }

    if (!isValidPort(port)) {
      throw FormatException('Invalid port in JSON: $port');
    }

    // FIX: Sanitize name to prevent issues
    final sanitizedName = _sanitizeName(name);

    return Device(
      id: id,
      name: sanitizedName,
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => DevicePlatform.unknown,
      ),
      ipAddress: ipAddress,
      port: port,
      isOnline: json['isOnline'] as bool? ?? true,
      lastSeen: _parseDateTime(json['lastSeen']),
    );
  }

  // FIX: Safe datetime parsing
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  // FIX: Sanitize device name
  static String _sanitizeName(String name) {
    if (name.isEmpty) return 'Unknown Device';

    // Remove control characters
    final sanitized = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Limit length
    if (sanitized.length > 100) {
      return sanitized.substring(0, 100);
    }

    return sanitized.isEmpty ? 'Unknown Device' : sanitized;
  }

  /// Check if this device is on a private network
  bool get isOnPrivateNetwork {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);

      if (a == null || b == null) return false;

      // 10.x.x.x
      if (a == 10) return true;

      // 172.16.x.x - 172.31.x.x
      if (a == 172 && b >= 16 && b <= 31) return true;

      // 192.168.x.x
      if (a == 192 && b == 168) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  List<Object?> get props =>
      [id, name, platform, ipAddress, port, isOnline, lastSeen];
}
