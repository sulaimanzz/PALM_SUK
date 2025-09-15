import 'package:get/get.dart';
import 'package:palm_app/database_helper.dart';
import 'package:sqflite/sqflite.dart'; 
import 'package:path/path.dart';

class ReportController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ตัวแปรเก็บข้อมูลจากฐานข้อมูล
  RxList<Map<String, dynamic>> palmRecords = <Map<String, dynamic>>[].obs;
  RxInt totalRipeCount = 0.obs;
  RxInt totalUnripeCount = 0.obs;
  RxInt ripeCount = 0.obs;
  RxInt unripeCount = 0.obs;

  // ฐานข้อมูล
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    var dbPath = await getDatabasesPath();
    var path = join(dbPath, 'palm_detection.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(''' 
      CREATE TABLE palm_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        ripeCount INTEGER,
        unripeCount INTEGER
      )
    ''');
  }

  // ฟังก์ชันดึงข้อมูลทั้งหมดจากฐานข้อมูลหรือกรองตามวันที่
  Future<void> loadPalmRecords({String? date}) async {
    if (date != null) {
      palmRecords.value = await _dbHelper.getDetectionDataByDate(date);
    } else {
      palmRecords.value = await _dbHelper.getDetectionData();
    }
  }

  // ฟังก์ชันคำนวณผลรวมของการตรวจจับปาล์ม
  Future<void> getDashboardStats() async {
    final stats = await _getStats();
    totalRipeCount.value = stats['totalRipe'] ?? 0;
    totalUnripeCount.value = stats['totalUnripe'] ?? 0;
  }

  // ฟังก์ชันดึงข้อมูลจากฐานข้อมูลเพื่อคำนวณผลรวม
  Future<Map<String, int>> _getStats() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> stats = await db.rawQuery('''
      SELECT SUM(ripeCount) as totalRipe, SUM(unripeCount) as totalUnripe
      FROM palm_records
    ''');

    return {
      'totalRipe': stats.isNotEmpty ? stats[0]['totalRipe'] ?? 0 : 0,
      'totalUnripe': stats.isNotEmpty ? stats[0]['totalUnripe'] ?? 0 : 0,
    };
  }

  // ฟังก์ชันบันทึกข้อมูลการตรวจจับ
  Future<void> savePalmRecord() async {
    final db = await database;
    final date = DateTime.now().toString();
    await db.insert('palm_records', {
      'date': date,
      'ripeCount': ripeCount.value,
      'unripeCount': unripeCount.value,
    });

    // เก็บข้อมูลไว้ใน palmRecords เพื่อใช้ใน UI
    palmRecords.add({
      'date': date,
      'ripeCount': ripeCount.value,
      'unripeCount': unripeCount.value,
    });
  }

  // ฟังก์ชันดึงข้อมูลทั้งหมดจากฐานข้อมูล
  Future<void> getPalmRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> records = await db.query('palm_records');
    palmRecords.value = records;
  }
}
