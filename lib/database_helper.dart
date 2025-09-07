import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;

  // สร้างการเชื่อมต่อกับฐานข้อมูล
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    } else {
      _database = await _initDatabase();
      return _database!;
    }
  }

  // สร้างและเปิดฐานข้อมูล
  Future<Database> _initDatabase() async {
    var dbPath = await getDatabasesPath();
    var path = join(dbPath, 'palm_detection.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // สร้างตารางในฐานข้อมูล
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE detection_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        laptop_count INTEGER,
        keyboard_count INTEGER
      )
    ''');
  }

  // ฟังก์ชันสำหรับบันทึกข้อมูล
  Future<void> insertDetectionData(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'detection_data',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ฟังก์ชันเพื่อดึงข้อมูลทั้งหมด
  Future<List<Map<String, dynamic>>> getDetectionData() async {
    final db = await database;
    return await db.query('detection_data');
  }

  // ฟังก์ชันสำหรับกรองข้อมูลตามวันที่
  Future<List<Map<String, dynamic>>> getDetectionDataByDate(String date) async {
    final db = await database;
    return await db.query(
      'detection_data',
      where: 'date = ?',
      whereArgs: [date],
    );
  }
}
