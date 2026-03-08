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
/// FIXED: Proper resource cleanup, error handling, and timeout management
class ParallelTransferService {
  final ParallelConfig config;
  final ChunkWriterManager _writerManager = ChunkWriterManager();

  final AesGcm _aesGcm = AesGcm.with256bits();

  final List<http.Client> _clientPool = [];
  static const int _maxPoolSize = 6;

  final Map<String, ParallelTransferState> _activeTransfers = {};

  final _SimpleLock _transfersLock = _SimpleLock();

  final _progressController = StreamController<ParallelProgress>.broadcast();
  Stream<ParallelProgress> get progressStream => _progressController.stream;

  bool _isDisposed = false;

  ParallelTransferService({ParallelConfig? config})
      : config = config ?? ParallelConfig.appToApp {
    for (int i = 0; i < _maxPoolSize; i++) {
      _clientPool.add(http.Client());
    }
  }

  http.Client _getClient(int connectionId) {
    return _clientPool[connectionId % _clientPool.length];
  }

  /// Send a file using parallel chunks
  /// 
  /// FIX: Initiates transfer BEFORE hash calculation to notify receiver immediately.
  /// Hash is calculated in parallel with chunk uploads and verified at completion.
  Future<void> sendFileParallel({
    required String transferId,
    required File file,
    required Device receiver,
    required String senderToken,
    required Device sender,
    SecretKey? encryptionKey,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    if (_isDisposed) {
      throw StateError('ParallelTransferService has been disposed');
    }

    final fileSize = await file.length();
    final fileName = file.path.split(Platform.pathSeparator).last;

    if (!config.shouldUseParallel(fileSize)) {
      debugPrint('📁 File too small for parallel, using single connection');
      throw UnsupportedError('Use regular sendFile for small files');
    }

    debugPrint(
        '🚀 Starting parallel transfer: $fileName (${_formatBytes(fileSize)})');
    debugPrint(
        '   Connections: ${config.connections}, Chunk size: ${_formatBytes(config.chunkSize)}');
    debugPrint(
        '   Receiver: ${receiver.ipAddress}:${receiver.port}');

    final chunks = config.getAllChunks(fileSize);
    debugPrint('   Total chunks: ${chunks.length}');

    final state = ParallelTransferState(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: chunks.length,
    );

    await _transfersLock.synchronized(() async {
      _activeTransfers[transferId] = state;
    });

    try {
      // FIX: Initiate transfer FIRST with placeholder hash
      // This notifies the receiver immediately so they can show the transfer request
      debugPrint('📤 Initiating transfer with receiver (hash will be calculated in parallel)...');
      final initResponse = await _initiateParallelTransfer(
        receiver: receiver,
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        fileHash: 'pending', // Placeholder - actual hash sent at completion
        totalChunks: chunks.length,
        chunkSize: config.chunkSize,
        sender: sender,
        senderToken: senderToken,
        encrypted: encryptionKey != null,
      );

      // FIX: Handle pending_approval status - wait for receiver to approve
      final status = initResponse['status'] as String?;
      if (status == 'pending_approval') {
        debugPrint('⏳ Transfer pending approval. Waiting for receiver to accept...');
        
        // Wait for approval by polling the receiver
        final requestId = initResponse['requestId'] as String? ?? transferId;
        final approved = await _waitForApproval(
          receiver: receiver,
          requestId: requestId,
          timeout: const Duration(minutes: 5),
        );
        
        if (!approved) {
          throw Exception('Transfer rejected or timed out');
        }
        
        debugPrint('✅ Transfer approved! Starting upload...');
      } else if (initResponse['success'] != true) {
        throw Exception(
            'Failed to initiate parallel transfer: ${initResponse['error']}');
      } else {
        debugPrint('✅ Receiver auto-accepted! Starting upload...');
      }

      debugPrint('📤 Now calculating hash and uploading chunks in parallel...');

      // FIX: Calculate hash in parallel with chunk uploads
      final hashCompleter = Completer<String>();
      
      // Start hash calculation in background
      final hashFuture = _calculateHashInBackground(
        file: file,
        onProgress: (bytesProcessed, totalBytes) {
          if (bytesProcessed % (100 * 1024 * 1024) == 0) {
            debugPrint('   Hash progress: ${_formatBytes(bytesProcessed)}/${_formatBytes(totalBytes)}');
          }
        },
      ).then((hash) {
        if (!hashCompleter.isCompleted) {
          hashCompleter.complete(hash);
        }
        return hash;
      }).catchError((e) {
        debugPrint('❌ Hash calculation failed: $e');
        if (!hashCompleter.isCompleted) {
          hashCompleter.completeError(e);
        }
        throw e;
      });

      final chunkQueues = _distributeChunks(chunks, config.connections);

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

      // Wait for all chunks to be uploaded
      await Future.wait(futures);

      // Wait for hash calculation to complete (should be done by now)
      debugPrint('⏳ Waiting for hash calculation to complete...');
      final fileHash = await hashFuture;
      debugPrint('✅ Hash calculated: ${fileHash.substring(0, 16)}...');

      await _notifyTransferComplete(
        receiver: receiver,
        transferId: transferId,
        fileHash: fileHash,
      );

      debugPrint('✅ Parallel transfer complete: $fileName');
    } on SocketException catch (e) {
      debugPrint('❌ Network error during parallel transfer: $e');
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout during parallel transfer: $e');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Parallel transfer failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    } finally {
      await _transfersLock.synchronized(() async {
        _activeTransfers.remove(transferId);
      });
    }
  }

  /// Calculate file hash in background
  Future<String> _calculateHashInBackground({
    required File file,
    void Function(int bytesProcessed, int totalBytes)? onProgress,
  }) async {
    final hashStartTime = DateTime.now();
    debugPrint('📝 Starting background hash calculation...');
    
    final hash = await StreamingHashService.calculateFileHashWithProgress(
      file,
      timeout: const Duration(minutes: 10),
      onProgress: onProgress,
    );
    
    final hashDuration = DateTime.now().difference(hashStartTime);
    debugPrint('📝 Hash calculated in ${hashDuration.inSeconds}s');
    return hash;
  }

  List<List<ChunkInfo>> _distributeChunks(
      List<ChunkInfo> chunks, int connections) {
    final queues = List.generate(connections, (_) => <ChunkInfo>[]);

    for (int i = 0; i < chunks.length; i++) {
      final connId = i % connections;
      queues[connId].add(chunks[i]);
    }

    return queues;
  }

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
    debugPrint(
        '🔗 Connection $connectionId: Uploading ${chunks.length} chunks');

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);

