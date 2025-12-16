import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'intenter.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        intent TEXT,
        start_time INTEGER,
        end_time INTEGER,
        duration INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE app_usage(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        package_name TEXT,
        total_time_visible INTEGER,
        last_time_used INTEGER,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');
  }

  Future<int> insertSession(String intent, int startTime) async {
    final db = await database;
    return await db.insert('sessions', {
      'intent': intent,
      'start_time': startTime,
    });
  }

  Future<void> updateSessionEndTime(int id, int endTime) async {
    final db = await database;
    // Calculate duration only if we have the start time, but for now just update end time
    // We can compute duration by fetching start_time first or trigger logic elsewhere
    // Let's fetch start time to compute duration
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      columns: ['start_time'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      int startTime = maps.first['start_time'] as int;
      int duration = endTime - startTime;
      await db.update(
        'sessions',
        {'end_time': endTime, 'duration': duration},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> insertAppUsage(
    int sessionId,
    String packageName,
    int totalTime,
    int lastUsed,
  ) async {
    final db = await database;
    await db.insert('app_usage', {
      'session_id': sessionId,
      'package_name': packageName,
      'total_time_visible': totalTime,
      'last_time_used': lastUsed,
    });
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final db = await database;
    return await db.query('sessions', orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getAppUsage(int sessionId) async {
    final db = await database;
    return await db.query(
      'app_usage',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'total_time_visible DESC',
    );
  }

  Future<List<Map<String, dynamic>>> returnOpenSessions() async {
    final db = await database;
    return await db.query('sessions', where: 'end_time IS NULL');
  }

  Future<void> closeOngoingSession(int endTime) async {
    final db = await database;
    // Find sessions with no end time (or 0 if that's how we store it, but schema didn't default)
    // Actually our updateSessionEndTime assumes we know the ID.
    // Here we want to close ALL currently open sessions (conceptually usually one).
    final openSessions = await db.query('sessions', where: 'end_time IS NULL');

    for (var session in openSessions) {
      int id = session['id'] as int;
      int startTime = session['start_time'] as int;
      if (endTime > startTime) {
        int duration = endTime - startTime;
        await db.update(
          'sessions',
          {'end_time': endTime, 'duration': duration},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<String> getAllDataAsJson() async {
    final db = await database;
    final sessions = await db.query('sessions');
    final appUsage = await db.query('app_usage');

    final Map<String, dynamic> data = {
      'sessions': sessions,
      'app_usage': appUsage,
      'export_timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(data);
  }
}
