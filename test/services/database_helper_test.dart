import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/database/database_helper.dart';
import 'package:syndro/core/models/transfer.dart';

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
        senderName: 'Test Sender',
        receiverName: 'Test Receiver',
        status: TransferStatus.completed,
        totalBytes: 1024,
        bytesTransferred: 1024,
        fileCount: 1,
        createdAt: DateTime.now(),
        items: [
          TransferItem(
            fileName: 'test.txt',
            fileSize: 1024,
            isDirectory: false,
          ),
        ],
      );

      await databaseHelper.insertTransfer(transfer);
      
      final transfers = await databaseHelper.getTransfers();
      expect(transfers, isNotEmpty);
      expect(transfers.first.id, equals('test-transfer-1'));
    });

    test('should update transfer status', () async {
      final transfer = Transfer(
        id: 'test-transfer-2',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        status: TransferStatus.inProgress,
        totalBytes: 2048,
        bytesTransferred: 512,
        fileCount: 1,
        createdAt: DateTime.now(),
        items: [],
      );

      await databaseHelper.insertTransfer(transfer);
      
      await databaseHelper.updateTransferStatus(
        'test-transfer-2',
        TransferStatus.completed,
        bytesTransferred: 2048,
      );
      
      final transfers = await databaseHelper.getTransfers();
      final updated = transfers.firstWhere((t) => t.id == 'test-transfer-2');
      expect(updated.status, equals(TransferStatus.completed));
    });

    test('should delete transfer', () async {
      final transfer = Transfer(
        id: 'test-transfer-3',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        status: TransferStatus.completed,
        totalBytes: 512,
        bytesTransferred: 512,
        fileCount: 1,
        createdAt: DateTime.now(),
        items: [],
      );

      await databaseHelper.insertTransfer(transfer);
      await databaseHelper.deleteTransfer('test-transfer-3');
      
      final transfers = await databaseHelper.getTransfers();
      expect(transfers.where((t) => t.id == 'test-transfer-3'), isEmpty);
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
            totalBytes: 100,
            bytesTransferred: 100,
            fileCount: 1,
            createdAt: DateTime.now(),
            items: [],
          )),
        );
      }
      
      await Future.wait(futures);
      
      final transfers = await databaseHelper.getTransfers();
      expect(
        transfers.where((t) => t.id.startsWith('concurrent-test-')).length,
        equals(10),
      );
    });
  });
}
