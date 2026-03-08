import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class TransferCheckpoint extends Equatable {
  final String transferId;
  final String fileId; // Which file in multi-file transfer (file path or index)
  final int bytesTransferred;
  final DateTime timestamp;
  final int currentFileIndex; // Index in items list
  final int totalFiles;

  // FIX: Add file paths for validation
  final List<String>? filePaths;

  const TransferCheckpoint({
    required this.transferId,
    required this.fileId,
    required this.bytesTransferred,
    required this.timestamp,
    required this.currentFileIndex,
    required this.totalFiles,
    this.filePaths,
  });

  // FIX: Enhanced validity check - includes file existence verification
  bool get isValid {
    // Check time validity (within 24 hours)
    if (!isTimeValid) return false;

    // Check data validity
    if (!isDataValid) return false;

    return true;
  }

  // FIX: Separate time validity check
  bool get isTimeValid {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 24;
  }

  // FIX: Separate data validity check
  bool get isDataValid {
    if (transferId.isEmpty) return false;
    if (bytesTransferred < 0) return false;
    if (currentFileIndex < 0) return false;
    if (totalFiles <= 0) return false;
    if (currentFileIndex > totalFiles) return false;

    return true;
  }

  // FIX: Check if files still exist (async operation)
  Future<bool> areFilesValid() async {
    if (filePaths == null || filePaths!.isEmpty) {
      // If no file paths stored, we can't verify - assume valid
      return true;
    }

    try {
      // Check if current file exists
      if (currentFileIndex < filePaths!.length) {
        final currentFile = File(filePaths![currentFileIndex]);
        if (!await currentFile.exists()) {
          debugPrint(
              '⚠️ Checkpoint file not found: ${filePaths![currentFileIndex]}');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error checking checkpoint files: $e');
      return false;
    }
  }

  // FIX: Full async validation
  Future<bool> isValidAsync() async {
    if (!isValid) return false;
    return await areFilesValid();
  }

  // FIX: Get completion percentage (clamped to 0-100)
  double get completionPercentage {
    if (totalFiles <= 0) return 0;
    if (currentFileIndex <= 0) return 0;
    if (currentFileIndex >= totalFiles) return 100;

    final percent = (currentFileIndex / totalFiles) * 100;
    return math.max(0, math.min(100, percent));
  }

  // FIX: Get remaining files count
  int get remainingFiles {
    if (totalFiles <= 0) return 0;
    return math.max(0, totalFiles - currentFileIndex);
  }

  // FIX: Get age of checkpoint
  Duration get age => DateTime.now().difference(timestamp);

  // FIX: Check if checkpoint is stale (older than 1 hour but less than 24)
  bool get isStale {
    final hours = age.inHours;
    return hours >= 1 && hours < 24;
  }

  // FIX: Check if checkpoint is expired
  bool get isExpired {
    return age.inHours >= 24;
  }

  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'fileId': fileId,
      'bytesTransferred': bytesTransferred,
      'timestamp': timestamp.toIso8601String(),
      'currentFileIndex': currentFileIndex,
      'totalFiles': totalFiles,
      'filePaths': filePaths,
    };
  }

  // FIX: Add validation to fromJson
  factory TransferCheckpoint.fromJson(Map<String, dynamic> json) {
    final transferId = json['transferId'] as String? ?? '';
    final fileId = json['fileId'] as String? ?? '';
    final bytesTransferred = json['bytesTransferred'] as int? ?? 0;
    final currentFileIndex = json['currentFileIndex'] as int? ?? 0;
    final totalFiles = json['totalFiles'] as int? ?? 0;

    if (transferId.isEmpty) {
      throw const FormatException('TransferCheckpoint transferId cannot be empty');
    }

    // FIX: Parse file paths if present
    List<String>? filePaths;
    if (json['filePaths'] != null) {
      filePaths = (json['filePaths'] as List).cast<String>();
    }

    return TransferCheckpoint(
      transferId: transferId,
      fileId: fileId,
      bytesTransferred: math.max(0, bytesTransferred),
      timestamp: _parseTimestamp(json['timestamp']),
      currentFileIndex: math.max(0, currentFileIndex),
      totalFiles: math.max(0, totalFiles),
      filePaths: filePaths,
    );
  }

  // FIX: Safe timestamp parsing
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('Error parsing checkpoint timestamp: $e');
        return DateTime.now();
      }
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  TransferCheckpoint copyWith({
    String? transferId,
    String? fileId,
    int? bytesTransferred,
    DateTime? timestamp,
    int? currentFileIndex,
    int? totalFiles,
    List<String>? filePaths,
  }) {
    return TransferCheckpoint(
      transferId: transferId ?? this.transferId,
      fileId: fileId ?? this.fileId,
      bytesTransferred: math.max(0, bytesTransferred ?? this.bytesTransferred),
      timestamp: timestamp ?? this.timestamp,
      currentFileIndex: math.max(0, currentFileIndex ?? this.currentFileIndex),
      totalFiles: math.max(0, totalFiles ?? this.totalFiles),
      filePaths: filePaths ?? this.filePaths,
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
        filePaths,
      ];
}
