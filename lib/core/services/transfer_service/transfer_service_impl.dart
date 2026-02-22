import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_hash;

import '../streaming_hash_service.dart' show AccumulatorSink;
import '../../models/device.dart';
import '../../models/transfer.dart';
import '../../models/transfer_checkpoint.dart';
import '../../database/database_helper.dart';
import '../encryption_service.dart';
import '../file_service.dart';
import '../app_settings_service.dart';
import '../checkpoint_manager.dart';
import '../background_transfer_service.dart';
import '../device_nickname_service.dart';
import 'models.dart';

import '../parallel/parallel_config.dart';
import '../parallel/parallel_receiver_handler.dart';
import '../parallel/parallel_transfer_service.dart';
import '../live_activity_service.dart';

/// Core transfer service for peer-to-peer file transfers.
///
/// This service handles all aspects of file transfers between devices:
/// - HTTP server for receiving files
/// - HTTP client for sending files
/// - Encryption and key exchange (X25519, AES-256-GCM)
/// - Trusted device management
/// - Transfer progress tracking
/// - Resume/checkpoint support for large files
/// - Parallel transfer support for improved speed
///
/// ## Usage
///
/// ```dart
/// final transferService = TransferService(fileService);
/// await transferService.initialize();
/// await transferService.startServer(8765);
///
/// // Send files
/// await transferService.sendFiles(
///   recipientIp: '192.168.1.100',
///   recipientPort: 8765,
///   files: [TransferItem(...)],
/// );
///
/// // Listen for incoming transfer requests
/// transferService.onTransferRequest = (senderId, senderName, items) {
///   // Handle incoming transfer request
/// };
/// ```
///
/// ## Encryption
///
/// All transfers are encrypted by default using:
/// - X25519 for key exchange (same as Signal, WhatsApp)
/// - AES-256-GCM for symmetric encryption
/// - Unique nonce per chunk to prevent replay attacks
///
/// ## Parallel Transfers
///
/// For large files (>10MB), parallel transfers are automatically enabled:
/// - Multiple HTTP connections for faster transfer
/// - Chunk-based transfer with resume support
/// - Automatic speed optimization
class TransferService {
  final FileService _fileService;
  final CheckpointManager _checkpointManager = CheckpointManager();
  final DeviceNicknameService _nicknameService = DeviceNicknameService();
  final _uuid = const Uuid();

  final _transferController = StreamController<Transfer>.broadcast();
  final Map<String, Transfer> _activeTransfers = {};
  final Map<String, StreamController<TransferProgress>> _progressControllers =
      {};

  late final ParallelReceiverHandler _parallelReceiver;
  ParallelTransferService? _parallelSender;
  ParallelConfig? _parallelConfig;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _trustedDevicesKey = 'syndro_trusted_devices';
  final AppSettingsService _settingsService = AppSettingsService();

  final Map<String, TrustedDevice> _trustedDevices = {};
  final Map<String, PendingTransferRequest> _pendingRequests = {};

  final _pendingRequestsController =
      StreamController<List<PendingTransferRequest>>.broadcast();

  HttpServer? _server;

  String _deviceId = '';
  String _deviceName = '';
  String _devicePlatform = '';
  String _deviceToken = '';

  static const int maxRetries = 3;
  static const int initialRetryDelaySeconds = 2;
  static const int _maxCompletedTransfers = 10;
  // OPTIMIZED: Support files up to 100GB for low-end devices
  // Using streaming transfer, only one chunk is loaded in memory at a time
  static const int _maxFileSizeBytes = 100 * 1024 * 1024 * 1024; // 100GB limit

  static const Duration _sessionMaxAge = Duration(hours: 1);
  Timer? _sessionCleanupTimer;

  Timer? _pendingRequestsCleanupTimer;
  StreamSubscription<Map<String, dynamic>>? _notificationEventSubscription;

  bool encryptionEnabled = true;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final X25519 _keyExchange = X25519();
  SimpleKeyPair? _encryptionKeyPair;
  final Map<String, EncryptionSession> _encryptionSessions = {};

  Function(String senderId, String senderName, List<TransferItem> items)?
      onTransferRequest;

  bool _isDisposed = false;

  bool _isInitialized = false;
  Future<void>? _initFuture;

  TransferService(this._fileService) {
    _startPendingRequestsCleanup();
    _listenToNotificationEvents();
    _initializeParallelTransfer();
    _startSessionCleanup();
    _startTrustedDevicesCleanup();
  }

