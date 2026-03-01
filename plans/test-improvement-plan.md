# Syndro Test Improvement Plan

## Current Test Coverage Analysis

### Existing Tests

| File | Tests | Coverage |
|------|-------|----------|
| `test/services/encryption_service_test.dart` | 4 tests | Basic encryption operations |
| `test/services/file_service_test.dart` | 5 tests | Filename sanitization, path validation |
| `test/services/database_helper_test.dart` | 1 test | Singleton pattern only |
| `test/services/streaming_hash_service_test.dart` | 5 tests | Hash calculation |
| `test/integration/transfer_integration_test.dart` | 2 tests | End-to-end encryption flow |
| `test/widget_test.dart` | 1 test | Placeholder only |

### Coverage Gaps

1. **Encryption Service** - Missing edge cases
2. **File Service** - Missing Unicode/path traversal edge cases
3. **Database Helper** - Only singleton test, no CRUD operations
4. **Transfer Service** - No unit tests
5. **Providers** - No state management tests
6. **Widgets** - No UI component tests

---

## Proposed Test Additions

### 1. Encryption Service Tests (Add to existing file)

```dart
// test/services/encryption_service_test.dart

group('Edge Cases', () {
  test('should reject invalid public key length', () async {
    final invalidPublicKey = SimplePublicKey(
      Uint8List(16), // Wrong length
      type: KeyPairType.x25519,
    );
    
    expect(
      () => encryptionService.deriveSharedSecret(
        myKeyPair: keyPair,
        theirPublicKey: invalidPublicKey,
      ),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('should reject data too small to decrypt', () async {
    final tinyData = Uint8List(10);
    
    expect(
      () => encryptionService.decryptChunk(tinyData, sharedSecret),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('should reject chunk exceeding max size', () async {
    // Test with mocked large data
    final largeData = Uint8List(101 * 1024 * 1024); // 101MB
    
    expect(
      () => encryptionService.decryptChunk(largeData, sharedSecret),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('should detect tampered data via MAC failure', () async {
    final encrypted = await encryptionService.encryptChunk(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      sharedSecret,
    );
    
    // Tamper with the ciphertext
    encrypted[15] ^= 0xFF;
    
    expect(
      () => encryptionService.decryptChunk(encrypted, sharedSecret),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('should generate unique nonces for each encryption', () async {
    final data = Uint8List.fromList([1, 2, 3, 4, 5]);
    
    final encrypted1 = await encryptionService.encryptChunk(data, sharedSecret);
    final encrypted2 = await encryptionService.encryptChunk(data, sharedSecret);
    
    // Nonces should be different
    final nonce1 = encrypted1.sublist(0, 12);
    final nonce2 = encrypted2.sublist(0, 12);
    
    expect(nonce1, isNot(equals(nonce2)));
  });

  test('should reset nonce tracking on deriveSharedSecret', () async {
    // Encrypt some data
    await encryptionService.encryptChunk(
      Uint8List.fromList([1, 2, 3]),
      sharedSecret,
    );
    
    expect(encryptionService.nonceCount, greaterThan(0));
    
    // Derive new secret should reset
    final newKeyPair = await encryptionService.generateKeyPair();
    final newPublic = await encryptionService.getPublicKey(newKeyPair);
    
    await encryptionService.deriveSharedSecret(
      myKeyPair: keyPair,
      theirPublicKey: newPublic,
    );
    
    expect(encryptionService.nonceCount, equals(0));
  });
});
```

### 2. File Service Tests (Add to existing file)

