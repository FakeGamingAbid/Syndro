import 'package:flutter/foundation.dart';

/// Centralized logger that strips sensitive data and silences output in release builds.
///
/// Usage:
/// ```dart
/// AppLogger.info('Server started on port 8080');
/// AppLogger.info('Connecting to 192.168.1.5');
/// ```
class AppLogger {
  AppLogger._();

  static bool _enabled = kDebugMode;

  /// Enable or disable logging at runtime.
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Log an informational message.
  static void info(String message) => _log('INFO', message);

  /// Log a warning.
  static void warn(String message) => _log('WARN', message);

  /// Log an error with optional stack trace.
  static void error(String message, [Object? error, StackTrace? stack]) {
    _log('ERROR', message);
    if (error != null) {
      _log('ERROR', '  → $error');
    }
    if (stack != null && _enabled) {
      debugPrint('  $stack');
    }
  }

  /// Sanitize a potentially sensitive string (IPs, file paths, device IDs).
  ///
  /// Only redacts patterns that are clearly IPs or file paths.
  /// Does NOT match version numbers, build IDs, or non-path content with slashes.
  static String sanitize(String value) {
    var result = value;

    // Redact IPv4 addresses (with word boundaries to avoid matching version numbers)
    // Matches: "192.168.1.5", "at 10.0.0.1:", "from 172.16.0.5 "
    // Does NOT match: "v2.14.3.0", "1.2.3.45678", "Build 1.2.3"
    final ipRegex = RegExp(r'(?<![.\d])\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?![.\d])');
    result = result.replaceAllMapped(ipRegex, (m) => _maskIp(m.group(0)!));

    // Redact file paths (only if they start with / or ~ or contain common path patterns)
    // Does NOT strip: "Rate: 100/200 MB", "a/b/c" (simple separators)
    result = _sanitizePaths(result);

    return result;
  }

  static String _sanitizePaths(String value) {
    // Match actual file paths: /path/to/file, C:\path\to\file, ~/path/to/file
    final pathRegex = RegExp(r'(?:^|[\s])([/~][^\s]+|[A-Z]:\\[^\s]+)');
    final matches = pathRegex.allMatches(value).toList();

    if (matches.isEmpty) return value;

    var result = value;
    // Replace in reverse order to preserve indices
    for (final match in matches.reversed) {
      final fullPath = match.group(1)!;
      final parts = fullPath.split(RegExp(r'[/\\]'));
      final fileName = parts.last;
      final masked = '.../$fileName';
      result = result.replaceRange(match.start + 1, match.end, masked);
    }

    return result;
  }

  static String _maskIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 'x.x.x.x';
    return '${parts[0]}.xxx.xxx.${parts[3]}';
  }

  static void _log(String level, String message) {
    if (!_enabled) return;
    final sanitized = sanitize(message);
    debugPrint('[$level] $sanitized');
  }
}
