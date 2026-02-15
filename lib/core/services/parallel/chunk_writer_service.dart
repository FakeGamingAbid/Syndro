import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'parallel_config.dart';

/// RAM-efficient chunk writer service
/// 
/// Writes chunks directly to disk at specific offsets
/// Memory usage: ~1-2MB regardless of file size
class ChunkWriterService {
  final String filePath;
  final int totalSize;
  final int totalChunks;
  final ParallelConfig config;
  
  RandomAccessFile? _file;
  final Set<int> _receivedChunks = {};
  final _completionController = StreamController<double>.broadcast();
  bool _isComplete = false;
  bool _isClosed = false;
  
  /// Track bytes received for progress
  int _bytesReceived = 0;

  ChunkWriterService({
    required this.filePath,
    required this.totalSize,
    required this.totalChunks,
    required this.config,
  });

  /// Stream of completion percentage (0.0 - 1.0)
  Stream<double> get completionStream => _completionController.stream;
  
  /// Current completion percentage
  double get completionPercentage => _receivedChunks.length / totalChunks;
  
  /// Bytes received so far
  int get bytesReceived => _bytesReceived;
  
  /// Check if transfer is complete
  bool get isComplete => _isComplete;
  
  /// Check if file is closed
  bool get isClosed => _isClosed;

  /// Initialize and pre-allocate file
  Future<void> initialize() async {
    if (_file != null) return;
    
    try {
      // Ensure directory exists
      final dir = Directory(filePath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Create temp file
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);
      
      // Pre-allocate file with zeros (sparse file on supported systems)
      _file = await tempFile.open(mode: FileMode.write);
      
      // Seek to end to set file size (creates sparse file)
      await _file!.setPosition(totalSize - 1);
      await _file!.writeByte(0);
      await _file!.setPosition(0);
      
      debugPrint('📁 Pre-allocated file: $tempPath (${_formatBytes(totalSize)})');
    } catch (e) {
      debugPrint('Error initializing chunk writer: $e');
      rethrow;
    }
  }

  /// Write a chunk at specific index
  /// 
  /// Thread-safe: Can be called from multiple isolates/connections
  Future<void> writeChunk(int chunkIndex, Uint8List data) async {
    if (_isClosed) {
      throw StateError('ChunkWriter is closed');
    }
    
    if (_file == null) {
      throw StateError('ChunkWriter not initialized');
    }
    
    if (_receivedChunks.contains(chunkIndex)) {
      debugPrint('⚠️ Chunk $chunkIndex already received, skipping');
      return;
    }
    
    if (chunkIndex >= totalChunks) {
      throw RangeError('Chunk index $chunkIndex out of range (max: ${totalChunks - 1})');
    }

    try {
      // Calculate offset
      final offset = chunkIndex * config.chunkSize;
      
      // Seek to offset and write
      await _file!.setPosition(offset);
      await _file!.writeFrom(data);
      
      // Mark chunk as received
      _receivedChunks.add(chunkIndex);
      _bytesReceived += data.length;
      
      // Emit progress
      final progress = _receivedChunks.length / totalChunks;
      if (!_completionController.isClosed) {
        _completionController.add(progress);
      }
      
      // Check if complete
      if (_receivedChunks.length == totalChunks) {
        _isComplete = true;
        debugPrint('✅ All $totalChunks chunks received');
      }
    } catch (e) {
      debugPrint('Error writing chunk $chunkIndex: $e');
      rethrow;
    }
  }

  /// Get list of missing chunks (for retry)
  List<int> getMissingChunks() {
    final missing = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!_receivedChunks.contains(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  /// Check if specific chunk was received
  bool hasChunk(int chunkIndex) => _receivedChunks.contains(chunkIndex);

  /// Finalize and rename temp file to final
  Future<File> finalize() async {
    if (!_isComplete) {
      final missing = getMissingChunks();
      throw StateError('Cannot finalize: ${missing.length} chunks missing: $missing');
    }
    
    try {
      // Flush and close
      await _file?.flush();
      await _file?.close();
      _file = null;
      
      // Rename temp to final
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);
      final finalFile = File(filePath);
      
      // Delete existing final file if exists
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      
      // Rename
      await tempFile.rename(filePath);
      
      _isClosed = true;
      await _completionController.close();
      
      debugPrint('✅ File finalized: $filePath');
      return File(filePath);
    } catch (e) {
      debugPrint('Error finalizing file: $e');
      rethrow;
    }
  }

  /// Abort and cleanup
  Future<void> abort() async {
    try {
      await _file?.close();
      _file = null;
      
      // Delete temp file
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      _isClosed = true;
      await _completionController.close();
      
      debugPrint('🚫 Transfer aborted, temp file deleted');
    } catch (e) {
      debugPrint('Error aborting: $e');
    }
  }

  /// Close without finalizing (for cleanup)
  Future<void> close() async {
    if (_isClosed) return;
    
    try {
      await _file?.close();
      _file = null;
      _isClosed = true;
      
      if (!_completionController.isClosed) {
        await _completionController.close();
      }
    } catch (e) {
      debugPrint('Error closing chunk writer: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// Manages multiple chunk writers for a transfer session
class ChunkWriterManager {
  final Map<String, ChunkWriterService> _writers = {};

  /// Create a new chunk writer for a file
  Future<ChunkWriterService> createWriter({
    required String fileId,
    required String filePath,
    required int totalSize,
    required ParallelConfig config,
  }) async {
    if (_writers.containsKey(fileId)) {
      throw StateError('Writer already exists for file: $fileId');
    }
    
    final totalChunks = config.calculateChunkCount(totalSize);
    
    final writer = ChunkWriterService(
      filePath: filePath,
      totalSize: totalSize,
      totalChunks: totalChunks,
      config: config,
    );
    
    await writer.initialize();
    _writers[fileId] = writer;
    
    return writer;
  }

  /// Get existing writer
  ChunkWriterService? getWriter(String fileId) => _writers[fileId];

  /// Remove writer
  Future<void> removeWriter(String fileId) async {
    final writer = _writers.remove(fileId);
    await writer?.close();
  }

  /// Close all writers
  Future<void> closeAll() async {
    for (final writer in _writers.values) {
      await writer.close();
    }
    _writers.clear();
  }

  /// Abort all writers
  Future<void> abortAll() async {
    for (final writer in _writers.values) {
      await writer.abort();
    }
    _writers.clear();
  }
}
