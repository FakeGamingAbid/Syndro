import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/transfer.dart';
import '../models/device.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _initFuture;

  DatabaseHelper._internal();

  /// Get the database instance, initializing if necessary.
  /// Uses a simple future-based lock to prevent concurrent initialization.
  Future<Database> get database async {
    if (_database != null) return _database!;

    // If already initializing, wait for the existing future
    if (_initFuture != null) {
      return _initFuture!;
    }

    // Start initialization and cache the future
    _initFuture = _initDatabase().then((db) {
      _database = db;
      return db;
    }).catchError((e) {
      // Reset on error to allow retry
      _initFuture = null;
      throw e;
    });

    return _initFuture!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'syndro.db');

    return await openDatabase(
      path,
      version: 2, // FIX: Bump version for migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // FIX: Enable foreign keys
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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

    // FIX: Add index for status queries
    await db.execute('''
      CREATE INDEX idx_transfers_status ON transfers(status)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    if (oldVersion < 2) {
      // Add index for status if upgrading from v1
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status)
        ''');
      } catch (e) {
        debugPrint('Migration error (non-fatal): $e');
      }
    }
  }

  // FIX: Insert a transfer record using parameterized queries
  Future<void> insertTransfer(
      Transfer transfer, Device? sender, Device? receiver) async {
    final db = await database;

    await db.transaction((txn) async {
      // FIX: Use parameterized insert (already correct in original)
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

      // FIX: Delete existing items first to avoid duplicates on replace
      await txn.delete(
        'transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [transfer.id],
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

    // Auto-prune if over 1000 records (run outside transaction)
    await pruneOldTransfers(maxRecords: 1000);
  }

  // FIX: Update transfer status using parameterized queries
  Future<void> updateTransferStatus(
    String transferId,
    TransferStatus status, {
    int? bytesTransferred,
    String? errorMessage,
  }) async {
    // FIX: Validate transferId
    if (transferId.isEmpty) {
      throw ArgumentError('transferId cannot be empty');
    }

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

    // FIX: Using parameterized query (already correct)
    await db.update(
      'transfers',
      updates,
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }

  // FIX: Get transfer history with parameterized queries
  Future<List<Map<String, dynamic>>> getTransferHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    // FIX: Validate parameters
    if (limit <= 0 || limit > 1000) {
      limit = 50;
    }
    if (offset < 0) {
      offset = 0;
    }

    final db = await database;

    // FIX: Using query builder (already parameterized)
    return await db.query(
      'transfers',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  // FIX: Get transfer by ID with parameterized queries
  Future<Map<String, dynamic>?> getTransferById(String transferId) async {
    // FIX: Validate transferId
    if (transferId.isEmpty) {
      return null;
    }

    final db = await database;

    // FIX: Using parameterized query (already correct)
    final transfers = await db.query(
      'transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );

    if (transfers.isEmpty) return null;

    final transfer = transfers.first;

    // FIX: Using parameterized query for items
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

  // FIX: Get transfers by status with parameterized queries
  Future<List<Map<String, dynamic>>> getTransfersByStatus(
    TransferStatus status,
  ) async {
    final db = await database;

    // FIX: Using parameterized query (already correct)
    return await db.query(
      'transfers',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
  }

  // FIX: Search transfers by name with parameterized LIKE query (now includes files)
  Future<List<Map<String, dynamic>>> searchTransfers(String query) async {
    if (query.isEmpty) {
      return await getTransferHistory();
    }

    final db = await database;

    // FIX: Sanitize query for LIKE - remove special characters that could cause issues
    final sanitizedQuery = query
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll('[', '')
        .replaceAll(']', '');

    // FIX: Use raw query to search in both transfers and transfer_items tables
    return await db.rawQuery('''
      SELECT DISTINCT t.* 
      FROM transfers t
      LEFT JOIN transfer_items ti ON t.id = ti.transfer_id
      WHERE t.sender_name LIKE ? 
         OR t.receiver_name LIKE ? 
         OR ti.file_name LIKE ?
      ORDER BY t.created_at DESC
      LIMIT 50
    ''', ['%$sanitizedQuery%', '%$sanitizedQuery%', '%$sanitizedQuery%']);
  }

  // FIX: Delete a transfer with parameterized query
  Future<void> deleteTransfer(String transferId) async {
    // FIX: Validate transferId
    if (transferId.isEmpty) {
      throw ArgumentError('transferId cannot be empty');
    }

    final db = await database;

    // FIX: Using parameterized query (already correct)
    await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );
    // Items will be cascade deleted due to foreign key
  }

  // FIX: Delete old transfers (cleanup)
  Future<int> deleteOldTransfers({int olderThanDays = 30}) async {
    final db = await database;

    final cutoffTime = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;

    // FIX: Using parameterized query
    return await db.delete(
      'transfers',
      where: 'created_at < ? AND status IN (?, ?, ?)',
      whereArgs: [
        cutoffTime,
        TransferStatus.completed.name,
        TransferStatus.failed.name,
        TransferStatus.cancelled.name,
      ],
    );
  }

  // Clear all history
  Future<void> clearHistory() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('transfer_items');
      await txn.delete('transfers');
    });
  }

  // FIX: Get statistics using parameterized queries
  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    // FIX: Using parameterized queries for all statistics
    final totalTransfers = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transfers'),
        ) ??
        0;

    final completedTransfers = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transfers WHERE status = ?',
            [TransferStatus.completed.name],
          ),
        ) ??
        0;

    final failedTransfers = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transfers WHERE status = ?',
            [TransferStatus.failed.name],
          ),
        ) ??
        0;

    final totalBytes = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT SUM(total_bytes) FROM transfers WHERE status = ?',
            [TransferStatus.completed.name],
          ),
        ) ??
        0;

    return {
      'totalTransfers': totalTransfers,
      'completedTransfers': completedTransfers,
      'failedTransfers': failedTransfers,
      'totalBytes': totalBytes,
    };
  }

  // FIX: Get database size info
  Future<Map<String, int>> getDatabaseInfo() async {
    final db = await database;

    final transferCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transfers'),
        ) ??
        0;

    final itemCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transfer_items'),
        ) ??
        0;

    return {
      'transferCount': transferCount,
      'itemCount': itemCount,
    };
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _initFuture = null; // Reset to allow re-initialization
    }
  }

  // Get total transfer count
  Future<int> getTransferCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transfers'),
        ) ??
        0;
  }

  // Search transfers by device name or filename (full search)
  Future<List<Map<String, dynamic>>> searchTransfersFull(
    String query, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final searchPattern = '%$query%';

    return await db.rawQuery('''
      SELECT DISTINCT t.* 
      FROM transfers t
      LEFT JOIN transfer_items ti ON t.id = ti.transfer_id
      WHERE t.sender_name LIKE ? 
         OR t.receiver_name LIKE ? 
         OR ti.file_name LIKE ?
      ORDER BY t.created_at DESC
      LIMIT ? OFFSET ?
    ''', [searchPattern, searchPattern, searchPattern, limit, offset]);
  }

  // Get transfers by status with search
  Future<List<Map<String, dynamic>>> getTransfersByStatusAndSearch(
    TransferStatus status,
    String searchQuery, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final searchPattern = '%$searchQuery%';

    return await db.rawQuery('''
      SELECT DISTINCT t.* 
      FROM transfers t
      LEFT JOIN transfer_items ti ON t.id = ti.transfer_id
      WHERE t.status = ?
        AND (t.sender_name LIKE ? 
           OR t.receiver_name LIKE ? 
           OR ti.file_name LIKE ?)
      ORDER BY t.created_at DESC
      LIMIT ? OFFSET ?
    ''', [
      status.name,
      searchPattern,
      searchPattern,
      searchPattern,
      limit,
      offset
    ]);
  }

  // Prune oldest transfers if count exceeds maxRecords
  Future<int> pruneOldTransfers({int maxRecords = 1000}) async {
    final db = await database;
    final count = await getTransferCount();

    if (count <= maxRecords) {
      return 0;
    }

    // Calculate how many to delete
    final toDelete = count - maxRecords;

    // Get IDs of oldest transfers to delete
    final toRemove = await db.rawQuery('''
      SELECT id FROM transfers 
      ORDER BY created_at ASC 
      LIMIT ?
    ''', [toDelete]);

    if (toRemove.isEmpty) {
      return 0;
    }

    final ids = toRemove.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    // Delete in transaction to maintain consistency
    return await db.transaction((txn) async {
      // Delete items first (cascade should handle this, but being explicit)
      await txn.delete(
        'transfer_items',
        where: 'transfer_id IN ($placeholders)',
        whereArgs: ids,
      );
      // Delete transfers
      return await txn.delete(
        'transfers',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    });
  }

  // Delete transfers older than a specific date
  Future<int> deleteTransfersOlderThan(DateTime cutoff) async {
    final db = await database;
    final cutoffTime = cutoff.millisecondsSinceEpoch;

    return await db.delete(
      'transfers',
      where: 'created_at < ?',
      whereArgs: [cutoffTime],
    );
  }

  // Bulk delete multiple transfers
  Future<int> deleteTransfers(List<String> transferIds) async {
    if (transferIds.isEmpty) return 0;

    final db = await database;
    final placeholders = List.filled(transferIds.length, '?').join(',');

    return await db.transaction((txn) async {
      // Delete items first
      await txn.delete(
        'transfer_items',
        where: 'transfer_id IN ($placeholders)',
        whereArgs: transferIds,
      );
      // Delete transfers
      return await txn.delete(
        'transfers',
        where: 'id IN ($placeholders)',
        whereArgs: transferIds,
      );
    });
  }
}