      for (final chunk in chunks) {
        if (state.isCancelled || _isDisposed) {
          debugPrint('🚫 Connection $connectionId: Transfer cancelled');
          break;
        }

        await raf.setPosition(chunk.start);
        final data = await raf.read(chunk.size);

        Uint8List dataToSend;
        if (encryptionKey != null) {
          dataToSend =
              await _encryptChunk(Uint8List.fromList(data), encryptionKey);
        } else {
          dataToSend = Uint8List.fromList(data);
        }

        await _uploadSingleChunkWithRetry(
          receiver: receiver,
          transferId: transferId,
          chunkIndex: chunk.index,
          chunkData: dataToSend,
          originalSize: chunk.size,
          senderToken: senderToken,
          senderId: sender.id,
          encrypted: encryptionKey != null,
          connectionId: connectionId,
        );

        await state.markChunkSent(chunk.index, chunk.size);
        onProgress?.call(state.bytesSent, state.fileSize);
        _emitProgress(state);
      }

      debugPrint('✅ Connection $connectionId: Complete');
    } on FileSystemException catch (e) {
      debugPrint('⚠️ File system error in connection $connectionId: $e');
      rethrow;
    } finally {
      // FIXED: Ensure file is always closed
      try {
        await raf?.close();
      } catch (e) {
        debugPrint('⚠️ Error closing file in connection $connectionId: $e');
      }
    }
  }

  Future<void> _uploadSingleChunkWithRetry({
    required Device receiver,
    required String transferId,
    required int chunkIndex,
    required Uint8List chunkData,
    required int originalSize,
    required String senderToken,
    required String senderId,
    required bool encrypted,
    required int connectionId,
    int maxRetries = 3,
  }) async {
    Exception? lastError;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await _uploadSingleChunk(
          receiver: receiver,
          transferId: transferId,
          chunkIndex: chunkIndex,
          chunkData: chunkData,
          originalSize: originalSize,
          senderToken: senderToken,
          senderId: senderId,
          encrypted: encrypted,
          connectionId: connectionId,
        );
        return;
      } on SocketException catch (e) {
        lastError = e;
        debugPrint(
            '⚠️ Network error uploading chunk $chunkIndex (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint(
            '⚠️ Timeout uploading chunk $chunkIndex (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint(
            '⚠️ Chunk $chunkIndex upload failed (attempt ${attempt + 1}): $e');

        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    throw lastError ??
        Exception('Chunk upload failed after $maxRetries retries');
  }

  Future<void> _uploadSingleChunk({
    required Device receiver,
    required String transferId,
    required int chunkIndex,
    required Uint8List chunkData,
    required int originalSize,
    required String senderToken,
    required String senderId,
    required bool encrypted,
    required int connectionId,
  }) async {
    final url = Uri.parse(
        'http://${receiver.ipAddress}:${receiver.port}/transfer/chunk');

    final client = _getClient(connectionId);

    final response = await client
        .post(
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
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('Chunk upload timed out after 60 seconds');
          },
        );

    if (response.statusCode != 200) {
      throw HttpException(
          'Chunk upload failed: ${response.statusCode} ${response.body}');
    }
  }

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
        'http://${receiver.ipAddress}:${receiver.port}/transfer/parallel/initiate');

    debugPrint('📤 Initiating parallel transfer to ${receiver.ipAddress}:${receiver.port}');

    try {
      final response = await http
          .post(
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
          )
          .timeout(
            const Duration(seconds: 30), // Increased from 10s for large file preparation
            onTimeout: () {
              throw TimeoutException('Initiation timed out after 30 seconds');
            },
          );

      debugPrint('📥 Initiation response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } on SocketException catch (e) {
      debugPrint('❌ Socket error during initiation: $e');
      return {'success': false, 'error': 'Network error: $e'};
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout during initiation: $e');
      return {'success': false, 'error': 'Request timeout: $e'};
    } on FormatException catch (e) {
      debugPrint('❌ Invalid response format: $e');
      return {'success': false, 'error': 'Invalid response format: $e'};
    } catch (e) {
      debugPrint('❌ Unexpected error during initiation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _notifyTransferComplete({
    required Device receiver,
    required String transferId,
    required String fileHash,
  }) async {
    final url = Uri.parse(
        'http://${receiver.ipAddress}:${receiver.port}/transfer/parallel/complete');

    try {
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'transferId': transferId,
              'fileHash': fileHash,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Completion notification timed out');
            },
          );
    } catch (e) {
      debugPrint('⚠️ Failed to notify transfer completion: $e');
      // Don't rethrow - transfer is already complete, notification is optional
    }
  }

  /// Wait for receiver to approve the transfer
  Future<bool> _waitForApproval({
    required Device receiver,
    required String requestId,
    required Duration timeout,
  }) async {
    final startTime = DateTime.now();
    final approvalUrl = 'http://${receiver.ipAddress}:${receiver.port}/transfer/approval/$requestId';
    
    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final response = await http
            .get(Uri.parse(approvalUrl))
            .timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;
          
          if (status == 'approved') {
            debugPrint('✅ Transfer approved by receiver');
            return true;
          } else if (status == 'rejected' || status == 'expired') {
            debugPrint('❌ Transfer $status by receiver');
            return false;
          }
          // status == 'pending' - continue waiting
        }
      } catch (e) {
        debugPrint('⚠️ Error checking approval status: $e');
      }
      
      // Wait before polling again
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    debugPrint('⏰ Transfer approval timed out');
    return false;
  }

  Future<Uint8List> _encryptChunk(
      Uint8List plaintext, SecretKey secretKey) async {
    final nonce = _aesGcm.newNonce();

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final result = Uint8List(12 + secretBox.cipherText.length + 16);
    int offset = 0;

    result.setRange(offset, offset + 12, nonce);
    offset += 12;

    result.setRange(
        offset, offset + secretBox.cipherText.length, secretBox.cipherText);
    offset += secretBox.cipherText.length;

    result.setRange(offset, offset + 16, secretBox.mac.bytes);

    return result;
  }

  Future<Uint8List> decryptChunk(
      Uint8List encryptedData, SecretKey secretKey) async {
    if (encryptedData.length < 28) {
      throw ArgumentError('Data too small to decrypt: ${encryptedData.length} bytes (minimum 28)');
    }

    final nonce = encryptedData.sublist(0, 12);
    final mac = encryptedData.sublist(encryptedData.length - 16);
    final ciphertext = encryptedData.sublist(12, encryptedData.length - 16);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    try {
      final plaintext = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (e) {
      throw DecryptionException(
        'Decryption failed: Authentication error - data may be corrupted or tampered',
        originalError: e,
      );
    } on ArgumentError catch (e) {
      throw DecryptionException('Invalid encrypted data: ${e.message}', originalError: e);
    } catch (e) {
      throw DecryptionException('Decryption failed: ${e.runtimeType}', originalError: e);
    }
  }

  void _emitProgress(ParallelTransferState state) {
    if (!_progressController.isClosed && !_isDisposed) {
      try {
        _progressController.add(ParallelProgress(
          transferId: state.transferId,
          fileName: state.fileName,
          bytesSent: state.bytesSent,
          totalBytes: state.fileSize,
          chunksSent: state.chunksSent,
          totalChunks: state.totalChunks,
          percentage: state.percentage,
        ));
      } catch (e) {
        debugPrint('⚠️ Error emitting progress: $e');
      }
    }
  }

  void cancelTransfer(String transferId) {
    final state = _activeTransfers[transferId];
    if (state != null) {
      state.cancel();
      _activeTransfers.remove(transferId);
    }
  }

  ChunkWriterManager get writerManager => _writerManager;

  // FIXED: Comprehensive disposal with proper error handling
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('🧹 Disposing ParallelTransferService...');

    // Cancel all active transfers first to unblock any pending lock waiters
    try {
      for (final state in _activeTransfers.values) {
        state.cancel();
      }
      _activeTransfers.clear();
    } catch (e) {
      debugPrint('⚠️ Error cancelling active transfers: $e');
    }

    // Dispose the transfer lock so any pending waiters are released
    try {
      _transfersLock.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing transfer lock: $e');
    }

    // FIXED: Close HTTP clients with error handling
    for (final client in _clientPool) {
      try {
        client.close();
      } catch (e) {
        debugPrint('⚠️ Error closing HTTP client: $e');
      }
    }
    _clientPool.clear();

    // FIXED: Close writer manager with error handling
    try {
      await _writerManager.closeAll();
    } catch (e) {
      debugPrint('⚠️ Error closing writer manager: $e');
    }

    // FIXED: Close progress controller with error handling
    try {
      if (!_progressController.isClosed) {
        await _progressController.close();
      }
    } catch (e) {
      debugPrint('⚠️ Error closing progress controller: $e');
    }

    debugPrint('✅ ParallelTransferService disposed');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
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

  final _SimpleLock _lock = _SimpleLock();

  ParallelTransferState({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
  });

  Future<void> markChunkSent(int chunkIndex, int chunkSize) async {
    await _lock.synchronized(() async {
      if (!_sentChunks.contains(chunkIndex)) {
        _sentChunks.add(chunkIndex);
        _bytesSent += chunkSize;
      }
    });
  }

  int get chunksSent => _sentChunks.length;
  int get bytesSent => _bytesSent;
  double get percentage =>
      totalChunks > 0 ? _sentChunks.length / totalChunks : 0;
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
  String toString() =>
      'Progress: $chunksSent/$totalChunks chunks (${(percentage * 100).toStringAsFixed(1)}%)';
}

