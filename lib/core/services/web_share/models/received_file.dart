/// Model for received files
class ReceivedFile {
  final String name;
  final String path;
  final int size;
  final DateTime receivedAt;

  ReceivedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.receivedAt,
  });

  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
