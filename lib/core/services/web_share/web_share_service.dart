import 'dart:async';
import 'dart:io';

import 'models/received_file.dart';
import 'models/pending_files_manager.dart';
import 'servers/share_server.dart';
import 'servers/receive_server.dart';

export 'models/received_file.dart';
export 'models/pending_files_manager.dart';
export 'servers/share_server.dart' show ConnectionEvent, ConnectionEventType, PendingConfirmation;

/// Main facade for web sharing functionality
///
/// This service orchestrates file sharing and receiving via HTTP servers.
/// It provides a unified interface for:
/// - Sharing files (others can download from you)
/// - Receiving files (others can upload to you)
/// - Managing pending files (save/discard)
class WebShareService {
  final ShareServer _shareServer = ShareServer();
  final ReceiveServer _receiveServer = ReceiveServer();

  /// Stream of received files
  Stream<ReceivedFile> get receivedFilesStream =>
      _receiveServer.receivedFilesStream;

  /// Stream of pending files list updates
  Stream<List<ReceivedFile>> get pendingFilesStream =>
      _receiveServer.pendingFilesStream;

  /// Get pending files manager for direct access
  PendingFilesManager get pendingFilesManager =>
      _receiveServer.pendingFilesManager;

  /// Stream of connection events (connect, download start/complete)
  Stream<ConnectionEvent> get connectionEventStream =>
      _shareServer.connectionEventStream;

  /// Stream of active connection count changes
  Stream<int> get activeConnectionCountStream =>
      _shareServer.activeConnectionCountStream;

  /// Stream of pending connection confirmation requests
  /// Listen to this to show approval/deny dialogs when someone tries to download
  Stream<PendingConfirmation> get confirmationRequestStream =>
      _shareServer.confirmationRequestStream;

  /// Get list of pending confirmation requests
  List<PendingConfirmation> get pendingConfirmations =>
      _shareServer.pendingConfirmations;

  /// Confirm a pending connection by IP address
  /// Returns true if the confirmation was successful
  bool confirmConnection(String ipAddress) =>
      _shareServer.confirmConnection(ipAddress);

  /// Deny a pending connection by IP address
  /// Returns true if the denial was successful
  bool denyConnection(String ipAddress) =>
      _shareServer.denyConnection(ipAddress);

  /// Enable or disable requiring user confirmation before allowing downloads
  void setRequireConfirmation(bool require) =>
      _shareServer.setRequireConfirmation(require);

  /// Current number of active connections
  int get activeConnectionCount => _shareServer.activeConnectionCount;

  /// Get current share URL (for sharing or receiving)
  String? get shareUrl => _shareServer.shareUrl ?? _receiveServer.shareUrl;

  /// Check if currently sharing
  bool get isSharing => _shareServer.isSharing || _receiveServer.isReceiving;

  /// Get list of pending files
  List<ReceivedFile> get pendingFiles => pendingFilesManager.pendingFiles;

  /// Get list of unsaved pending files
  List<ReceivedFile> get unsavedFiles => pendingFilesManager.unsavedFiles;

  /// Check if there are pending files
  bool get hasPendingFiles => pendingFilesManager.hasPendingFiles;

  /// Get count of pending files
  int get pendingCount => pendingFilesManager.pendingCount;

  /// Get final directory path
  String? get finalDirectory => _receiveServer.finalDirectory;

  /// Start sharing files via HTTP server
  ///
  /// Creates an HTTP server that serves the provided files for download.
  /// Returns the URL that others can use to download the files.
  ///
  /// [expiryDuration] - Optional custom expiry duration (defaults to 1 hour)
  /// 
  /// Example:
  /// ```dart
  /// final url = await webShareService.startSharing([file1, file2]);
  /// print('Share URL: $url'); // http://192.168.1.100:8766
  /// 
  /// // With custom 30 minute expiry:
  /// final url = await webShareService.startSharing([file1], expiryDuration: Duration(minutes: 30));
  /// ```
  Future<String?> startSharing(List<File> files, {Duration? expiryDuration}) async {
    // Stop any existing sharing/receiving
    await stopSharing();
    return _shareServer.startSharing(files, expiryDuration: expiryDuration);
  }

  /// Start receiving files via HTTP server
  ///
  /// Creates an HTTP server that accepts file uploads from others.
  /// Files are stored in a temp location until saved/discarded.
  /// Returns the URL that others can use to upload files.
  ///
  /// [expiryDuration] - Optional custom expiry duration (defaults to 1 hour)
  ///
  /// Example:
  /// ```dart
  /// final url = await webShareService.startReceiving('/path/to/downloads');
  /// print('Receive URL: $url'); // http://192.168.1.100:8767
  /// ```
  Future<String?> startReceiving(String downloadDirectory, {Duration? expiryDuration}) async {
    // Stop any existing sharing/receiving
    await stopSharing();
    return _receiveServer.startReceiving(downloadDirectory, expiryDuration: expiryDuration);
  }

  /// Save a single pending file to final destination
  ///
  /// Returns true if save was successful, false otherwise.
  Future<bool> saveFile(ReceivedFile file) async {
    return pendingFilesManager.saveFile(file);
  }

  /// Save all pending files to final destination
  ///
  /// Returns a result with success/fail counts.
  Future<SaveAllResult> saveAllFiles() async {
    return pendingFilesManager.saveAllFiles();
  }

  /// Discard a single pending file (delete from temp)
  ///
  /// Returns true if discard was successful, false otherwise.
  Future<bool> discardFile(ReceivedFile file) async {
    return pendingFilesManager.discardFile(file);
  }

  /// Discard all pending files
  Future<void> discardAllFiles() async {
    return pendingFilesManager.discardAllFiles();
  }

  /// Remove a file from the pending list (after save or discard)
  void removeFile(ReceivedFile file) {
    pendingFilesManager.removeFile(file);
  }

  /// Clear all pending files and clean up
  Future<void> clearPendingFiles() async {
    await pendingFilesManager.clearAll();
  }

  /// Stop sharing/receiving and close all servers
  Future<void> stopSharing() async {
    await _shareServer.stop();
    await _receiveServer.stop();
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _shareServer.dispose();
    await _receiveServer.dispose();
  }
}