```dart
// test/services/file_service_test.dart

group('sanitizeFilename Edge Cases', () {
  test('should handle Unicode path separator lookalikes', () {
    // U+2044 (fraction slash)
    expect(fileService.sanitizeFilename('file⁄name.txt').contains('⁄'), isFalse);
    
    // U+2215 (division slash)
    expect(fileService.sanitizeFilename('file∕name.txt').contains('∕'), isFalse);
    
    // U+FF0F (fullwidth solidus)
    expect(fileService.sanitizeFilename('file／name.txt').contains('／'), isFalse);
  });

  test('should truncate long filenames while preserving extension', () {
    final longName = 'a' * 250 + '.txt';
    final result = fileService.sanitizeFilename(longName);
    
    expect(result.length, lessThanOrEqualTo(200));
    expect(result.endsWith('.txt'), isTrue);
  });

  test('should handle empty result after sanitization', () {
    final result = fileService.sanitizeFilename('...');
    expect(result, equals('unnamed_file'));
  });

  test('should handle control characters', () {
    final result = fileService.sanitizeFilename('file\x00\x01\x1Fname.txt');
    expect(result.contains('\x00'), isFalse);
    expect(result.contains('\x01'), isFalse);
    expect(result.contains('\x1F'), isFalse);
  });

  test('should handle multi-byte Unicode characters safely', () {
    final result = fileService.sanitizeFilename('文件名测试.txt');
    expect(result.contains('文件名测试'), isTrue);
  });
});

group('isPathWithinDirectory Edge Cases', () {
  test('should handle symlink traversal attempts', () {
    // This test requires filesystem setup
    // Mark as integration test if needed
  });

  test('should handle case sensitivity based on platform', () {
    // Windows is case-insensitive, Linux/Mac is case-sensitive
    final result = fileService.isPathWithinDirectory(
      '/home/user/Downloads/file.txt',
      '/home/user/downloads', // Note: lowercase 'd'
    );
    // Behavior depends on platform
  });
});
```

### 3. Database Helper Tests (Expand existing file)

```dart
// test/services/database_helper_test.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper', () {
    test('should be a singleton', () {
      final instance1 = DatabaseHelper.instance;
      final instance2 = DatabaseHelper.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should create database with correct schema', () async {
      final db = await DatabaseHelper.instance.database;
      
      // Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      
      final tableNames = tables.map((t) => t['name']).toList();
      expect(tableNames, contains('transfers'));
      expect(tableNames, contains('transfer_items'));
    });

    test('should have foreign keys enabled', () async {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], equals(1));
    });

    test('should insert and retrieve transfer', () async {
      final transfer = Transfer(
        id: 'test-transfer-id',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        items: [
          TransferItem(name: 'test.txt', path: '/path/test.txt', size: 100),
        ],
        status: TransferStatus.pending,
        progress: TransferProgress(bytesTransferred: 0, totalBytes: 100),
      );
      
      await DatabaseHelper.instance.insertTransfer(
        transfer,
        Device(id: 'sender-1', name: 'Sender', ip: '192.168.1.1', port: 8080),
        Device(id: 'receiver-1', name: 'Receiver', ip: '192.168.1.2', port: 8080),
      );
      
      final history = await DatabaseHelper.instance.getTransferHistory();
      expect(history.any((t) => t.id == 'test-transfer-id'), isTrue);
    });

    test('should update transfer status', () async {
      // Insert first
      final transfer = Transfer(
        id: 'test-status-update',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        items: [],
        status: TransferStatus.pending,
        progress: TransferProgress(bytesTransferred: 0, totalBytes: 0),
      );
      
      await DatabaseHelper.instance.insertTransfer(transfer, null, null);
      
      // Update status
      await DatabaseHelper.instance.updateTransferStatus(
        'test-status-update',
        TransferStatus.completed,
        bytesTransferred: 100,
      );
      
      final history = await DatabaseHelper.instance.getTransferHistory();
      final updated = history.firstWhere((t) => t.id == 'test-status-update');
      expect(updated.status, equals(TransferStatus.completed));
    });

    test('should reject empty transfer ID', () async {
      expect(
        () => DatabaseHelper.instance.updateTransferStatus('', TransferStatus.completed),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should cascade delete transfer items when transfer deleted', () async {
      // This tests the foreign key constraint
      final db = await DatabaseHelper.instance.database;
      
      // Insert transfer with items
      // Then delete transfer
      // Verify items are also deleted
    });
  });
}
```

### 4. Transfer Provider Tests (New file)

