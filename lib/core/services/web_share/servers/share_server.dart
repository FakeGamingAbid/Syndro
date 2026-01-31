import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../utils/network_utils.dart';
import '../utils/file_type_utils.dart';
import '../templates/share_page_template.dart';

/// HTTP server for sharing files (download mode)
class ShareServer {
  HttpServer? _server;
  List<File>? _sharedFiles;
  String? _shareUrl;
  Timer? _expirationTimer;

  static const int _defaultPort = 8766;
  static const Duration _shareExpiration = Duration(hours: 1);

  /// Get current share URL
  String? get shareUrl => _shareUrl;

  /// Check if currently sharing
  bool get isSharing => _server != null;

  /// Start sharing files via HTTP server
  Future<String?> startSharing(List<File> files) async {
    if (files.isEmpty) return null;

    await stop();
    _sharedFiles = files;

    try {
      int port = _defaultPort;

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

      print('Web share server running at $_shareUrl');

      _serve();

      // Auto-expire after duration
      _expirationTimer = Timer(_shareExpiration, () {
        print('Share expired, stopping server');
        stop();
      });

      return _shareUrl;
    } catch (e) {
      print('Error starting web share: $e');
      return null;
    }
  }

  /// Stop sharing and close server
  Future<void> stop() async {
    _expirationTimer?.cancel();
    _expirationTimer = null;

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _sharedFiles = null;
    _shareUrl = null;
  }

  /// Serve HTTP requests
  void _serve() async {
    if (_server == null) return;

    await for (final request in _server!) {
      try {
        await _handleRequest(request);
      } catch (e) {
        print('Error handling request: $e');
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
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    // Route requests
    if (requestPath == '/' || requestPath == '/index.html') {
      await _serveIndexPage(request);
    } else if (requestPath == '/api/files') {
      await _serveFileList(request);
    } else if (requestPath.startsWith('/thumbnail/')) {
      await _serveThumbnail(request, requestPath);
    } else if (requestPath.startsWith('/download/')) {
      await _serveFile(request, requestPath);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found');
      await request.response.close();
    }
  }

  /// Serve the index HTML page
  Future<void> _serveIndexPage(HttpRequest request) async {
    final html = SharePageTemplate.generate();
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Serve the file list as JSON
  Future<void> _serveFileList(HttpRequest request) async {
    if (_sharedFiles == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('No files shared');
      await request.response.close();
      return;
    }

    final fileList = <Map<String, dynamic>>[];

    for (int i = 0; i < _sharedFiles!.length; i++) {
      final file = _sharedFiles![i];
      final fileName = path.basename(file.path);
      final stat = await file.stat();
      final fileType = FileTypeUtils.getFileType(fileName);
      final isImage = FileTypeUtils.isImage(fileName);

      fileList.add({
        'id': i,
        'name': fileName,
        'size': stat.size,
        'sizeFormatted': NetworkUtils.formatBytes(stat.size),
        'downloadUrl': '/download/$i/${Uri.encodeComponent(fileName)}',
        'type': fileType,
        'isImage': isImage,
        'thumbnailUrl': isImage ? '/thumbnail/$i' : null,
      });
    }

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'files': fileList,
      'totalFiles': fileList.length,
    }));
    await request.response.close();
  }

  /// Serve image thumbnail
  Future<void> _serveThumbnail(HttpRequest request, String requestPath) async {
    if (_sharedFiles == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final parts = requestPath.split('/');
    if (parts.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final fileIndex = int.tryParse(parts[2]);
    if (fileIndex == null || fileIndex < 0 || fileIndex >= _sharedFiles!.length) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = _sharedFiles![fileIndex];
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fileName = path.basename(file.path);
    final ext = fileName.split('.').last.toLowerCase();

    if (!FileTypeUtils.imageExtensions.contains(ext)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final contentType = FileTypeUtils.getImageContentType(ext);

    request.response.headers.contentType = contentType;
    request.response.headers.add('Cache-Control', 'public, max-age=3600');

    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  /// Serve file download
  Future<void> _serveFile(HttpRequest request, String requestPath) async {
    if (_sharedFiles == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final parts = requestPath.split('/');
    if (parts.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final fileIndex = int.tryParse(parts[2]);
    if (fileIndex == null || fileIndex < 0 || fileIndex >= _sharedFiles!.length) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = _sharedFiles![fileIndex];
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fileName = path.basename(file.path);
    final stat = await file.stat();

    request.response.headers.contentType = ContentType.binary;
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="${Uri.encodeComponent(fileName)}"',
    );
    request.response.headers.contentLength = stat.size;

    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}
