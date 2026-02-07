import 'dart:io';

/// Network utility functions for web sharing
class NetworkUtils {
  /// Get local IP address
  /// Prioritizes hotspot interface (192.168.43.x) when available
  static Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      String? hotspotIp;
      String? wifiIp;
      String? anyPrivateIp;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        
        for (final addr in interface.addresses) {
          if (addr.isLoopback) continue;
          
          final ip = addr.address;
          if (!isPrivateIP(ip)) continue;

          // Hotspot typically uses 192.168.43.x or 192.168.49.x
          if (ip.startsWith('192.168.43.') || ip.startsWith('192.168.49.')) {
            hotspotIp = ip;
          }
          // Check interface name for hotspot indicators
          else if (name.contains('ap') || name.contains('hotspot') || name.contains('wlan1')) {
            hotspotIp = ip;
          }
          // Regular WiFi
          else if (name.contains('wlan') || name.contains('wifi') || name.contains('en0')) {
            wifiIp = ip;
          }
          // Any other private IP as fallback
          else {
            anyPrivateIp ??= ip;
          }
        }
      }

      // Priority: hotspot > wifi > any private IP
      final selectedIp = hotspotIp ?? wifiIp ?? anyPrivateIp ?? '127.0.0.1';
      print('🌐 Network interfaces found:');
      print('   Hotspot IP: $hotspotIp');
      print('   WiFi IP: $wifiIp');
      print('   Selected: $selectedIp');
      
      return selectedIp;
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return '127.0.0.1';
  }

  /// Get all available local IPs (for debugging/display)
  static Future<List<String>> getAllLocalIps() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && isPrivateIP(addr.address)) {
            ips.add('${interface.name}: ${addr.address}');
          }
        }
      }
    } catch (e) {
      print('Error getting local IPs: $e');
    }
    return ips;
  }

  /// Check if IP is private
  static bool isPrivateIP(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);

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

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
