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

  // ✅ NEW: Factory for creating empty/placeholder device
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

  Device copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
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
    );
  }

  @override
  List<Object?> get props => [id, name, platform, ipAddress, port, isOnline, lastSeen];
}
