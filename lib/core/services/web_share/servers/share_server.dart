import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../utils/network_utils.dart';
import '../utils/file_type_utils.dart';
import '../templates/share_page_template.dart';

/// Connection event types
enum ConnectionEventType {
  connected,
  downloadStarted,
  downloadCompleted,
}

/// Represents a connection event
class ConnectionEvent {
  final ConnectionEventType type;
  final String ipAddress;
  final String? fileName;
  final int? fileSize;
  final String? userAgent; // NEW: Added userAgent
  final DateTime timestamp;

  ConnectionEvent({
    required this.type,
    required this.ipAddress,
    this.fileName,
    this.fileSize,
    this.userAgent, // NEW
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayMessage {
    switch (type) {
      case ConnectionEventType.connected:
        return 'Someone connected from $ipAddress';
      case ConnectionEventType.downloadStarted:
        return '$ipAddress started downloading ${fileName ?? "a file"}';
      case ConnectionEventType.downloadCompleted:
        return '$ipAddress downloaded ${fileName ?? "a file"}';
    }
  }
}

/// Connected client info - NEW CLASS
class ConnectedClient {
  final String ipAddress;
  final String userAgent;
  final DateTime connectedAt;

  ConnectedClient({
    required this.ipAddress,
    required this.userAgent,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() => {
        'ip': ipAddress,
        'userAgent': userAgent,
        'connectedAt': connectedAt.toIso8601String(),
      };
}

/// HTTP server for sharing files (download mode)
class ShareServer {
  HttpServer? _server;
  List<File>? _sharedFiles;
  String? _shareUrl;
  Timer? _expirationTimer;
  Timer? _cleanupTimer; // FIX (Bug #31): Store cleanup timer reference

  static const int _defaultPort = 8766;
  static const Duration _shareExpiration = Duration(hours: 1);

  // Connection tracking
  final Set<String> _activeConnections = {};
  final Map<String, ConnectedClient> _connectedClients = {};
  static const int _maxConnectedClients = 500;
  final StreamController<ConnectionEvent> _connectionEventController =
      StreamController<ConnectionEvent>.broadcast();
  final StreamController<int> _activeConnectionCountController =
      StreamController<int>.broadcast();

  /// Stream of connection events (connect, download start/complete)
  Stream<ConnectionEvent> get connectionEventStream =>
      _connectionEventController.stream;

  /// Stream of active connection count changes
  Stream<int> get activeConnectionCountStream =>
      _activeConnectionCountController.stream;

  /// Current number of active connections
  int get activeConnectionCount => _activeConnections.length;

  /// Get list of connected clients - NEW
  List<ConnectedClient> get connectedClients => _connectedClients.values.toList();

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
            debugPrint('Failed to bind to any port');
            return null;
          }
        }
      }

      if (_server == null) return null;

      final localIp = await NetworkUtils.getLocalIp();
      _shareUrl = 'http://$localIp:${_server!.port}';

      debugPrint('Web share server running at $_shareUrl');

      _serve();

      // FIX (Bug #31): Store timer reference for proper cleanup
      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanupStaleClients());

      // Auto-expire after duration
      _expirationTimer = Timer(_shareExpiration, () {
        debugPrint('Share expired, stopping server');
        stop();
      });

