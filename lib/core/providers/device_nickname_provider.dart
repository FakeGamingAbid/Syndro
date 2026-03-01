import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/device_nickname_service.dart';
import '../../core/providers/device_provider.dart' show deviceNicknameServiceProvider;

/// State notifier for managing device nicknames
class DeviceNicknameNotifier extends StateNotifier<Map<String, String>> {
  final DeviceNicknameService _service;

  DeviceNicknameNotifier(this._service) : super({}) {
    _loadNicknames();
  }

  /// Load all nicknames on initialization
  Future<void> _loadNicknames() async {
    final nicknames = await _service.getAllNicknames();
    state = nicknames;
  }

  /// Save a nickname for a device
  Future<bool> setNickname(String deviceId, String nickname) async {
    final success = await _service.saveNickname(deviceId, nickname);
    
    if (success) {
      if (nickname.trim().isEmpty) {
        // Remove from state if nickname is empty
        final newState = Map<String, String>.from(state);
        newState.remove(deviceId);
        state = newState;
      } else {
        // Add/update in state
        state = {
          ...state,
          deviceId: nickname.trim(),
        };
      }
    }
    
    return success;
  }

  /// Get nickname for a device (from state)
  String? getNickname(String deviceId) {
    return state[deviceId];
  }

  /// Delete a nickname
  Future<bool> deleteNickname(String deviceId) async {
    final success = await _service.deleteNickname(deviceId);
    
    if (success) {
      final newState = Map<String, String>.from(state);
      newState.remove(deviceId);
      state = newState;
    }
    
    return success;
  }

  /// Clear all nicknames
  Future<bool> clearAll() async {
    final success = await _service.clearAllNicknames();
    
    if (success) {
      state = {};
    }
    
    return success;
  }
}

/// Provider for device nickname notifier
final deviceNicknameProvider =
    StateNotifierProvider<DeviceNicknameNotifier, Map<String, String>>((ref) {
  final service = ref.watch(deviceNicknameServiceProvider);
  return DeviceNicknameNotifier(service);
});
