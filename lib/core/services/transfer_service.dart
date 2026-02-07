import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../models/device.dart';
import '../models/transfer.dart';
import '../models/transfer_checkpoint.dart';
import '../database/database_helper.dart';
import 'encryption_service.dart';
import 'file_service.dart';
import 'checkpoint_manager.dart';
import 'background_transfer_service.dart';
import 'device_nickname_service.dart';

// ============================================
// 🚀 PARALLEL TRANSFER IMPORTS
// ============================================
import 'parallel/parallel_config.dart';
import 'parallel/parallel_receiver_handler.dart';
import 'parallel/parallel_transfer_service.dart';

/// Custom exception for transfer errors
class TransferException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  TransferException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'TransferException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Pending transfer request model
class PendingTransferRequest {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderToken;
  final List<TransferItem> items;
  final DateTime timestamp;
  final Uint8List? senderPublicKey; // NEW: For encryption

  PendingTransferRequest({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderToken,
    required this.items,
    required this.timestamp,
    this.senderPublicKey,
  });

  int get fileCount => items.length;
  int get totalSize => items.fold<int>(0, (sum, item) => sum + item.size);
}

/// Trusted device with verification token
class TrustedDevice {
  final String senderId;
  final String senderName;
  final String token;
  final DateTime trustedAt;

  TrustedDevice({
    required this.senderId,
    required this.senderName,
    required this.token,
    required this.trustedAt,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'token': token,
        'trustedAt': trustedAt.toIso8601String(),
      };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        token: json['token'] as String,
        trustedAt: DateTime.parse(json['trustedAt'] as String),
      );
}

/// Encryption session for a transfer
class EncryptionSession {
  final String sessionId;
  final SecretKey sharedSecret;
  final DateTime createdAt;

  EncryptionSession({
    required this.sessionId,
    required this.sharedSecret,
    required this.createdAt,
  });
}

class TransferService {
  final FileService _fileService;
  final CheckpointManager _checkpointManager = CheckpointManager();
  final DeviceNicknameService _nicknameService = DeviceNicknameService();
  final _uuid = const Uuid();

  final _transferController = StreamController<Transfer>.broadcast();
  final Map<String, Transfer> _activeTransfers = {};
  final Map<String, StreamController<TransferProgress>> _progressControllers = {};

  // ============================================
  // 🚀 PARALLEL TRANSFER PROPERTIES
  // ============================================
  late final ParallelReceiverHandler _parallelReceiver;
  ParallelTransferService? _parallelSender;
  ParallelConfig? _parallelConfig;

  // Secure storage for trusted devices
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _trustedDevicesKey = 'syndro_trusted_devices';

  // Track authorized senders with tokens
  final Map<String, TrustedDevice> _trustedDevices = {};
  final Map<String, PendingTransferRequest> _pendingRequests = {};

  // Stream controller for pending requests
  final _pendingRequestsController =
      StreamController<List<PendingTransferRequest>>.broadcast();

  HttpServer? _server;

  // Device info
  String _deviceId = '';
  String _deviceName = '';
  String _devicePlatform = '';
  String _deviceToken = '';

  static const int maxRetries = 3;
  static const int initialRetryDelaySeconds = 2;
  static const int _maxCompletedTransfers = 10;

  Timer? _pendingRequestsCleanupTimer;
  StreamSubscription<Map<String, dynamic>>? _notificationEventSubscription;

  // ============================================
  // 🔐 ENCRYPTION PROPERTIES
  // ============================================
  
  /// Enable/disable encryption (default: true)
  bool encryptionEnabled = true;
  
  /// AES-256-GCM cipher
  final AesGcm _aesGcm = AesGcm.with256bits();
  
  /// X25519 key exchange (same as Signal Protocol)
  final X25519 _keyExchange = X25519();
  
  /// Current device's key pair for encryption
  SimpleKeyPair? _encryptionKeyPair;
  
  /// Active encryption sessions (deviceId -> session)
  final Map<String, EncryptionSession> _encryptionSessions = {};

  // Callback for transfer request approval
  Function(String senderId, String senderName, List<TransferItem> items)?
      onTransferRequest;

  TransferService(this._fileService) {
    _loadTrustedDevices();
    _startPendingRequestsCleanup();
    _listenToNotificationEvents();
    _initializeEncryption(); // NEW
    _initializeParallelTransfer(); // Initialize parallel transfer
  }

  Stream<Transfer> get transferStream => _transferController.stream;
  List<Transfer> get activeTransfers => _activeTransfers.values.toList();
  List<PendingTransferRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  Stream<List<PendingTransferRequest>> get pendingRequestsStream =>
      _pendingRequestsController.stream;
  List<TrustedDevice> get trustedDevices => _trustedDevices.values.toList();
  
  /// Check if encryption is available
  bool get isEncryptionReady => _encryptionKeyPair != null;

  // ============================================
  // 🔐 ENCRYPTION METHODS
  // ============================================

  /// Initialize encryption key pair
  Future<void> _initializeEncryption() async {
    try {
      _encryptionKeyPair = await _keyExchange.newKeyPair();
      debugPrint('🔐 Encryption initialized (X25519 + AES-256-GCM)');
    } catch (e) {
      debugPrint('❌ Failed to initialize encryption: $e');
      encryptionEnabled = false;
    }
  }

  /// Get our public key for sharing
  Future<Uint8List?> getPublicKey() async {
    if (_encryptionKeyPair == null) return null;
    final publicKey = await _encryptionKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Perform key exchange and derive shared secret
  Future<SecretKey> _performKeyExchange(Uint8List theirPublicKeyBytes) async {
    if (_encryptionKeyPair == null) {
      throw EncryptionException('Encryption not initialized');
    }

    final theirPublicKey = SimplePublicKey(
      theirPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: _encryptionKeyPair!,
      remotePublicKey: theirPublicKey,
    );

    return sharedSecret;
  }

  /// Encrypt a chunk of data using AES-256-GCM
  /// Returns: [nonce (12 bytes) | ciphertext | mac (16 bytes)]
  Future<Uint8List> _encryptChunk(Uint8List plaintext, SecretKey secretKey) async {
    final nonce = _aesGcm.newNonce();
    
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine: nonce + ciphertext + mac
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

  /// Decrypt a chunk of data
  /// Input format: [nonce (12 bytes) | ciphertext | mac (16 bytes)]
  Future<Uint8List> _decryptChunk(Uint8List encryptedData, SecretKey secretKey) async {
    if (encryptedData.length < 28) {
      throw EncryptionException(
          'Data too small to decrypt: ${encryptedData.length} bytes');
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
    } catch (e) {
      throw EncryptionException('Decryption failed: Authentication error',
          originalError: e);
    }
  }

  /// Calculate SHA-256 hash for file integrity verification
  String _calculateHash(List<int> bytes) {
    return crypto_hash.sha256.convert(bytes).toString();
  }

  // ============================================
  // EXISTING METHODS (with encryption integration)
  // ============================================


  // ============================================
  // 🚀 PARALLEL TRANSFER INITIALIZATION
  // ============================================

  /// Initialize parallel transfer handlers
  void _initializeParallelTransfer() {
    _parallelReceiver = ParallelReceiverHandler(_fileService);
    
    // Set up progress callback
    _parallelReceiver.onProgress = (transferId, received, total) {
      final transfer = _activeTransfers[transferId];
      if (transfer != null) {
        final updatedTransfer = transfer.copyWith(
          status: TransferStatus.transferring,
          progress: TransferProgress(
            bytesTransferred: received,
            totalBytes: total,
          ),
        );
        _activeTransfers[transferId] = updatedTransfer;
        _transferController.add(updatedTransfer);
        
        // Update notification
        BackgroundTransferService.updateProgress(
          title: 'Receiving file',
          fileName: transfer.items.first.name,
          progress: (received / total * 100).toInt(),
          bytesTransferred: received,
          totalBytes: total,
        );
      }
    };
    
    // Set up completion callback
    _parallelReceiver.onComplete = (transferId, filePath) {
      final transfer = _activeTransfers[transferId];
      if (transfer != null) {
        final updatedTransfer = transfer.copyWith(
          status: TransferStatus.completed,
          progress: TransferProgress(
            bytesTransferred: transfer.progress.totalBytes,
            totalBytes: transfer.progress.totalBytes,
          ),
        );
        _activeTransfers[transferId] = updatedTransfer;
        _transferController.add(updatedTransfer);
        
        // Clean up
        _cleanupProgressController(transferId);
      }
    };
    
    debugPrint('⚡ Parallel transfer handlers initialized');
  }

  // ============================================
  // 🚀 PARALLEL TRANSFER HANDLERS
  // ============================================

  /// Handle parallel transfer initiation
  Future<void> _handleParallelInitiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _parallelReceiver.handleInitiate(data);
      
      await _sendResponse(request, 
        result['success'] ? HttpStatus.ok : HttpStatus.badRequest, 
        result
      );
    } catch (e) {
      await _sendError(request, 'Error initiating parallel transfer: $e');
    }
  }

