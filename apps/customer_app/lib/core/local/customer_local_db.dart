import 'dart:convert';
import 'package:path/path.dart' as path_pkg;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for the Customer App.
///
/// Provides offline-capable caching of session, profile, and shipment data.
/// All sensitive data is cleared on sign-out via [clearSensitiveData].
///
/// SECURITY: This stores only data the authenticated user is already entitled
/// to see. No credentials beyond the Supabase refresh token (managed by the
/// SDK's secure storage) are stored here.
class CustomerLocalDb {
  factory CustomerLocalDb() => _instance ??= CustomerLocalDb._();
  CustomerLocalDb._();

  static CustomerLocalDb? _instance;
  static Database? _db;

  // ignore: prefer_constructors_over_static_methods
  static CustomerLocalDb get instance => CustomerLocalDb();

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, 'cerelo_customer.db');

    return openDatabase(
      fullPath,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS cached_profile');
        await db.execute('DROP TABLE IF EXISTS cached_shipments');
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_profile (
        user_id TEXT PRIMARY KEY,
        profile_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_shipments (
        user_id TEXT NOT NULL,
        shipments_json TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        PRIMARY KEY (user_id)
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
      'cached_profile',
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
      'cached_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final jsonStr = rows.first['profile_json'] as String?;
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  // ─── Shipments ─────────────────────────────────────────────────────────────

  Future<void> saveShipments({
    required String userId,
    required List<Map<String, dynamic>> shipments,
  }) async {
    final db = await _database;
    await db.insert(
      'cached_shipments',
      {
        'user_id': userId,
        'shipments_json': jsonEncode(shipments),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({List<Map<String, dynamic>> shipments, DateTime? cachedAt})>
      loadShipments(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_shipments',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return (shipments: <Map<String, dynamic>>[], cachedAt: null);

    final json = rows.first['shipments_json'] as String?;
    final cachedAtStr = rows.first['cached_at'] as String?;
    final cachedAt = cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;

    if (json == null) return (shipments: <Map<String, dynamic>>[], cachedAt: cachedAt);

    final decoded = jsonDecode(json) as List<dynamic>;
    final shipments = decoded.cast<Map<String, dynamic>>();
    return (shipments: shipments, cachedAt: cachedAt);
  }

  // ─── Diagnostic Inspection ────────────────────────────────────────────────
  Future<Map<String, dynamic>> inspectDatabaseStats() async {
    try {
      final db = await _database;
      final profileRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_profile');
      final shipmentRows = await db.rawQuery('SELECT user_id, cached_at FROM cached_shipments');

      return {
        'cached_profile_count': profileRows.length,
        'cached_profile_users': profileRows.map((r) => r['user_id']).toList(),
        'cached_shipments_count': shipmentRows.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Clears all user-specific cached data on sign-out.
  /// Called before Supabase sign-out to ensure clean state.
  Future<void> clearSensitiveData(String userId) async {
    final db = await _database;
    await db.delete('cached_profile', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('cached_shipments', where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Closes the database connection (used in tests).
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
