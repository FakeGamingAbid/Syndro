import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/database/database_helper.dart';
import 'package:syndro/core/models/transfer.dart';
import 'package:syndro/core/models/device.dart';

void main() {
  group('DatabaseHelper', () {
    late DatabaseHelper databaseHelper;

    setUp(() {
      databaseHelper = DatabaseHelper.instance;
    });

    test('should be a singleton', () {
      final instance1 = DatabaseHelper.instance;
      final instance2 = DatabaseHelper.instance;
      
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize database successfully', () async {
      final db = await databaseHelper.database;
      
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('should insert and retrieve transfer', () async {
      final transfer = Transfer(
        id: 'test-transfer-1',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        status: TransferStatus.completed,
        progress: const TransferProgress(
          bytesTransferred: 1024,
          totalBytes: 1024,
        ),
        createdAt: DateTime.now(),
        items: [
          const TransferItem(
            name: 'test.txt',
            path: '/path/to/test.txt',
            size: 1024,
            isDirectory: false,
          ),
        ],
      );

      final sender = Device(
        id: 'sender-1',
        name: 'Test Sender',
        platform: DevicePlatform.android,
        ipAddress: '192.168.1.1',
        port: 8765,
        lastSeen: DateTime.now(),
      );
      
      await databaseHelper.insertTransfer(transfer, sender, null);
      
      final history = await databaseHelper.getTransferHistory();
      expect(history, isNotEmpty);
      expect(history.first['id'], equals('test-transfer-1'));
    });

    test('should update transfer status', () async {
      final transfer = Transfer(
        id: 'test-transfer-2',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        status: TransferStatus.transferring,
        progress: const TransferProgress(
          bytesTransferred: 512,
          totalBytes: 2048,
        ),
        createdAt: DateTime.now(),
        items: const [],
      );

      await databaseHelper.insertTransfer(transfer, null, null);
      
      await databaseHelper.updateTransferStatus(
        'test-transfer-2',
        TransferStatus.completed,
        bytesTransferred: 2048,
      );
      
      final history = await databaseHelper.getTransferHistory();
      final updated = history.firstWhere((t) => t['id'] == 'test-transfer-2');
      expect(updated['status'], equals('completed'));
    });

    test('should delete transfer', () async {
      final transfer = Transfer(
        id: 'test-transfer-3',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        status: TransferStatus.completed,
        progress: const TransferProgress(
          bytesTransferred: 512,
          totalBytes: 512,
        ),
        createdAt: DateTime.now(),
        items: const [],
      );

      await databaseHelper.insertTransfer(transfer, null, null);
      await databaseHelper.deleteTransfer('test-transfer-3');
      
      final history = await databaseHelper.getTransferHistory();
      expect(history.where((t) => t['id'] == 'test-transfer-3'), isEmpty);
    });

    test('should handle concurrent database access', () async {
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(
          databaseHelper.insertTransfer(Transfer(
            id: 'concurrent-test-$i',
            senderId: 'sender',
            receiverId: 'receiver',
            status: TransferStatus.completed,
            progress: const TransferProgress(
              bytesTransferred: 100,
              totalBytes: 100,
            ),
            createdAt: DateTime.now(),
            items: const [],
          ), null, null),
        );
      }
      
      await Future.wait(futures);
      
      final history = await databaseHelper.getTransferHistory();
      expect(
        history.where((t) => (t['id'] as String).startsWith('concurrent-test-')).length,
        equals(10),
      );
    });
  });
}
