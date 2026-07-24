import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'signsense.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE detection_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        type TEXT NOT NULL,
        confidence REAL,
        position TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ocr_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE navigation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // ─── Detection History ──────────────────────────────────────────────────────

  Future<void> insertDetection({
    required String label,
    required String type,
    double confidence = 0.0,
    String position = '',
  }) async {
    final db = await database;
    await db.insert('detection_history', {
      'label': label,
      'type': type,
      'confidence': confidence,
      'position': position,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getDetectionHistory({
    int limit = 100,
  }) async {
    final db = await database;
    return db.query(
      'detection_history',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('detection_history');
    await db.delete('ocr_history');
    await db.delete('navigation_history');
  }

  // ─── OCR History ────────────────────────────────────────────────────────────

  Future<void> insertOCRResult(String text) async {
    final db = await database;
    await db.insert('ocr_history', {
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getOCRHistory() async {
    final db = await database;
    return db.query('ocr_history', orderBy: 'id DESC', limit: 50);
  }

  // ─── Navigation History ─────────────────────────────────────────────────────

  Future<void> insertNavigation(String destination) async {
    final db = await database;
    await db.insert('navigation_history', {
      'destination': destination,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
