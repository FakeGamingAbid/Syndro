import 'dart:async';
import 'dart:io';

import 'models/received_file.dart';
import 'servers/share_server.dart';
import 'servers/receive_server.dart';

export 'models/received_file.dart';

/// Main facade for web sharing functionality
/// 
/// This service orchestrates file sharing and receiving via HTTP servers.
/// It provides a unified interface for:
/// - Sharing files (others can download from you)
/// - Receiving files (others can upload to you)
class WebShareService {
  final ShareServer _shareServer = ShareServer();
  final ReceiveServer _receiveServer = ReceiveServer();

  /// Stream of received files
  Stream<ReceivedFile> get receivedFilesStream => _receiveServer.receivedFilesStream;

  /// Get current share URL (for sharing or receiving)
  String? get shareUrl => _shareServer.shareUrl ?? _receiveServer.shareUrl;

  /// Check if currently sharing
  bool get isSharing => _shareServer.isSharing || _receiveServer.isReceiving;

  /// Start sharing files via HTTP server
  /// 
  /// Creates an HTTP server that serves the provided files for download.
  /// Returns the URL that others can use to download the files.
  /// 
  /// Example:
  /// ```dart
  /// final url = await webShareService.startSharing([file1, file2]);
  /// print('Share URL: $url'); // http://192.168.1.100:8766
  /// ```
  Future<String?> startSharing(List<File> files) async {
    // Stop any existing sharing/receiving
    await stopSharing();
    return _shareServer.startSharing(files);
  }

  /// Start receiving files via HTTP server
  /// 
  /// Creates an HTTP server that accepts file uploads from others.
  /// Returns the URL that others can use to upload files.
  /// 
  /// Example:
  /// ```dart
  /// final url = await webShareService.startReceiving('/path/to/downloads');
  /// print('Receive URL: $url'); // http://192.168.1.100:8767
  /// ```
  Future<String?> startReceiving(String downloadDirectory) async {
    // Stop any existing sharing/receiving
    await stopSharing();
    return _receiveServer.startReceiving(downloadDirectory);
  }

  /// Stop sharing/receiving and close all servers
  Future<void> stopSharing() async {
    await _shareServer.stop();
    await _receiveServer.stop();
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _shareServer.stop();
    await _receiveServer.dispose();
  }
}
