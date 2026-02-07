import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/received_file.dart';
import '../models/pending_files_manager.dart';
import '../utils/network_utils.dart';
// REMOVED: import '../utils/platform_paths.dart'; (unused)
import '../utils/multipart_parser.dart';
import '../templates/receive_page_template.dart';

/// HTTP server for receiving files (upload mode)
/// Files are stored in temp location until user decides to save/discard
class ReceiveServer {
  HttpServer? _server;
  String? _shareUrl;
  String? _tempDirectory;
  String? _finalDirectory;
  Timer? _expirationTimer;

  // Pending files manager
  final PendingFilesManager _pendingFilesManager = PendingFilesManager();

  // Stream controller for received files (for backward compatibility)
  final StreamController<ReceivedFile> _receivedFilesController =
      StreamController<ReceivedFile>.broadcast();

  static const int _receivePort = 8767;
  static const Duration _shareExpiration = Duration(hours: 1);

  /// Stream of received files
  Stream<ReceivedFile> get receivedFilesStream => _receivedFilesController.stream;

  /// Get pending files manager for save/discard operations
  PendingFilesManager get pendingFilesManager => _pendingFilesManager;

  /// Stream of pending files list updates
  Stream<List<ReceivedFile>> get pendingFilesStream =>
      _pendingFilesManager.filesStream;

  /// Get current share URL
  String? get shareUrl => _shareUrl;

  /// Check if currently receiving
  bool get isReceiving => _server != null;

  /// Get final directory path
  String? get finalDirectory => _finalDirectory;

  /// Start receiving files via HTTP server
  Future<String?> startReceiving(String downloadDirectory) async {
    await stop();

    _finalDirectory = downloadDirectory;

    // Create temp directory for pending files
    _tempDirectory = await _createTempDirectory();
    if (_tempDirectory == null) {
      print('❌ Failed to create temp directory');
      return null;
    }

    // Initialize pending files manager
    await _pendingFilesManager.initialize(
      tempDirectory: _tempDirectory!,
      finalDirectory: _finalDirectory!,
    );

    print('📁 Temp directory: $_tempDirectory');
    print('📁 Final directory: $_finalDirectory');

    try {
      int port = _receivePort;

      // Try to bind to a port, incrementing if busy
      for (int attempt = 0; attempt < 10; attempt++) {
        try {
          _server = await HttpServer.bind(
            InternetAddress.anyIPv4,
            port,
            shared: true,
          );
          break;
        } catch (e) {
          port++;
          if (attempt == 9) {
            print('Failed to bind to any port');
            return null;
          }
        }
      }

      if (_server == null) return null;

      final localIp = await NetworkUtils.getLocalIp();
      _shareUrl = 'http://$localIp:${_server!.port}';

      print('Web receive server running at $_shareUrl');

      _serve();

      // Auto-expire after duration
      _expirationTimer = Timer(_shareExpiration, () {
        print('Receive session expired');
        stop();
      });

      return _shareUrl;
    } catch (e) {
      print('Error starting receive server: $e');
      return null;
    }
  }

  /// Create temp directory for pending files
  Future<String?> _createTempDirectory() async {
    try {
      String baseTempPath;

      if (Platform.isAndroid) {
        // Use app's cache directory on Android
        baseTempPath = '/data/data/com.example.syndro/cache/pending_files';
        // Fallback to external cache
        const externalCache = '/storage/emulated/0/Android/data/com.example.syndro/cache/pending_files';
        final externalDir = Directory(externalCache);
        if (await externalDir.parent.exists()) {
          baseTempPath = externalCache;
        }
      } else if (Platform.isWindows) {
        final temp = Platform.environment['TEMP'] ?? 'C:\\Temp';
        baseTempPath = '$temp\\Syndro\\pending_files';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '/tmp';
        baseTempPath = '$home/.cache/syndro/pending_files';
      } else {
        baseTempPath = '/tmp/syndro/pending_files';
      }

      // Add timestamp to make unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '$baseTempPath/$timestamp';

      final dir = Directory(tempPath);
      await dir.create(recursive: true);

      return tempPath;
    } catch (e) {
      print('Error creating temp directory: $e');

      // Fallback to system temp
      try {
        final systemTemp = Directory.systemTemp;
        final fallbackPath =
            '${systemTemp.path}/syndro_pending_${DateTime.now().millisecondsSinceEpoch}';
        final dir = Directory(fallbackPath);
        await dir.create(recursive: true);
        return fallbackPath;
      } catch (e2) {
        print('Error creating fallback temp directory: $e2');
        return null;
      }
    }
  }

