import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

import '../streaming_hash_service.dart';
import 'parallel_config.dart';
import 'chunk_writer_service.dart';
import '../../models/device.dart';

/// Parallel transfer service for high-speed file transfers
/// 
/// Features:
/// - Multiple parallel connections (2-6)
/// - Zero RAM file reading (streaming)
/// - Works for App-to-App and App-to-Browser
/// - Supports encryption
/// - Low-end device friendly (4GB RAM safe)
class ParallelTransferService {
  final ParallelConfig config;
  final ChunkWriterManager _writerManager = ChunkWriterManager();
  
  // Encryption
  final AesGcm _aesGcm = AesGcm.with256bits();
  
  // Active transfers tracking
  final Map<String, ParallelTransferState> _activeTransfers = {};
  
  // Progress stream
  final _progressController = StreamController<ParallelProgress>.broadcast();
  Stream<ParallelProgress> get progressStream => _progressController.stream;

  ParallelTransferService({ParallelConfig? config}) 
      : config = config ?? ParallelConfig.appToApp;

  /// Send a file using parallel chunks
  /// 
  /// Memory usage: ~4-8MB regardless of file size
  Future<void> sendFileParallel({
    required String transferId,
    required File file,
    required Device receiver,
    required String senderToken,
    required Device sender,
    SecretKey? encryptionKey,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final fileSize = await file.length();
    final fileName = file.path.split(Platform.pathSeparator).last;
    
    // Check if should use parallel
    if (!config.shouldUseParallel(fileSize)) {
      debugPrint('📁 File too small for parallel, using single connection');
      // Fall back to single connection (your existing method)
      throw UnsupportedError('Use regular sendFile for small files');
    }
    
    debugPrint('🚀 Starting parallel transfer: $fileName (${_formatBytes(fileSize)})');
    debugPrint('   Connections: ${config.connections}, Chunk size: ${_formatBytes(config.chunkSize)}');
    
    // Calculate file hash (streaming - no RAM usage)
    debugPrint('📝 Calculating file hash (streaming)...');
    final fileHash = await StreamingHashService.calculateFileHash(file);
    debugPrint('   Hash: ${fileHash.substring(0, 16)}...');
    
    // Get all chunks info
    final chunks = config.getAllChunks(fileSize);
    debugPrint('   Total chunks: ${chunks.length}');
    
    // Create transfer state
    final state = ParallelTransferState(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: chunks.length,
    );
    _activeTransfers[transferId] = state;
    
    // Initiate parallel transfer with receiver
    final initResponse = await _initiateParallelTransfer(
      receiver: receiver,
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      fileHash: fileHash,
      totalChunks: chunks.length,
      chunkSize: config.chunkSize,
      sender: sender,
      senderToken: senderToken,
      encrypted: encryptionKey != null,
    );
    
    if (!initResponse['success']) {
      throw Exception('Failed to initiate parallel transfer: ${initResponse['error']}');
    }
    
    // Distribute chunks across connections
    final chunkQueues = _distributeChunks(chunks, config.connections);
    
    // Start parallel uploads
    final futures = <Future<void>>[];
    
    for (int connId = 0; connId < config.connections; connId++) {
      final queue = chunkQueues[connId];
      if (queue.isEmpty) continue;
      
      futures.add(_uploadChunkQueue(
        connectionId: connId,
        chunks: queue,
        file: file,
        receiver: receiver,
        transferId: transferId,
        senderToken: senderToken,
        sender: sender,
        encryptionKey: encryptionKey,
        state: state,
        onProgress: onProgress,
      ));
    }
    
    // Wait for all connections to complete
    try {
      await Future.wait(futures);
      
      // Notify receiver that transfer is complete
      await _notifyTransferComplete(
        receiver: receiver,
        transferId: transferId,
        fileHash: fileHash,
      );
      
      debugPrint('✅ Parallel transfer complete: $fileName');
    } catch (e) {
      debugPrint('❌ Parallel transfer failed: $e');
      _activeTransfers.remove(transferId);
      rethrow;
    }
    
    _activeTransfers.remove(transferId);
  }

  /// Distribute chunks across connections evenly
  List<List<ChunkInfo>> _distributeChunks(List<ChunkInfo> chunks, int connections) {
    final queues = List.generate(connections, (_) => <ChunkInfo>[]);
    
    for (int i = 0; i < chunks.length; i++) {
      final connId = i % connections;
      queues[connId].add(chunks[i]);
    }
    
    return queues;
  }

  /// Upload chunks for a single connection
  Future<void> _uploadChunkQueue({
    required int connectionId,
    required List<ChunkInfo> chunks,
    required File file,
    required Device receiver,
    required String transferId,
    required String senderToken,
    required Device sender,
    required ParallelTransferState state,
    SecretKey? encryptionKey,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    debugPrint('🔗 Connection $connectionId: Uploading ${chunks.length} chunks');
    
    final raf = await file.open(mode: FileMode.read);
    
    try {
      for (final chunk in chunks) {
        if (state.isCancelled) {
          debugPrint('🚫 Connection $connectionId: Transfer cancelled');
          break;
        }
        
        // Read chunk from file (streaming - only this chunk in RAM)
        await raf.setPosition(chunk.start);
        final data = await raf.read(chunk.size);
        
        // Encrypt if needed
        Uint8List dataToSend;
        if (encryptionKey != null) {
          dataToSend = await _encryptChunk(Uint8List.fromList(data), encryptionKey);
        } else {
          dataToSend = Uint8List.fromList(data);
        }
        
        // Upload chunk
        await _uploadSingleChunk(
          receiver: receiver,
          transferId: transferId,
          chunkIndex: chunk.index,
          chunkData: dataToSend,
          originalSize: chunk.size,
          senderToken: senderToken,
          senderId: sender.id,
          encrypted: encryptionKey != null,
        );
        
        // Update progress
        state.markChunkSent(chunk.index, chunk.size);
        onProgress?.call(state.bytesSent, state.fileSize);
        
        _emitProgress(state);
      }
      
      debugPrint('✅ Connection $connectionId: Complete');
    } finally {
      await raf.close();
    }
  }

  /// Upload a single chunk
  Future<void> _uploadSingleChunk({
    required Device receiver,
    required String transferId,
    required int chunkIndex,
    required Uint8List chunkData,
    required int originalSize,
    required String senderToken,
    required String senderId,
    required bool encrypted,
  }) async {
    final url = Uri.parse(
      'http://${receiver.ipAddress}:${receiver.port}/transfer/chunk'
    );
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Transfer-Id': transferId,
        'X-Chunk-Index': chunkIndex.toString(),
        'X-Original-Size': originalSize.toString(),
        'X-Sender-Token': senderToken,
        'X-Sender-Id': senderId,
        'X-Encrypted': encrypted.toString(),
      },
      body: chunkData,
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode != 200) {
      throw Exception('Chunk upload failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Initiate parallel transfer with receiver
  Future<Map<String, dynamic>> _initiateParallelTransfer({
    required Device receiver,
    required String transferId,
    required String fileName,
    required int fileSize,
    required String fileHash,
    required int totalChunks,
    required int chunkSize,
    required Device sender,
    required String senderToken,
    required bool encrypted,
  }) async {
    final url = Uri.parse(
      'http://${receiver.ipAddress}:${receiver.port}/transfer/parallel/initiate'
    );
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transferId': transferId,
          'fileName': fileName,
          'fileSize': fileSize,
          'fileHash': fileHash,
          'totalChunks': totalChunks,
          'chunkSize': chunkSize,
          'senderId': sender.id,
          'senderName': sender.name,
          'senderToken': senderToken,
          'encrypted': encrypted,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Notify receiver that all chunks have been sent
  Future<void> _notifyTransferComplete({
    required Device receiver,
    required String transferId,
    required String fileHash,
  }) async {
    final url = Uri.parse(
      'http://${receiver.ipAddress}:${receiver.port}/transfer/parallel/complete'
    );
    
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transferId': transferId,
        'fileHash': fileHash,
      }),
    ).timeout(const Duration(seconds: 10));
  }

  /// Encrypt a chunk using AES-256-GCM
  Future<Uint8List> _encryptChunk(Uint8List plaintext, SecretKey secretKey) async {
    final nonce = _aesGcm.newNonce();
    
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine: nonce (12) + ciphertext + mac (16)
    final result = Uint8List(12 + secretBox.cipherText.length + 16);
    int offset = 0;

    result.setRange(offset, offset + 12, nonce);
    offset += 12;

    result.setRange(offset, offset + secretBox.cipherText.length, secretBox.cipherText);
    offset += secretBox.cipherText.length;

    result.setRange(offset, offset + 16, secretBox.mac.bytes);

    return result;
  }

  /// Decrypt a chunk
  Future<Uint8List> decryptChunk(Uint8List encryptedData, SecretKey secretKey) async {
    if (encryptedData.length < 28) {
      throw Exception('Data too small to decrypt');
    }

    final nonce = encryptedData.sublist(0, 12);
    final mac = encryptedData.sublist(encryptedData.length - 16);
    final ciphertext = encryptedData.sublist(12, encryptedData.length - 16);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    
    return Uint8List.fromList(plaintext);
  }

  void _emitProgress(ParallelTransferState state) {
    if (!_progressController.isClosed) {
      _progressController.add(ParallelProgress(
        transferId: state.transferId,
        fileName: state.fileName,
        bytesSent: state.bytesSent,
        totalBytes: state.fileSize,
        chunksSent: state.chunksSent,
        totalChunks: state.totalChunks,
        percentage: state.percentage,
      ));
    }
  }

  /// Cancel a transfer
  void cancelTransfer(String transferId) {
    final state = _activeTransfers[transferId];
    if (state != null) {
      state.cancel();
      _activeTransfers.remove(transferId);
    }
  }

  /// Get chunk writer manager (for receiver)
  ChunkWriterManager get writerManager => _writerManager;

  /// Cleanup
  Future<void> dispose() async {
    await _writerManager.closeAll();
    await _progressController.close();
    _activeTransfers.clear();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// State for tracking parallel transfer progress
class ParallelTransferState {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  
  final Set<int> _sentChunks = {};
  int _bytesSent = 0;
  bool _isCancelled = false;

  ParallelTransferState({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
  });

  void markChunkSent(int chunkIndex, int chunkSize) {
    if (!_sentChunks.contains(chunkIndex)) {
      _sentChunks.add(chunkIndex);
      _bytesSent += chunkSize;
    }
  }

  int get chunksSent => _sentChunks.length;
  int get bytesSent => _bytesSent;
  double get percentage => totalChunks > 0 ? _sentChunks.length / totalChunks : 0;
  bool get isComplete => _sentChunks.length == totalChunks;
  bool get isCancelled => _isCancelled;
  
  void cancel() => _isCancelled = true;
}

/// Progress update for parallel transfer
class ParallelProgress {
  final String transferId;
  final String fileName;
  final int bytesSent;
  final int totalBytes;
  final int chunksSent;
  final int totalChunks;
  final double percentage;

  ParallelProgress({
    required this.transferId,
    required this.fileName,
    required this.bytesSent,
    required this.totalBytes,
    required this.chunksSent,
    required this.totalChunks,
    required this.percentage,
  });

  @override
  String toString() => 'Progress: $chunksSent/$totalChunks chunks (${(percentage * 100).toStringAsFixed(1)}%)';
}
