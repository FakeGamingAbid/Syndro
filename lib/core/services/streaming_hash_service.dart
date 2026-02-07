import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

/// Service for calculating file hashes WITHOUT loading entire file into RAM
/// 
/// Memory usage: ~1MB regardless of file size
/// Speed: ~500MB/s on modern devices
class StreamingHashService {
  /// Calculate SHA-256 hash of a file using streaming
  /// 
  /// Memory usage: ~1MB constant
  /// Works for files of ANY size (even 100GB+)
  static Future<String> calculateFileHash(File file) async {
    if (!await file.exists()) {
      throw FileNotFoundException('File not found: ${file.path}');
    }

    final output = AccumulatorSink<crypto.Digest>();
    final input = crypto.sha256.startChunkedConversion(output);

    try {
      final stream = file.openRead();
      await for (final chunk in stream) {
        input.add(chunk);
      }
      input.close();

      return output.events.single.toString();
    } catch (e) {
      debugPrint('Error calculating file hash: $e');
      rethrow;
    }
  }

  /// Calculate SHA-256 hash of a file with progress callback
  static Future<String> calculateFileHashWithProgress(
    File file, {
    void Function(int bytesProcessed, int totalBytes)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw FileNotFoundException('File not found: ${file.path}');
    }

    final fileSize = await file.length();
    final output = AccumulatorSink<crypto.Digest>();
    final input = crypto.sha256.startChunkedConversion(output);

    int bytesProcessed = 0;

    try {
      final stream = file.openRead();
      await for (final chunk in stream) {
        input.add(chunk);
        bytesProcessed += chunk.length;
        onProgress?.call(bytesProcessed, fileSize);
      }
      input.close();

      return output.events.single.toString();
    } catch (e) {
      debugPrint('Error calculating file hash: $e');
      rethrow;
    }
  }

  /// Calculate hash of a stream (useful for received data)
  static Future<String> calculateStreamHash(Stream<List<int>> stream) async {
    final output = AccumulatorSink<crypto.Digest>();
    final input = crypto.sha256.startChunkedConversion(output);

    try {
      await for (final chunk in stream) {
        input.add(chunk);
      }
      input.close();

      return output.events.single.toString();
    } catch (e) {
      debugPrint('Error calculating stream hash: $e');
      rethrow;
    }
  }

  /// Calculate hash of bytes (for small data only)
  static String calculateBytesHash(List<int> bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  /// Incremental hash calculator for chunk-by-chunk hashing
  static IncrementalHashCalculator createIncrementalCalculator() {
    return IncrementalHashCalculator();
  }
}

/// Incremental hash calculator - add chunks one by one
class IncrementalHashCalculator {
  final AccumulatorSink<crypto.Digest> _output = AccumulatorSink<crypto.Digest>();
  late final ByteConversionSink _input;
  bool _finalized = false;

  IncrementalHashCalculator() {
    _input = crypto.sha256.startChunkedConversion(_output);
  }

  /// Add a chunk of data to the hash calculation
  void addChunk(List<int> chunk) {
    if (_finalized) {
      throw StateError('Hash already finalized');
    }
    _input.add(chunk);
  }

  /// Finalize and get the hash string
  String finalize() {
    if (_finalized) {
      throw StateError('Hash already finalized');
    }
    _finalized = true;
    _input.close();
    return _output.events.single.toString();
  }

  bool get isFinalized => _finalized;
}

/// Accumulator sink for collecting digest
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}

/// Exception for file not found
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}
