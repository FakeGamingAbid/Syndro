import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage device nicknames with persistence
class DeviceNicknameService {
  static const String _nicknamePrefix = 'device_nickname_';
  
  /// Save nickname for a device
  Future<bool> saveNickname(String deviceId, String nickname) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_nicknamePrefix$deviceId';
      
      if (nickname.trim().isEmpty) {
        // If nickname is empty, remove it
        return await prefs.remove(key);
      }
      
      return await prefs.setString(key, nickname.trim());
    } catch (e) {
      debugPrint('Error saving nickname: $e');
      return false;
    }
  }
  
  /// Get nickname for a device
  Future<String?> getNickname(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_nicknamePrefix$deviceId';
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Error getting nickname: $e');
      return null;
    }
  }
  
  /// Delete nickname for a device
  Future<bool> deleteNickname(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_nicknamePrefix$deviceId';
      return await prefs.remove(key);
    } catch (e) {
      debugPrint('Error deleting nickname: $e');
      return false;
    }
  }
  
  /// Get all nicknames as a map {deviceId: nickname}
  Future<Map<String, String>> getAllNicknames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final nicknames = <String, String>{};
      
      for (final key in keys) {
        if (key.startsWith(_nicknamePrefix)) {
          final deviceId = key.substring(_nicknamePrefix.length);
          final nickname = prefs.getString(key);
          if (nickname != null) {
            nicknames[deviceId] = nickname;
          }
        }
      }
      
      return nicknames;
    } catch (e) {
      debugPrint('Error getting all nicknames: $e');
      return {};
    }
  }
  
  /// Clear all nicknames
  Future<bool> clearAllNicknames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_nicknamePrefix)) {
          await prefs.remove(key);
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error clearing nicknames: $e');
      return false;
    }
  }
}