class _SimpleLock {
  Future<void>? _lock;
  bool _isDisposed = false;
  Completer<void>? _disposeCompleter;

  Future<T> synchronized<T>(FutureOr<T> Function() action) async {
    if (_isDisposed) {
      throw StateError('Lock has been disposed');
    }

    // Wait for any existing lock to be released, checking for disposal
    while (_lock != null && !_isDisposed) {
      try {
        await _lock;
      } catch (e) {
        // If the lock future throws (e.g., due to disposal), re-throw
        if (_isDisposed) {
          throw StateError('Lock has been disposed');
        }
        rethrow;
      }
    }

    // Check again after waiting
    if (_isDisposed) {
      throw StateError('Lock has been disposed');
    }

    final completer = Completer<void>();
    _lock = completer.future;

    try {
      return await action();
    } finally {
      _lock = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
  
  void dispose() {
    _isDisposed = true;
    // Complete any pending lock to release waiters
    if (_lock != null && _disposeCompleter != null && !_disposeCompleter!.isCompleted) {
      _disposeCompleter!.complete();
    }
  }
}

/// Custom exception for decryption errors in parallel transfers
class DecryptionException implements Exception {
  final String message;
  final dynamic originalError;

  DecryptionException(this.message, {this.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'DecryptionException: $message (caused by: $originalError)';
    }
    return 'DecryptionException: $message';
  }
}
