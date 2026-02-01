import 'package:equatable/equatable.dart';

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

  String get icon {
    switch (this) {
      case DevicePlatform.android:
        return '📱';
      case DevicePlatform.windows:
        return '💻';
      case DevicePlatform.linux:
        return '🐧';
      case DevicePlatform.unknown:
        return '📡';
    }
  }
}

/// Represents a device in the network
/// 
/// [trusted] - Whether this device is trusted by the user
/// [trustedAt] - When the device was marked as trusted (null if not trusted)
class Device extends Equatable {
  final String id;
  final String name;
  final DevicePlatform platform;
  final String ipAddress;
  final int port;
  final bool isOnline;
  final DateTime lastSeen;
  final bool trusted;
  final DateTime? trustedAt;

  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.port,
    this.isOnline = true,
    required this.lastSeen,
    this.trusted = false,
    this.trustedAt,
  });

  /// Factory for creating empty/placeholder device
  factory Device.empty() {
    return Device(
      id: 'empty',
      name: 'No Device',
      platform: DevicePlatform.unknown,
      ipAddress: '0.0.0.0',
      port: 8765,
      lastSeen: DateTime.now(),
      trusted: false,
    );
  }

  Device copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
    bool? trusted,
    DateTime? trustedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      trusted: trusted ?? this.trusted,
      trustedAt: trustedAt ?? this.trustedAt,
    );
  }

  /// Mark this device as trusted
  Device markTrusted() {
    return copyWith(
      trusted: true,
      trustedAt: DateTime.now(),
    );
  }

  /// Mark this device as untrusted
  Device markUntrusted() {
    return copyWith(
      trusted: false,
      trustedAt: null,
    );
  }

  /// Update device info while preserving trust status
  Device updateInfo({
    String? name,
    String? ipAddress,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return copyWith(
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
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
      'trusted': trusted,
      'trustedAt': trustedAt?.toIso8601String(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => DevicePlatform.unknown,
      ),
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      isOnline: json['isOnline'] as bool? ?? true,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      trusted: json['trusted'] as bool? ?? false,
      trustedAt: json['trustedAt'] != null
          ? DateTime.parse(json['trustedAt'] as String)
          : null,
    );
  }

  /// Convert to database map (for SQLite storage)
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'platform': platform.name,
      'ip_address': ipAddress,
      'port': port,
      'is_online': isOnline ? 1 : 0,
      'last_seen': lastSeen.millisecondsSinceEpoch,
      'trusted': trusted ? 1 : 0,
      'trusted_at': trustedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create from database map
  factory Device.fromDbMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name == map['platform'],
        orElse: () => DevicePlatform.unknown,
      ),
      ipAddress: map['ip_address'] as String,
      port: map['port'] as int,
      isOnline: (map['is_online'] as int) == 1,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
      trusted: (map['trusted'] as int) == 1,
      trustedAt: map['trusted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['trusted_at'] as int)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        platform,
        ipAddress,
        port,
        isOnline,
        lastSeen,
        trusted,
        trustedAt,
      ];
}
