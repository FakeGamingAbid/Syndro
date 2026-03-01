import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum TransferStatus {
  pending,
  connecting,
  transferring,
  paused,
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
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Check if transfer is in a terminal state
  bool get isTerminal {
    return this == TransferStatus.completed ||
        this == TransferStatus.failed ||
        this == TransferStatus.cancelled;
  }

  /// Check if transfer is active (including paused)
  bool get isActive {
    return this == TransferStatus.connecting ||
        this == TransferStatus.transferring ||
        this == TransferStatus.paused;
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

  // FIX: Ensure percentage is always between 0 and 100
  double get percentage {
    if (totalBytes <= 0) return 0;
    if (bytesTransferred <= 0) return 0;
    if (bytesTransferred >= totalBytes) return 100;

    final percent = (bytesTransferred / totalBytes) * 100;

    // FIX: Clamp to valid range
    return math.max(0, math.min(100, percent));
  }

  // FIX: Safe percentage as int
  int get percentageInt {
    return percentage.round().clamp(0, 100);
  }

  // FIX: Progress ratio (0.0 to 1.0)
  double get ratio {
    if (totalBytes <= 0) return 0;
    if (bytesTransferred <= 0) return 0;
    if (bytesTransferred >= totalBytes) return 1.0;

    return math.max(0, math.min(1, bytesTransferred / totalBytes));
  }

  // Format bytes transferred as human-readable string
  String get bytesTransferredFormatted => _formatBytes(bytesTransferred);

  // Format total bytes as human-readable string
  String get totalBytesFormatted => _formatBytes(totalBytes);

  // Helper function to format bytes
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 1 : 2)} ${suffixes[i]}';
  }

  String get speedFormatted {
    if (speed <= 0) return '0 B/s';

    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else if (speed < 1024 * 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  String get progressFormatted {
    return '${_formatBytes(bytesTransferred)} / ${_formatBytes(totalBytes)}';
  }

  String get etaFormatted {
    if (eta == null) return '';

    if (eta!.inHours > 0) {
      return '${eta!.inHours}h ${eta!.inMinutes.remainder(60)}m left';
    } else if (eta!.inMinutes > 0) {
      return '${eta!.inMinutes}m ${eta!.inSeconds.remainder(60)}s left';
    } else if (eta!.inSeconds > 5) {
      return '${eta!.inSeconds}s left';
    } else {
      return 'Almost done...';
    }
  }

  TransferProgress copyWith({
    int? bytesTransferred,
    int? totalBytes,
    double? speed,
    Duration? eta,
  }) {
    return TransferProgress(
      bytesTransferred: math.max(0, bytesTransferred ?? this.bytesTransferred),
      totalBytes: math.max(0, totalBytes ?? this.totalBytes),
      speed: math.max(0, speed ?? this.speed),
      eta: eta ?? this.eta,
    );
  }

  // FIX: Factory for creating progress with validation
  factory TransferProgress.create({
    required int bytesTransferred,
    required int totalBytes,
    double speed = 0,
    Duration? eta,
  }) {
    return TransferProgress(
      bytesTransferred: math.max(0, bytesTransferred),
      totalBytes: math.max(0, totalBytes),
      speed: math.max(0, speed),
      eta: eta,
    );
  }

  // FIX: Calculate ETA from speed
  factory TransferProgress.withCalculatedEta({
    required int bytesTransferred,
    required int totalBytes,
    required double speed,
  }) {
    Duration? eta;

    if (speed > 0 && bytesTransferred < totalBytes) {
      final remainingBytes = totalBytes - bytesTransferred;
      final secondsRemaining = remainingBytes / speed;

      // FIX: Cap ETA at reasonable maximum (24 hours)
      if (secondsRemaining < 86400) {
        eta = Duration(seconds: secondsRemaining.round());
      }
    }

    return TransferProgress(
      bytesTransferred: math.max(0, bytesTransferred),
      totalBytes: math.max(0, totalBytes),
      speed: math.max(0, speed),
      eta: eta,
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
  final DateTime? createdAt; // File creation time (metadata preservation)
  final DateTime? modifiedAt; // File modification time (metadata preservation)

  const TransferItem({
    required this.name,
    required this.path,
    required this.size,
    this.isDirectory = false,
    this.parentPath,
    this.itemCount = 0,
    this.createdAt,
    this.modifiedAt,
  });

  // Get relative path for folder reconstruction
  String get relativePath {
    if (parentPath == null || parentPath!.isEmpty) return name;
    return '$parentPath/$name';
  }

  // Check if folder has children
  bool get hasChildren => isDirectory && itemCount > 0;

  String get sizeFormatted {
    if (size < 0) return '0 B';

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

  // FIX: Get file extension safely
  String get extension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot == -1 || lastDot == name.length - 1) return '';
    return name.substring(lastDot + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'isDirectory': isDirectory,
      'parentPath': parentPath,
      'itemCount': itemCount,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  // FIX: Add validation to fromJson
  factory TransferItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final path = json['path'] as String? ?? '';
    final size = json['size'] as int? ?? 0;

    if (name.isEmpty) {
      throw const FormatException('TransferItem name cannot be empty');
    }

    DateTime? createdAt;
    DateTime? modifiedAt;
    
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'] as String);
      } catch (e) {
        debugPrint('Warning: Failed to parse createdAt: $e');
      }
    }
    
    if (json['modifiedAt'] != null) {
      try {
        modifiedAt = DateTime.parse(json['modifiedAt'] as String);
      } catch (e) {
        debugPrint('Warning: Failed to parse modifiedAt: $e');
      }
    }

    return TransferItem(
      name: name,
      path: path,
      size: math.max(0, size),
      isDirectory: json['isDirectory'] as bool? ?? false,
      parentPath: json['parentPath'] as String?,
      itemCount: math.max(0, json['itemCount'] as int? ?? 0),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
  }

  @override
  List<Object?> get props =>
      [name, path, size, isDirectory, parentPath, itemCount, createdAt, modifiedAt];
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

  int get fileCount => items.where((item) => !item.isDirectory).length;

  int get directoryCount => items.where((item) => item.isDirectory).length;

  // FIX: Duration since created
  Duration get age => DateTime.now().difference(createdAt);

  // FIX: Check if transfer is stale (older than 24 hours and not completed)
  bool get isStale {
    if (status.isTerminal) return false;
    return age.inHours > 24;
  }

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

  // FIX: Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status.name,
      'progress': {
        'bytesTransferred': progress.bytesTransferred,
        'totalBytes': progress.totalBytes,
        'speed': progress.speed,
      },
      'createdAt': createdAt.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  // FIX: Create from JSON with validation
  factory Transfer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) {
      throw const FormatException('Transfer ID cannot be empty');
    }

    final itemsList = json['items'] as List? ?? [];
    final items = itemsList
        .map((item) => TransferItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final progressJson = json['progress'] as Map<String, dynamic>?;

    return Transfer(
      id: id,
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      items: items,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.pending,
      ),
      progress: TransferProgress(
        bytesTransferred: progressJson?['bytesTransferred'] as int? ?? 0,
        totalBytes: progressJson?['totalBytes'] as int? ?? 0,
        speed: (progressJson?['speed'] as num?)?.toDouble() ?? 0,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      errorMessage: json['errorMessage'] as String?,
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

/// Statistics for parallel transfer - shows chunk count and bytes per connection
class ParallelTransferStats extends Equatable {
  /// Total number of chunks the file is divided into
  final int totalChunks;

  /// Number of chunks already completed
  final int completedChunks;

  /// Bytes transferred per connection (index = connection id)
  final List<int> bytesPerConnection;

  /// Number of active connections currently transferring
  final int activeConnections;

  /// Whether parallel transfer is being used
  final bool isParallel;

  const ParallelTransferStats({
    this.totalChunks = 0,
    this.completedChunks = 0,
    this.bytesPerConnection = const [],
    this.activeConnections = 0,
    this.isParallel = false,
  });

  /// Progress ratio (0.0 to 1.0)
  double get chunkProgress {
    if (totalChunks == 0) return 0;
    return completedChunks / totalChunks;
  }

  /// Total bytes across all connections
  int get totalBytesTransferred {
    return bytesPerConnection.fold(0, (sum, bytes) => sum + bytes);
  }

  /// Average bytes per connection
  double get averageBytesPerConnection {
    if (bytesPerConnection.isEmpty) return 0;
    return totalBytesTransferred / bytesPerConnection.length;
  }

  @override
  List<Object?> get props => [
        totalChunks,
        completedChunks,
        bytesPerConnection,
        activeConnections,
        isParallel,
      ];
}
