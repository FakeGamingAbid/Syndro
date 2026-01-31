import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transfer.dart';
import '../models/device.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'syndro.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Transfers table
    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        sender_name TEXT,
        receiver_name TEXT,
        status TEXT NOT NULL,
        total_bytes INTEGER NOT NULL,
        bytes_transferred INTEGER NOT NULL,
        file_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        error_message TEXT
      )
    ''');

    // Transfer items table
    await db.execute('''
      CREATE TABLE transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_path TEXT,
        is_directory INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (transfer_id) REFERENCES transfers(id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_transfers_created_at ON transfers(created_at DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations in future versions
  }

  // Insert a transfer record
  Future<void> insertTransfer(Transfer transfer, Device? sender, Device? receiver) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Insert transfer
      await txn.insert(
        'transfers',
        {
          'id': transfer.id,
          'sender_id': transfer.senderId,
          'receiver_id': transfer.receiverId,
          'sender_name': sender?.name,
          'receiver_name': receiver?.name,
          'status': transfer.status.name,
          'total_bytes': transfer.totalSize,
          'bytes_transferred': transfer.progress.bytesTransferred,
          'file_count': transfer.items.length,
          'created_at': transfer.createdAt.millisecondsSinceEpoch,
          'completed_at': transfer.status == TransferStatus.completed
              ? DateTime.now().millisecondsSinceEpoch
              : null,
          'error_message': transfer.errorMessage,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert transfer items
      for (final item in transfer.items) {
        await txn.insert('transfer_items', {
          'transfer_id': transfer.id,
          'file_name': item.name,
          'file_size': item.size,
          'file_path': item.path,
          'is_directory': item.isDirectory ? 1 : 0,
        });
      }
    });
  }

  // Update transfer status
  Future<void> updateTransferStatus(
    String transferId,
    TransferStatus status, {
    int? bytesTransferred,
    String? errorMessage,
  }) async {
    final db = await database;
    
    final updates = <String, dynamic>{
      'status': status.name,
    };
    
    if (bytesTransferred != null) {
      updates['bytes_transferred'] = bytesTransferred;
    }
    
    if (status == TransferStatus.completed || status == TransferStatus.failed) {
      updates['completed_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }

    await db.update(
      'transfers',
      updates,
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }

  // Get transfer history
  Future<List<Map<String, dynamic>>> getTransferHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    
    return await db.query(
      'transfers',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  // Get transfer by ID with items
  Future<Map<String, dynamic>?> getTransferById(String transferId) async {
    final db = await database;
    
    final transfers = await db.query(
      'transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );
    
    if (transfers.isEmpty) return null;
    
    final transfer = transfers.first;
    
    final items = await db.query(
      'transfer_items',
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
    
    return {
      ...transfer,
      'items': items,
    };
  }

  // Get transfers by status
  Future<List<Map<String, dynamic>>> getTransfersByStatus(
    TransferStatus status,
  ) async {
    final db = await database;
    
    return await db.query(
      'transfers',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
  }

  // Delete a transfer
  Future<void> deleteTransfer(String transferId) async {
    final db = await database;
    
    await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );
    
    // Items will be cascade deleted due to foreign key
  }

  // Clear all history
  Future<void> clearHistory() async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('transfer_items');
      await txn.delete('transfers');
    });
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    final db = await database;
    
    final totalTransfers = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM transfers'),
    ) ?? 0;
    
    final completedTransfers = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transfers WHERE status = ?',
        [TransferStatus.completed.name],
      ),
    ) ?? 0;
    
    final failedTransfers = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transfers WHERE status = ?',
        [TransferStatus.failed.name],
      ),
    ) ?? 0;
    
    final totalBytes = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT SUM(total_bytes) FROM transfers WHERE status = ?',
        [TransferStatus.completed.name],
      ),
    ) ?? 0;

    return {
      'totalTransfers': totalTransfers,
      'completedTransfers': completedTransfers,
      'failedTransfers': failedTransfers,
      'totalBytes': totalBytes,
    };
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
