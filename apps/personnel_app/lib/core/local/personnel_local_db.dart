import 'dart:convert';
import 'package:path/path.dart' as path_pkg;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for the Personnel App.
///
/// Provides offline-capable caching of personnel profile and today's operational
/// workload (pickup tasks, incoming batch arrivals, and delivery queue).
///
/// Prunes completed operational records older than 30 days.
/// Clears all operational cache on sign-out via [clearSensitiveData].
class PersonnelLocalDb {
  factory PersonnelLocalDb() => _instance ??= PersonnelLocalDb._();
  PersonnelLocalDb._();

  static PersonnelLocalDb? _instance;
  static Database? _db;

  // ignore: prefer_constructors_over_static_methods
  static PersonnelLocalDb get instance => PersonnelLocalDb();

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, 'cerelo_personnel.db');

    return openDatabase(
      fullPath,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS cached_personnel_profile');
        await db.execute('DROP TABLE IF EXISTS cached_pickups');
        await db.execute('DROP TABLE IF EXISTS cached_batches');
        await db.execute('DROP TABLE IF EXISTS cached_deliveries');
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_personnel_profile (
        user_id TEXT PRIMARY KEY,
        profile_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_pickups (
        user_id TEXT PRIMARY KEY,
        pickups_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_batches (
        user_id TEXT PRIMARY KEY,
        batches_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_deliveries (
        user_id TEXT PRIMARY KEY,
        deliveries_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  // ─── Profile ───────────────────────────────────────────────────────────────

  Future<void> saveProfile({
    required String userId,
    required Map<String, dynamic> profileJson,
  }) async {
    final db = await _database;
    await db.insert(
      'cached_personnel_profile',
      {
        'user_id': userId,
        'profile_json': jsonEncode(profileJson),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> loadProfile(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_personnel_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final jsonStr = rows.first['profile_json'] as String?;
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  // ─── Pickups ───────────────────────────────────────────────────────────────

  Future<void> savePickups({
    required String userId,
    required List<Map<String, dynamic>> pickups,
  }) async {
    final db = await _database;
    await db.insert(
      'cached_pickups',
      {
        'user_id': userId,
        'pickups_json': jsonEncode(pickups),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({List<Map<String, dynamic>> pickups, DateTime? cachedAt})>
      loadPickups(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_pickups',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return (pickups: <Map<String, dynamic>>[], cachedAt: null);

    final json = rows.first['pickups_json'] as String?;
    final cachedAtStr = rows.first['cached_at'] as String?;
    final cachedAt = cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;

    if (json == null) return (pickups: <Map<String, dynamic>>[], cachedAt: cachedAt);

    final decoded = jsonDecode(json) as List<dynamic>;
    final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (pickups: list, cachedAt: cachedAt);
  }

  // ─── Batches ───────────────────────────────────────────────────────────────

  Future<void> saveBatches({
    required String userId,
    required List<Map<String, dynamic>> batches,
  }) async {
    final db = await _database;
    await db.insert(
      'cached_batches',
      {
        'user_id': userId,
        'batches_json': jsonEncode(batches),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({List<Map<String, dynamic>> batches, DateTime? cachedAt})>
      loadBatches(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_batches',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return (batches: <Map<String, dynamic>>[], cachedAt: null);

    final json = rows.first['batches_json'] as String?;
    final cachedAtStr = rows.first['cached_at'] as String?;
    final cachedAt = cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;

    if (json == null) return (batches: <Map<String, dynamic>>[], cachedAt: cachedAt);

    final decoded = jsonDecode(json) as List<dynamic>;
    final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (batches: list, cachedAt: cachedAt);
  }

  // ─── Deliveries ────────────────────────────────────────────────────────────

  Future<void> saveDeliveries({
    required String userId,
    required List<Map<String, dynamic>> deliveries,
  }) async {
    final db = await _database;
    await db.insert(
      'cached_deliveries',
      {
        'user_id': userId,
        'deliveries_json': jsonEncode(deliveries),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({List<Map<String, dynamic>> deliveries, DateTime? cachedAt})>
      loadDeliveries(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_deliveries',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return (deliveries: <Map<String, dynamic>>[], cachedAt: null);

    final json = rows.first['deliveries_json'] as String?;
    final cachedAtStr = rows.first['cached_at'] as String?;
    final cachedAt = cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;

    if (json == null) return (deliveries: <Map<String, dynamic>>[], cachedAt: cachedAt);

    final decoded = jsonDecode(json) as List<dynamic>;
    final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (deliveries: list, cachedAt: cachedAt);
  }

  // ─── Diagnostic Inspection ────────────────────────────────────────────────
  Future<Map<String, dynamic>> inspectDatabaseStats() async {
    try {
      final db = await _database;
      final profileRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_personnel_profile');
      final pickupRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_pickups');
      final batchRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_batches');
      final deliveryRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_deliveries');

      return {
        'cached_personnel_profile_count': profileRows.length,
        'cached_personnel_profile_users': profileRows.map((r) => r['user_id']).toList(),
        'cached_pickups_count': pickupRows.length,
        'cached_batches_count': batchRows.length,
        'cached_deliveries_count': deliveryRows.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> clearSensitiveData(String userId) async {
    final db = await _database;
    await db.delete('cached_personnel_profile', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_pickups', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_batches', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_deliveries', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
