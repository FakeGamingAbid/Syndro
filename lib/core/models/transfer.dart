import 'package:equatable/equatable.dart';

enum TransferStatus {
  pending,
  connecting,
  transferring,
  completed,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.connecting:
        return 'Connecting';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class TransferProgress extends Equatable {
  final int bytesTransferred;
  final int totalBytes;
  final double speed; // bytes per second
  final Duration? eta;

  const TransferProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    this.speed = 0,
    this.eta,
  });

  double get percentage {
    if (totalBytes == 0) return 0;
    return (bytesTransferred / totalBytes) * 100;
  }

  String get speedFormatted {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get progressFormatted {
    return '${_formatBytes(bytesTransferred)} / ${_formatBytes(totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  TransferProgress copyWith({
    int? bytesTransferred,
    int? totalBytes,
    double? speed,
    Duration? eta,
  }) {
    return TransferProgress(
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
    );
  }

  @override
  List<Object?> get props => [bytesTransferred, totalBytes, speed, eta];
}

class TransferItem extends Equatable {
  final String name;
  final String path;
  final int size;
  final bool isDirectory;
  final String? parentPath; // Relative path from transfer root
  final int itemCount; // Number of files in folder (if directory)

  const TransferItem({
    required this.name,
    required this.path,
    required this.size,
    this.isDirectory = false,
    this.parentPath,
    this.itemCount = 0,
  });

  // Get relative path for folder reconstruction
  String get relativePath {
    if (parentPath == null || parentPath!.isEmpty) return name;
    return '$parentPath/$name';
  }

  // Check if folder has children
  bool get hasChildren => isDirectory && itemCount > 0;

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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'isDirectory': isDirectory,
      'parentPath': parentPath,
      'itemCount': itemCount,
    };
  }

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      isDirectory: json['isDirectory'] as bool? ?? false,
      parentPath: json['parentPath'] as String?,
      itemCount: json['itemCount'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [name, path, size, isDirectory, parentPath, itemCount];
}

class Transfer extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final List<TransferItem> items;
  final TransferStatus status;
  final TransferProgress progress;
  final DateTime createdAt;
  final String? errorMessage;

  const Transfer({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.items,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.errorMessage,
  });

  int get totalSize => items.fold(0, (sum, item) => sum + item.size);

  Transfer copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    List<TransferItem>? items,
    TransferStatus? status,
    TransferProgress? progress,
    DateTime? createdAt,
    String? errorMessage,
  }) {
    return Transfer(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      items: items ?? this.items,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        receiverId,
        items,
        status,
        progress,
        createdAt,
        errorMessage,
      ];
}
