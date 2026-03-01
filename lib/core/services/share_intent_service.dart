import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a shared file from another app
class SharedFile {
  final String uri;
  final String? mimeType;
  final String? name;
  final int size;

  SharedFile({
    required this.uri,
    this.mimeType,
    this.name,
    this.size = 0,
  });

  factory SharedFile.fromMap(Map<dynamic, dynamic> map) {
    return SharedFile(
      uri: map['uri'] as String,
      mimeType: map['mimeType'] as String?,
      name: map['name'] as String?,
      size: map['size'] as int? ?? 0,
    );
  }

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;
}

/// Android share mode enum (for share sheet selection)
enum AndroidShareMode {
  appToApp,
  browserShare,
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

  final StreamController<AndroidShareMode> _shareModeController =
      StreamController<AndroidShareMode>.broadcast();

  Stream<List<SharedFile>> get sharedFilesStream => _sharedFilesController.stream;
  Stream<AndroidShareMode> get shareModeStream => _shareModeController.stream;

  List<SharedFile>? _lastSharedFiles;
  List<SharedFile>? get lastSharedFiles => _lastSharedFiles;

  AndroidShareMode _lastShareMode = AndroidShareMode.appToApp;
  AndroidShareMode get lastShareMode => _lastShareMode;

  bool get hasSharedFiles => _lastSharedFiles != null && _lastSharedFiles!.isNotEmpty;

  /// Initialize the share intent service
  Future<void> initialize() async {
    // Set up method call handler for share intent events
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareIntentReceived') {
        final mode = _parseShareMode(call.arguments);
        await _handleShareIntentReceived(mode);
      }
    });

    // Check if app was launched with shared files
    await checkForSharedFiles();
  }

  AndroidShareMode _parseShareMode(dynamic arguments) {
    if (arguments is Map && arguments['mode'] != null) {
      final mode = arguments['mode'] as String;
      return mode == 'browser_share' ? AndroidShareMode.browserShare : AndroidShareMode.appToApp;
    }
    return AndroidShareMode.appToApp;
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
      debugPrint('Error checking for shared files: ${e.message}');
    }
    return null;
  }

  /// Handle incoming share intent
  Future<void> _handleShareIntentReceived(AndroidShareMode mode) async {
    _lastShareMode = mode;
    _shareModeController.add(mode);
    
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
      debugPrint('Error clearing shared files: ${e.message}');
    }
  }

  /// Copy content URI to a file path (Android only)
  /// 
  /// On Android, shared files come as content:// URIs that need to be
  /// copied to actual files before they can be used by the transfer service.
  /// 
  /// Returns the path to the copied file, or null if the copy failed.
  Future<String?> copyContentUri({
    required String uri,
    required String tempDir,
    String? fileName,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('copyContentUri', {
        'uri': uri,
        'tempDir': tempDir,
        'fileName': fileName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error copying content URI: ${e.message}');
      return null;
    }
  }

  void dispose() {
    _sharedFilesController.close();
    _shareModeController.close();
  }
}
