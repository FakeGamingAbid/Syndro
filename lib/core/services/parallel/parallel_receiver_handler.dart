import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';

import 'parallel_config.dart';
import 'chunk_writer_service.dart';
import '../streaming_hash_service.dart';
import '../file_service.dart';

/// Handles receiving parallel chunk transfers
/// 
/// Integrates with your existing HTTP server in transfer_service.dart
class ParallelReceiverHandler {
  final FileService _fileService;
  final ChunkWriterManager _writerManager = ChunkWriterManager();
  final Map<String, ParallelReceiveSession> _sessions = {};
  
  // Encryption
  final AesGcm _aesGcm = AesGcm.with256bits();
  
  // Progress callback
  void Function(String transferId, int bytesReceived, int totalBytes)? onProgress;
  
  // Completion callback
  void Function(String transferId, String filePath)? onComplete;

  ParallelReceiverHandler(this._fileService);

  /// Handle parallel transfer initiation
  /// 
  /// Add this route to your server: POST /transfer/parallel/initiate
  Future<Map<String, dynamic>> handleInitiate(Map<String, dynamic> data) async {
    final transferId = data['transferId'] as String;
    final fileName = data['fileName'] as String;
    final fileSize = data['fileSize'] as int;
    final fileHash = data['fileHash'] as String;
    final totalChunks = data['totalChunks'] as int;
    final chunkSize = data['chunkSize'] as int;
    final senderId = data['senderId'] as String;
    final senderName = data['senderName'] as String;
    final encrypted = data['encrypted'] as bool? ?? false;
    
    debugPrint('📥 Parallel transfer initiated: $fileName');
    debugPrint('   Size: ${_formatBytes(fileSize)}, Chunks: $totalChunks');
    
    try {
      // Get download directory
      final downloadDir = await _fileService.getDownloadDirectory();
      final sanitizedName = _fileService.sanitizeFilename(fileName);
      final filePath = '$downloadDir${Platform.pathSeparator}$sanitizedName';
      
      // Create config
      final config = ParallelConfig(
        connections: 4,
        chunkSize: chunkSize,
        minFileSize: 0,
        enabled: true,
      );
      
      // Create chunk writer
      final writer = await _writerManager.createWriter(
        fileId: transferId,
        filePath: filePath,
        totalSize: fileSize,
        config: config,
      );
      
      // Create session
      _sessions[transferId] = ParallelReceiveSession(
        transferId: transferId,
        fileName: sanitizedName,
        filePath: filePath,
        fileSize: fileSize,
        fileHash: fileHash,
        totalChunks: totalChunks,
        chunkSize: chunkSize,
        senderId: senderId,
        senderName: senderName,
        encrypted: encrypted,
        writer: writer,
      );
      
      return {
        'success': true,
        'transferId': transferId,
        'message': 'Ready to receive chunks',
      };
    } catch (e) {
      debugPrint('Error initiating parallel receive: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Handle incoming chunk
  /// 
  /// Add this route to your server: POST /transfer/chunk
  Future<Map<String, dynamic>> handleChunk({
    required String transferId,
    required int chunkIndex,
    required Uint8List chunkData,
    required int originalSize,
    required bool encrypted,
    SecretKey? decryptionKey,
  }) async {
    final session = _sessions[transferId];
    if (session == null) {
      return {'success': false, 'error': 'Unknown transfer'};
    }
    
    try {
      // Decrypt if needed
      Uint8List dataToWrite;
      if (encrypted && decryptionKey != null) {
        dataToWrite = await _decryptChunk(chunkData, decryptionKey);
      } else {
        dataToWrite = chunkData;
      }
      
      // Write chunk
      await session.writer.writeChunk(chunkIndex, dataToWrite);
      
      // Update session
      session.chunksReceived++;
      session.bytesReceived += dataToWrite.length;
      
      // Emit progress
      onProgress?.call(transferId, session.bytesReceived, session.fileSize);
      
      return {
        'success': true,
        'chunkIndex': chunkIndex,
        'chunksReceived': session.chunksReceived,
        'totalChunks': session.totalChunks,
      };
    } catch (e) {
      debugPrint('Error receiving chunk $chunkIndex: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle transfer completion notification
  /// 
  /// Add this route to your server: POST /transfer/parallel/complete
  Future<Map<String, dynamic>> handleComplete({
    required String transferId,
    required String fileHash,
  }) async {
    final session = _sessions[transferId];
    if (session == null) {
      return {'success': false, 'error': 'Unknown transfer'};
    }
    
    try {
      // Check if all chunks received
      if (!session.writer.isComplete) {
        final missing = session.writer.getMissingChunks();
        return {
          'success': false,
          'error': 'Missing chunks: $missing',
          'missingChunks': missing,
        };
      }
      
      // Finalize file
      final file = await session.writer.finalize();
      
      // Verify hash
      debugPrint('📝 Verifying file hash...');
      final calculatedHash = await StreamingHashService.calculateFileHash(file);
      
      if (calculatedHash != fileHash) {
        // Hash mismatch - delete file
        await file.delete();
        _sessions.remove(transferId);
        
        return {
          'success': false,
          'error': 'Hash mismatch - file corrupted',
          'expectedHash': fileHash,
          'calculatedHash': calculatedHash,
        };
      }
      
      debugPrint('✅ File verified and saved: ${session.filePath}');
      
      // Cleanup
      _sessions.remove(transferId);
      await _writerManager.removeWriter(transferId);
      
      // Notify completion
      onComplete?.call(transferId, session.filePath);
      
      return {
        'success': true,
        'filePath': session.filePath,
        'fileSize': session.fileSize,
        'verified': true,
      };
    } catch (e) {
      debugPrint('Error completing transfer: $e');
      
      // Cleanup on error
      await session.writer.abort();
      _sessions.remove(transferId);
      await _writerManager.removeWriter(transferId);
      
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Decrypt a chunk
  Future<Uint8List> _decryptChunk(Uint8List encryptedData, SecretKey secretKey) async {
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

  /// Get session info
  ParallelReceiveSession? getSession(String transferId) => _sessions[transferId];

  /// Abort a transfer
  Future<void> abortTransfer(String transferId) async {
    final session = _sessions[transferId];
    if (session != null) {
      await session.writer.abort();
      _sessions.remove(transferId);
      await _writerManager.removeWriter(transferId);
    }
  }

  /// Cleanup all sessions
  Future<void> dispose() async {
    for (final session in _sessions.values) {
      await session.writer.abort();
    }
    _sessions.clear();
    await _writerManager.closeAll();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// Session state for receiving parallel transfer
class ParallelReceiveSession {
  final String transferId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileHash;
  final int totalChunks;
  final int chunkSize;
  final String senderId;
  final String senderName;
  final bool encrypted;
  final ChunkWriterService writer;
  
  int chunksReceived = 0;
  int bytesReceived = 0;
  DateTime startTime = DateTime.now();

  ParallelReceiveSession({
    required this.transferId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileHash,
    required this.totalChunks,
    required this.chunkSize,
    required this.senderId,
    required this.senderName,
    required this.encrypted,
    required this.writer,
  });

  double get progress => totalChunks > 0 ? chunksReceived / totalChunks : 0;
  bool get isComplete => chunksReceived == totalChunks;
}
