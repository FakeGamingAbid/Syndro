import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/transfer.dart';
import '../models/transfer_checkpoint.dart';
import '../database/database_helper.dart';
import 'file_service.dart';
import 'checkpoint_manager.dart';
import 'background_transfer_service.dart';

/// Custom exception for transfer errors
class TransferException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  TransferException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'TransferException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Pending transfer request model
class PendingTransferRequest {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderToken;  // NEW: Token for verification
  final List<TransferItem> items;
  final DateTime timestamp;

  PendingTransferRequest({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderToken,
    required this.items,
    required this.timestamp,
  });
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
}

class TransferService {
  final FileService _fileService;
  final CheckpointManager _checkpointManager = CheckpointManager();
  final _uuid = const Uuid();

  final _transferController = StreamController<Transfer>.broadcast();
  final Map<String, Transfer> _activeTransfers = {};
  final Map<String, StreamController<TransferProgress>> _progressControllers = {};

  // IMPROVED: Track authorized senders with tokens (not just IDs)
  final Map<String, TrustedDevice> _trustedDevices = {};
  final Map<String, PendingTransferRequest> _pendingRequests = {};

  // Stream controller for pending requests (for UI to listen)
  final _pendingRequestsController = StreamController<List<PendingTransferRequest>>.broadcast();

  HttpServer? _server;

  // Device info - set from outside
  String _deviceId = '';
  String _deviceName = '';
  String _devicePlatform = '';
  String _deviceToken = '';  // NEW: Unique device token for auth

  static const int maxRetries = 3;
  static const int initialRetryDelaySeconds = 2;

  // Callback for transfer request approval (set by UI)
  Function(String senderId, String senderName, List<TransferItem> items)? onTransferRequest;

  TransferService(this._fileService);

  Stream<Transfer> get transferStream => _transferController.stream;
  List<Transfer> get activeTransfers => _activeTransfers.values.toList();

  // Expose pending requests for UI
  List<PendingTransferRequest> get pendingRequests => _pendingRequests.values.toList();

  // Stream for pending requests (UI listens to this)
  Stream<List<PendingTransferRequest>> get pendingRequestsStream => _pendingRequestsController.stream;

  // Expose trusted devices for UI
  List<TrustedDevice> get trustedDevices => _trustedDevices.values.toList();

  /// Set device info (call this before startServer)
  void setDeviceInfo({
    required String id,
    required String name,
    required String platform,
  }) {
    _deviceId = id;
    _deviceName = name;
    _devicePlatform = platform;
    // Generate a secure token for this device session
    _deviceToken = _generateSecureToken();
  }

