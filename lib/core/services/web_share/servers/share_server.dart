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
      print('Error serving thumbnail: $e');
    }
  }

  /// Serve file download - FIXED VERSION
  Future<void> _serveFile(HttpRequest request, String requestPath) async {
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
      // Using both filename (for older browsers) and filename* (RFC 5987 for Unicode support)
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
      
      print('Successfully served file: $fileName ($fileSize bytes)');
    } catch (e) {
      print('Error streaming file $fileName: $e');
      // Don't try to send error response if headers already sent
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Sanitize filename for Content-Disposition header
  /// Removes or escapes characters that could cause issues
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
      'ts': 'video/mp2t',
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
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
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
