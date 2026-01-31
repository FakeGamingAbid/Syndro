import 'package:equatable/equatable.dart';

class TransferCheckpoint extends Equatable {
  final String transferId;
  final String fileId; // Which file in multi-file transfer (file path or index)
  final int bytesTransferred;
  final DateTime timestamp;
  final int currentFileIndex; // Index in items list
  final int totalFiles;

  const TransferCheckpoint({
    required this.transferId,
    required this.fileId,
    required this.bytesTransferred,
    required this.timestamp,
    required this.currentFileIndex,
    required this.totalFiles,
  });

  // Check if checkpoint is still valid (within 24 hours)
  bool get isValid {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 24;
  }

  // Get completion percentage
  double get completionPercentage {
    if (totalFiles == 0) return 0;
    return (currentFileIndex / totalFiles) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'fileId': fileId,
      'bytesTransferred': bytesTransferred,
      'timestamp': timestamp.toIso8601String(),
      'currentFileIndex': currentFileIndex,
      'totalFiles': totalFiles,
    };
  }

  factory TransferCheckpoint.fromJson(Map<String, dynamic> json) {
    return TransferCheckpoint(
      transferId: json['transferId'] as String,
      fileId: json['fileId'] as String,
      bytesTransferred: json['bytesTransferred'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      currentFileIndex: json['currentFileIndex'] as int,
      totalFiles: json['totalFiles'] as int,
    );
  }

  TransferCheckpoint copyWith({
    String? transferId,
    String? fileId,
    int? bytesTransferred,
    DateTime? timestamp,
    int? currentFileIndex,
    int? totalFiles,
  }) {
    return TransferCheckpoint(
      transferId: transferId ?? this.transferId,
      fileId: fileId ?? this.fileId,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      timestamp: timestamp ?? this.timestamp,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
    );
  }

  @override
  List<Object?> get props => [
        transferId,
        fileId,
        bytesTransferred,
        timestamp,
        currentFileIndex,
        totalFiles,
      ];
}