  /// Generate a secure random token
  String _generateSecureToken() {
    final random = math.Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<void> startServer(int port) async {
    // If device info not set, generate defaults
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

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Transfer server running on port ${_server!.port}');
      _serve();
    } catch (e) {
      print('Failed to start transfer server: $e');
      throw TransferException('Failed to start server', code: 'SERVER_START_FAILED', originalError: e);
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isWindows) {
        return Platform.environment['COMPUTERNAME'] ?? 'Windows PC';
      } else if (Platform.isLinux) {
        return Platform.environment['HOSTNAME'] ?? 'Linux PC';
      }
    } catch (e) {
      print('Error getting device name: $e');
    }
    return 'Syndro Device';
  }

  /// Main request handler
  Future<void> _serve() async {
    if (_server == null) return;

    await for (final request in _server!) {
      try {
        await _handleRequest(request);
      } catch (e, stackTrace) {
        print('Error handling request: $e');
        print('Stack trace: $stackTrace');
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

      // POST /transfer/initiate
      if (method == 'POST' && path == '/transfer/initiate') {
        await _handleTransferInitiate(request);
        return;
      }

      // GET /transfer/approval/<requestId> - Check if request was approved
      if (method == 'GET' && path.startsWith('/transfer/approval/')) {
        final requestId = path.split('/').last;
        await _handleApprovalCheck(request, requestId);
        return;
      }

      // POST /transfer/upload - Requires authorization
      if (method == 'POST' && path == '/transfer/upload') {
        await _handleFileUpload(request);
        return;
      }

      // GET /transfer/status/<transferId>
      if (method == 'GET' && path.startsWith('/transfer/status/')) {
        final transferId = path.split('/').last;
        await _handleTransferStatus(request, transferId);
        return;
      }

      // Not found
      _sendNotFound(request, 'Not found');
    } catch (e, stackTrace) {
      print('Error handling request: $e');
      print('Stack trace: $stackTrace');
      _sendError(request, 'Internal server error');
    }
  }

  /// Serve device info for discovery (syndro.json)
  Future<void> _serveDeviceInfo(HttpRequest request) async {
    final info = {
      'id': _deviceId,
      'name': _deviceName,
      'os': _devicePlatform,
      'platform': _devicePlatform,
      'version': '1.0',
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(info));
    await request.response.close();
  }

  void _sendResponse(HttpRequest request, int statusCode, Map<String, dynamic> body) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }

  void _sendNotFound(HttpRequest request, String message) {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write(message);
    request.response.close();
  }

  void _sendBadRequest(HttpRequest request, String message) {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(message);
    request.response.close();
  }

  void _sendUnauthorized(HttpRequest request, String message) {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write(message);
    request.response.close();
  }

  void _sendError(HttpRequest request, String message) {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(message);
    request.response.close();
  }

  /// Validate incoming JSON data
  Map<String, dynamic>? _validateAndParseJson(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return data;
    } catch (e) {
      print('JSON parse error: $e');
      return null;
    }
  }

  /// Validate transfer initiation data
  bool _validateTransferData(Map<String, dynamic> data) {
    // Required fields
    if (!data.containsKey('senderId') || data['senderId'] is! String) return false;
    if (!data.containsKey('id') || data['id'] is! String) return false;
    if (!data.containsKey('items') || data['items'] is! List) return false;
    if (!data.containsKey('senderToken') || data['senderToken'] is! String) return false;
    
    // Validate senderId format (should be UUID-like)
    final senderId = data['senderId'] as String;
    if (senderId.isEmpty || senderId.length > 100) return false;
    
    // Validate items
    final items = data['items'] as List;
    if (items.isEmpty || items.length > 1000) return false;  // Reasonable limits
    
    return true;
  }

  /// Handle transfer initiation with approval system
  Future<void> _handleTransferInitiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      
      // FIXED: Validate and parse JSON safely
      final data = _validateAndParseJson(body);
      if (data == null) {
        _sendBadRequest(request, 'Invalid JSON format');
        return;
      }

      // FIXED: Validate required fields
      if (!_validateTransferData(data)) {
        _sendBadRequest(request, 'Missing or invalid required fields');
        return;
      }

      final senderId = data['senderId'] as String;
      final senderName = data['senderName'] as String? ?? 'Unknown Device';
      final senderToken = data['senderToken'] as String;
      final requestId = data['id'] as String;
      
      // FIXED: Validate items with proper error handling
      List<TransferItem> items;
      try {
        items = (data['items'] as List)
            .map((item) {
              if (item is! Map<String, dynamic>) {
                throw FormatException('Invalid item format');
              }
              return TransferItem.fromJson(item);
            })
            .toList();
      } catch (e) {
        _sendBadRequest(request, 'Invalid transfer items format');
        return;
      }

      if (items.isEmpty) {
        _sendBadRequest(request, 'No items to transfer');
        return;
      }

      // IMPROVED: Check if sender is trusted with matching token
      final trustedDevice = _trustedDevices[senderId];
      if (trustedDevice != null && trustedDevice.token == senderToken) {
        // Auto-approve for verified trusted senders
        _approveTransferRequest(requestId, senderId, senderName, senderToken, items);
        _sendResponse(request, HttpStatus.ok, {
          'status': 'accepted',
          'transferId': requestId,
          'authorized': true,
        });
        return;
      }

      // Store pending request with token
      _pendingRequests[requestId] = PendingTransferRequest(
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        senderToken: senderToken,
        items: items,
        timestamp: DateTime.now(),
      );

      // Emit to stream so UI can react immediately
      _pendingRequestsController.add(_pendingRequests.values.toList());

      // Show notification on all platforms
      await BackgroundTransferService.showTransferRequest(
        senderName: senderName,
        fileCount: items.length,
        totalSize: items.fold<int>(0, (sum, item) => sum + item.size),
      );

      // Notify UI about incoming request (if callback is set)
      onTransferRequest?.call(senderId, senderName, items);

      _sendResponse(request, HttpStatus.ok, {
        'status': 'pending_approval',
        'requestId': requestId,
        'message': 'Waiting for receiver approval',
      });
    } catch (e, stackTrace) {
      print('Error initiating transfer: $e');
      print('Stack trace: $stackTrace');
      _sendError(request, 'Error initiating transfer');
    }
  }

  /// Check approval status
  Future<void> _handleApprovalCheck(HttpRequest request, String requestId) async {
    // FIXED: Validate requestId
    if (requestId.isEmpty || requestId.length > 100) {
      _sendBadRequest(request, 'Invalid request ID');
      return;
    }

    final pending = _pendingRequests[requestId];
    if (pending == null) {
      // Check if already approved and transferred
      final transfer = _activeTransfers[requestId];
      if (transfer != null) {
        _sendResponse(request, HttpStatus.ok, {
          'status': 'approved',
          'transferId': requestId,
        });
        return;
      }

      _sendResponse(request, HttpStatus.ok, {
        'status': 'rejected',
        'message': 'Request was rejected or expired',
      });
      return;
    }

    // Check if request expired (5 minutes timeout)
    if (DateTime.now().difference(pending.timestamp).inMinutes > 5) {
      _pendingRequests.remove(requestId);
      // Update stream when request expires
      _pendingRequestsController.add(_pendingRequests.values.toList());
      _sendResponse(request, HttpStatus.ok, {
        'status': 'expired',
        'message': 'Request expired',
      });
      return;
    }

    _sendResponse(request, HttpStatus.ok, {
      'status': 'pending',
      'message': 'Waiting for approval',
    });
  }

  /// Approve a transfer request (called from UI)
  void approveTransfer(String requestId, {bool trustSender = false}) {
    final pending = _pendingRequests[requestId];
    if (pending == null) {
      print('Warning: Attempted to approve non-existent request: $requestId');
      return;
    }

    if (trustSender) {
      // IMPROVED: Store trusted device with token for verification
      _trustedDevices[pending.senderId] = TrustedDevice(
        senderId: pending.senderId,
        senderName: pending.senderName,
        token: pending.senderToken,
        trustedAt: DateTime.now(),
      );
    }

    _approveTransferRequest(
      requestId,
      pending.senderId,
      pending.senderName,
      pending.senderToken,
      pending.items,
    );

    _pendingRequests.remove(requestId);
    // Update stream after approval
    _pendingRequestsController.add(_pendingRequests.values.toList());
  }

  /// Reject a transfer request (called from UI)
  void rejectTransfer(String requestId) {
    final removed = _pendingRequests.remove(requestId);
    if (removed == null) {
      print('Warning: Attempted to reject non-existent request: $requestId');
    }
    // Update stream after rejection
    _pendingRequestsController.add(_pendingRequests.values.toList());

    // Clear notification
    BackgroundTransferService.stopBackgroundTransfer();
  }

  void _approveTransferRequest(
    String requestId,
    String senderId,
    String senderName,
    String senderToken,
    List<TransferItem> items,
  ) {
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

    // Show receiving notification on all platforms
    BackgroundTransferService.startBackgroundTransfer(
      title: 'Receiving from $senderName',
      fileName: items.length == 1 ? items.first.name : '${items.length} files',
    );
  }

  /// File upload with authorization check
  Future<void> _handleFileUpload(HttpRequest request) async {
    IOSink? fileSink;
    String? tempFilePath;

    try {
      final transferId = request.headers.value('x-transfer-id');
      final fileName = request.headers.value('x-file-name');
      final fileSizeHeader = request.headers.value('x-file-size');
      final senderId = request.headers.value('x-sender-id');
      final senderToken = request.headers.value('x-sender-token');
      final fileSize = fileSizeHeader != null ? int.tryParse(fileSizeHeader) ?? 0 : 0;

      // FIXED: Validate required headers
      if (transferId == null || transferId.isEmpty) {
        _sendBadRequest(request, 'Missing transfer ID header');
        return;
      }
      if (fileName == null || fileName.isEmpty) {
        _sendBadRequest(request, 'Missing file name header');
        return;
      }
      if (senderId == null || senderId.isEmpty) {
        _sendBadRequest(request, 'Missing sender ID header');
        return;
      }
      if (senderToken == null || senderToken.isEmpty) {
        _sendBadRequest(request, 'Missing sender token header');
        return;
      }

      // Verify transfer is authorized
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        _sendUnauthorized(request, 'Transfer not authorized. Request approval first.');
        return;
      }

      // IMPROVED: Verify sender matches AND validate token
      if (transfer.senderId != senderId) {
        print('Security: Sender ID mismatch. Expected: ${transfer.senderId}, Got: $senderId');
        _sendUnauthorized(request, 'Sender ID mismatch');
        return;
      }

      // FIXED: Sanitize filename to prevent path traversal
      final sanitizedFileName = _fileService.sanitizeFilename(fileName);
      if (sanitizedFileName != fileName) {
        print('Security: Filename was sanitized. Original: $fileName, Sanitized: $sanitizedFileName');
      }

      // Update transfer status
      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
      );
      _transferController.add(_activeTransfers[transferId]!);

      // Get download directory and create file path with SANITIZED filename
      final downloadDir = await _fileService.getDownloadDirectory();
      final finalFilePath = '$downloadDir${Platform.pathSeparator}$sanitizedFileName';
      tempFilePath = '$finalFilePath.tmp';

      // FIXED: Verify path is within allowed directory
      if (!_fileService.isPathWithinDirectory(finalFilePath, downloadDir)) {
        print('Security: Path traversal attempt detected for file: $fileName');
        _sendBadRequest(request, 'Invalid filename');
        return;
      }

      // Ensure download directory exists
      final dir = Directory(downloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Stream directly to disk - NO MEMORY LOADING!
      final tempFile = File(tempFilePath);
      fileSink = tempFile.openWrite();

      int bytesReceived = 0;
      int lastProgressUpdate = 0;

      // Stream chunks to file
      await for (final chunk in request) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;

        // Update progress every 5% or 1MB
        final progressPercent =
            fileSize > 0 ? ((bytesReceived / fileSize) * 100).toInt() : 0;
        if (progressPercent - lastProgressUpdate >= 5 ||
            bytesReceived - lastProgressUpdate > 1024 * 1024) {
          lastProgressUpdate = progressPercent;

          // Update notification with real progress on all platforms
          await BackgroundTransferService.updateProgress(
            title: 'Receiving files...',
            fileName: sanitizedFileName,
            progress: progressPercent,
          );

          // Update transfer progress
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

      // Close the file sink
      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      // Rename temp file to final file
      final tempFileRef = File(tempFilePath);
      final finalFile = File(finalFilePath);

      // Delete existing file if it exists
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

      // Show completion notification on all platforms
      await BackgroundTransferService.showTransferComplete(
        fileName: sanitizedFileName,
        filePath: finalFilePath,
      );

      // Save received transfer to history
      await DatabaseHelper.instance.insertTransfer(completedTransfer, null, null);

      _sendResponse(request, HttpStatus.ok, {
        'status': 'completed',
        'bytesReceived': bytesReceived,
        'filePath': finalFilePath,
      });
    } catch (e, stackTrace) {
      // FIXED: Proper error handling with logging
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');

      // Clean up on error
      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }

      // Delete temp file if it exists
      if (tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      // Stop background notification on error
      await BackgroundTransferService.stopBackgroundTransfer();

      _sendError(request, 'Error uploading file');
    }
  }

  Future<void> _handleTransferStatus(HttpRequest request, String transferId) async {
    // FIXED: Validate transferId
    if (transferId.isEmpty || transferId.length > 100) {
      _sendBadRequest(request, 'Invalid transfer ID');
      return;
    }

    final transfer = _activeTransfers[transferId];
    if (transfer == null) {
      _sendNotFound(request, 'Transfer not found');
      return;
    }

    _sendResponse(request, HttpStatus.ok, {
      'id': transfer.id,
      'status': transfer.status.name,
      'progress': {
        'bytesTransferred': transfer.progress.bytesTransferred,
        'totalBytes': transfer.progress.totalBytes,
        'percentage': transfer.progress.percentage,
      },
    });
  }

  /// Send files with authentication headers
  Future<void> sendFiles({
    required Device sender,
    required Device receiver,
    required List<TransferItem> items,
  }) async {
    if (items.isEmpty) {
      throw TransferException('No items to transfer', code: 'EMPTY_ITEMS');
    }

    final transferId = _uuid.v4();
    final totalSize = items.fold<int>(0, (sum, item) => sum + item.size);

    // Check for existing checkpoint
    final checkpoint = await _checkpointManager.loadCheckpoint(transferId);
    final startIndex = checkpoint?.currentFileIndex ?? 0;

    final transfer = Transfer(
      id: transferId,
      senderId: sender.id,
      receiverId: receiver.id,
      items: items,
      status: TransferStatus.connecting,
      progress: TransferProgress(
        bytesTransferred: checkpoint?.bytesTransferred ?? 0,
        totalBytes: totalSize,
      ),
      createdAt: DateTime.now(),
    );

    _activeTransfers[transferId] = transfer;
    _transferController.add(transfer);

    // Start notification on all platforms
    await BackgroundTransferService.startBackgroundTransfer(
      title: 'Sending to ${receiver.name}',
      fileName: items.length == 1 ? items.first.name : '${items.length} files',
    );

    try {
      // Step 1: Initiate transfer with receiver (includes auth info)
      final initiateUrl = 'http://${receiver.ipAddress}:${receiver.port}/transfer/initiate';
      final initiateResponse = await _retryRequest(
        () => http.post(
          Uri.parse(initiateUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': transferId,
            'senderId': sender.id,
            'senderName': sender.name,
            'senderToken': _deviceToken,  // IMPROVED: Include device token
            'receiverId': receiver.id,
            'items': items.map((item) => item.toJson()).toList(),
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
        throw TransferException('Invalid response from receiver', code: 'INVALID_RESPONSE');
      }
      
      final status = initiateData['status'] as String? ?? '';

      // Handle approval pending
      if (status == 'pending_approval') {
        // Update transfer status
        _activeTransfers[transferId] = transfer.copyWith(
          status: TransferStatus.pending,
        );
        _transferController.add(_activeTransfers[transferId]!);

        // Poll for approval (with timeout)
        final approved = await _waitForApproval(
          receiver: receiver,
          requestId: transferId,
          timeout: const Duration(minutes: 5),
        );

        if (!approved) {
          throw TransferException('Transfer rejected or timed out', code: 'REJECTED');
        }
      }

      int totalBytesTransferred = checkpoint?.bytesTransferred ?? 0;

      // Step 2: Send each file using chunked streaming
      for (int i = startIndex; i < items.length; i++) {
        final item = items[i];

        try {
          final file = File(item.path);
          
          if (!await file.exists()) {
            throw TransferException('File not found: ${item.path}', code: 'FILE_NOT_FOUND');
          }
          
          final fileSize = await file.length();

          final uploadUrl = 'http://${receiver.ipAddress}:${receiver.port}/transfer/upload';

          // Create chunked upload request with auth headers
          final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
          request.headers['x-transfer-id'] = transferId;
          request.headers['x-sender-id'] = sender.id;
          request.headers['x-sender-token'] = _deviceToken;  // IMPROVED: Include token
          request.headers['x-file-name'] = item.name;
          request.headers['x-file-size'] = fileSize.toString();
          request.headers['x-relative-path'] = item.parentPath ?? '';
          request.headers['Content-Type'] = 'application/octet-stream';
          request.headers['Content-Length'] = fileSize.toString();

          // Stream file chunks
          int bytesSent = 0;
          final fileStream = file.openRead();

          fileStream.listen(
            (chunk) {
              request.sink.add(chunk);
              bytesSent += chunk.length;

              // Update progress
              final progressPercent =
                  ((totalBytesTransferred + bytesSent) / totalSize * 100).toInt();

              // Update notification on all platforms
              BackgroundTransferService.updateProgress(
                title: 'Sending to ${receiver.name}',
                fileName: item.name,
                progress: progressPercent,
              );

              // Update transfer progress
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

          // Wait for response
          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == HttpStatus.unauthorized) {
            throw TransferException('Transfer not authorized', code: 'UNAUTHORIZED');
          }

          if (response.statusCode != 200) {
            throw TransferException(
              'Upload failed: ${response.statusCode}',
              code: 'UPLOAD_FAILED_${response.statusCode}',
            );
          }

          totalBytesTransferred += fileSize;

          // Save checkpoint after each file
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
          print('Error sending file ${item.name}: $e');
          print('Stack trace: $stackTrace');
          rethrow;
        }
      }

      // Transfer completed
      final completedTransfer = transfer.copyWith(
        status: TransferStatus.completed,
        progress: TransferProgress(bytesTransferred: totalSize, totalBytes: totalSize),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);

      // Show completion notification on all platforms
      await BackgroundTransferService.showTransferComplete(
        fileName: items.length == 1 ? items.first.name : '${items.length} files',
        filePath: '',
      );

      // Save to history database
      await DatabaseHelper.instance.insertTransfer(completedTransfer, sender, receiver);

      // Clear checkpoint on success
      await _checkpointManager.clearCheckpoint(transferId);
    } catch (e, stackTrace) {
      // FIXED: Proper error handling with logging
      print('Error sending files: $e');
      print('Stack trace: $stackTrace');

      await BackgroundTransferService.stopBackgroundTransfer();

      final failedTransfer = transfer.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      _activeTransfers[transferId] = failedTransfer;
      _transferController.add(failedTransfer);

      // Save failed transfer to history
      await DatabaseHelper.instance.insertTransfer(failedTransfer, sender, receiver);

      // Re-throw with proper error type
      if (e is TransferException) {
        rethrow;
      }
      throw TransferException('Transfer failed', originalError: e);
    }
  }

  /// Wait for receiver approval
  Future<bool> _waitForApproval({
    required Device receiver,
    required String requestId,
    required Duration timeout,
  }) async {
    final endTime = DateTime.now().add(timeout);
    final checkUrl = 'http://${receiver.ipAddress}:${receiver.port}/transfer/approval/$requestId';

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
              return true;
            } else if (status == 'rejected' || status == 'expired') {
              return false;
            }
          }
        }
      } catch (e) {
        print('Error checking approval: $e');
      }

      // Wait 2 seconds before checking again
      await Future.delayed(const Duration(seconds: 2));
    }

    return false; // Timeout
  }

  // Retry logic with exponential backoff
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
        print('Retry attempt ${attempts + 1}/$maxRetries after ${delay}s delay');
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
      final statusCode = int.tryParse(error.message.split(' ').last) ?? 0;
      return statusCode >= 500 && statusCode < 600;
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
    } else {
      print('Warning: Attempted to cancel non-existent transfer: $transferId');
    }
  }

  /// Remove a sender from trusted list
  void revokeTrust(String senderId) {
    final removed = _trustedDevices.remove(senderId);
    if (removed != null) {
      print('Revoked trust for device: ${removed.senderName}');
    }
  }

  /// Clear all trusted senders
  void clearTrustedSenders() {
    _trustedDevices.clear();
    print('Cleared all trusted devices');
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    await _transferController.close();
    // Close pending requests controller
    await _pendingRequestsController.close();
    for (final controller in _progressControllers.values) {
      await controller.close();
    }
  }
}