  /// Stop receiving and close server
  Future<void> stop() async {
    _expirationTimer?.cancel();
    _expirationTimer = null;

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _shareUrl = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _pendingFilesManager.dispose();
    await _receivedFilesController.close();

    // Clean up temp directory
    if (_tempDirectory != null) {
      try {
        final dir = Directory(_tempDirectory!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        print('Error cleaning up temp directory: $e');
      }
    }
  }

  /// Serve HTTP requests
  void _serve() async {
    if (_server == null) return;

    await for (final request in _server!) {
      try {
        await _handleRequest(request);
      } catch (e) {
        print('Error handling receive request: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  /// Handle HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    final uri = request.requestedUri;
    final requestPath = uri.path;

    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Route requests
    if (requestPath == '/' || requestPath == '/index.html') {
      await _serveIndexPage(request);
    } else if (request.method == 'POST' && requestPath == '/upload') {
      await _handleFileUpload(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  /// Serve the index HTML page
  Future<void> _serveIndexPage(HttpRequest request) async {
    final html = ReceivePageTemplate.generate();

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Handle file upload - saves to TEMP location (not final)
  Future<void> _handleFileUpload(HttpRequest request) async {
    if (_tempDirectory == null) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Server not properly initialized');
      await request.response.close();
      return;
    }

    print('📥 Receiving files to temp: $_tempDirectory');

    try {
      final contentType = request.headers.contentType;

      if (contentType == null ||
          !contentType.mimeType.contains('multipart/form-data')) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Invalid content type');
        await request.response.close();
        return;
      }

      final boundary = contentType.parameters['boundary'];
      if (boundary == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('No boundary found');
        await request.response.close();
        return;
      }

      // Read all bytes
      final bytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      print('📦 Received ${bytes.length} bytes');

      // Parse multipart data
      final parts = MultipartParser.parse(bytes, boundary);
      final uploadedFiles = <Map<String, dynamic>>[];

      for (final part in parts) {
        if (part.filename != null &&
            part.filename!.isNotEmpty &&
            part.data.isNotEmpty) {
          // Clean filename (remove path traversal attempts)
          final cleanFilename = path.basename(part.filename!);

          // Generate unique temp filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final tempFilename = '${timestamp}_$cleanFilename';
          final tempFilePath = path.join(_tempDirectory!, tempFilename);

          print('💾 Saving to temp: $cleanFilename → $tempFilePath');

          try {
            final file = File(tempFilePath);

            // Write file to TEMP location
            await file.writeAsBytes(part.data, flush: true);

            // Verify file was written
            if (await file.exists()) {
              final stat = await file.stat();
              print(
                  '✅ File saved to temp: $cleanFilename (${stat.size} bytes)');

              uploadedFiles.add({
                'name': cleanFilename,
                'size': part.data.length,
                'tempPath': tempFilePath,
              });

              // Create ReceivedFile with PENDING status
              final receivedFile = ReceivedFile(
                name: cleanFilename,
                tempPath: tempFilePath,
                size: part.data.length,
                receivedAt: DateTime.now(),
                status: FileReceiveStatus.pending,
              );

              // Add to pending files manager
              _pendingFilesManager.addFile(receivedFile);

              // Also notify via stream (for backward compatibility)
              _receivedFilesController.add(receivedFile);
            } else {
              print('❌ File was not created: $tempFilePath');
            }
          } catch (e) {
            print('❌ Error saving file $cleanFilename: $e');
          }
        }
      }

      print('📊 Total files received: ${uploadedFiles.length}');

      // Send response
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'success',
        'files': uploadedFiles,
        'count': uploadedFiles.length,
        'message': 'Files received and pending review',
      }));
      await request.response.close();
    } catch (e) {
      print('❌ Error handling upload: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Upload failed: $e');
      await request.response.close();
    }
  }
}
