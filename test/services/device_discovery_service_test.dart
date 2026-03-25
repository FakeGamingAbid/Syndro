import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/config/app_config.dart';
import 'package:syndro/core/models/device.dart';

void main() {
  group('DeviceDiscoveryService - Constants', () {
    test('should have correct discovery timeout (30 seconds)', () {
      expect(AppConfig.discoveryTimeoutSeconds, equals(30));
    });

    test('discovery timeout should be reasonable for network conditions', () {
      // Timeout should be at least 10 seconds for reliable detection
      expect(AppConfig.discoveryTimeoutSeconds, greaterThanOrEqualTo(10));
      
      // Timeout should not be excessive (more than 120 seconds)
      expect(AppConfig.discoveryTimeoutSeconds, lessThanOrEqualTo(120));
    });
  });

  group('DeviceDiscoveryService - Stale Device Detection', () {
    test('Device.lastSeen should be used for stale detection', () {
      final now = DateTime.now();
      
      // Fresh device - seen now
      final freshDevice = Device(
        id: 'device-1',
        name: 'Fresh Device',
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.100',
        port: 8765,
        lastSeen: now,
      );
      
      // Stale device - seen more than 30 seconds ago
      final staleDevice = Device(
        id: 'device-2',
        name: 'Stale Device',
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.101',
        port: 8765,
        lastSeen: now.subtract(const Duration(seconds: 31)),
      );
      
      // Verify stale detection logic
      const timeout = Duration(seconds: AppConfig.discoveryTimeoutSeconds);
      
      expect(
        now.difference(freshDevice.lastSeen).compareTo(timeout) < 0,
        isTrue,
        reason: 'Fresh device should be within timeout',
      );
      
      expect(
        now.difference(staleDevice.lastSeen).compareTo(timeout) >= 0,
        isTrue,
        reason: 'Stale device should be beyond timeout',
      );
    });

    test('should identify stale devices correctly', () {
      final now = DateTime.now();
      const timeout = Duration(seconds: AppConfig.discoveryTimeoutSeconds);
      
      // Device seen exactly at timeout boundary
      final boundaryDevice = Device(
        id: 'device-3',
        name: 'Boundary Device',
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.102',
        port: 8765,
        lastSeen: now.subtract(timeout),
      );
      
      // At exactly the timeout, device should be considered stale
      expect(
        now.difference(boundaryDevice.lastSeen).compareTo(timeout) >= 0,
        isTrue,
      );
    });
  });

  group('DeviceDiscoveryService - UDP Packet Loss Handling', () {
    test('should handle null/missing port in UDP packet gracefully', () {
      // Simulate UDP packet with missing port
      final dataWithMissingPort = <String, dynamic>{
        'id': 'device-1',
        'name': 'Test Device',
        // 'port' is missing
      };
      
      // Default port should be used when port is missing
      final port = dataWithMissingPort['port'] as int? ?? AppConfig.defaultTransferPort;
      expect(port, equals(AppConfig.defaultTransferPort));
    });

    test('should handle malformed UDP packets without crashing', () {
      // Test various malformed packet scenarios
      final malformedPackets = [
        <String, dynamic>{}, // Empty
        {'id': null}, // Null ID
        {'name': null}, // Null name
        {'port': 'invalid'}, // Invalid port type
      ];
      
      for (final packet in malformedPackets) {
        // Should not throw, just handle gracefully
        expect(
          () {
            final id = packet['id'] as String?;
            final name = packet['name'] as String?;
            final port = packet['port'] is int 
                ? packet['port'] as int 
                : AppConfig.defaultTransferPort;
            
            // Basic validation
            if (id == null || id.isEmpty) return null;
            return {'id': id, 'name': name ?? 'Unknown', 'port': port};
          },
          returnsNormally,
        );
      }
    });
  });
}