      return _shareUrl;
    } catch (e) {
      debugPrint('Error starting web share: $e');
      return null;
    }
  }

  /// Stop sharing and close server
  Future<void> stop() async {
    // FIX (Bug #31): Cancel all timers with try-catch
    try {
      _expirationTimer?.cancel();
      _expirationTimer = null;
    } catch (e) {
      debugPrint('Error cancelling expiration timer: $e');
    }

    try {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    } catch (e) {
      debugPrint('Error cancelling cleanup timer: $e');
    }

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    // Clear active connections
    _activeConnections.clear();
    _connectedClients.clear();
    
    // FIX (Bug #35): Check if controller is closed before adding
    if (!_activeConnectionCountController.isClosed) {
      _activeConnectionCountController.add(0);
    }

    _sharedFiles = null;
    _shareUrl = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    
    // FIX (Bug #38): Close controllers with try-catch
    try {
      if (!_connectionEventController.isClosed) {
        await _connectionEventController.close();
      }
    } catch (e) {
      debugPrint('Error closing connection event controller: $e');
    }
    
    try {
      if (!_activeConnectionCountController.isClosed) {
        await _activeConnectionCountController.close();
      }
    } catch (e) {
      debugPrint('Error closing active connection count controller: $e');
    }
  }

  /// Clean up stale connected clients to avoid unbounded growth
  void _cleanupStaleClients() {
    if (_connectedClients.isEmpty) return;

    final now = DateTime.now();
    final toRemove = <String>[];

    // Consider clients stale if they've been connected longer than the share expiration
    for (final entry in _connectedClients.entries) {
      if (now.difference(entry.value.connectedAt) > _shareExpiration) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isEmpty) return;

    for (final key in toRemove) {
      _connectedClients.remove(key);
      _activeConnections.remove(key);
    }

    _activeConnectionCountController.add(_activeConnections.length);
  }

  // Connection tracking methods - MODIFIED to include userAgent
  void _onClientConnected(String ipAddress, String userAgent) {
    if (!_activeConnections.contains(ipAddress)) {
      // FIX (Bug #11): Evict oldest entries if map grows too large
      if (_connectedClients.length >= _maxConnectedClients) {
        final oldestKey = _connectedClients.keys.first;
        _connectedClients.remove(oldestKey);
        _activeConnections.remove(oldestKey);
      }

      _activeConnections.add(ipAddress);
      _connectedClients[ipAddress] = ConnectedClient(
        ipAddress: ipAddress,
        userAgent: userAgent,
        connectedAt: DateTime.now(),
      );
      _activeConnectionCountController.add(_activeConnections.length);
      _connectionEventController.add(ConnectionEvent(
        type: ConnectionEventType.connected,
        ipAddress: ipAddress,
        userAgent: userAgent,
      ));
      debugPrint(
          'Client connected: $ipAddress (Total: ${_activeConnections.length})');
    }
  }

  void _onDownloadStarted(String ipAddress, String fileName, int fileSize) {
    _connectionEventController.add(ConnectionEvent(
      type: ConnectionEventType.downloadStarted,
      ipAddress: ipAddress,
      fileName: fileName,
      fileSize: fileSize,
    ));
    debugPrint('Download started: $fileName by $ipAddress');
  }

  void _onDownloadCompleted(String ipAddress, String fileName, int fileSize) {
    _connectionEventController.add(ConnectionEvent(
      type: ConnectionEventType.downloadCompleted,
      ipAddress: ipAddress,
      fileName: fileName,
      fileSize: fileSize,
    ));
    debugPrint('Download completed: $fileName by $ipAddress');
  }

  /// Serve HTTP requests
  void _serve() async {
    if (_server == null) return;

    await for (final request in _server!) {
      try {
        await _handleRequest(request);
      } catch (e) {
        debugPrint('Error handling request: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (closeError) {
          debugPrint('Error closing error response: $closeError');
        }
      }
    }
  }

  /// Handle HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    final uri = request.requestedUri;
    final requestPath = uri.path;
    final clientIp =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final userAgent = request.headers.value('user-agent') ?? 'Unknown'; // NEW

    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, OPTIONS');
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

    // Track connection when accessing index page
    if (requestPath == '/' || requestPath == '/index.html') {
      _onClientConnected(clientIp, userAgent); // MODIFIED
    }

    // Route requests
    if (requestPath == '/' || requestPath == '/index.html') {
      await _serveIndexPage(request);
    } else if (requestPath == '/api/files') {
      await _serveFileList(request);
    } else if (requestPath == '/api/client-info') {
      // NEW: Serve client info
      await _serveClientInfo(request, clientIp);
    } else if (requestPath == '/api/connected-clients') {
      // NEW: Serve all connected clients
      await _serveConnectedClients(request);
    } else if (requestPath.startsWith('/thumbnail/')) {
      await _serveThumbnail(request, requestPath);
    } else if (requestPath.startsWith('/download/')) {
      await _serveFile(request, requestPath, clientIp);
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

  /// NEW: Serve client info (IP address)
  Future<void> _serveClientInfo(HttpRequest request, String clientIp) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'ip': clientIp,
    }));
    await request.response.close();
  }

  /// NEW: Serve all connected clients list
  Future<void> _serveConnectedClients(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'clients': _connectedClients.values.map((c) => c.toJson()).toList(),
      'totalCount': _connectedClients.length,
    }));
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
    if (fileIndex == null ||
        fileIndex < 0 ||
        fileIndex >= _sharedFiles!.length) {
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

    try {
      await request.response.addStream(file.openRead());
      await request.response.close();
    } catch (e) {
      debugPrint('Error serving thumbnail: $e');
    }
  }

  /// Serve file download - with connection tracking
  Future<void> _serveFile(
      HttpRequest request, String requestPath, String clientIp) async {
    if (_sharedFiles == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('No files shared');
      await request.response.close();
      return;
    }

    final parts = requestPath.split('/');
    if (parts.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Invalid request');
      await request.response.close();
      return;
    }

    final fileIndex = int.tryParse(parts[2]);
    if (fileIndex == null ||
        fileIndex < 0 ||
        fileIndex >= _sharedFiles!.length) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found');
      await request.response.close();
      return;
    }

    final file = _sharedFiles![fileIndex];
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found on disk');
      await request.response.close();
      return;
    }

    final fileName = path.basename(file.path);
    final stat = await file.stat();
    final fileSize = stat.size;

    // Get the correct MIME type for the file
    final mimeType = _getMimeType(fileName);

    // Notify download started
    _onDownloadStarted(clientIp, fileName, fileSize);

    try {
      // Set headers for file download
      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        mimeType,
      );
      request.response.headers.set(
        HttpHeaders.contentLengthHeader,
        fileSize.toString(),
      );

      // Content-Disposition with proper encoding for all filenames
      final sanitizedFileName = _sanitizeFileName(fileName);
      final encodedFileName = Uri.encodeComponent(fileName);
      request.response.headers.set(
        'Content-Disposition',
        'attachment; filename="$sanitizedFileName"; filename*=UTF-8\'\'$encodedFileName',
      );

      // Prevent caching issues
      request.response.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache, no-store, must-revalidate',
      );
      request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      request.response.headers.set(HttpHeaders.expiresHeader, '0');

      // Allow cross-origin downloads
      request.response.headers.set(
        'Access-Control-Expose-Headers',
        'Content-Disposition, Content-Length, Content-Type',
      );

      // Stream the file to response
      await request.response.addStream(file.openRead());
      await request.response.close();

      // Notify download completed
      _onDownloadCompleted(clientIp, fileName, fileSize);

      debugPrint(
          'Successfully served file: $fileName ($fileSize bytes) to $clientIp');
    } catch (e) {
      debugPrint('Error streaming file $fileName: $e');
      // Don't try to send error response if headers already sent
      try {
        await request.response.close();
      } catch (closeError) {
        debugPrint('Error closing response after stream error: $closeError');
      }
    }
  }

  /// Sanitize filename for Content-Disposition header
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll('"', '\\"')
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ');
  }

  /// Get MIME type based on file extension
  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    const mimeTypes = {
      // Images
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'ico': 'image/x-icon',
      'tiff': 'image/tiff',
      'tif': 'image/tiff',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'avif': 'image/avif',

      // Videos
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'flv': 'video/x-flv',
      'wmv': 'video/x-ms-wmv',
      'm4v': 'video/x-m4v',
      '3gp': 'video/3gpp',
      '3g2': 'video/3gpp2',
      'mts': 'video/mp2t',
      'm2ts': 'video/mp2t',

      // Audio
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'oga': 'audio/ogg',
      'm4a': 'audio/mp4',
      'wma': 'audio/x-ms-wma',
      'opus': 'audio/opus',
      'aiff': 'audio/aiff',
      'aif': 'audio/aiff',
      'mid': 'audio/midi',
      'midi': 'audio/midi',

      // Documents
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'odt': 'application/vnd.oasis.opendocument.text',
      'ods': 'application/vnd.oasis.opendocument.spreadsheet',
      'odp': 'application/vnd.oasis.opendocument.presentation',
      'rtf': 'application/rtf',
      'epub': 'application/epub+zip',
      'mobi': 'application/x-mobipocket-ebook',

      // Archives
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
      'gzip': 'application/gzip',
      'bz2': 'application/x-bzip2',
      'xz': 'application/x-xz',
      'zst': 'application/zstd',

      // Text/Code
      'txt': 'text/plain',
      'text': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'js': 'text/javascript',
      'mjs': 'text/javascript',
      'jsx': 'text/javascript',
      'ts': 'text/typescript',
      'tsx': 'text/typescript',
      'dart': 'text/plain',
      'py': 'text/x-python',
      'java': 'text/x-java-source',
      'c': 'text/x-c',
      'cpp': 'text/x-c++src',
      'cc': 'text/x-c++src',
      'cxx': 'text/x-c++src',
      'h': 'text/x-c',
      'hpp': 'text/x-c++hdr',
      'cs': 'text/x-csharp',
      'go': 'text/x-go',
      'rs': 'text/x-rust',
      'rb': 'text/x-ruby',
      'php': 'text/x-php',
      'swift': 'text/x-swift',
      'kt': 'text/x-kotlin',
      'kts': 'text/x-kotlin',
      'scala': 'text/x-scala',
      'groovy': 'text/x-groovy',
      'lua': 'text/x-lua',
      'perl': 'text/x-perl',
      'pl': 'text/x-perl',
      'r': 'text/x-r',
      'sql': 'text/x-sql',
      'sh': 'text/x-shellscript',
      'bash': 'text/x-shellscript',
      'zsh': 'text/x-shellscript',
      'ps1': 'text/plain',
      'bat': 'text/plain',
      'cmd': 'text/plain',
      'md': 'text/markdown',
      'markdown': 'text/markdown',
      'yaml': 'text/yaml',
      'yml': 'text/yaml',
      'toml': 'text/plain',
      'ini': 'text/plain',
      'cfg': 'text/plain',
      'conf': 'text/plain',
      'config': 'text/plain',
      'log': 'text/plain',
      'csv': 'text/csv',
      'tsv': 'text/tab-separated-values',

      // Executables / Apps
      'apk': 'application/vnd.android.package-archive',
      'aab': 'application/vnd.android.package-archive',
      'exe': 'application/vnd.microsoft.portable-executable',
      'msi': 'application/x-msi',
      'dmg': 'application/x-apple-diskimage',
      'pkg': 'application/x-newton-compatible-pkg',
      'deb': 'application/vnd.debian.binary-package',
      'rpm': 'application/x-rpm',
      'appimage': 'application/x-executable',
      'app': 'application/x-executable',
      'jar': 'application/java-archive',
      'war': 'application/java-archive',
      'ear': 'application/java-archive',

      // Fonts
      'ttf': 'font/ttf',
      'otf': 'font/otf',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'eot': 'application/vnd.ms-fontobject',

      // 3D / CAD
      'obj': 'model/obj',
      'stl': 'model/stl',
      'fbx': 'application/octet-stream',
      'gltf': 'model/gltf+json',
      'glb': 'model/gltf-binary',

      // Other
      'bin': 'application/octet-stream',
      'dat': 'application/octet-stream',
      'iso': 'application/x-iso9660-image',
      'img': 'application/octet-stream',
      'torrent': 'application/x-bittorrent',
      'ics': 'text/calendar',
      'vcf': 'text/vcard',
      'pem': 'application/x-pem-file',
      'crt': 'application/x-x509-ca-cert',
      'cer': 'application/x-x509-ca-cert',
      'key': 'application/x-pem-file',
      'p12': 'application/x-pkcs12',
      'pfx': 'application/x-pkcs12',
    };

    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}