  /// Handle chunk upload
  Future<void> _handleChunkUpload(HttpRequest request) async {
    try {
      final transferId = request.headers.value('X-Transfer-Id');
      final chunkIndexStr = request.headers.value('X-Chunk-Index');
      final originalSizeStr = request.headers.value('X-Original-Size');
      final encryptedStr = request.headers.value('X-Encrypted');
      
      if (transferId == null || chunkIndexStr == null) {
        await _sendBadRequest(request, 'Missing required headers');
        return;
      }
      
      final chunkIndex = int.parse(chunkIndexStr);
      final originalSize = int.tryParse(originalSizeStr ?? '0') ?? 0;
      final encrypted = encryptedStr == 'true';
      
      // Read chunk data
      final chunks = <int>[];
      await for (final chunk in request) {
        chunks.addAll(chunk);
      }
      final chunkData = Uint8List.fromList(chunks);
      
      // Get decryption key if encrypted
      SecretKey? decryptionKey;
      if (encrypted) {
        final session = _parallelReceiver.getSession(transferId);
        if (session != null) {
          decryptionKey = _encryptionSessions[session.senderId]?.sharedSecret;
        }
      }
      
      final result = await _parallelReceiver.handleChunk(
        transferId: transferId,
        chunkIndex: chunkIndex,
        chunkData: chunkData,
        originalSize: originalSize,
        encrypted: encrypted,
        decryptionKey: decryptionKey,
      );
      
      await _sendResponse(request,
        result['success'] ? HttpStatus.ok : HttpStatus.badRequest,
        result
      );
    } catch (e) {
      await _sendError(request, 'Error receiving chunk: $e');
    }
  }

  /// Handle chunk download (for browser)
  Future<void> _handleChunkDownload(HttpRequest request) async {
    try {
      final pathParts = request.uri.path.split('/');
      // Path: /transfer/chunk/:transferId/:chunkIndex
      if (pathParts.length < 5) {
        await _sendBadRequest(request, 'Invalid path');
        return;
      }
      
      final transferId = pathParts[3];
      // final chunkIndex = int.parse(pathParts[4]); // Not yet implemented
      
      // Get the file and read the chunk
      final session = _parallelReceiver.getSession(transferId);
      if (session == null) {
        await _sendNotFound(request, 'Transfer not found');
        return;
      }
      
      // This would need to be implemented based on your send-to-browser flow
      // For now, return error
      await _sendError(request, 'Browser chunk download not implemented');
    } catch (e) {
      await _sendError(request, 'Error serving chunk: $e');
    }
  }