```dart
// test/providers/transfer_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syndro/core/providers/transfer_provider.dart';
import 'package:syndro/core/services/transfer_service.dart';

void main() {
  group('Transfer Providers', () {
    test('fileServiceProvider provides FileService instance', () {
      final container = ProviderContainer();
      final fileService = container.read(fileServiceProvider);
      expect(fileService, isNotNull);
      container.dispose();
    });

    test('transferServiceProvider provides initialized service', () async {
      final container = ProviderContainer();
      final service = container.read(transferServiceProvider);
      
      await service.initialize();
      expect(service.isEncryptionReady, isTrue);
      
      container.dispose();
    });

    test('selectedFilesProvider starts empty', () {
      final container = ProviderContainer();
      final files = container.read(selectedFilesProvider);
      expect(files, isEmpty);
      container.dispose();
    });

    test('selectedFilesProvider can be updated', () {
      final container = ProviderContainer();
      
      container.read(selectedFilesProvider.notifier).state = [
        TransferItem(name: 'test.txt', path: '/test.txt', size: 100),
      ];
      
      final files = container.read(selectedFilesProvider);
      expect(files.length, equals(1));
      expect(files.first.name, equals('test.txt'));
      
      container.dispose();
    });
  });

  group('TransferStateNotifier', () {
    test('initializes with empty state', () {
      final container = ProviderContainer();
      // Add tests for TransferStateNotifier
      container.dispose();
    });

    test('updates state on transfer events', () async {
      // Test transfer stream updates
    });

    test('handles errors gracefully', () async {
      // Test error handling
    });
  });
}
```

### 5. Widget Tests (New file)

```dart
// test/widgets/transfer_request_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syndro/ui/widgets/transfer_request_sheet.dart';
import 'package:syndro/core/services/transfer_service.dart';

void main() {
  group('TransferRequestSheet', () {
    testWidgets('displays sender name and file count', (tester) async {
      final request = PendingTransferRequest(
        requestId: 'test-123',
        senderId: 'sender-1',
        senderName: 'Test Device',
        items: [
          TransferItem(name: 'file1.txt', path: '/file1.txt', size: 100),
          TransferItem(name: 'file2.txt', path: '/file2.txt', size: 200),
        ],
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TransferRequestSheet(request: request),
            ),
          ),
        ),
      );

      expect(find.text('Test Device'), findsOneWidget);
      expect(find.textContaining('2 files'), findsOneWidget);
    });

    testWidgets('shows accept and reject buttons', (tester) async {
      // Test button presence and interaction
    });

    testWidgets('calls onAccept when accept button tapped', (tester) async {
      // Test accept callback
    });
  });
}
```

### 6. Integration Tests (Add to existing file)

```dart
// test/integration/large_file_transfer_test.dart

import 'dart:io';

void main() {
  group('Large File Transfer Tests', () {
    test('should handle 1GB file encryption/decryption', () async {
      // Create 1GB test file
      // Encrypt in chunks
      // Decrypt and verify
    }, timeout: Timeout(Duration(minutes: 5)));

    test('should resume interrupted transfer from checkpoint', () async {
      // Test checkpoint save/load
      // Simulate interruption
      // Resume and verify
    });

    test('should maintain integrity with parallel transfers', () async {
      // Test parallel chunk transfer
      // Verify file hash matches
    });
  });
}
```

---

## Test Configuration

### Add to `pubspec.yaml`

```yaml
dev_dependencies:
  mocktail: ^1.0.0  # For mocking
  bloc_test: ^9.1.0  # If using bloc pattern
  coverage: ^1.6.0   # For code coverage
```

### Create `test/test_config.dart`

```dart
// test/test_config.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupTestEnvironment() {
  // Initialize SQLite FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
```

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/encryption_service_test.dart

# Run integration tests
flutter test integration_test/
```

---

## Coverage Goals

| Component | Current | Target |
|-----------|---------|--------|
| Encryption Service | ~60% | 90% |
| File Service | ~40% | 85% |
| Database Helper | ~5% | 80% |
| Transfer Service | 0% | 75% |
| Providers | 0% | 80% |
| Widgets | 0% | 70% |

---

## Implementation Priority

1. **High Priority**: Encryption edge cases (security-critical)
2. **High Priority**: File service edge cases (security-critical)
3. **Medium Priority**: Database helper CRUD tests
4. **Medium Priority**: Provider tests
5. **Low Priority**: Widget tests
6. **Low Priority**: Large file integration tests
