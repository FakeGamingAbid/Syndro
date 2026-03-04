// Test helpers and shared fixtures for TransferService tests

import 'dart:typed_data';

import 'package:syndro/core/models/device.dart';
import 'package:syndro/core/models/transfer.dart';
import 'package:syndro/core/models/transfer_checkpoint.dart';
import 'package:syndro/core/services/transfer_service/models.dart';

// ============================================================================
// Fake Device - Test fixture for Device model
// ============================================================================

/// Creates a fake Device for testing
class FakeDevice {
  static Device create({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? 'test-device-id-${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Test Device',
      platform: platform ?? DevicePlatform.android,
      ipAddress: ipAddress ?? '192.168.1.100',
      port: port ?? 8765,
      isOnline: isOnline ?? true,
      lastSeen: lastSeen ?? DateTime.now(),
    );
  }

  /// Creates a sender device for transfer tests
  static Device createSender() {
    return create(
      id: 'sender-device-id',
      name: 'Sender Device',
      platform: DevicePlatform.android,
      ipAddress: '192.168.1.100',
      port: 8765,
    );
  }

  /// Creates a receiver device for transfer tests
  static Device createReceiver() {
    return create(
      id: 'receiver-device-id',
      name: 'Receiver Device',
      platform: DevicePlatform.windows,
      ipAddress: '192.168.1.200',
      port: 8765,
    );
  }
}

// ============================================================================
// Fake TransferItem - Test fixture for TransferItem model
// ============================================================================

/// Creates a fake TransferItem for testing
class FakeTransferItem {
  static TransferItem create({
    String? name,
    String? path,
    int? size,
    bool? isDirectory,
    String? parentPath,
    int? itemCount,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return TransferItem(
      name: name ?? 'test-file.txt',
      path: path ?? '/tmp/test-file.txt',
      size: size ?? 1024,
      isDirectory: isDirectory ?? false,
      parentPath: parentPath,
      itemCount: itemCount ?? 0,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
  }

  /// Creates a small file item (< 10MB)
  static TransferItem createSmallFile() {
    return create(
      name: 'small-file.txt',
      path: '/tmp/small-file.txt',
      size: 1024, // 1KB - under 10MB threshold
    );
  }

  /// Creates a large file item (> 10MB) for parallel transfer tests
  static TransferItem createLargeFile() {
    return create(
      name: 'large-file.bin',
      path: '/tmp/large-file.bin',
      size: 15 * 1024 * 1024, // 15MB - over 10MB threshold
    );
  }

  /// Creates multiple small files for sequential transfer tests
  static List<TransferItem> createMultipleFiles({int count = 3}) {
    return List.generate(
      count,
      (index) => create(
        name: 'file-$index.txt',
        path: '/tmp/file-$index.txt',
        size: 1024 * (index + 1),
      ),
    );
  }
}

// ============================================================================
// Fake TrustedDevice - Test fixture for trusted device handling
// ============================================================================

/// Creates a fake TrustedDevice for testing
class FakeTrustedDevice {
  static TrustedDevice create({
    String? senderId,
    String? senderName,
    String? token,
    DateTime? trustedAt,
  }) {
    return TrustedDevice(
      senderId: senderId ?? 'trusted-device-id',
      senderName: senderName ?? 'Trusted Device',
      token: token ?? 'test-token-${DateTime.now().millisecondsSinceEpoch}',
      trustedAt: trustedAt ?? DateTime.now(),
    );
  }

  /// Creates a list of trusted devices
  static List<TrustedDevice> createList({int count = 2}) {
    return List.generate(
      count,
      (index) => create(
        senderId: 'trusted-device-$index',
        senderName: 'Trusted Device $index',
        token: 'token-$index',
      ),
    );
  }
}

// ============================================================================
// Fake TransferCheckpoint - Test fixture for resume tests
// ============================================================================

/// Creates a fake TransferCheckpoint for testing resume functionality
class FakeTransferCheckpoint {
  static TransferCheckpoint create({
    String? transferId,
    String? fileId,
    int? bytesTransferred,
    DateTime? timestamp,
    int? currentFileIndex,
    int? totalFiles,
    List<String>? filePaths,
  }) {
    return TransferCheckpoint(
      transferId: transferId ?? 'test-checkpoint-${DateTime.now().millisecondsSinceEpoch}',
      fileId: fileId ?? 'test-file.txt',
      bytesTransferred: bytesTransferred ?? 0,
      timestamp: timestamp ?? DateTime.now(),
      currentFileIndex: currentFileIndex ?? 0,
      totalFiles: totalFiles ?? 1,
      filePaths: filePaths,
    );
  }

  /// Creates a checkpoint for resuming a partially transferred file
  static TransferCheckpoint createForResume({
    String? transferId,
    int? bytesTransferred,
    int? currentFileIndex,
    int? totalFiles,
  }) {
    return create(
      transferId: transferId ?? 'resume-checkpoint',
      bytesTransferred: bytesTransferred ?? 512 * 1024, // 512KB transferred
      currentFileIndex: currentFileIndex ?? 0,
      totalFiles: totalFiles ?? 1,
      filePaths: ['/tmp/test-file.bin'],
    );
  }
}

// ============================================================================
// Fake PendingTransferRequest - Test fixture for incoming transfer tests
// ============================================================================

/// Creates a fake PendingTransferRequest for testing
class FakePendingTransferRequest {
  static PendingTransferRequest create({
    String? requestId,
    String? senderId,
    String? senderName,
    String? senderToken,
    List<TransferItem>? items,
    DateTime? timestamp,
    Uint8List? senderPublicKey,
    bool? isParallelTransfer,
    Map<String, dynamic>? parallelData,
    bool? isTrusted,
  }) {
    return PendingTransferRequest(
      requestId: requestId ?? 'test-request-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId ?? 'sender-device-id',
      senderName: senderName ?? 'Sender Device',
      senderToken: senderToken ?? 'test-token',
      items: items ?? [FakeTransferItem.create()],
      timestamp: timestamp ?? DateTime.now(),
      senderPublicKey: senderPublicKey,
      isParallelTransfer: isParallelTransfer ?? false,
      parallelData: parallelData,
      isTrusted: isTrusted ?? false,
    );
  }
}

// ============================================================================
// Mock SecretKey - For encryption testing
// ============================================================================

// Note: We use mocktail to mock the SecretKey interface in tests
// See transfer_service_test.dart for mock setup

// Placeholder for SecretKey mock - actual mocking done in test file
class FakeSecretKeyPlaceholder {}

// ============================================================================
// Test Constants
// ============================================================================

/// Test constants for TransferService tests
class TestConstants {
  // File size thresholds
  static const int smallFileSize = 1024; // 1KB
  static const int largeFileSizeThreshold = 10 * 1024 * 1024; // 10MB
  static const int largeFileSize = 15 * 1024 * 1024; // 15MB

  // Network
  static const String testIpAddress = '192.168.1.100';
  static const int testPort = 8765;

  // Timeouts
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration shortTimeout = Duration(milliseconds: 100);

  // Checkpoint
  static const Duration checkpointMaxAge = Duration(hours: 24);
  static const Duration staleCheckpointAge = Duration(hours: 2);
}