  /// Handle parallel transfer completion
  Future<void> _handleParallelComplete(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final transferId = data['transferId'] as String;
      final fileHash = data['fileHash'] as String;
      
      final result = await _parallelReceiver.handleComplete(
        transferId: transferId,
        fileHash: fileHash,
      );
      
      if (result['success']) {
        // Show completion notification
        await BackgroundTransferService.showTransferComplete(
          fileName: result['filePath'].toString().split(Platform.pathSeparator).last,
          filePath: result['filePath'] as String,
          fileCount: 1,
          totalSize: result['fileSize'] as int,
        );
      }
      
      await _sendResponse(request,
        result['success'] ? HttpStatus.ok : HttpStatus.badRequest,
        result
      );
    } catch (e) {
      await _sendError(request, 'Error completing parallel transfer: $e');
    }
  }

  void _listenToNotificationEvents() {
    _notificationEventSubscription =
        BackgroundTransferService.transferEvents.listen((event) {
      final eventType = event['event'] as String?;
      final requestId = event['requestId'] as String?;

      switch (eventType) {
        case 'cancelled':
          debugPrint('📱 Transfer cancelled from notification');
          for (final transferId in _activeTransfers.keys.toList()) {
            cancelTransfer(transferId);
          }
          break;
        case 'accepted':
          debugPrint('📱 Transfer accepted from notification: $requestId');
          if (requestId != null) {
            approveTransfer(requestId, trustSender: false);
          }
          break;
        case 'rejected':
          debugPrint('📱 Transfer rejected from notification: $requestId');
          if (requestId != null) {
            rejectTransfer(requestId);
          }
          break;
      }
    });
  }

  Future<void> _loadTrustedDevices() async {
    try {
      final jsonString = await _secureStorage.read(key: _trustedDevicesKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        for (final json in jsonList) {
          final device = TrustedDevice.fromJson(json as Map<String, dynamic>);
          _trustedDevices[device.senderId] = device;
        }
        debugPrint('✅ Loaded ${_trustedDevices.length} trusted devices');
      }
    } catch (e) {
      debugPrint('Error loading trusted devices: $e');
    }
  }

  Future<void> _saveTrustedDevices() async {
    try {
      final jsonList = _trustedDevices.values.map((d) => d.toJson()).toList();
      await _secureStorage.write(
        key: _trustedDevicesKey,
        value: jsonEncode(jsonList),
      );
      debugPrint('✅ Saved ${_trustedDevices.length} trusted devices');
    } catch (e) {
      debugPrint('Error saving trusted devices: $e');
    }
  }

  void _startPendingRequestsCleanup() {
    _pendingRequestsCleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _cleanupExpiredPendingRequests(),
    );
  }

  void _cleanupExpiredPendingRequests() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _pendingRequests.entries) {
      if (now.difference(entry.value.timestamp).inMinutes > 5) {
        expiredIds.add(entry.key);
      }
    }

    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _pendingRequests.remove(id);
      }
      if (!_pendingRequestsController.isClosed) {
        _pendingRequestsController.add(_pendingRequests.values.toList());
      }
      debugPrint(
          '🧹 Cleaned up ${expiredIds.length} expired pending requests');
    }
  }

  Future<void> setDeviceInfo({
    required String id,
    required String name,
    required String platform,
  }) async {
    _deviceId = id;
    _devicePlatform = platform;

    try {
      final customNickname = await _nicknameService.getNickname(id);
      if (customNickname != null && customNickname.isNotEmpty) {
        _deviceName = customNickname;
        debugPrint(
            '✅ Using custom nickname for transfer service: $_deviceName');
      } else {
        _deviceName = name;
      }
    } catch (e) {
      debugPrint('Error getting custom nickname: $e');
      _deviceName = name;
    }

    _deviceToken = _generateSecureToken();
  }

  Future<void> updateDeviceName() async {
    try {
      final customNickname = await _nicknameService.getNickname(_deviceId);
      if (customNickname != null && customNickname.isNotEmpty) {
        _deviceName = customNickname;
        debugPrint('✅ Updated device name to: $_deviceName');
      }
    } catch (e) {
      debugPrint('Error updating device name: $e');
    }
  }

  String _generateSecureToken() {
    final random = math.Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _generateCheckpointKey(
      String senderId, String receiverId, List<TransferItem> items) {
    final itemsSignature =
        items.map((item) => '${item.name}:${item.size}').join('|');
    final keySource = '$senderId->$receiverId:$itemsSignature';
    final bytes = utf8.encode(keySource);
    int hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return 'ckpt_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  Future<void> startServer(int port) async {
    if (_deviceId.isEmpty) {
      _deviceId = const Uuid().v4();
    }
    if (_deviceName.isEmpty) {
      _deviceName = await _getDeviceName();
    }
    if (_devicePlatform.isEmpty) {
      _devicePlatform = Platform.operatingSystem;
    }
    if (_deviceToken.isEmpty) {
      _deviceToken = _generateSecureToken();
    }

    // Ensure encryption is initialized
    if (_encryptionKeyPair == null) {
      await _initializeEncryption();
    _initializeParallelTransfer(); // Initialize parallel transfer
    }

    // Try ports in range [port, port + 5]
    for (int p = port; p <= port + 5; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        debugPrint('🚀 Transfer server running on port ${_server!.port}');
        debugPrint('🔐 Encryption: ${encryptionEnabled ? "ENABLED" : "DISABLED"}');
        _serve();
        break; // Success!
      } catch (e) {
        if (p == port + 5) {
          debugPrint('Failed to start transfer server on any port in range: $e');
          throw TransferException('Failed to start server',
              code: 'SERVER_START_FAILED', originalError: e);
        }
        debugPrint('Port $p busy, trying next port...');
      }
    }

    if (_server != null) {
      // ============================================
      // 🚀 AUTO-DETECT PARALLEL CONFIG
      // ============================================
      _parallelConfig = await ParallelConfig.autoDetect();
      _parallelSender = ParallelTransferService(config: _parallelConfig);
      debugPrint('⚡ Parallel transfer: ${_parallelConfig!.connections} connections, ${_parallelConfig!.chunkSize ~/ (1024 * 1024)}MB chunks');
    }
  }

  Future<String> _getDeviceName() async {
    if (_deviceId.isNotEmpty) {
      try {
        final customNickname = await _nicknameService.getNickname(_deviceId);
        if (customNickname != null && customNickname.isNotEmpty) {
          return customNickname;
        }
      } catch (e) {
        debugPrint('Error getting custom nickname: $e');
      }
    }

    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isWindows) {
        return Platform.environment['COMPUTERNAME'] ?? 'Windows PC';
      } else if (Platform.isLinux) {
        return Platform.environment['HOSTNAME'] ?? 'Linux PC';
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return 'Syndro Device';
  }

  Future<void> _serve() async {
    if (_server == null) return;

    await for (final request in _server!) {
      try {
        await _handleRequest(request);
      } catch (e, stackTrace) {
        debugPrint('Error handling request: $e');
        debugPrint('Stack trace: $stackTrace');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal server error');
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final uri = request.requestedUri;
    final path = uri.path;
    final method = request.method;

    try {
      // Serve syndro.json for device discovery
      if (method == 'GET' && path == '/syndro.json') {
        await _serveDeviceInfo(request);
        return;
      }

      // POST /key-exchange - NEW: Encryption key exchange
      if (method == 'POST' && path == '/key-exchange') {
        await _handleKeyExchange(request);
        return;
      }

      // POST /transfer/initiate

      // ============================================
      // 🚀 PARALLEL TRANSFER ROUTES
      // ============================================

      // POST /transfer/parallel/initiate
      if (method == 'POST' && path == '/transfer/parallel/initiate') {
        await _handleParallelInitiate(request);
        return;
      }

      // POST /transfer/chunk
      if (method == 'POST' && path == '/transfer/chunk') {
        await _handleChunkUpload(request);
        return;
      }

      // GET /transfer/chunk/:transferId/:chunkIndex
      if (method == 'GET' && path.startsWith('/transfer/chunk/')) {
        await _handleChunkDownload(request);
        return;
      }

      // POST /transfer/parallel/complete
      if (method == 'POST' && path == '/transfer/parallel/complete') {
        await _handleParallelComplete(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/initiate') {
        await _handleTransferInitiate(request);
        return;
      }

      // GET /transfer/approval/<requestId>
      if (method == 'GET' && path.startsWith('/transfer/approval/')) {
        final requestId = path.split('/').last;
        await _handleApprovalCheck(request, requestId);
        return;
      }

      // POST /transfer/upload (unencrypted - legacy)
      if (method == 'POST' && path == '/transfer/upload') {
        await _handleFileUpload(request);
        return;
      }

      // POST /transfer/upload-encrypted - NEW
      if (method == 'POST' && path == '/transfer/upload-encrypted') {
        await _handleEncryptedFileUpload(request);
        return;
      }

      // GET /transfer/status/<transferId>
      if (method == 'GET' && path.startsWith('/transfer/status/')) {
        final transferId = path.split('/').last;
        await _handleTransferStatus(request, transferId);
        return;
      }

      await _sendNotFound(request, 'Not found');
    } catch (e, stackTrace) {
      debugPrint('Error handling request: $e');
      debugPrint('Stack trace: $stackTrace');
      await _sendError(request, 'Internal server error');
    }
  }

  /// Handle key exchange request - NEW
  Future<void> _handleKeyExchange(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = _validateAndParseJson(body);

      if (data == null) {
        await _sendBadRequest(request, 'Invalid JSON');
        return;
      }

      final theirDeviceId = data['deviceId'] as String?;
      final theirPublicKeyList = data['publicKey'] as List?;

      if (theirDeviceId == null || theirPublicKeyList == null) {
        await _sendBadRequest(request, 'Missing deviceId or publicKey');
        return;
      }

      final theirPublicKeyBytes =
          Uint8List.fromList(theirPublicKeyList.cast<int>());

      // Derive shared secret
      final sharedSecret = await _performKeyExchange(theirPublicKeyBytes);

      // Store session
      _encryptionSessions[theirDeviceId] = EncryptionSession(
        sessionId: '$_deviceId-$theirDeviceId',
        sharedSecret: sharedSecret,
        createdAt: DateTime.now(),
      );

      // Return our public key
      final myPublicKey = await getPublicKey();

      await _sendResponse(request, HttpStatus.ok, {
        'deviceId': _deviceId,
        'publicKey': myPublicKey?.toList() ?? [],
      });

      debugPrint('🔐 Key exchange completed with $theirDeviceId');
    } catch (e) {
      debugPrint('Key exchange error: $e');
      await _sendError(request, 'Key exchange failed');
    }
  }

  Future<void> _serveDeviceInfo(HttpRequest request) async {
    String currentName = _deviceName;
    try {
      final customNickname = await _nicknameService.getNickname(_deviceId);
      if (customNickname != null && customNickname.isNotEmpty) {
        currentName = customNickname;
      }
    } catch (e) {
      debugPrint('Error getting nickname for device info: $e');
    }

    final myPublicKey = await getPublicKey();

    final info = {
      'id': _deviceId,
      'name': currentName,
      'os': _devicePlatform,
      'platform': _devicePlatform,
      'version': '2.0',
      'encryption': encryptionEnabled,
      'publicKey': myPublicKey?.toList(), // NEW: Include public key
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(info));
    await request.response.close();
  }

  Future<void> _sendResponse(
      HttpRequest request, int statusCode, Map<String, dynamic> body) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _sendNotFound(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write(message);
    await request.response.close();
  }

  Future<void> _sendBadRequest(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(message);
    await request.response.close();
  }

  Future<void> _sendUnauthorized(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write(message);
    await request.response.close();
  }

  Future<void> _sendError(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(message);
    await request.response.close();
  }

  Map<String, dynamic>? _validateAndParseJson(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return data;
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return null;
    }
  }

  bool _validateTransferData(Map<String, dynamic> data) {
    if (!data.containsKey('senderId') || data['senderId'] is! String) {
      return false;
    }
    if (!data.containsKey('id') || data['id'] is! String) return false;
    if (!data.containsKey('items') || data['items'] is! List) return false;
    if (!data.containsKey('senderToken') || data['senderToken'] is! String) {
      return false;
    }

    final senderId = data['senderId'] as String;
    if (senderId.isEmpty || senderId.length > 100) return false;

    final items = data['items'] as List;
    if (items.isEmpty || items.length > 1000) return false;

    return true;
  }

  Future<void> _handleTransferInitiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = _validateAndParseJson(body);

      if (data == null) {
        await _sendBadRequest(request, 'Invalid JSON format');
        return;
      }

      if (!_validateTransferData(data)) {
        await _sendBadRequest(request, 'Missing or invalid required fields');
        return;
      }

      final senderId = data['senderId'] as String;
      final senderName = data['senderName'] as String? ?? 'Unknown Device';
      final senderToken = data['senderToken'] as String;
      final requestId = data['id'] as String;
      final senderPublicKeyList = data['publicKey'] as List?; // NEW

      Uint8List? senderPublicKey;
      if (senderPublicKeyList != null) {
        senderPublicKey = Uint8List.fromList(senderPublicKeyList.cast<int>());
      }

      List<TransferItem> items;
      try {
        items = (data['items'] as List).map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid item format');
          }
          return TransferItem.fromJson(item);
        }).toList();
      } catch (e) {
        await _sendBadRequest(request, 'Invalid transfer items format');
        return;
      }

      if (items.isEmpty) {
        await _sendBadRequest(request, 'No items to transfer');
        return;
      }

      // Check if sender is trusted with matching token
      final trustedDevice = _trustedDevices[senderId];
      if (trustedDevice != null && trustedDevice.token == senderToken) {
        // Perform key exchange if public key provided
        if (senderPublicKey != null && encryptionEnabled) {
          final sharedSecret = await _performKeyExchange(senderPublicKey);
          _encryptionSessions[senderId] = EncryptionSession(
            sessionId: '$_deviceId-$senderId',
            sharedSecret: sharedSecret,
            createdAt: DateTime.now(),
          );
        }

        _approveTransferRequest(
            requestId, senderId, senderName, senderToken, items);

        final myPublicKey = await getPublicKey();

        await _sendResponse(request, HttpStatus.ok, {
          'status': 'accepted',
          'transferId': requestId,
          'authorized': true,
          'encryption': encryptionEnabled,
          'publicKey': myPublicKey?.toList(),
        });
        return;
      }

      // Store pending request with token and public key
      _pendingRequests[requestId] = PendingTransferRequest(
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        senderToken: senderToken,
        items: items,
        timestamp: DateTime.now(),
        senderPublicKey: senderPublicKey,
      );

      _pendingRequestsController.add(_pendingRequests.values.toList());

      await BackgroundTransferService.showTransferRequest(
        senderName: senderName,
        fileCount: items.length,
        totalSize: items.fold<int>(0, (sum, item) => sum + item.size),
        requestId: requestId,
      );

      onTransferRequest?.call(senderId, senderName, items);

      await _sendResponse(request, HttpStatus.ok, {
        'status': 'pending_approval',
        'requestId': requestId,
        'message': 'Waiting for receiver approval',
      });
    } catch (e, stackTrace) {
      debugPrint('Error initiating transfer: $e');
      debugPrint('Stack trace: $stackTrace');
      await _sendError(request, 'Error initiating transfer');
    }
  }

  Future<void> _handleApprovalCheck(
      HttpRequest request, String requestId) async {
    if (requestId.isEmpty || requestId.length > 100) {
      await _sendBadRequest(request, 'Invalid request ID');
      return;
    }

    final pending = _pendingRequests[requestId];
    if (pending == null) {
      final transfer = _activeTransfers[requestId];
      if (transfer != null) {
        final myPublicKey = await getPublicKey();
        await _sendResponse(request, HttpStatus.ok, {
          'status': 'approved',
          'transferId': requestId,
          'encryption': encryptionEnabled,
          'publicKey': myPublicKey?.toList(),
        });
        return;
      }
      await _sendResponse(request, HttpStatus.ok, {
        'status': 'rejected',
        'message': 'Request was rejected or expired',
      });
      return;
    }

    if (DateTime.now().difference(pending.timestamp).inMinutes > 5) {
      _pendingRequests.remove(requestId);
      _pendingRequestsController.add(_pendingRequests.values.toList());
      await _sendResponse(request, HttpStatus.ok, {
        'status': 'expired',
        'message': 'Request expired',
      });
      return;
    }

    await _sendResponse(request, HttpStatus.ok, {
      'status': 'pending',
      'message': 'Waiting for approval',
    });
  }

  void approveTransfer(String requestId, {bool trustSender = false}) {
    final pending = _pendingRequests[requestId];
    if (pending == null) {
      debugPrint(
          'Warning: Attempted to approve non-existent request: $requestId');
      return;
    }

    if (trustSender) {
      _trustedDevices[pending.senderId] = TrustedDevice(
        senderId: pending.senderId,
        senderName: pending.senderName,
        token: pending.senderToken,
        trustedAt: DateTime.now(),
      );
      _saveTrustedDevices();
    }

    // Perform key exchange if public key available
    if (pending.senderPublicKey != null && encryptionEnabled) {
      _performKeyExchange(pending.senderPublicKey!).then((sharedSecret) {
        _encryptionSessions[pending.senderId] = EncryptionSession(
          sessionId: '$_deviceId-${pending.senderId}',
          sharedSecret: sharedSecret,
          createdAt: DateTime.now(),
        );
        debugPrint('🔐 Key exchange completed on approval');
      }).catchError((e) {
        debugPrint('❌ Key exchange failed on approval: $e');
      });
    }

    _approveTransferRequest(
      requestId,
      pending.senderId,
      pending.senderName,
      pending.senderToken,
      pending.items,
    );

    _pendingRequests.remove(requestId);
    _pendingRequestsController.add(_pendingRequests.values.toList());
    BackgroundTransferService.dismissTransferRequest();
  }

  void rejectTransfer(String requestId) {
    final removed = _pendingRequests.remove(requestId);
    if (removed == null) {
      debugPrint(
          'Warning: Attempted to reject non-existent request: $requestId');
    }
    _pendingRequestsController.add(_pendingRequests.values.toList());
    BackgroundTransferService.stopBackgroundTransfer();
    BackgroundTransferService.dismissTransferRequest();
  }

  void _approveTransferRequest(
    String requestId,
    String senderId,
    String senderName,
    String senderToken,
    List<TransferItem> items,
  ) {
    _cleanupCompletedTransfers();

    final transfer = Transfer(
      id: requestId,
      senderId: senderId,
      receiverId: _deviceId,
      items: items,
      status: TransferStatus.pending,
      progress: const TransferProgress(bytesTransferred: 0, totalBytes: 0),
      createdAt: DateTime.now(),
    );

    _activeTransfers[transfer.id] = transfer;
    _transferController.add(transfer);

    BackgroundTransferService.startBackgroundTransfer(
      title: 'Receiving from $senderName',
      fileName:
          items.length == 1 ? items.first.name : '${items.length} files',
    );
  }

  void _cleanupCompletedTransfers() {
    final completedIds = <String>[];

    for (final entry in _activeTransfers.entries) {
      final status = entry.value.status;
      if (status == TransferStatus.completed ||
          status == TransferStatus.failed ||
          status == TransferStatus.cancelled) {
        completedIds.add(entry.key);
      }
    }

    if (completedIds.length > _maxCompletedTransfers) {
      final toRemove = completedIds
          .map((id) => _activeTransfers[id]!)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final removeCount = completedIds.length - _maxCompletedTransfers;
      for (int i = 0; i < removeCount; i++) {
        final transfer = toRemove[i];
        _activeTransfers.remove(transfer.id);
        _cleanupProgressController(transfer.id);
        debugPrint('🧹 Cleaned up old transfer: ${transfer.id}');
      }
    }
  }

  void _cleanupProgressController(String transferId) {
    final controller = _progressControllers.remove(transferId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Handle encrypted file upload - NEW
  Future<void> _handleEncryptedFileUpload(HttpRequest request) async {
    IOSink? fileSink;
    String? tempFilePath;

    try {
      final transferId = request.headers.value('x-transfer-id');
      final fileName = request.headers.value('x-file-name');
      final originalSizeHeader = request.headers.value('x-original-size');
      final senderId = request.headers.value('x-sender-id');
      final fileHash = request.headers.value('x-file-hash'); // NEW: integrity check

      final originalSize =
          originalSizeHeader != null ? int.tryParse(originalSizeHeader) ?? 0 : 0;

      // Validate headers
      if (transferId == null || transferId.isEmpty) {
        await _sendBadRequest(request, 'Missing transfer ID');
        return;
      }
      if (fileName == null || fileName.isEmpty) {
        await _sendBadRequest(request, 'Missing file name');
        return;
      }
      if (senderId == null || senderId.isEmpty) {
        await _sendBadRequest(request, 'Missing sender ID');
        return;
      }

      // Verify transfer is authorized
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        await _sendUnauthorized(request, 'Transfer not authorized');
        return;
      }

      if (transfer.senderId != senderId) {
        await _sendUnauthorized(request, 'Sender ID mismatch');
        return;
      }

      // Get encryption session
      final session = _encryptionSessions[senderId];
      if (session == null) {
        await _sendUnauthorized(request, 'No encryption session');
        return;
      }

      // Sanitize filename
      final sanitizedFileName = _fileService.sanitizeFilename(fileName);

      // Update transfer status
      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
      );
      _transferController.add(_activeTransfers[transferId]!);

      // Prepare file paths
      final downloadDir = await _fileService.getDownloadDirectory();
      final finalFilePath =
          '$downloadDir${Platform.pathSeparator}$sanitizedFileName';
      tempFilePath = '$finalFilePath.tmp';

      // Verify path
      if (!_fileService.isPathWithinDirectory(finalFilePath, downloadDir)) {
        await _sendBadRequest(request, 'Invalid filename');
        return;
      }

      // Ensure directory exists
      final dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Open temp file for writing
      final tempFile = File(tempFilePath);
      fileSink = tempFile.openWrite();

      int bytesReceived = 0;
      List<int> buffer = [];
      List<int> allDecryptedBytes = []; // For hash verification

      // Process encrypted stream
      await for (final chunk in request) {
        buffer.addAll(chunk);

        // Process complete encrypted chunks
        while (buffer.length >= 4) {
          // Read chunk size (4 bytes, big endian)
          final sizeBytes = Uint8List.fromList(buffer.sublist(0, 4));
          final byteData = ByteData.view(sizeBytes.buffer);
          final chunkSize = byteData.getUint32(0, Endian.big);

          if (buffer.length < 4 + chunkSize) {
            break; // Wait for more data
          }

          // Extract encrypted chunk
          final encryptedChunk =
              Uint8List.fromList(buffer.sublist(4, 4 + chunkSize));
          buffer = buffer.sublist(4 + chunkSize);

          // Decrypt chunk
          final decrypted =
              await _decryptChunk(encryptedChunk, session.sharedSecret);

          // Write to file
          fileSink.add(decrypted);
          allDecryptedBytes.addAll(decrypted);
          bytesReceived += decrypted.length;

          // Update progress
          final progressPercent = originalSize > 0
              ? ((bytesReceived / originalSize) * 100).toInt()
              : 0;

          if (progressPercent % 5 == 0) {
            await BackgroundTransferService.updateProgress(
              title: 'Receiving (encrypted)...',
              fileName: sanitizedFileName,
              progress: progressPercent,
              bytesTransferred: bytesReceived,
              totalBytes: originalSize,
            );

            final updatedTransfer = _activeTransfers[transferId]!.copyWith(
              progress: TransferProgress(
                bytesTransferred: bytesReceived,
                totalBytes: originalSize > 0 ? originalSize : bytesReceived,
              ),
            );
            _activeTransfers[transferId] = updatedTransfer;
            _transferController.add(updatedTransfer);
          }
        }
      }

      // Flush and close
      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      // Verify file integrity if hash provided
      if (fileHash != null && fileHash.isNotEmpty) {
        final calculatedHash = _calculateHash(allDecryptedBytes);
        if (calculatedHash != fileHash) {
          // Delete corrupted file
          await File(tempFilePath).delete();
          throw TransferException('File integrity check failed',
              code: 'HASH_MISMATCH');
        }
        debugPrint('✅ File integrity verified');
      }

      // Rename temp to final
      final tempFileRef = File(tempFilePath);
      final finalFile = File(finalFilePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFileRef.rename(finalFilePath);
      tempFilePath = null;

      // Update to completed
      final completedTransfer = _activeTransfers[transferId]!.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(
          bytesTransferred: bytesReceived,
          totalBytes: bytesReceived,
        ),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      await BackgroundTransferService.showTransferComplete(
        fileName: sanitizedFileName,
        filePath: finalFilePath,
        fileCount: 1,
        totalSize: bytesReceived,
      );

      await DatabaseHelper.instance
          .insertTransfer(completedTransfer, null, null);

      await _sendResponse(request, HttpStatus.ok, {
        'status': 'completed',
        'bytesReceived': bytesReceived,
        'filePath': finalFilePath,
        'encrypted': true,
        'verified': fileHash != null,
      });

      debugPrint('🔐 Encrypted file received: $finalFilePath');
      _cleanupCompletedTransfers();

    } catch (e, stackTrace) {
      debugPrint('Error receiving encrypted file: $e');
      debugPrint('Stack trace: $stackTrace');

      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      await BackgroundTransferService.stopBackgroundTransfer();
      await _sendError(request, 'Error receiving encrypted file');
    }
  }

  /// Handle unencrypted file upload (legacy support)
  Future<void> _handleFileUpload(HttpRequest request) async {
    IOSink? fileSink;
    String? tempFilePath;

    try {
      final transferId = request.headers.value('x-transfer-id');
      final fileName = request.headers.value('x-file-name');
      final fileSizeHeader = request.headers.value('x-file-size');
      final senderId = request.headers.value('x-sender-id');
      final senderToken = request.headers.value('x-sender-token');

      final fileSize =
          fileSizeHeader != null ? int.tryParse(fileSizeHeader) ?? 0 : 0;

      if (transferId == null || transferId.isEmpty) {
        await _sendBadRequest(request, 'Missing transfer ID header');
        return;
      }
      if (fileName == null || fileName.isEmpty) {
        await _sendBadRequest(request, 'Missing file name header');
        return;
      }
      if (senderId == null || senderId.isEmpty) {
        await _sendBadRequest(request, 'Missing sender ID header');
        return;
      }
      if (senderToken == null || senderToken.isEmpty) {
        await _sendBadRequest(request, 'Missing sender token header');
        return;
      }

      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        await _sendUnauthorized(
            request, 'Transfer not authorized. Request approval first.');
        return;
      }

      if (transfer.senderId != senderId) {
        debugPrint(
            'Security: Sender ID mismatch. Expected: ${transfer.senderId}, Got: $senderId');
        await _sendUnauthorized(request, 'Sender ID mismatch');
        return;
      }

      final sanitizedFileName = _fileService.sanitizeFilename(fileName);
      if (sanitizedFileName != fileName) {
        debugPrint(
            'Security: Filename was sanitized. Original: $fileName, Sanitized: $sanitizedFileName');
      }

      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
      );
      _transferController.add(_activeTransfers[transferId]!);

      final downloadDir = await _fileService.getDownloadDirectory();
      final finalFilePath =
          '$downloadDir${Platform.pathSeparator}$sanitizedFileName';
      tempFilePath = '$finalFilePath.tmp';

      if (!_fileService.isPathWithinDirectory(finalFilePath, downloadDir)) {
        debugPrint(
            'Security: Path traversal attempt detected for file: $fileName');
        await _sendBadRequest(request, 'Invalid filename');
        return;
      }

      final dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final tempFile = File(tempFilePath);
      fileSink = tempFile.openWrite();

      int bytesReceived = 0;
      int lastProgressPercent = 0;
      int lastProgressBytes = 0;

      await for (final chunk in request) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;

        final progressPercent =
            fileSize > 0 ? ((bytesReceived / fileSize) * 100).toInt() : 0;

        if (progressPercent - lastProgressPercent >= 2 ||
            bytesReceived - lastProgressBytes > 512 * 1024) {
          lastProgressPercent = progressPercent;
          lastProgressBytes = bytesReceived;

          await BackgroundTransferService.updateProgress(
            title: 'Receiving files...',
            fileName: sanitizedFileName,
            progress: progressPercent,
            bytesTransferred: bytesReceived,
            totalBytes: fileSize,
          );

          final updatedTransfer = _activeTransfers[transferId]!.copyWith(
            progress: TransferProgress(
              bytesTransferred: bytesReceived,
              totalBytes: fileSize > 0 ? fileSize : bytesReceived,
            ),
          );
          _activeTransfers[transferId] = updatedTransfer;
          _transferController.add(updatedTransfer);
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      final tempFileRef = File(tempFilePath);
      final finalFile = File(finalFilePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFileRef.rename(finalFilePath);
      tempFilePath = null;

      final completedTransfer = _activeTransfers[transferId]!.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(
          bytesTransferred: bytesReceived,
          totalBytes: bytesReceived,
        ),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      await BackgroundTransferService.showTransferComplete(
        fileName: sanitizedFileName,
        filePath: finalFilePath,
        fileCount: 1,
        totalSize: bytesReceived,
      );

      await DatabaseHelper.instance
          .insertTransfer(completedTransfer, null, null);

      await _sendResponse(request, HttpStatus.ok, {
        'status': 'completed',
        'bytesReceived': bytesReceived,
        'filePath': finalFilePath,
        'encrypted': false,
      });

      _cleanupCompletedTransfers();
    } catch (e, stackTrace) {
      debugPrint('Error uploading file: $e');
      debugPrint('Stack trace: $stackTrace');

      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      await BackgroundTransferService.stopBackgroundTransfer();
      await _sendError(request, 'Error uploading file');
    }
  }

  Future<void> _handleTransferStatus(
      HttpRequest request, String transferId) async {
    if (transferId.isEmpty || transferId.length > 100) {
      await _sendBadRequest(request, 'Invalid transfer ID');
      return;
    }

    final transfer = _activeTransfers[transferId];
    if (transfer == null) {
      await _sendNotFound(request, 'Transfer not found');
      return;
    }

    await _sendResponse(request, HttpStatus.ok, {
      'id': transfer.id,
      'status': transfer.status.name,
      'progress': {
        'bytesTransferred': transfer.progress.bytesTransferred,
        'totalBytes': transfer.progress.totalBytes,
        'percentage': transfer.progress.percentage,
      },
    });
  }

  /// Send files with optional encryption
  Future<void> sendFiles({
    required Device sender,
    required Device receiver,
    required List<TransferItem> items,
    bool? encrypted, // null = auto-detect based on receiver capability
  }) async {
    if (items.isEmpty) {
      throw TransferException('No items to transfer', code: 'EMPTY_ITEMS');
    }

    _cleanupCompletedTransfers();

    final checkpointKey =
        _generateCheckpointKey(sender.id, receiver.id, items);
    final checkpoint = await _checkpointManager.loadCheckpoint(checkpointKey);
    final startIndex = checkpoint?.currentFileIndex ?? 0;
    final resumedBytes = checkpoint?.bytesTransferred ?? 0;
    final transferId = checkpoint != null ? checkpointKey : _uuid.v4();
    final totalSize = items.fold<int>(0, (sum, item) => sum + item.size);


    // ============================================
    // 🚀 PARALLEL TRANSFER DECISION
    // ============================================
    final useParallel = _parallelConfig?.shouldUseParallel(totalSize) ?? false;
    
    if (useParallel && items.length == 1 && _parallelSender != null) {
      // Single large file and parallel sender is ready - use parallel
      debugPrint('⚡ Using parallel transfer for large file (${totalSize ~/ (1024 * 1024)}MB)');
      
      final item = items.first;
      final file = File(item.path);
      
      // Get encryption key if enabled
      SecretKey? encryptionKey;
      final shouldEncrypt = encrypted ?? encryptionEnabled;
      if (shouldEncrypt && encryptionEnabled) {
        // Perform key exchange first
        final myPublicKey = await getPublicKey();
        
        // Request key exchange
        final keyExchangeUrl = 'http://${receiver.ipAddress}:${receiver.port}/key-exchange';
        try {
          final keyResponse = await http.post(
            Uri.parse(keyExchangeUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': sender.id,
              'publicKey': myPublicKey?.toList(),
            }),
          );
          
          if (keyResponse.statusCode == 200) {
            final keyData = jsonDecode(keyResponse.body);
            final receiverPublicKeyList = keyData['publicKey'] as List?;
            if (receiverPublicKeyList != null) {
              final receiverPublicKey = Uint8List.fromList(receiverPublicKeyList.cast<int>());
              encryptionKey = await _performKeyExchange(receiverPublicKey);
              _encryptionSessions[receiver.id] = EncryptionSession(
                sessionId: '${sender.id}-${receiver.id}',
                sharedSecret: encryptionKey,
                createdAt: DateTime.now(),
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Key exchange failed: $e');
        }
      }
      
      // Create transfer record
      final parallelTransfer = Transfer(
        id: transferId,
        senderId: sender.id,
        receiverId: receiver.id,
        items: items,
        status: TransferStatus.transferring,
        progress: TransferProgress(
          bytesTransferred: 0,
          totalBytes: totalSize,
        ),
        createdAt: DateTime.now(),
      );
      
      _activeTransfers[transferId] = parallelTransfer;
      _transferController.add(parallelTransfer);
      
      try {
        await _parallelSender!.sendFileParallel(
          transferId: transferId,
          file: file,
          receiver: receiver,
          senderToken: _deviceToken,
          sender: sender,
          encryptionKey: encryptionKey,
          onProgress: (sent, total) {
            final updatedTransfer = parallelTransfer.copyWith(
              status: TransferStatus.transferring,
              progress: TransferProgress(
                bytesTransferred: sent,
                totalBytes: total,
              ),
            );
            _activeTransfers[transferId] = updatedTransfer;
            _transferController.add(updatedTransfer);
            
            // Update notification
            BackgroundTransferService.updateProgress(
              title: 'Sending to ${receiver.name}',
              fileName: item.name,
              progress: (sent / total * 100).toInt(),
              bytesTransferred: sent,
              totalBytes: total,
            );
          },
        );
        
        // Mark as completed
        final completedTransfer = parallelTransfer.copyWith(
          status: TransferStatus.completed,
          progress: TransferProgress(
            bytesTransferred: totalSize,
            totalBytes: totalSize,
          ),
        );
        _activeTransfers[transferId] = completedTransfer;
        _transferController.add(completedTransfer);
        
        // Save to database
        await DatabaseHelper.instance.insertTransfer(completedTransfer, sender, receiver);
        
        // Show completion notification
        await BackgroundTransferService.showTransferComplete(
          fileName: item.name,
          filePath: item.path,
          fileCount: 1,
          totalSize: totalSize,
        );
        
        _cleanupProgressController(transferId);
        
        return; // Exit early - parallel transfer complete
        
      } catch (e) {
        debugPrint('❌ Parallel transfer failed: $e');
        final failedTransfer = parallelTransfer.copyWith(
          status: TransferStatus.failed,
          errorMessage: e.toString(),
        );
        _activeTransfers[transferId] = failedTransfer;
        _transferController.add(failedTransfer);
        
        BackgroundTransferService.stopBackgroundTransfer();
        _cleanupProgressController(transferId);
        
        rethrow;
      }
    }
    
    // Continue with sequential transfer if parallel not used
    debugPrint('Using sequential transfer for ${items.length} file(s)');


    if (checkpoint != null) {
      debugPrint(
          '📂 Resuming transfer from checkpoint: file $startIndex, $resumedBytes bytes');
    }

    final transfer = Transfer(
      id: transferId,
      senderId: sender.id,
      receiverId: receiver.id,
      items: items,
      status: TransferStatus.connecting,
      progress: TransferProgress(
        bytesTransferred: resumedBytes,
        totalBytes: totalSize,
      ),
      createdAt: DateTime.now(),
    );

    _activeTransfers[transferId] = transfer;
    _transferController.add(transfer);

    await BackgroundTransferService.startBackgroundTransfer(
      title: 'Sending to ${receiver.name}',
      fileName:
          items.length == 1 ? items.first.name : '${items.length} files',
    );

    try {
      // Get our public key for key exchange
      final myPublicKey = await getPublicKey();

      // Step 1: Initiate transfer with receiver
      final initiateUrl =
          'http://${receiver.ipAddress}:${receiver.port}/transfer/initiate';

      final initiateResponse = await _retryRequest(
        () => http.post(
          Uri.parse(initiateUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': transferId,
            'senderId': sender.id,
            'senderName': sender.name,
            'senderToken': _deviceToken,
            'receiverId': receiver.id,
            'items': items.map((item) => item.toJson()).toList(),
            'publicKey': myPublicKey?.toList(), // NEW: Send public key
          }),
        ),
      );

      if (initiateResponse.statusCode != 200) {
        throw TransferException(
          'Failed to initiate transfer',
          code: 'INITIATE_FAILED_${initiateResponse.statusCode}',
        );
      }

      final initiateData = _validateAndParseJson(initiateResponse.body);
      if (initiateData == null) {
        throw TransferException('Invalid response from receiver',
            code: 'INVALID_RESPONSE');
      }

      final status = initiateData['status'] as String? ?? '';
      final receiverSupportsEncryption =
          initiateData['encryption'] as bool? ?? false;
      final receiverPublicKeyList = initiateData['publicKey'] as List?;

      // Determine if we should use encryption
      bool useEncryption = encrypted ?? 
          (encryptionEnabled && receiverSupportsEncryption && receiverPublicKeyList != null);

      // Perform key exchange if encryption is enabled
      SecretKey? sharedSecret;
      if (useEncryption && receiverPublicKeyList != null) {
        try {
          final receiverPublicKey =
              Uint8List.fromList(receiverPublicKeyList.cast<int>());
          sharedSecret = await _performKeyExchange(receiverPublicKey);
          _encryptionSessions[receiver.id] = EncryptionSession(
            sessionId: '${sender.id}-${receiver.id}',
            sharedSecret: sharedSecret,
            createdAt: DateTime.now(),
          );
          debugPrint('🔐 Key exchange successful, encryption enabled');
        } catch (e) {
          debugPrint('❌ Key exchange failed, falling back to unencrypted: $e');
          useEncryption = false;
        }
      }

      // Handle approval pending
      if (status == 'pending_approval') {
        _activeTransfers[transferId] = transfer.copyWith(
          status: TransferStatus.pending,
        );
        _transferController.add(_activeTransfers[transferId]!);

        final approved = await _waitForApproval(
          receiver: receiver,
          requestId: transferId,
          timeout: const Duration(minutes: 5),
        );

        if (!approved) {
          throw TransferException('Transfer rejected or timed out',
              code: 'REJECTED');
        }
      }

      int totalBytesTransferred = checkpoint?.bytesTransferred ?? 0;

      // Step 2: Send each file
      for (int i = startIndex; i < items.length; i++) {
        final item = items[i];

        try {
          final file = File(item.path);
          if (!await file.exists()) {
            throw TransferException('File not found: ${item.path}',
                code: 'FILE_NOT_FOUND');
          }

          final fileSize = await file.length();

          if (useEncryption && sharedSecret != null) {
            // Send encrypted
            await _sendFileEncrypted(
              receiver: receiver,
              transferId: transferId,
              sender: sender,
              item: item,
              file: file,
              fileSize: fileSize,
              sharedSecret: sharedSecret,
              totalSize: totalSize,
              totalBytesTransferred: totalBytesTransferred,
            );
          } else {
            // Send unencrypted (legacy)
            await _sendFileUnencrypted(
              receiver: receiver,
              transferId: transferId,
              sender: sender,
              item: item,
              file: file,
              fileSize: fileSize,
              totalSize: totalSize,
              totalBytesTransferred: totalBytesTransferred,
            );
          }

          totalBytesTransferred += fileSize;

          // Save checkpoint
          await _checkpointManager.saveCheckpoint(
            TransferCheckpoint(
              transferId: transferId,
              fileId: item.path,
              bytesTransferred: totalBytesTransferred,
              timestamp: DateTime.now(),
              currentFileIndex: i + 1,
              totalFiles: items.length,
            ),
          );
        } catch (e, stackTrace) {
          debugPrint('Error sending file ${item.name}: $e');
          debugPrint('Stack trace: $stackTrace');
          rethrow;
        }
      }

      // Transfer completed
      final completedTransfer = transfer.copyWith(
        status: TransferStatus.completed,
        progress:
            TransferProgress(bytesTransferred: totalSize, totalBytes: totalSize),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      await BackgroundTransferService.showTransferComplete(
        fileName:
            items.length == 1 ? items.first.name : '${items.length} files',
        filePath: '',
        fileCount: items.length,
        totalSize: totalSize,
      );

      await DatabaseHelper.instance
          .insertTransfer(completedTransfer, sender, receiver);
      await _checkpointManager.clearCheckpoint(transferId);

      debugPrint(
          '✅ Transfer completed ${useEncryption ? "(encrypted)" : "(unencrypted)"}');

      _cleanupCompletedTransfers();
    } catch (e, stackTrace) {
      debugPrint('Error sending files: $e');
      debugPrint('Stack trace: $stackTrace');

      await BackgroundTransferService.stopBackgroundTransfer();

      final failedTransfer = transfer.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      _activeTransfers[transferId] = failedTransfer;
      _transferController.add(failedTransfer);

      await DatabaseHelper.instance
          .insertTransfer(failedTransfer, sender, receiver);

      if (e is TransferException) {
        rethrow;
      }
      throw TransferException('Transfer failed', originalError: e);
    }
  }

  /// Send file encrypted - NEW
  Future<void> _sendFileEncrypted({
    required Device receiver,
    required String transferId,
    required Device sender,
    required TransferItem item,
    required File file,
    required int fileSize,
    required SecretKey sharedSecret,
    required int totalSize,
    required int totalBytesTransferred,
  }) async {
    final uploadUrl =
        'http://${receiver.ipAddress}:${receiver.port}/transfer/upload-encrypted';

    // Calculate file hash for integrity verification
    final fileBytes = await file.readAsBytes();
    final fileHash = _calculateHash(fileBytes);

    final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
    request.headers['x-transfer-id'] = transferId;
    request.headers['x-sender-id'] = sender.id;
    request.headers['x-sender-token'] = _deviceToken;
    request.headers['x-file-name'] = item.name;
    request.headers['x-original-size'] = fileSize.toString();
    request.headers['x-file-hash'] = fileHash; // NEW: integrity check
    request.headers['Content-Type'] = 'application/octet-stream';

    int bytesSent = 0;
    const chunkSize = 1024 * 1024; // 1MB chunks

    // Stream file, encrypt chunks, and send
    final fileStream = file.openRead();
    List<int> buffer = [];

    fileStream.listen(
      (chunk) async {
        buffer.addAll(chunk);

        // Process full chunks
        while (buffer.length >= chunkSize) {
          final plainChunk = Uint8List.fromList(buffer.sublist(0, chunkSize));
          buffer = buffer.sublist(chunkSize);

          // Encrypt chunk
          final encrypted = await _encryptChunk(plainChunk, sharedSecret);

          // Prepend size (4 bytes, big endian)
          final sizeBytes = Uint8List(4);
          final byteData = ByteData.view(sizeBytes.buffer);
          byteData.setUint32(0, encrypted.length, Endian.big);

          request.sink.add(sizeBytes);
          request.sink.add(encrypted);

          bytesSent += plainChunk.length;

          // Update progress
          final progressPercent =
              ((totalBytesTransferred + bytesSent) / totalSize * 100).toInt();

          BackgroundTransferService.updateProgress(
            title: 'Sending (encrypted) to ${receiver.name}',
            fileName: item.name,
            progress: progressPercent,
            bytesTransferred: totalBytesTransferred + bytesSent,
            totalBytes: totalSize,
          );

          final updatedTransfer = _activeTransfers[transferId]!.copyWith(
            status: TransferStatus.transferring,
            progress: TransferProgress(
              bytesTransferred: totalBytesTransferred + bytesSent,
              totalBytes: totalSize,
            ),
          );
          _activeTransfers[transferId] = updatedTransfer;
          _transferController.add(updatedTransfer);
        }
      },
      onDone: () async {
        // Send remaining buffer
        if (buffer.isNotEmpty) {
          final plainChunk = Uint8List.fromList(buffer);
          final encrypted = await _encryptChunk(plainChunk, sharedSecret);

          final sizeBytes = Uint8List(4);
          final byteData = ByteData.view(sizeBytes.buffer);
          byteData.setUint32(0, encrypted.length, Endian.big);

          request.sink.add(sizeBytes);
          request.sink.add(encrypted);
        }
        request.sink.close();
      },
      onError: (e) {
        request.sink.addError(e);
      },
      cancelOnError: true,
    );

    // Wait for response
    final response = await request.send();

    if (response.statusCode == HttpStatus.unauthorized) {
      final errorBody = await response.stream.bytesToString();
      throw TransferException('Transfer not authorized: $errorBody',
          code: 'UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw TransferException(
        'Encrypted upload failed: ${response.statusCode} - $errorBody',
        code: 'UPLOAD_FAILED_${response.statusCode}',
      );
    }

    await response.stream.drain();
    debugPrint('🔐 File sent encrypted: ${item.name}');
  }

  /// Send file unencrypted (legacy)
  Future<void> _sendFileUnencrypted({
    required Device receiver,
    required String transferId,
    required Device sender,
    required TransferItem item,
    required File file,
    required int fileSize,
    required int totalSize,
    required int totalBytesTransferred,
  }) async {
    final uploadUrl =
        'http://${receiver.ipAddress}:${receiver.port}/transfer/upload';

    final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
    request.headers['x-transfer-id'] = transferId;
    request.headers['x-sender-id'] = sender.id;
    request.headers['x-sender-token'] = _deviceToken;
    request.headers['x-file-name'] = item.name;
    request.headers['x-file-size'] = fileSize.toString();
    request.headers['x-relative-path'] = item.parentPath ?? '';
    request.headers['Content-Type'] = 'application/octet-stream';
    request.headers['Content-Length'] = fileSize.toString();

    int bytesSent = 0;
    final fileStream = file.openRead();

    fileStream.listen(
      (chunk) {
        request.sink.add(chunk);
        bytesSent += chunk.length;

        final progressPercent =
            ((totalBytesTransferred + bytesSent) / totalSize * 100).toInt();

        BackgroundTransferService.updateProgress(
          title: 'Sending to ${receiver.name}',
          fileName: item.name,
          progress: progressPercent,
          bytesTransferred: totalBytesTransferred + bytesSent,
          totalBytes: totalSize,
        );

        final updatedTransfer = _activeTransfers[transferId]!.copyWith(
          status: TransferStatus.transferring,
          progress: TransferProgress(
            bytesTransferred: totalBytesTransferred + bytesSent,
            totalBytes: totalSize,
          ),
        );
        _activeTransfers[transferId] = updatedTransfer;
        _transferController.add(updatedTransfer);
      },
      onDone: () {
        request.sink.close();
      },
      onError: (e) {
        request.sink.addError(e);
      },
      cancelOnError: true,
    );

    final response = await request.send();

    if (response.statusCode == HttpStatus.unauthorized) {
      final errorBody = await response.stream.bytesToString();
      throw TransferException('Transfer not authorized: $errorBody',
          code: 'UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw TransferException(
        'Upload failed: ${response.statusCode} - $errorBody',
        code: 'UPLOAD_FAILED_${response.statusCode}',
      );
    }

    await response.stream.drain();
  }

  Future<bool> _waitForApproval({
    required Device receiver,
    required String requestId,
    required Duration timeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    final checkUrl =
        'http://${receiver.ipAddress}:${receiver.port}/transfer/approval/$requestId';

    while (DateTime.now().isBefore(endTime)) {
      try {
        final response = await http.get(Uri.parse(checkUrl)).timeout(
              const Duration(seconds: 5),
            );

        if (response.statusCode == 200) {
          final data = _validateAndParseJson(response.body);
          if (data != null) {
            final status = data['status'] as String? ?? '';
            if (status == 'approved') {
              // Check if we need to do key exchange
              final publicKeyList = data['publicKey'] as List?;
              if (publicKeyList != null && encryptionEnabled) {
                try {
                  final publicKey =
                      Uint8List.fromList(publicKeyList.cast<int>());
                  final sharedSecret = await _performKeyExchange(publicKey);
                  _encryptionSessions[receiver.id] = EncryptionSession(
                    sessionId: '$_deviceId-${receiver.id}',
                    sharedSecret: sharedSecret,
                    createdAt: DateTime.now(),
                  );
                  debugPrint('🔐 Key exchange completed on approval');
                } catch (e) {
                  debugPrint('❌ Key exchange failed: $e');
                }
              }
              return true;
            } else if (status == 'rejected' || status == 'expired') {
              return false;
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking approval: $e');
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    return false;
  }

  Future<http.Response> _retryRequest(
    Future<http.Response> Function() request, {
    int attempts = 0,
  }) async {
    try {
      final response = await request().timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw HttpException('HTTP ${response.statusCode}');
    } catch (e) {
      if (attempts < maxRetries && _isRetryableError(e)) {
        final delay = initialRetryDelaySeconds * math.pow(2, attempts);
        debugPrint(
            'Retry attempt ${attempts + 1}/$maxRetries after ${delay}s delay');
        await Future.delayed(Duration(seconds: delay.toInt()));
        return _retryRequest(request, attempts: attempts + 1);
      }
      rethrow;
    }
  }

  bool _isRetryableError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) {
      try {
        final message = error.message;
        final parts = message.split(' ');
        if (parts.length >= 2) {
          final statusCode = int.tryParse(parts.last) ?? 0;
          return statusCode >= 500 && statusCode < 600;
        }
      } catch (_) {}
    }
    return false;
  }

  void cancelTransfer(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.cancelled,
      );
      _transferController.add(_activeTransfers[transferId]!);
      BackgroundTransferService.stopBackgroundTransfer();
      _cleanupProgressController(transferId);
    } else {
      debugPrint(
          'Warning: Attempted to cancel non-existent transfer: $transferId');
    }
  }

  void revokeTrust(String senderId) {
    final removed = _trustedDevices.remove(senderId);
    if (removed != null) {
      debugPrint('Revoked trust for device: ${removed.senderName}');
      _saveTrustedDevices();
    }
  }

  void clearTrustedSenders() {
    _trustedDevices.clear();
    _saveTrustedDevices();
    debugPrint('Cleared all trusted devices');
  }

  Stream<TransferProgress> getTransferProgress(String transferId) {
    if (!_progressControllers.containsKey(transferId)) {
      _progressControllers[transferId] =
          StreamController<TransferProgress>.broadcast();
    }
    return _progressControllers[transferId]!.stream;
  }

  Future<void> dispose() async {
    _pendingRequestsCleanupTimer?.cancel();
    _notificationEventSubscription?.cancel(); // FIX: Memory leak fixed!

    await _server?.close(force: true);

    if (!_transferController.isClosed) {
      await _transferController.close();
    }

    if (!_pendingRequestsController.isClosed) {
      await _pendingRequestsController.close();
    }

    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _progressControllers.clear();

    _activeTransfers.clear();
    _pendingRequests.clear();
    _encryptionSessions.clear(); // NEW: Clear encryption sessions

    // ============================================
    // 🚀 DISPOSE PARALLEL HANDLERS
    // ============================================
    await _parallelReceiver.dispose();
    await _parallelSender?.dispose();

  }
}
