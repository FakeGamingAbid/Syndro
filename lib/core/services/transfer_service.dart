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

/// Pending transfer request model
class PendingTransferRequest {
  final String requestId;
  final String senderId;
  final String senderName;
  final List<TransferItem> items;
  final DateTime timestamp;

  PendingTransferRequest({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.items,
    required this.timestamp,
  });
}

class TransferService {
  final FileService _fileService;
  final CheckpointManager _checkpointManager = CheckpointManager();
  final _uuid = const Uuid();
  final _transferController = StreamController<Transfer>.broadcast();
  final Map<String, Transfer> _activeTransfers = {};
  final Map<String, StreamController<TransferProgress>> _progressControllers = {};

  // Track authorized senders and pending requests
  final Set<String> _authorizedSenders = {};
  final Map<String, PendingTransferRequest> _pendingRequests = {};

  // Stream controller for pending requests (for UI to listen)
  final _pendingRequestsController = StreamController<List<PendingTransferRequest>>.broadcast();

  HttpServer? _server;

  // Device info - set from outside
  String _deviceId = '';
  String _deviceName = '';
  String _devicePlatform = '';

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

  /// Set device info (call this before startServer)
  void setDeviceInfo({
    required String id,
    required String name,
    required String platform,
  }) {
    _deviceId = id;
    _deviceName = name;
    _devicePlatform = platform;
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

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Transfer server running on port ${_server!.port}');
      _serve();
    } catch (e) {
      print('Failed to start transfer server: $e');
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
      } catch (e) {
        print('Error handling request: $e');
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
    } catch (e) {
      print('Error handling request: $e');
      _sendError(request, 'Internal server error: $e');
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

  /// Handle transfer initiation with approval system
  Future<void> _handleTransferInitiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final senderId = data['senderId'] as String;
      final senderName = data['senderName'] as String? ?? 'Unknown Device';
      final requestId = data['id'] as String;
      final items = (data['items'] as List)
          .map((item) => TransferItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Check if sender is already authorized
      if (_authorizedSenders.contains(senderId)) {
        // Auto-approve for trusted senders
        _approveTransferRequest(requestId, senderId, senderName, items);
        _sendResponse(request, HttpStatus.ok, {
          'status': 'accepted',
          'transferId': requestId,
          'authorized': true,
        });
        return;
      }

      // Store pending request
      _pendingRequests[requestId] = PendingTransferRequest(
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
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
    } catch (e) {
      _sendError(request, 'Error initiating transfer: $e');
    }
  }

  /// Check approval status
  Future<void> _handleApprovalCheck(HttpRequest request, String requestId) async {
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
    if (pending == null) return;

    if (trustSender) {
      _authorizedSenders.add(pending.senderId);
    }

    _approveTransferRequest(
      requestId,
      pending.senderId,
      pending.senderName,
      pending.items,
    );
    _pendingRequests.remove(requestId);

    // Update stream after approval
    _pendingRequestsController.add(_pendingRequests.values.toList());
  }

  /// Reject a transfer request (called from UI)
  void rejectTransfer(String requestId) {
    _pendingRequests.remove(requestId);

    // Update stream after rejection
    _pendingRequestsController.add(_pendingRequests.values.toList());

    // Clear notification
    BackgroundTransferService.stopBackgroundTransfer();
  }

  void _approveTransferRequest(
    String requestId,
    String senderId,
    String senderName,
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
      final fileSize = fileSizeHeader != null ? int.tryParse(fileSizeHeader) ?? 0 : 0;

      if (transferId == null || fileName == null) {
        _sendBadRequest(request, 'Missing required headers');
        return;
      }

      // Verify transfer is authorized
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        _sendUnauthorized(request, 'Transfer not authorized. Request approval first.');
        return;
      }

      // Verify sender matches
      if (senderId != null && transfer.senderId != senderId) {
        _sendUnauthorized(request, 'Sender ID mismatch');
        return;
      }

      // Update transfer status
      _activeTransfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
      );
      _transferController.add(_activeTransfers[transferId]!);

      // Get download directory and create file path
      final downloadDir = await _fileService.getDownloadDirectory();
      final finalFilePath = '$downloadDir${Platform.pathSeparator}$fileName';
      tempFilePath = '$finalFilePath.tmp';

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
        final progressPercent = fileSize > 0 ? ((bytesReceived / fileSize) * 100).toInt() : 0;
        if (progressPercent - lastProgressUpdate >= 5 || bytesReceived - lastProgressUpdate > 1024 * 1024) {
          lastProgressUpdate = progressPercent;

          // Update notification with real progress on all platforms
          await BackgroundTransferService.updateProgress(
            title: 'Receiving files...',
            fileName: fileName,
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
        fileName: fileName,
        filePath: finalFilePath,
      );

      // Save received transfer to history
      await DatabaseHelper.instance.insertTransfer(completedTransfer, null, null);

      _sendResponse(request, HttpStatus.ok, {
        'status': 'completed',
        'bytesReceived': bytesReceived,
        'filePath': finalFilePath,
      });
    } catch (e) {
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

      print('Error uploading file: $e');
      _sendError(request, 'Error uploading file: $e');
    }
  }

  Future<void> _handleTransferStatus(HttpRequest request, String transferId) async {
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
            'receiverId': receiver.id,
            'items': items.map((item) => item.toJson()).toList(),
          }),
        ),
      );

      if (initiateResponse.statusCode != 200) {
        throw Exception('Failed to initiate transfer: ${initiateResponse.statusCode}');
      }

      final initiateData = jsonDecode(initiateResponse.body) as Map<String, dynamic>;
      final status = initiateData['status'] as String;

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
          throw Exception('Transfer rejected or timed out');
        }
      }

      int totalBytesTransferred = checkpoint?.bytesTransferred ?? 0;

      // Step 2: Send each file using chunked streaming
      for (int i = startIndex; i < items.length; i++) {
        final item = items[i];

        try {
          final file = File(item.path);
          final fileSize = await file.length();

          final uploadUrl = 'http://${receiver.ipAddress}:${receiver.port}/transfer/upload';

          // Create chunked upload request with auth headers
          final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
          request.headers['x-transfer-id'] = transferId;
          request.headers['x-sender-id'] = sender.id;
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
              final progressPercent = ((totalBytesTransferred + bytesSent) / totalSize * 100).toInt();

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
            throw Exception('Transfer not authorized: $responseBody');
          }

          if (response.statusCode != 200) {
            throw Exception('Upload failed: ${response.statusCode} - $responseBody');
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
        } catch (e) {
          print('Error sending file ${item.name}: $e');
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
    } catch (e) {
      // Transfer failed
      await BackgroundTransferService.stopBackgroundTransfer();

      final failedTransfer = transfer.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      _activeTransfers[transferId] = failedTransfer;
      _transferController.add(failedTransfer);

      // Save failed transfer to history
      await DatabaseHelper.instance.insertTransfer(failedTransfer, sender, receiver);

      print('Error sending files: $e');
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
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String;

          if (status == 'approved') {
            return true;
          } else if (status == 'rejected' || status == 'expired') {
            return false;
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
    }
  }

  /// Remove a sender from trusted list
  void revokeTrust(String senderId) {
    _authorizedSenders.remove(senderId);
  }

  /// Clear all trusted senders
  void clearTrustedSenders() {
    _authorizedSenders.clear();
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
