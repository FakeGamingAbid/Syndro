/// Canonical byte formatting utility.
///
/// Provides a single [format] method to convert byte counts
/// into human-readable strings (B, KB, MB, GB).
class ByteFormatter {
  ByteFormatter._();

  /// Format [bytes] to a human-readable string.
  ///
  /// Examples:
  /// ```dart
  /// ByteFormatter.format(0);       // '0 B'
  /// ByteFormatter.format(1024);    // '1.0 KB'
  /// ByteFormatter.format(1048576); // '1.0 MB'
  /// ```
  static String format(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
