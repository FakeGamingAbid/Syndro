import 'dart:async';
import 'package:flutter/services.dart';

/// Represents a shared file from another app
class SharedFile {
  final String uri;
  final String? mimeType;
  final String? name;

  SharedFile({
    required this.uri,
    this.mimeType,
    this.name,
  });

  factory SharedFile.fromMap(Map<dynamic, dynamic> map) {
    return SharedFile(
      uri: map['uri'] as String,
      mimeType: map['mimeType'] as String?,
      name: map['name'] as String?,
    );
  }

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;
}

/// Service to handle share intents from other apps
class ShareIntentService {
  static const MethodChannel _channel =
      MethodChannel('com.syndro.app/share_intent');

  static final ShareIntentService _instance = ShareIntentService._internal();
  factory ShareIntentService() => _instance;
  ShareIntentService._internal();

  final StreamController<List<SharedFile>> _sharedFilesController =
      StreamController<List<SharedFile>>.broadcast();

  Stream<List<SharedFile>> get sharedFilesStream => _sharedFilesController.stream;

  List<SharedFile>? _lastSharedFiles;
  List<SharedFile>? get lastSharedFiles => _lastSharedFiles;

  bool get hasSharedFiles => _lastSharedFiles != null && _lastSharedFiles!.isNotEmpty;

  /// Initialize the share intent service
  Future<void> initialize() async {
    // Set up method call handler for share intent events
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareIntentReceived') {
        await _handleShareIntentReceived();
      }
    });

    // Check if app was launched with shared files
    await checkForSharedFiles();
  }

  /// Check if app was launched with shared files
  Future<List<SharedFile>?> checkForSharedFiles() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSharedFiles');
      if (result != null) {
        final files = result
            .map((item) => SharedFile.fromMap(item as Map<dynamic, dynamic>))
            .toList();
        _lastSharedFiles = files;
        if (files.isNotEmpty) {
          _sharedFilesController.add(files);
        }
        return files;
      }
    } on PlatformException catch (e) {
      print('Error checking for shared files: ${e.message}');
    }
    return null;
  }

  /// Handle incoming share intent
  Future<void> _handleShareIntentReceived() async {
    final files = await checkForSharedFiles();
    if (files != null && files.isNotEmpty) {
      _sharedFilesController.add(files);
    }
  }

  /// Clear the shared files after processing
  Future<void> clearSharedFiles() async {
    try {
      await _channel.invokeMethod('clearSharedFiles');
      _lastSharedFiles = null;
    } on PlatformException catch (e) {
      print('Error clearing shared files: ${e.message}');
    }
  }

  void dispose() {
    _sharedFilesController.close();
  }
}
