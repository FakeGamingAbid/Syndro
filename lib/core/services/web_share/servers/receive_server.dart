import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../models/received_file.dart';
import '../utils/network_utils.dart';
import '../utils/platform_paths.dart';
import '../utils/multipart_parser.dart';
import '../templates/receive_page_template.dart';

/// HTTP server for receiving files (upload mode)
class ReceiveServer {
  HttpServer? _server;
  String? _shareUrl;
  String? _downloadDirectory;
  Timer? _expirationTimer;

  // Stream controller for received files
  final StreamController<ReceivedFile> _receivedFilesController =
      StreamController<ReceivedFile>.broadcast();

  static const int _receivePort = 8767;
  static const Duration _shareExpiration = Duration(hours: 1);

  /// Stream of received files
  Stream<ReceivedFile> get receivedFilesStream => _receivedFilesController.stream;

  /// Get current share URL
  String? get shareUrl => _shareUrl;

  /// Check if currently receiving
  bool get isReceiving => _server != null;

  /// Start receiving files via HTTP server
  Future<String?> startReceiving(String downloadDirectory) async {
    await stop();

    // Ensure download directory exists
    final dir = Directory(downloadDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _downloadDirectory = downloadDirectory;

    print('📁 Download directory set to: $_downloadDirectory');

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

  /// Stop receiving and close server
  Future<void> stop() async {
    _expirationTimer?.cancel();
    _expirationTimer = null;

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _shareUrl = null;
    _downloadDirectory = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _receivedFilesController.close();
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
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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

  /// Handle file upload
  Future<void> _handleFileUpload(HttpRequest request) async {
    // Get download directory - use fallback if not set
    String downloadDir = _downloadDirectory ?? 
        await PlatformPaths.getDefaultDownloadDirectory();

    print('📥 Receiving files to: $downloadDir');

    // Ensure directory exists
    final dir = Directory(downloadDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('📁 Created download directory: $downloadDir');
    }

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
          final filePath = path.join(downloadDir, cleanFilename);

          print('💾 Saving file: $cleanFilename to $filePath');

          try {
            final file = File(filePath);

            // Write file
            await file.writeAsBytes(part.data, flush: true);

            // Verify file was written
            if (await file.exists()) {
              final stat = await file.stat();
              print('✅ File saved successfully: $cleanFilename (${stat.size} bytes)');

              uploadedFiles.add({
                'name': cleanFilename,
                'size': part.data.length,
                'path': filePath,
              });

              // Notify listeners
              _receivedFilesController.add(ReceivedFile(
                name: cleanFilename,
                path: filePath,
                size: part.data.length,
                receivedAt: DateTime.now(),
              ));
            } else {
              print('❌ File was not created: $filePath');
            }
          } catch (e) {
            print('❌ Error saving file $cleanFilename: $e');
          }
        }
      }

      print('📊 Total files saved: ${uploadedFiles.length}');

      // Send response
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'success',
        'files': uploadedFiles,
        'count': uploadedFiles.length,
        'savedTo': downloadDir,
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