  /// Must be awaited before using the service for transfers.
  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) return;
    // If initialization is in progress, wait for it
    if (_initFuture != null) {
      return _initFuture;
    }
    // Start initialization and store the future
    _initFuture = _doInitialize();
    return _initFuture;
  }

  Future<void> _doInitialize() async {
    await _loadTrustedDevices();
    await _initializeEncryption();
    _isInitialized = true;
    debugPrint('✅ TransferService initialized');
  }

  Stream<Transfer> get transferStream => _transferController.stream;
  List<Transfer> get activeTransfers => _activeTransfers.values.toList();
  List<PendingTransferRequest> get pendingRequests =>
      _pendingRequests.values.toList();
  Stream<List<PendingTransferRequest>> get pendingRequestsStream =>
      _pendingRequestsController.stream;
  List<TrustedDevice> get trustedDevices => _trustedDevices.values.toList();
  bool get isEncryptionReady => _encryptionKeyPair != null;

  Future<void> _initializeEncryption() async {
    try {
      _encryptionKeyPair = await _keyExchange.newKeyPair();
      debugPrint('🔐 Encryption initialized (X25519 + AES-256-GCM)');
    } catch (e) {
      debugPrint('❌ Failed to initialize encryption: $e');
      encryptionEnabled = false;
    }
  }

  Future<Uint8List?> getPublicKey() async {
    if (_encryptionKeyPair == null) return null;
    final publicKey = await _encryptionKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

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

  Future<Uint8List> _decryptChunk(
      Uint8List encryptedData, SecretKey secretKey) async {
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

  Future<String> _calculateHashFromFile(File file) async {
    final digest = await crypto_hash.sha256.bind(file.openRead()).last;
    return digest.toString();
  }

  void _startSessionCleanup() {
    _sessionCleanupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _cleanupExpiredSessions(),
    );
  }

  void _cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _encryptionSessions.entries) {
      if (now.difference(entry.value.createdAt) > _sessionMaxAge) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      _encryptionSessions.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      debugPrint(
          '🧹 Cleaned up ${expiredIds.length} expired encryption sessions');
    }
  }

  // Trusted devices cleanup - remove old entries to prevent unbounded growth
  static const Duration _trustedDevicesMaxAge = Duration(days: 90);
  Timer? _trustedDevicesCleanupTimer;

  void _startTrustedDevicesCleanup() {
    _trustedDevicesCleanupTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => _cleanupOldTrustedDevices(),
    );
  }

  void _cleanupOldTrustedDevices() {
    if (_trustedDevices.isEmpty) return;

    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _trustedDevices.entries) {
      if (now.difference(entry.value.trustedAt) > _trustedDevicesMaxAge) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      _trustedDevices.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${expiredIds.length} old trusted devices');
      _saveTrustedDevices();
    }
  }

  void _initializeParallelTransfer() {
    _parallelReceiver = ParallelReceiverHandler(_fileService);

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

        BackgroundTransferService.updateProgress(
          title: 'Receiving file',
          fileName: transfer.items.first.name,
          progress: (received / total * 100).toInt(),
          bytesTransferred: received,
          totalBytes: total,
        );
      }
    };

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
        _cleanupProgressController(transferId);
      }
    };

    debugPrint('⚡ Parallel transfer handlers initialized');
  }

  Future<void> _handleParallelInitiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final transferId = data['transferId'] as String? ?? '';
      final fileName = data['fileName'] as String? ?? '';
      final fileSize = data['fileSize'] as int? ?? 0;
      final senderId = data['senderId'] as String? ?? '';
      final senderName = data['senderName'] as String? ?? '';
      final senderToken = data['senderToken'] as String? ?? '';

      if (transferId.isEmpty || fileName.isEmpty || fileSize <= 0) {
        await _sendBadRequest(request, 'Missing required fields');
        return;
      }

      // Check if auto-accept is enabled for trusted devices
      final trustedDevice = _trustedDevices[senderId];
      final autoAcceptTrusted = await _settingsService.getAutoAcceptTrusted();

      if (trustedDevice != null &&
          _secureTokenCompare(trustedDevice.token, senderToken) &&
          autoAcceptTrusted) {
        // Auto-accept: proceed with transfer immediately
        debugPrint('✅ Auto-accepting parallel transfer from trusted device: $senderName');
        
        final result = await _parallelReceiver.handleInitiate(data);
        await _sendResponse(request,
            result['success'] == true ? HttpStatus.ok : HttpStatus.badRequest, result);
        return;
      }

      // FIX: Create pending request for UI approval
      // This ensures the transfer request dialog is shown before transfer starts
      final item = TransferItem(
        name: fileName,
        path: '', // Path not known yet on receiver side
        size: fileSize,
      );

      _pendingRequests[transferId] = PendingTransferRequest(
        requestId: transferId,
        senderId: senderId,
        senderName: senderName,
        senderToken: senderToken,
        items: [item],
        timestamp: DateTime.now(),
        senderPublicKey: null,
        isParallelTransfer: true,
        parallelData: data,
        isTrusted: trustedDevice != null,
      );

      // Notify UI via stream (this will show the transfer request dialog)
      if (!_pendingRequestsController.isClosed) {
        _pendingRequestsController.add(_pendingRequests.values.toList());
      }

      debugPrint('📥 Parallel transfer pending approval: $fileName from $senderName');

      // Return pending_approval status so sender waits for approval
      await _sendResponse(request, HttpStatus.ok, {
        'status': 'pending_approval',
        'requestId': transferId,
        'message': 'Waiting for receiver approval',
      });
    } catch (e) {
      await _sendError(request, 'Error initiating parallel transfer: $e');
    }
  }

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

      // FIX (Bug #34): Use int.tryParse instead of int.parse
      final chunkIndex = int.tryParse(chunkIndexStr);
      if (chunkIndex == null) {
        await _sendBadRequest(request, 'Invalid chunk index');
        return;
      }

      final originalSize = int.tryParse(originalSizeStr ?? '0') ?? 0;
      final encrypted = encryptedStr == 'true';

      final chunks = <int>[];
      await for (final chunk in request) {
        chunks.addAll(chunk);
      }
      final chunkData = Uint8List.fromList(chunks);

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
          result['success'] == true ? HttpStatus.ok : HttpStatus.badRequest, result);
    } catch (e) {
      await _sendError(request, 'Error receiving chunk: $e');
    }
  }

  Future<void> _handleChunkDownload(HttpRequest request) async {
    try {
      final pathParts = request.uri.path.split('/');

      if (pathParts.length < 5) {
        await _sendBadRequest(request, 'Invalid path');
        return;
      }

      final transferId = pathParts[3];

      final session = _parallelReceiver.getSession(transferId);
      if (session == null) {
        await _sendNotFound(request, 'Transfer not found');
        return;
      }

      // Chunk download via browser not supported - use parallel transfer instead
      await _sendError(request, 'Chunk download not supported for browser mode');
    } catch (e) {
      await _sendError(request, 'Error serving chunk: $e');
    }
  }

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

      if (result['success'] == true) {
        await BackgroundTransferService.showTransferComplete(
          fileName:
              result['filePath'].toString().split(Platform.pathSeparator).last,
          filePath: result['filePath'] as String,
          fileCount: 1,
          totalSize: result['fileSize'] as int,
        );
      }

      await _sendResponse(request,
          result['success'] == true ? HttpStatus.ok : HttpStatus.badRequest, result);
    } catch (e) {
      await _sendError(request, 'Error completing parallel transfer: $e');
    }
  }

  void _listenToNotificationEvents() {
    _notificationEventSubscription =
        BackgroundTransferService.transferEvents.listen((event) {
      final eventType = event['event'] as String?;
      final requestId = event['requestId'] as String?;

      debugPrint('📱 Notification event: $eventType for request: $requestId');

      switch (eventType) {
        case 'cancelled':
          debugPrint('📱 Transfer cancelled from notification: $requestId');
          if (requestId != null && _activeTransfers.containsKey(requestId)) {
            cancelTransfer(requestId);
          }
          break;
        case 'accepted':
          debugPrint('📱 Transfer accepted from notification: $requestId');
          if (requestId != null) {
            // FIX: Check if request still exists before approving
            if (_pendingRequests.containsKey(requestId)) {
              approveTransfer(requestId, trustSender: false);
            } else {
              debugPrint('⚠️ Request $requestId no longer exists (may have been handled by UI)');
            }
          }
          break;
        case 'rejected':
          debugPrint('📱 Transfer rejected from notification: $requestId');
          if (requestId != null) {
            // FIX: Check if request still exists before rejecting
            if (_pendingRequests.containsKey(requestId)) {
              rejectTransfer(requestId);
            } else {
              debugPrint('⚠️ Request $requestId no longer exists (may have been handled by UI)');
            }
          }
          break;
      }
    }, onError: (error) {
      debugPrint('❌ Error in notification events: $error');
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
      debugPrint('🧹 Cleaned up ${expiredIds.length} expired pending requests');
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

  /// Generate a unique checkpoint key using SHA-256 for better collision resistance
  String _generateCheckpointKey(
      String senderId, String receiverId, List<TransferItem> items) {
    final itemsSignature =
        items.map((item) => '${item.name}:${item.size}').join('|');
    final keySource = '$senderId->$receiverId:$itemsSignature';
    
    // Use SHA-256 for cryptographic hash instead of weak custom hash
    final bytes = utf8.encode(keySource);
    final digest = crypto_hash.sha256.convert(bytes);
    final hashHex = digest.toString().substring(0, 16); // Use first 16 chars (64 bits)
    return 'ckpt_$hashHex';
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

    if (_encryptionKeyPair == null) {
      await _initializeEncryption();
      _initializeParallelTransfer();
    }

    for (int p = port; p <= port + 5; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        debugPrint('🚀 Transfer server running on port ${_server!.port}');
        debugPrint(
            '🔐 Encryption: ${encryptionEnabled ? "ENABLED" : "DISABLED"}');
        // FIX: Don't await _serve() - it runs indefinitely and blocks initialization
        _serve(); // Run in background
        break;
      } catch (e) {
        if (p == port + 5) {
          debugPrint(
              'Failed to start transfer server on any port in range: $e');
          throw TransferException('Failed to start server',
              code: 'SERVER_START_FAILED', originalError: e);
        }
        debugPrint('Port $p busy, trying next port...');
      }
    }

    if (_server != null) {
      _parallelConfig = await ParallelConfig.autoDetect();
      _parallelSender = ParallelTransferService(config: _parallelConfig);
      debugPrint(
          '⚡ Parallel transfer: ${_parallelConfig!.connections} connections, ${_parallelConfig!.chunkSize ~/ (1024 * 1024)}MB chunks');
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
        // FIX: Use proper method channel to get Android device name
        const platform = MethodChannel('com.syndro.app/device_info');
        try {
          final String? deviceName = await platform.invokeMethod('getDeviceName');
          if (deviceName != null && deviceName.isNotEmpty) {
            return deviceName;
          }
        } catch (e) {
          debugPrint('Platform channel not available: $e');
        }
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

    try {
      await for (final request in _server!) {
        if (_isDisposed) break;
        try {
          await _handleRequest(request);
        } catch (e, stackTrace) {
          debugPrint('Error handling request: $e');
          debugPrint('Stack trace: $stackTrace');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('Internal server error');
            await request.response.close();
          } catch (closeError) { 
            // Response may already be closed or in error state
            debugPrint("Error closing response: $closeError"); 
          }
        }
      }
    } catch (e) {
      // Server was closed or socket error - this is expected during dispose
      if (!_isDisposed) {
        debugPrint('Server error: $e');
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    try {
      if (method == 'GET' && path == '/syndro.json') {
        await _serveDeviceInfo(request);
        return;
      }

      if (method == 'POST' && path == '/key-exchange') {
        await _handleKeyExchange(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/parallel/initiate') {
        await _handleParallelInitiate(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/chunk') {
        await _handleChunkUpload(request);
        return;
      }

      if (method == 'GET' && path.startsWith('/transfer/chunk/')) {
        await _handleChunkDownload(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/parallel/complete') {
        await _handleParallelComplete(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/initiate') {
        await _handleTransferInitiate(request);
        return;
      }

      if (method == 'GET' && path.startsWith('/transfer/approval/')) {
        final requestId = path.split('/').last;
        await _handleApprovalCheck(request, requestId);
        return;
      }

      if (method == 'POST' && path == '/transfer/upload') {
        await _handleFileUpload(request);
        return;
      }

      if (method == 'POST' && path == '/transfer/upload-encrypted') {
        await _handleEncryptedFileUpload(request);
        return;
      }

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

      final sharedSecret = await _performKeyExchange(theirPublicKeyBytes);

      _encryptionSessions[theirDeviceId] = EncryptionSession(
        sessionId: '$_deviceId-$theirDeviceId',
        sharedSecret: sharedSecret,
        createdAt: DateTime.now(),
      );

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
      'publicKey': myPublicKey?.toList(),
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

  bool _secureTokenCompare(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
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
      final senderPublicKeyList = data['publicKey'] as List?;

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

      final trustedDevice = _trustedDevices[senderId];
      
      // Check if auto-accept is enabled for trusted devices
      final autoAcceptTrusted = await _settingsService.getAutoAcceptTrusted();
      
      if (trustedDevice != null &&
          _secureTokenCompare(trustedDevice.token, senderToken) &&
          autoAcceptTrusted) {
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

      _pendingRequests[requestId] = PendingTransferRequest(
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        senderToken: senderToken,
        items: items,
        timestamp: DateTime.now(),
        senderPublicKey: senderPublicKey,
        isTrusted: trustedDevice != null,
      );

      // Notify UI via stream (this will show the modal sheet if app is in foreground)
      if (!_pendingRequestsController.isClosed) {
        _pendingRequestsController.add(_pendingRequests.values.toList());
      }

      // NOTE: onTransferRequest callback is NOT called here to avoid double-showing
      // The UI listens to pendingRequestsStream via pendingTransferRequestsProvider
      // Calling both would result in duplicate transfer request dialogs

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

  Future<void> approveTransfer(String requestId,
      {bool trustSender = false}) async {
    final pending = _pendingRequests[requestId];
    if (pending == null) {
      debugPrint(
          '⚠️ Warning: Attempted to approve non-existent request: $requestId');
      return;
    }

    // FIX: Remove from pending list immediately to prevent double-handling
    _pendingRequests.remove(requestId);
    if (!_pendingRequestsController.isClosed) {
      _pendingRequestsController.add(_pendingRequests.values.toList());
    }

    // Dismiss notification if shown
    BackgroundTransferService.dismissTransferRequest();

    if (trustSender) {
      _trustedDevices[pending.senderId] = TrustedDevice(
        senderId: pending.senderId,
        senderName: pending.senderName,
        token: pending.senderToken,
        trustedAt: DateTime.now(),
      );
      await _saveTrustedDevices();
    }

    if (pending.senderPublicKey != null && encryptionEnabled) {
      try {
        final sharedSecret =
            await _performKeyExchange(pending.senderPublicKey!);
        _encryptionSessions[pending.senderId] = EncryptionSession(
          sessionId: '$_deviceId-${pending.senderId}',
          sharedSecret: sharedSecret,
          createdAt: DateTime.now(),
        );
        debugPrint('🔐 Key exchange completed on approval');
      } catch (e) {
        debugPrint('❌ Key exchange failed on approval: $e');
      }
    }

    // FIX: Handle parallel transfer approval differently
    if (pending.isParallelTransfer && pending.parallelData != null) {
      // For parallel transfers, initialize the receiver session
      debugPrint('✅ Approving parallel transfer: ${pending.requestId}');
      final result = await _parallelReceiver.handleInitiate(pending.parallelData!);
      if (result['success'] != true) {
        debugPrint('❌ Failed to initialize parallel receiver: ${result['error']}');
      }
      // The sender will check approval status and start uploading chunks
    } else {
      _approveTransferRequest(
        requestId,
        pending.senderId,
        pending.senderName,
        pending.senderToken,
        pending.items,
      );
    }
  }

  void rejectTransfer(String requestId) {
    // FIX: Check if request exists and remove it
    final removed = _pendingRequests.remove(requestId);
    if (removed == null) {
      debugPrint(
          '⚠️ Warning: Attempted to reject non-existent request: $requestId');
      return;
    }
    
    // Update UI
    if (!_pendingRequestsController.isClosed) {
      _pendingRequestsController.add(_pendingRequests.values.toList());
    }
    
    // Dismiss notifications
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

    // Start Live Activity for Android lock screen progress
    if (items.isNotEmpty) {
      final totalBytes = items.fold<int>(0, (sum, item) => sum + item.size);
      LiveActivityService.startTransferActivity(
        fileName: items.length == 1 ? items.first.name : '${items.length} files',
        totalBytes: totalBytes,
        senderName: senderName,
        isIncoming: true,
      );
    }

    BackgroundTransferService.startBackgroundTransfer(
      title: 'Receiving from $senderName',
      fileName: items.length == 1 ? items.first.name : '${items.length} files',
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

  Future<void> _handleEncryptedFileUpload(HttpRequest request) async {
    IOSink? fileSink;
    String? tempFilePath;

    try {
      final transferId = request.headers.value('x-transfer-id');
      final fileName = request.headers.value('x-file-name');
      final originalSizeHeader = request.headers.value('x-original-size');
      final senderId = request.headers.value('x-sender-id');
      final fileHash = request.headers.value('x-file-hash');
      // Read file metadata timestamps
      final modifiedHeader = request.headers.value('x-file-modified');

      final originalSize = originalSizeHeader != null
          ? int.tryParse(originalSizeHeader) ?? 0
          : 0;
      
      // Parse metadata timestamps
      DateTime? fileModified;
      if (modifiedHeader != null) {
        final ms = int.tryParse(modifiedHeader);
        if (ms != null) fileModified = DateTime.fromMillisecondsSinceEpoch(ms);
      }

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

      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        await _sendUnauthorized(request, 'Transfer not authorized');
        return;
      }

      if (transfer.senderId != senderId) {
        await _sendUnauthorized(request, 'Sender ID mismatch');
        return;
      }

      final session = _encryptionSessions[senderId];
      if (session == null) {
        await _sendUnauthorized(request, 'No encryption session');
        return;
      }

      final sanitizedFileName = _fileService.sanitizeFilename(fileName);

      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
      );
      _transferController.add(_activeTransfers[transferId]!);

      final downloadDir = await _fileService.getDownloadDirectory();
      final finalFilePath =
          '$downloadDir${Platform.pathSeparator}$sanitizedFileName';
      tempFilePath = '$finalFilePath.tmp';

      if (!_fileService.isPathWithinDirectory(finalFilePath, downloadDir)) {
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
      List<int> buffer = [];
      int lastReportedProgress = -1;
      const int maxBufferSize = 10 * 1024 * 1024; // 10MB max buffer

      // Use streaming SHA-256 to avoid loading entire file into memory
      final hashOutput = AccumulatorSink<crypto_hash.Digest>();
      final hashInput = crypto_hash.sha256.startChunkedConversion(hashOutput);

      await for (final chunk in request) {
        buffer.addAll(chunk);

        // Check buffer size to prevent memory exhaustion
        if (buffer.length > maxBufferSize) {
          debugPrint('Buffer overflow: ${buffer.length} > $maxBufferSize');
          await _sendBadRequest(request, 'Buffer overflow - chunk size mismatch');
          await fileSink.close();
          try {
            await File(tempFilePath).delete();
          } catch (e) {
            debugPrint('⚠️ Failed to delete temp file: $e');
          }
          return;
        }

        while (buffer.length >= 4) {
          final sizeBytes = Uint8List.fromList(buffer.sublist(0, 4));
          final byteData = ByteData.view(sizeBytes.buffer);
          final chunkSize = byteData.getUint32(0, Endian.big);

          if (buffer.length < 4 + chunkSize) {
            break;
          }

          final encryptedChunk =
              Uint8List.fromList(buffer.sublist(4, 4 + chunkSize));
          buffer = buffer.sublist(4 + chunkSize);

          final decrypted =
              await _decryptChunk(encryptedChunk, session.sharedSecret);

          fileSink.add(decrypted);
          hashInput.add(decrypted);

          bytesReceived += decrypted.length;

          final progressPercent = originalSize > 0
              ? ((bytesReceived / originalSize) * 100).toInt()
              : 0;

          if (progressPercent - lastReportedProgress >= 5) {
            lastReportedProgress = progressPercent;
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

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      hashInput.close();
      final calculatedHash = hashOutput.events.single.toString();

      if (fileHash != null && fileHash.isNotEmpty) {
        if (calculatedHash != fileHash) {
          await File(tempFilePath).delete();
          throw TransferException('File integrity check failed',
              code: 'HASH_MISMATCH');
        }
        debugPrint('✅ File integrity verified');
      }

      final tempFileRef = File(tempFilePath);
      final finalFile = File(finalFilePath);

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFileRef.rename(finalFilePath);
      tempFilePath = null;

      // Apply file metadata (modification time)
      if (fileModified != null) {
        try {
          await finalFile.setLastModified(fileModified);
          debugPrint('📅 Applied file modification time: $fileModified');
        } catch (e) {
          debugPrint('⚠️ Could not set file modification time: $e');
        }
      }

      final completedTransfer = _activeTransfers[transferId]!.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(
          bytesTransferred: bytesReceived,
          totalBytes: bytesReceived,
        ),
      );

      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      // End Live Activity on completion
      LiveActivityService.endActivity(success: true, message: 'Transfer complete');

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
        } catch (closeError) {
          debugPrint('Error closing file sink: $closeError');
        }
      }

      if (tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (deleteError) {
          debugPrint('Error deleting temp file: $deleteError');
        }
      }

      await BackgroundTransferService.stopBackgroundTransfer();
      await _sendError(request, 'Error receiving encrypted file');
    }
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
    IOSink? fileSink;
    String? tempFilePath;

    try {
      final transferId = request.headers.value('x-transfer-id');
      final fileName = request.headers.value('x-file-name');
      final fileSizeHeader = request.headers.value('x-file-size');
      final senderId = request.headers.value('x-sender-id');
      final senderToken = request.headers.value('x-sender-token');
      // Read file metadata timestamps
      final modifiedHeader = request.headers.value('x-file-modified');

      final fileSize =
          fileSizeHeader != null ? int.tryParse(fileSizeHeader) ?? 0 : 0;
      
      // Parse metadata timestamps
      DateTime? fileModified;
      if (modifiedHeader != null) {
        final ms = int.tryParse(modifiedHeader);
        if (ms != null) fileModified = DateTime.fromMillisecondsSinceEpoch(ms);
      }

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

      // Validate file size limit
      if (fileSize > _maxFileSizeBytes) {
        debugPrint('Security: File size $fileSize exceeds maximum $_maxFileSizeBytes');
        await _sendBadRequest(request, 'File size exceeds maximum allowed size (16GB)');
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

      // Apply file metadata (modification time)
      if (fileModified != null) {
        try {
          await finalFile.setLastModified(fileModified);
          debugPrint('📅 Applied file modification time: $fileModified');
        } catch (e) {
          debugPrint('⚠️ Could not set file modification time: $e');
        }
      }

      final completedTransfer = _activeTransfers[transferId]!.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(
          bytesTransferred: bytesReceived,
          totalBytes: bytesReceived,
        ),
      );

      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      // End Live Activity on completion
      LiveActivityService.endActivity(success: true, message: 'Transfer complete');

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
        } catch (closeError) {
          debugPrint('Error closing file sink: $closeError');
        }
      }

      if (tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (deleteError) {
          debugPrint('Error deleting temp file: $deleteError');
        }
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

  Future<void> sendFiles({
    required Device sender,
    required Device receiver,
    required List<TransferItem> items,
    bool? encrypted,
  }) async {
    // IMPROVEMENT: Add validation for empty IDs
    if (sender.id.isEmpty) {
      throw TransferException('Invalid sender device', code: 'INVALID_SENDER');
    }
    
    if (receiver.id.isEmpty) {
      throw TransferException('Invalid receiver device', code: 'INVALID_RECEIVER');
    }
    
    if (items.isEmpty) {
      throw TransferException('No items to transfer', code: 'EMPTY_ITEMS');
    }

    // IMPROVEMENT: Validate all items have valid paths
    for (final item in items) {
      if (item.path.isEmpty) {
        throw TransferException('Item has invalid path: ${item.name}', code: 'INVALID_PATH');
      }
    }

    _cleanupCompletedTransfers();

    final checkpointKey = _generateCheckpointKey(sender.id, receiver.id, items);
    final checkpoint = await _checkpointManager.loadCheckpoint(checkpointKey);
    final startIndex = checkpoint?.currentFileIndex ?? 0;
    final resumedBytes = checkpoint?.bytesTransferred ?? 0;

    final transferId = checkpoint != null ? checkpointKey : _uuid.v4();
    final totalSize = items.fold<int>(0, (sum, item) => sum + item.size);

    final useParallel = _parallelConfig?.shouldUseParallel(totalSize) ?? false;

    // Store in local variable to avoid force unwrap and ensure thread safety
    final parallelSender = _parallelSender;
    if (useParallel && items.length == 1 && parallelSender != null) {
      debugPrint(
          '⚡ Using parallel transfer for large file (${totalSize ~/ (1024 * 1024)}MB)');

      final item = items.first;
      final file = File(item.path);

      SecretKey? encryptionKey;
      final shouldEncrypt = encrypted ?? encryptionEnabled;

      if (shouldEncrypt && encryptionEnabled) {
        debugPrint('🔐 Starting key exchange with receiver...');
        final myPublicKey = await getPublicKey();

        final keyExchangeUrl =
            'http://${receiver.ipAddress}:${receiver.port}/key-exchange';

        try {
          final keyResponse = await http.post(
            Uri.parse(keyExchangeUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': sender.id,
              'publicKey': myPublicKey?.toList(),
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Key exchange timeout'),
          );

          if (keyResponse.statusCode == 200) {
            final keyData = jsonDecode(keyResponse.body);
            final receiverPublicKeyList = keyData['publicKey'] as List?;

            if (receiverPublicKeyList != null) {
              final receiverPublicKey =
                  Uint8List.fromList(receiverPublicKeyList.cast<int>());
              encryptionKey = await _performKeyExchange(receiverPublicKey);

              _encryptionSessions[receiver.id] = EncryptionSession(
                sessionId: '${sender.id}-${receiver.id}',
                sharedSecret: encryptionKey,
                createdAt: DateTime.now(),
              );
              debugPrint('🔐 Key exchange successful');
            }
          }
        } catch (e) {
          debugPrint('❌ Key exchange failed: $e');
        }
      }

      // Create transfer with "transferring" status
      // FIX: Receiver is now notified immediately (hash calculated in parallel with upload)
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
        await parallelSender.sendFileParallel(
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

            BackgroundTransferService.updateProgress(
              title: 'Sending to ${receiver.name}',
              fileName: item.name,
              progress: (sent / total * 100).toInt(),
              bytesTransferred: sent,
              totalBytes: total,
            );
          },
        );

        final completedTransfer = parallelTransfer.copyWith(
          status: TransferStatus.completed,
          progress: TransferProgress(
            bytesTransferred: totalSize,
            totalBytes: totalSize,
          ),
        );

        _activeTransfers[transferId] = completedTransfer;
        _transferController.add(completedTransfer);

        await DatabaseHelper.instance
            .insertTransfer(completedTransfer, sender, receiver);

        await BackgroundTransferService.showTransferComplete(
          fileName: item.name,
          filePath: item.path,
          fileCount: 1,
          totalSize: totalSize,
        );

        _cleanupProgressController(transferId);
        return;
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
      fileName: items.length == 1 ? items.first.name : '${items.length} files',
    );

    try {
      final myPublicKey = await getPublicKey();

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
            'publicKey': myPublicKey?.toList(),
          }),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Transfer initiate timeout'),
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

      bool useEncryption = encrypted ??
          (encryptionEnabled &&
              receiverSupportsEncryption &&
              receiverPublicKeyList != null);

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

      final completedTransfer = transfer.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(
            bytesTransferred: totalSize, totalBytes: totalSize),
      );

      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      // End Live Activity on completion
      LiveActivityService.endActivity(success: true, message: 'Transfer complete');

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

    final fileHash = await _calculateHashFromFile(file);

    final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));

    request.headers['x-transfer-id'] = transferId;
    request.headers['x-sender-id'] = sender.id;
    request.headers['x-sender-token'] = _deviceToken;
    request.headers['x-file-name'] = item.name;
    request.headers['x-original-size'] = fileSize.toString();
    request.headers['x-file-hash'] = fileHash;
    // Add file metadata timestamps
    if (item.modifiedAt != null) {
      request.headers['x-file-modified'] = item.modifiedAt!.millisecondsSinceEpoch.toString();
    }
    if (item.createdAt != null) {
      request.headers['x-file-created'] = item.createdAt!.millisecondsSinceEpoch.toString();
    }
    request.headers['Content-Type'] = 'application/octet-stream';

    int bytesSent = 0;
    const chunkSize = 1024 * 1024;

    // Use await-for to avoid async race condition in stream listener
    final fileStream = file.openRead();
    List<int> buffer = [];

    try {
      await for (final chunk in fileStream) {
        buffer.addAll(chunk);

        while (buffer.length >= chunkSize) {
          final plainChunk = Uint8List.fromList(buffer.sublist(0, chunkSize));
          buffer = buffer.sublist(chunkSize);

          final encrypted = await _encryptChunk(plainChunk, sharedSecret);

          final sizeBytes = Uint8List(4);
          final byteData = ByteData.view(sizeBytes.buffer);
          byteData.setUint32(0, encrypted.length, Endian.big);

          request.sink.add(sizeBytes);
          request.sink.add(encrypted);

          bytesSent += plainChunk.length;

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
      }

      // Flush remaining bytes in buffer
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
    } catch (e) {
      request.sink.addError(e);
      request.sink.close();
      rethrow;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == HttpStatus.unauthorized) {
      throw TransferException('Transfer not authorized: $responseBody',
          code: 'UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      throw TransferException(
        'Encrypted upload failed: ${response.statusCode} - $responseBody',
        code: 'UPLOAD_FAILED_${response.statusCode}',
      );
    }

    debugPrint('🔐 File sent encrypted: ${item.name}');
  }

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

    try {
      await for (final chunk in fileStream) {
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
      }
      request.sink.close();
    } catch (e) {
      request.sink.addError(e);
      request.sink.close();
      rethrow;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == HttpStatus.unauthorized) {
      throw TransferException('Transfer not authorized: $responseBody',
          code: 'UNAUTHORIZED');
    }

    if (response.statusCode != 200) {
      throw TransferException(
        'Upload failed: ${response.statusCode} - $responseBody',
        code: 'UPLOAD_FAILED_${response.statusCode}',
      );
    }
  }

  Future<bool> _waitForApproval({
    required Device receiver,
    required String requestId,
    required Duration timeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    final checkUrl =
        'http://${receiver.ipAddress}:${receiver.port}/transfer/approval/$requestId';

    while (DateTime.now().isBefore(endTime) && !_isDisposed) {
      try {
        final response = await http.get(Uri.parse(checkUrl)).timeout(
              const Duration(seconds: 5),
            );

        if (response.statusCode == 200) {
          final data = _validateAndParseJson(response.body);
          if (data != null) {
            final status = data['status'] as String? ?? '';

            if (status == 'approved') {
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

      await Future.delayed(const Duration(milliseconds: 500)); // FIX: Faster polling (was 2 seconds)
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
        // FIX: Use fixed 1-second delay for local network (was exponential backoff)
        const delay = 1; // Fixed 1 second instead of 2^attempts
        debugPrint(
            'Retry attempt ${attempts + 1}/$maxRetries after ${delay}s delay');
        await Future.delayed(const Duration(seconds: delay));
        return _retryRequest(request, attempts: attempts + 1);
      }
      rethrow;
    }
  }

  bool _isRetryableError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) {
      // Extract status code from "HTTP <code>" formatted message
      final match = RegExp(r'HTTP\s+(\d+)').firstMatch(error.message);
      if (match != null) {
        final statusCode = int.tryParse(match.group(1)!) ?? 0;
        return statusCode >= 500 && statusCode < 600;
      }
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

  Future<void> revokeTrust(String senderId) async {
    final removed = _trustedDevices.remove(senderId);
    if (removed != null) {
      debugPrint('Revoked trust for device: ${removed.senderName}');
      await _saveTrustedDevices();
    }
  }

  Future<void> clearTrustedSenders() async {
    _trustedDevices.clear();
    await _saveTrustedDevices();
    debugPrint('Cleared all trusted devices');
  }

  Stream<TransferProgress> getTransferProgress(String transferId) {
    if (!_progressControllers.containsKey(transferId)) {
      _progressControllers[transferId] =
          StreamController<TransferProgress>.broadcast();
    }
    return _progressControllers[transferId]!.stream;
  }

  // FIX (Bug #32): Proper disposal with try-catch for all resources
  Future<void> dispose() async {
    _isDisposed = true;

    // Cancel timers
    try {
      _pendingRequestsCleanupTimer?.cancel();
      _pendingRequestsCleanupTimer = null;
    } catch (e) {
      debugPrint('Error cancelling pending requests cleanup timer: $e');
    }

    try {
      _sessionCleanupTimer?.cancel();
      _sessionCleanupTimer = null;
    } catch (e) {
      debugPrint('Error cancelling session cleanup timer: $e');
    }

    // Cancel notification subscription
    try {
      await _notificationEventSubscription?.cancel();
      _notificationEventSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling notification subscription: $e');
    }

    // Close server
    try {
      await _server?.close(force: true);
      _server = null;
    } catch (e) {
      debugPrint('Error closing server: $e');
    }

    // Close controllers
    try {
      if (!_transferController.isClosed) {
        await _transferController.close();
      }
    } catch (e) {
      debugPrint('Error closing transfer controller: $e');
    }

    try {
      if (!_pendingRequestsController.isClosed) {
        await _pendingRequestsController.close();
      }
    } catch (e) {
      debugPrint('Error closing pending requests controller: $e');
    }

    // Close progress controllers
    for (final controller in _progressControllers.values) {
      try {
        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e) {
        debugPrint('Error closing progress controller: $e');
      }
    }

    _progressControllers.clear();
    _activeTransfers.clear();
    _pendingRequests.clear();
    _encryptionSessions.clear();

    // Dispose parallel handlers
    try {
      await _parallelReceiver.dispose();
    } catch (e) {
      debugPrint('Error disposing parallel receiver: $e');
    }

    try {
      await _parallelSender?.dispose();
    } catch (e) {
      debugPrint('Error disposing parallel sender: $e');
    }

    debugPrint('✅ TransferService disposed');
  }
}
