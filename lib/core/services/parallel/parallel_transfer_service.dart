import 'dart:async' show Completer, FutureOr, StreamController;
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

    debugPrint('📝 Calculating file hash (streaming)...');
    final fileHash = await StreamingHashService.calculateFileHash(file);
    debugPrint('   Hash: ${fileHash.substring(0, 16)}...');

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

      if (initResponse['success'] != true) {
        throw Exception(
            'Failed to initiate parallel transfer: ${initResponse['error']}');
      }

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

      await Future.wait(futures);

      await _notifyTransferComplete(
        receiver: receiver,
        transferId: transferId,
        fileHash: fileHash,
      );

      debugPrint('✅ Parallel transfer complete: $fileName');
    } catch (e) {
      debugPrint('❌ Parallel transfer failed: $e');
      rethrow;
    } finally {
      await _transfersLock.synchronized(() async {
        _activeTransfers.remove(transferId);
      });
    }
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

    final raf = await file.open(mode: FileMode.read);

    try {
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
    } finally {
      await raf.close();
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
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
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

    await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transferId': transferId,
            'fileHash': fileHash,
          }),
        )
        .timeout(const Duration(seconds: 10));
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
    if (!_progressController.isClosed && !_isDisposed) {
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

  void cancelTransfer(String transferId) {
    final state = _activeTransfers[transferId];
    if (state != null) {
      state.cancel();
      _activeTransfers.remove(transferId);
    }
  }

  ChunkWriterManager get writerManager => _writerManager;

  Future<void> dispose() async {
    _isDisposed = true;

    // Cancel all active transfers first to unblock any pending lock waiters
    for (final state in _activeTransfers.values) {
      state.cancel();
    }
    _activeTransfers.clear();

    // FIX (Bug #21): Dispose the transfer lock so any pending waiters are released
    _transfersLock.dispose();

    for (final client in _clientPool) {
      client.close();
    }
    _clientPool.clear();

    await _writerManager.closeAll();

    if (!_progressController.isClosed) {
      await _progressController.close();
    }
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

  Future<T> synchronized<T>(FutureOr<T> Function() action) async {
    if (_isDisposed) {
      throw StateError('Lock has been disposed');
    }

    while (_lock != null) {
      await _lock;
    }

    final completer = Completer<void>();
    _lock = completer.future;

    try {
      return await action();
    } finally {
      _lock = null;
      completer.complete();
    }
  }

  /// Release any pending waiters so they don't hang on dispose
  void dispose() {
    _isDisposed = true;
    _lock = null;
  }
}
