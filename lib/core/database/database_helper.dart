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
      version: 2, // Incremented version for trusted_devices table
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

    // Trusted devices table - stores trusted device info
    await db.execute('''
      CREATE TABLE trusted_devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        platform TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 0,
        last_seen INTEGER NOT NULL,
        trusted INTEGER NOT NULL DEFAULT 1,
        trusted_at INTEGER,
        auto_accept_transfers INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create index for faster lookups
    await db.execute('''
      CREATE INDEX idx_trusted_devices_trusted ON trusted_devices(trusted)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add trusted_devices table for version 2
      await db.execute('''
        CREATE TABLE trusted_devices (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          platform TEXT NOT NULL,
          ip_address TEXT NOT NULL,
          port INTEGER NOT NULL,
          is_online INTEGER NOT NULL DEFAULT 0,
          last_seen INTEGER NOT NULL,
          trusted INTEGER NOT NULL DEFAULT 1,
          trusted_at INTEGER,
          auto_accept_transfers INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_trusted_devices_trusted ON trusted_devices(trusted)
      ''');
    }
  }

  // ==================== Transfer Operations ====================

  Future<void> insertTransfer(Transfer transfer) async {
    final db = await database;
    await db.insert(
      'transfers',
      _transferToMap(transfer),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final item in transfer.items) {
      await db.insert('transfer_items', {
        'transfer_id': transfer.id,
        'file_name': item.fileName,
        'file_size': item.fileSize,
        'file_path': item.filePath,
        'is_directory': item.isDirectory ? 1 : 0,
      });
    }
  }

  Future<void> updateTransfer(Transfer transfer) async {
    final db = await database;
    await db.update(
      'transfers',
      _transferToMap(transfer),
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
  }

  Future<List<Transfer>> getTransfers() async {
    final db = await database;
    final transferMaps = await db.query('transfers', orderBy: 'created_at DESC');

    final transfers = <Transfer>[];
    for (final map in transferMaps) {
      final itemMaps = await db.query(
        'transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [map['id']],
      );

      final items = itemMaps
          .map((item) => TransferItem(
                fileName: item['file_name'] as String,
                fileSize: item['file_size'] as int,
                filePath: item['file_path'] as String?,
                isDirectory: (item['is_directory'] as int) == 1,
              ))
          .toList();

      transfers.add(_mapToTransfer(map, items));
    }

    return transfers;
  }

  Future<void> deleteTransfer(String transferId) async {
    final db = await database;
    await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }

  // ==================== Trusted Device Operations ====================

  /// Save or update a trusted device in the database
  Future<void> saveTrustedDevice(Device device) async {
    if (!device.trusted) {
      // If device is not trusted, remove it from database
      await deleteTrustedDevice(device.id);
      return;
    }

    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'trusted_devices',
      {
        ...device.toDbMap(),
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all trusted devices from the database
  Future<List<Device>> getTrustedDevices() async {
    final db = await database;
    final maps = await db.query(
      'trusted_devices',
      where: 'trusted = ?',
      whereArgs: [1],
      orderBy: 'trusted_at DESC',
    );

    return maps.map((map) => Device.fromDbMap(map)).toList();
  }

  /// Get a specific trusted device by ID
  Future<Device?> getTrustedDevice(String deviceId) async {
    final db = await database;
    final maps = await db.query(
      'trusted_devices',
      where: 'id = ? AND trusted = ?',
      whereArgs: [deviceId, 1],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Device.fromDbMap(maps.first);
  }

  /// Update device online status and IP address
  Future<void> updateDeviceStatus(
    String deviceId, {
    required bool isOnline,
    String? ipAddress,
    int? port,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'is_online': isOnline ? 1 : 0,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
    };

    if (ipAddress != null) updates['ip_address'] = ipAddress;
    if (port != null) updates['port'] = port;

    await db.update(
      'trusted_devices',
      updates,
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Delete a trusted device from the database
  Future<void> deleteTrustedDevice(String deviceId) async {
    final db = await database;
    await db.delete(
      'trusted_devices',
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Check if a device is trusted
  Future<bool> isDeviceTrusted(String deviceId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM trusted_devices WHERE id = ? AND trusted = 1',
      [deviceId],
    );
    return (result.first['count'] as int) > 0;
  }

  /// Set auto-accept transfers for a trusted device
  Future<void> setAutoAcceptTransfers(String deviceId, bool autoAccept) async {
    final db = await database;
    await db.update(
      'trusted_devices',
      {'auto_accept_transfers': autoAccept ? 1 : 0},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Get auto-accept status for a device
  Future<bool> getAutoAcceptTransfers(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'trusted_devices',
      columns: ['auto_accept_transfers'],
      where: 'id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );

    if (result.isEmpty) return false;
    return (result.first['auto_accept_transfers'] as int) == 1;
  }

  /// Clear all trusted devices (use with caution)
  Future<void> clearAllTrustedDevices() async {
    final db = await database;
    await db.delete('trusted_devices');
  }

  /// Get count of trusted devices
  Future<int> getTrustedDeviceCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM trusted_devices WHERE trusted = 1',
    );
    return result.first['count'] as int;
  }

  // ==================== Helper Methods ====================

  Map<String, dynamic> _transferToMap(Transfer transfer) {
    return {
      'id': transfer.id,
      'sender_id': transfer.senderId,
      'receiver_id': transfer.receiverId,
      'sender_name': transfer.senderName,
      'receiver_name': transfer.receiverName,
      'status': transfer.status.name,
      'total_bytes': transfer.totalBytes,
      'bytes_transferred': transfer.bytesTransferred,
      'file_count': transfer.fileCount,
      'created_at': transfer.createdAt.millisecondsSinceEpoch,
      'completed_at': transfer.completedAt?.millisecondsSinceEpoch,
      'error_message': transfer.errorMessage,
    };
  }

  Transfer _mapToTransfer(Map<String, dynamic> map, List<TransferItem> items) {
    return Transfer(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      senderName: map['sender_name'] as String?,
      receiverName: map['receiver_name'] as String?,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransferStatus.pending,
      ),
      totalBytes: map['total_bytes'] as int,
      bytesTransferred: map['bytes_transferred'] as int,
      fileCount: map['file_count'] as int,
      items: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      errorMessage: map['error_message'] as String?,
    );
  }
}
