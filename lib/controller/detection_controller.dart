import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:palm_app/color/colors.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DetectionController extends GetxController {
  // ===== Camera =====
  RxBool isStreaming = false.obs;
  late CameraController cameraController;
  RxBool isInitialized = false.obs;
  RxBool isCameraRunning = false.obs;

  // ===== Inference =====
  Interpreter? _interp;
  TensorType? _inType, _outType;
  int? inW, inH;
  int? valuesPerDet, numDet;
  bool _layoutCHW = false; // true => [1,6,N], false => [1,N,6]
  double _inScale = 1.0 / 255.0; // default for float
  int _inZero = 0;
  double _outScale = 1.0;
  int _outZero = 0;

  // prealloc input
  List<List<List<List<double>>>>? _inputF; // float32/float16
  List<List<List<List<int>>>>? _inputI; // int8/uint8

  // resize maps cache
  List<int>? _mapX, _mapY, _mapXuv, _mapYuv;
  int _srcW = -1, _srcH = -1;

  // throttling
  int processEveryN = 5; // 1 = ทุกเฟรม (ถ้าอยากเบา CPU ตั้งเป็น 2/3)
  int _frameIdx = 0;
  bool _busy = false;

  // labels
  List<String> labels = const [];

  // results/state
  RxList<Map<String, dynamic>> recognitions = <Map<String, dynamic>>[].obs;
  RxInt ripeCount = 0.obs;
  RxInt unripeCount = 0.obs;
  RxInt savedRipeTotal = 0.obs;
  RxInt savedUnripeTotal = 0.obs;
  RxDouble imgW = 0.0.obs;
  RxDouble imgH = 0.0.obs;
  RxString summaryText = ''.obs;

  RxList<Map<String, dynamic>> palmRecords = <Map<String, dynamic>>[].obs;
  Rx<DateTime?> selectedDate = Rx<DateTime?>(null);

  // thresholds
  double confThresh = 0.2;
  double iouThresh = 0.2;
  int topK = 50;

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

  // Update this function to save to DB and trigger data refresh
  void saveCurrentCounts() {
    savePalmRecord();
    debugPrint(
      'Saved record: ripe=${ripeCount.value}, unripe=${unripeCount.value}',
    );
  }

  // ฟังก์ชันใหม่สำหรับบันทึกและแสดงการแจ้งเตือน
  // Future<void> saveAndNotify() async {
  //   await savePalmRecord();
  //   Get.snackbar(
  //     'บันทึกข้อมูล',
  //     'บันทึกข้อมูลเรียบร้อยแล้ว',
  //     snackPosition: SnackPosition.BOTTOM,
  //     backgroundColor: Colors.green,
  //     colorText: Colors.white,
  //   );
  // }

  void showSaveNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึกข้อมูลเรียบร้อยแล้ว'),
        duration: Duration(seconds: 3), // แสดงเป็นเวลา 3 วินาที
        backgroundColor: PGreen.withOpacity(0.8),
        behavior: SnackBarBehavior.floating, // ทำให้เป็นแบบลอย
      ),
    );
  }

  // ฟังก์ชันบันทึกข้อมูล
  Future<void> savePalmRecord() async {
    final db = await database;
    final date = DateTime.now().toString();
    await db.insert('palm_records', {
      'date': date,
      'ripeCount': ripeCount.value,
      'unripeCount': unripeCount.value,
    });
    ripeCount.value = 0;
    unripeCount.value = 0;
    // รีเฟรชข้อมูลในตารางและอัปเดต Dashboard
    await getPalmRecords(selectedDate.value);
  }

  // ฟังก์ชันดึงข้อมูลทั้งหมดจากฐานข้อมูลตามวันที่เลือก
  Future<void> getPalmRecords([DateTime? date]) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (date != null) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      whereClause = 'date LIKE ?';
      whereArgs = ['%$dateString%'];
    }

    final List<Map<String, dynamic>> records = await db.query(
      'palm_records',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    palmRecords.value = records;
    await updateDashboardStats(date); // อัปเดต Dashboard ตามข้อมูลในตาราง
  }

  // ฟังก์ชันคำนวณผลรวมสำหรับวันที่ระบุ
  Future<void> updateDashboardStats(DateTime? date) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (date != null) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      whereClause = 'date LIKE ?';
      whereArgs = ['%$dateString%'];
    } else {
      // If no date is selected, use today's date
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      whereClause = 'date LIKE ?';
      whereArgs = ['%$today%'];
    }

    final List<Map<String, dynamic>> stats = await db.rawQuery('''
      SELECT SUM(ripeCount) as totalRipe, SUM(unripeCount) as totalUnripe
      FROM palm_records
      WHERE $whereClause
    ''', whereArgs);

    if (stats.isNotEmpty) {
      final totalRipe = stats[0]['totalRipe'] ?? 0;
      final totalUnripe = stats[0]['totalUnripe'] ?? 0;
      savedRipeTotal.value = int.tryParse(totalRipe.toString()) ?? 0;
      savedUnripeTotal.value = int.tryParse(totalUnripe.toString()) ?? 0;
    }
  }

  // ฟังก์ชันสำหรับเลือกวันที่
  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        // 🎯 เพิ่ม Theme เพื่อกำหนดสีของปฏิทินป๊อปอัป
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: PBrown, // สีของหัวปฏิทินและวันที่ที่เลือก
              onPrimary: PWhite, // สีของข้อความในหัวปฏิทิน (เช่นปี, เดือน)
              onSurface: PBlack, // สีของข้อความในปฏิทิน (เช่นวัน, เดือนอื่นๆ)
              surface: PWhite, // สีพื้นหลังของปฏิทิน
            ),
            // คุณสามารถเพิ่มการปรับแต่งอื่นๆ ได้ที่นี่
            dialogBackgroundColor: PWhite, // สีพื้นหลังของ Dialog
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      selectedDate.value = picked;
      getPalmRecords(picked); // เรียกใช้ getPalmRecords เพื่อกรองข้อมูล
    }
  }

  @override
  Future<void> onInit() async {
    await _loadModelAndLabels();
    selectedDate.value = DateTime.now();
    await getPalmRecords(selectedDate.value);
    // 🎯 **ย้ายการรีเซ็ตมาที่นี่**
    ripeCount.value = 0;
    unripeCount.value = 0;
    super.onInit();
  }

  @override
  Future<void> onClose() async {
    try {
      if (isInitialized.value && cameraController.value.isStreamingImages) {
        await cameraController.stopImageStream();
      }
    } catch (_) {}
    if (isInitialized.value) {
      await cameraController.dispose();
    }
    try {
      _interp?.close();
    } catch (_) {}
    super.onClose();
  }

  // ===== Model =====
  Future<void> _loadModelAndLabels() async {
    // 1) try XNNPACK
    try {
      final opt = InterpreterOptions()..threads = 4;
      try {
        opt.addDelegate(XNNPackDelegate());
      } catch (_) {}
      final String modelPath =
          // 'assets/models/int8.tflite'
          'assets/models/best_int8.tflite'
      // 'assets/models/best_float16.tflite',
      // 'assets/models/int8.tflite',
      // 'assets/models/palm_best_float16.tflite',
      // 'assets/models/palm.tflite', // รองรับทั้ง float / int8
      ;
      _interp = await Interpreter.fromAsset(modelPath, options: opt);
      // 🎯 เพิ่ม Debug Log
      debugPrint('✅ TFLite model loaded from asset: $modelPath');
    } catch (e) {
      debugPrint('⚠️! XNNPACK failed ($e), fallback CPU only');
      final opt = InterpreterOptions()..threads = 4;
      final String modelPath =
          // 'assets/models/int8.tflite'
          // 'assets/models/best_float16.tflite',
          // 'assets/models/int8.tflite',
          'assets/models/best_int8.tflite';
      _interp = await Interpreter.fromAsset(modelPath, options: opt);
      // 🎯 เพิ่ม Debug Log
      debugPrint('✅ TFLite model loaded from asset: $modelPath');
    }
    debugPrint('✅ TFLite model loaded');

    // labels
    final labelStr = await rootBundle.loadString('assets/models/palm.txt');
    labels = labelStr
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // เพิ่ม print รายชื่อคลาส
    debugPrint('✅Loaded classes from palm.txt:');
    for (int i = 0; i < labels.length; i++) {
      debugPrint('[$i] ${labels[i]}');
    }

    // input tensor
    final inT = _interp!.getInputTensors().first;
    _inType = inT.type;
    final ishape = inT.shape; // [1,H,W,3]
    if (ishape.length != 4 || ishape[0] != 1 || ishape[3] != 3) {
      throw Exception('Unexpected input shape: $ishape (expect [1,h,w,3])');
    }
    inH = ishape[1];
    inW = ishape[2];

    final ip = inT.params;
    if (ip.scale != 0.0) _inScale = ip.scale;
    _inZero = ip.zeroPoint;
    debugPrint('📥 Input tensor params: scale=$_inScale, zeroPoint=$_inZero');

    // output tensor
    final outT = _interp!.getOutputTensors().first;
    _outType = outT.type;
    final oshape = outT.shape; // [1,6,N] or [1,N,6]
    if (oshape.length != 3 || oshape[0] != 1) {
      throw Exception('Unexpected output shape: $oshape');
    }
    if (oshape[1] == 6) {
      _layoutCHW = true;
      valuesPerDet = oshape[1];
      numDet = oshape[2];
    } else if (oshape[2] == 6) {
      _layoutCHW = false;
      valuesPerDet = oshape[2];
      numDet = oshape[1];
    } else {
      throw Exception('Cannot find 6-dim per detection in output: $oshape');
    }
    final op = outT.params;
    if (op.scale != 0.0) _outScale = op.scale;
    _outZero = op.zeroPoint;
    debugPrint(
      '📤 Output tensor params: scale=$_outScale, zeroPoint=$_outZero',
    );

    debugPrint(
      '📥 Input: ${inW}x${inH}, type=$_inType (scale=$_inScale, zp=$_inZero)',
    );
    debugPrint(
      '📤 Output: layoutCHW=$_layoutCHW, N=$numDet, type=$_outType (scale=$_outScale, zp=$_outZero)',
    );

    _preparePreallocatedInputs();

    // **สำคัญ**: ไม่ทำ warm-up เพื่อเลี่ยง PAD crash
  }

  void _preparePreallocatedInputs() {
    if (inW == null || inH == null) return;
    final isFloat =
        _inType == TensorType.float32 || _inType == TensorType.float16;
    if (isFloat) {
      _inputF = List.generate(
        1,
        (_) => List.generate(
          inH!,
          (_) => List.generate(inW!, (_) => List<double>.filled(3, 0.0)),
        ),
      );
      _inputI = null;
    } else {
      _inputI = List.generate(
        1,
        (_) => List.generate(
          inH!,
          (_) => List.generate(inW!, (_) => List<int>.filled(3, 0)),
        ),
      );
      _inputF = null;
    }
  }

  // ===== Camera =====
  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );
    await cameraController.initialize();
    isInitialized.value = true;
  }

  Future<void> toggleCamera() async {
    if (!isInitialized.value) {
      await initializeCamera();
      isCameraRunning.value = true;
      await _startStream();
    } else {
      await _stopStream();
      await cameraController.dispose();
      isInitialized.value = false;
      isCameraRunning.value = false;
    }
  }

  Future<void> _startStream() async {
    if (_interp == null) {
      debugPrint('⚠️ Interpreter not ready');
      return;
    }
    try {
      await cameraController.startImageStream(_onFrame);
      isStreaming.value = true;
    } catch (e) {
      debugPrint('⚠️ startImageStream failed: $e');
    }
  }

  Future<void> _stopStream() async {
    try {
      if (cameraController.value.isStreamingImages) {
        await cameraController.stopImageStream();
      }
    } catch (e) {
      debugPrint('⚠️ stopImageStream failed: $e');
    }
    isStreaming.value = false;
  }

  // ===== Stream Callback =====
  Future<void> _onFrame(CameraImage img) async {
    if (_busy ||
        _interp == null ||
        inW == null ||
        inH == null ||
        numDet == null) {
      return;
    }
    _frameIdx = (_frameIdx + 1) % processEveryN;
    if (_frameIdx != 0) return;

    _busy = true;
    recognitions.clear();
    ripeCount.value = 0;
    unripeCount.value = 0;
    

    try {
      imgW.value = img.width.toDouble();
      imgH.value = img.height.toDouble();

      _ensureResizeMaps(img.width, img.height, inW!, inH!);
      _fillInputFromYUV(img);

      final output = _prepareOutput();
      final input = (_inputF != null) ? _inputF! : _inputI!;

      _interp!.run(input, output);

      final dets = _parseDetections(output);

      // 🔍 **แก้ไข** - แสดงเฉพาะสรุป ไม่แสดงทุก detection
      debugPrint('🔍 Total detections: ${dets.length}');

      // แสดงเฉพาะ detection ที่มี confidence > 0.1
      final validDets = dets.where((d) => d.conf > 0.1).toList();
      debugPrint('🔍 Valid detections (conf > 0.1): ${validDets.length}');

      // แสดงแค่ 5 ตัวแรกที่มี confidence สูงสุด
      validDets.sort((a, b) => b.conf.compareTo(a.conf));
      for (int i = 0; i < math.min(5, validDets.length); i++) {
        final d = validDets[i];
        final label = d.cls >= 0 && d.cls < labels.length
            ? labels[d.cls]
            : "unknown";
        debugPrint(
          '  🎯 Top${i + 1}: $label (conf=${d.conf.toStringAsFixed(3)}, cls=${d.cls})',
        );
      }

      // กรองผลลัพธ์ตาม confidence threshold
      final beforeNMS = dets.where((d) => d.conf >= confThresh).toList();
      debugPrint(
        '🔍 After confidence filter (>=$confThresh): ${beforeNMS.length}',
      );

      final filtered = _nms(
        dets
            .where((d) => d.conf >= 0.1)
            .toList(), // ใช้ค่าเริ่มต้นที่ต่ำก่อนกรอง
        iouThresh: iouThresh,
        topK: topK,
      );

    
      for (final d in filtered) {
        // เพิ่มเงื่อนไขการกรองที่นี่
      if (d.conf >= confThresh) { // 🎯 ใช้ confThresh ที่กำหนดไว้ด้านบน
        final idx = d.cls;
        final clsName = (idx >= 0 && idx < labels.length)
            ? labels[idx]
            : 'Unknown';

        // 🎯 ส่วนที่แก้ไข: จัดการการนับและการแสดงผลในลูปเดียวกัน
        // โดยใช้เงื่อนไขที่กำหนดไว้ก่อนหน้า
        bool shouldShow = false;
        if (clsName == 'ripe') {
          shouldShow = true;
          ripeCount.value++; // อัปเดตจำนวนทันทีที่พบ
        } else if (clsName == 'unripe') {
          shouldShow = true;
          unripeCount.value++; // อัปเดตจำนวนทันทีที่พบ
        }

        if (shouldShow) {
          final xmin = (d.x - d.w / 2) * imgW.value;
          final ymin = (d.y - d.h / 2) * imgH.value;
          final xmax = (d.x + d.w / 2) * imgW.value;
          final ymax = (d.y + d.h / 2) * imgH.value;

          final rx = math.max(0.0, xmin);
          final ry = math.max(0.0, ymin);
          final rw = math.min(imgW.value, xmax) - rx;
          final rh = math.min(imgH.value, ymax) - ry;

          recognitions.add({
            'clsIndex': idx,
            'detectedClass': clsName,
            'confidenceInClass': d.conf,
            'rect': {'x': rx, 'y': ry, 'w': rw, 'h': rh},
          });
        }
      }
      // 🎯 สิ้นสุดส่วนที่แก้ไข

      summaryText.value =
          'พบปาล์มสุก ${ripeCount.value} | ปาล์มดิบ ${unripeCount.value} | รวม ${ripeCount.value + unripeCount.value}';
    }} catch (e, st) {
      debugPrint('❌ Inference failed: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  // ===== Helpers =====
  void _ensureResizeMaps(int srcW, int srcH, int dstW, int dstH) {
    debugPrint('🧮 Creating resize maps: src=($srcW,$srcH) dst=($dstW,$dstH)');
    if (_srcW == srcW && _srcH == srcH && _mapX != null) return;
    _srcW = srcW;
    _srcH = srcH;
    _mapX = List<int>.generate(
      dstW,
      (x) => ((x * srcW) / dstW).floor().clamp(0, srcW - 1),
    );
    _mapY = List<int>.generate(
      dstH,
      (y) => ((y * srcH) / dstH).floor().clamp(0, srcH - 1),
    );
    _mapXuv = List<int>.generate(
      dstW,
      (x) => ((_mapX![x]) >> 1).clamp(0, (srcW >> 1) - 1),
    );
    _mapYuv = List<int>.generate(
      dstH,
      (y) => ((_mapY![y]) >> 1).clamp(0, (srcH >> 1) - 1),
    );
  }

  // YUV420 → RGB + resize + (float/quant) เขียนลง buffer เดียว
  // แทนที่ method _fillInputFromYUV ใน DetectionController
  void _fillInputFromYUV(CameraImage cameraImage) {
    final isFloat =
        _inType == TensorType.float32 || _inType == TensorType.float16;
    final h = inH!, w = inW!;

    final pY = cameraImage.planes[0];
    final pU = cameraImage.planes[1];
    final pV = cameraImage.planes[2];

    final yBytes = pY.bytes;
    final uBytes = pU.bytes;
    final vBytes = pV.bytes;

    final rsY = pY.bytesPerRow;
    final psY = pY.bytesPerPixel ?? 1;
    final rsU = pU.bytesPerRow;
    final psU = pU.bytesPerPixel ?? 1;
    final rsV = pV.bytesPerRow;
    final psV = pV.bytesPerPixel ?? 1;

    // Debug sample pixels
    int debugCount = 0;

    for (int dy = 0; dy < h; dy++) {
      final sy = _mapY![dy];
      final suvY = _mapYuv![dy];
      for (int dx = 0; dx < w; dx++) {
        final sx = _mapX![dx];
        final suvX = _mapXuv![dx];

        final yIndex = sy * rsY + sx * psY;
        final uIndex = suvY * rsU + suvX * psU;
        final vIndex = suvY * rsV + suvX * psV;

        final Y = yBytes[yIndex] & 0xff;
        final U = (uBytes[uIndex] & 0xff) - 128;
        final V = (vBytes[vIndex] & 0xff) - 128;

        // YUV to RGB conversion (แก้ไขสูตร)
        int R = (Y + 1.402 * V).round().clamp(0, 255);
        int G = (Y - 0.344136 * U - 0.714136 * V).round().clamp(0, 255);
        int B = (Y + 1.772 * U).round().clamp(0, 255);

        if (isFloat) {
          // **สำคัญ**: ใช้ _inScale สำหรับ normalization
          _inputF![0][dy][dx][0] = R * _inScale; // แทน R / 255.0
          _inputF![0][dy][dx][1] = G * _inScale; // แทน G / 255.0
          _inputF![0][dy][dx][2] = B * _inScale; // แทน B / 255.0
        } else {
          // สำหรับ quantized models
          final qR = ((R * _inScale) + _inZero).round();
          final qG = ((G * _inScale) + _inZero).round();
          final qB = ((B * _inScale) + _inZero).round();

          if (_inType == TensorType.int8) {
            _inputI![0][dy][dx][0] = qR.clamp(-128, 127);
            _inputI![0][dy][dx][1] = qG.clamp(-128, 127);
            _inputI![0][dy][dx][2] = qB.clamp(-128, 127);
          } else {
            _inputI![0][dy][dx][0] = qR.clamp(0, 255);
            _inputI![0][dy][dx][1] = qG.clamp(0, 255);
            _inputI![0][dy][dx][2] = qB.clamp(0, 255);
          }
        }

        // Debug first few pixels
        if (debugCount < 3) {
          debugPrint(
            '🎨 Pixel[$dx,$dy]: YUV=($Y,$U,$V) -> RGB=($R,$G,$B) -> norm=(${R * _inScale}, ${G * _inScale}, ${B * _inScale})',
          );
          debugCount++;
        }
      }
    }
  }

  Object _prepareOutput() {
    final isFloat =
        _outType == TensorType.float32 || _outType == TensorType.float16;
    if (_layoutCHW) {
      return [
        List.generate(
          6,
          (_) => isFloat
              ? List<double>.filled(numDet!, 0.0)
              : List<int>.filled(numDet!, 0),
        ),
      ];
    } else {
      return [
        List.generate(
          numDet!,
          (_) => isFloat ? List<double>.filled(6, 0.0) : List<int>.filled(6, 0),
        ),
      ];
    }
  }

  double _dq(num q) {
    final isQuantOut =
        _outType == TensorType.int8 || _outType == TensorType.uint8;
    if (isQuantOut) {
      final result = _outScale * (q - _outZero);
      debugPrint(
        'Dequantize: q=$q, scale=$_outScale, zeroPoint=$_outZero => $result',
      );
      return result;
    }
    return q.toDouble();
  }

  // Parse (รองรับทั้ง [1,6,N] และ [1,N,6], ทั้ง xywh กับ x1y1x2y2)
  // แทนที่ method _parseDetections ด้วยโค้ดนี้
  List<_Det> _parseDetections(Object output) {
    final isFloat =
        _outType == TensorType.float32 || _outType == TensorType.float16;
    final dets = <_Det>[];

    // Debug raw output
    debugPrint('📤 Raw output type: ${output.runtimeType}');
    if (output is List) {
      final out0 = output[0];
      debugPrint('📤 Output[0] type: ${out0.runtimeType}');

      if (out0 is List) {
        debugPrint('📤 Output shape: [${output.length}, ${out0.length}]');

        // ตรวจสอบค่าตัวอย่าง
        if (out0.isNotEmpty && out0[0] is List) {
          final firstRow = out0[0] as List;
          debugPrint(
            '📤 First detection sample: [${firstRow.take(6).join(', ')}]',
          );
        }
      }
    }

    if (_layoutCHW) {
      // Layout: [1, 6, N] - channels first
      final out = (output as List)[0] as List;

      if (out.length < 6) {
        debugPrint('❌ Output channels < 6: ${out.length}');
        return dets;
      }

      final xs = out[0] as List;
      final ys = out[1] as List;
      final ws = out[2] as List;
      final hs = out[3] as List;
      final cs = out[4] as List;
      final ks = out[5] as List;

      debugPrint('📤 CHW Layout - N=${xs.length}');

      // Debug first few detections
      for (int i = 0; i < math.min(3, xs.length); i++) {
        final x = isFloat ? (xs[i] as num).toDouble() : _dq(xs[i] as num);
        final y = isFloat ? (ys[i] as num).toDouble() : _dq(ys[i] as num);
        final w = isFloat ? (ws[i] as num).toDouble() : _dq(ws[i] as num);
        final h = isFloat ? (hs[i] as num).toDouble() : _dq(hs[i] as num);
        final conf = isFloat ? (cs[i] as num).toDouble() : _dq(cs[i] as num);
        final cls = (isFloat ? (ks[i] as num).toDouble() : _dq(ks[i] as num))
            .round();

        debugPrint(
          '📤 Detection[$i]: x=$x, y=$y, w=$w, h=$h, conf=$conf, cls=$cls',
        );
      }

      for (int i = 0; i < numDet!; i++) {
        final x = isFloat ? (xs[i] as num).toDouble() : _dq(xs[i] as num);
        final y = isFloat ? (ys[i] as num).toDouble() : _dq(ys[i] as num);
        final w = isFloat ? (ws[i] as num).toDouble() : _dq(ws[i] as num);
        final h = isFloat ? (hs[i] as num).toDouble() : _dq(hs[i] as num);
        final conf = isFloat ? (cs[i] as num).toDouble() : _dq(cs[i] as num);
        final cls = (isFloat ? (ks[i] as num).toDouble() : _dq(ks[i] as num))
            .round();
        dets.add(_Det(x, y, w, h, conf, cls));
      }
      return dets;
    }

    // Layout: [1, N, 6] - channels last
    final out = (output as List)[0] as List;
    debugPrint('📤 HWC Layout - N=${out.length}');

    // Debug first few detections
    for (int i = 0; i < math.min(3, out.length); i++) {
      final row = out[i] as List;
      if (row.length >= 6) {
        final vals = row
            .take(6)
            .map((v) => isFloat ? (v as num).toDouble() : _dq(v as num))
            .toList();
        debugPrint(
          '📤 Detection[$i]: [${vals.map((v) => v.toStringAsFixed(3)).join(', ')}]',
        );
      }
    }

    for (int i = 0; i < numDet!; i++) {
      final row = out[i] as List;
      if (row.length < 6) continue;

      final v0 = isFloat ? (row[0] as num).toDouble() : _dq(row[0] as num);
      final v1 = isFloat ? (row[1] as num).toDouble() : _dq(row[1] as num);
      final v2 = isFloat ? (row[2] as num).toDouble() : _dq(row[2] as num);
      final v3 = isFloat ? (row[3] as num).toDouble() : _dq(row[3] as num);
      final conf = isFloat ? (row[4] as num).toDouble() : _dq(row[4] as num);
      final cls = (isFloat ? (row[5] as num).toDouble() : _dq(row[5] as num))
          .round();

      // Auto-detect format (xyxy vs xywh)
      final looksLikeNms = (v2 >= v0 && v3 >= v1) || (v2 > 1.5 || v3 > 1.5);
      if (looksLikeNms) {
        // XYXY format
        final isPixel = (v2 > 1.5 || v3 > 1.5);
        final sx = isPixel ? (1.0 / inW!) : 1.0;
        final sy = isPixel ? (1.0 / inH!) : 1.0;
        final x1 = v0 * sx, y1 = v1 * sy, x2 = v2 * sx, y2 = v3 * sy;
        final cx = (x1 + x2) / 2.0;
        final cy = (y1 + y2) / 2.0;
        final ww = (x2 - x1).abs();
        final hh = (y2 - y1).abs();
        dets.add(_Det(cx, cy, ww, hh, conf, cls));
      } else {
        // XYWH format
        dets.add(_Det(v0, v1, v2, v3, conf, cls));
      }
    }

    return dets;
  }

  List<_Det> _nms(List<_Det> dets, {double iouThresh = 0.2, int topK = 100}) {
    debugPrint('🔍 Before NMS: ${dets.length} detections');

    // แสดงผลลัพธ์ก่อน NMS (แสดงแค่ 10 ตัวแรก)
    for (int i = 0; i < dets.length && i < 10; i++) {
      final d = dets[i];
      final label = d.cls < labels.length ? labels[d.cls] : 'unknown';
      debugPrint('  [$i] $label: conf=${d.conf.toStringAsFixed(3)}');
    }

    dets.sort((a, b) => b.conf.compareTo(a.conf));
    final keep = <_Det>[];
    final used = List<bool>.filled(dets.length, false);

    // **แก้ไขตรงนี้** - วน loop แยกกัน
    for (int i = 0; i < dets.length; i++) {
      if (used[i]) continue;
      final a = dets[i];
      keep.add(a);

      // Debug: แสดงผลที่เก็บไว้
      final aLabel = a.cls < labels.length ? labels[a.cls] : 'unknown';
      debugPrint('✅ Keep: $aLabel (conf=${a.conf.toStringAsFixed(3)})');

      if (keep.length >= topK) break;

      int suppressCount = 0;
      // วน loop แยกเพื่อหา detection ที่จะ suppress
      for (int j = i + 1; j < dets.length; j++) {
        if (used[j]) continue;
        final b = dets[j];

        final iou = _iou(a, b);

        // 🎯 **ส่วนที่แก้ไข: ใช้เงื่อนไข 2 แบบ**
        // กรณีคลาสเดียวกัน
        if (a.cls == b.cls && iou > iouThresh) {
          used[j] = true;
          suppressCount++;
          final bLabel = b.cls < labels.length ? labels[b.cls] : 'unknown';
          debugPrint(
            '❌ Suppress: $bLabel (conf=${b.conf.toStringAsFixed(3)}, IoU=${iou.toStringAsFixed(3)})',
          );
        } 
         // กรณีต่างคลาส แต่ทับซ้อนเกิน 90%
        // else if (a.cls != b.cls && iou > 0.80) {
        //   used[j] = true;
        //   suppressCount++;
        //   final bLabel = b.cls < labels.length ? labels[b.cls] : 'unknown';
        //   debugPrint(
        //     '❌ Suppress (Cross-Class): $bLabel (conf=${b.conf.toStringAsFixed(3)}, IoU=${iou.toStringAsFixed(3)})',
        //   );
        // }
      }

      if (suppressCount > 0) {
        debugPrint('   └─ Suppressed $suppressCount detections');
      }
    }

    debugPrint('🔍 After NMS: ${keep.length} detections');
    final ripeCountNMS = keep.where((d) => d.cls == 0).length;
    final unripeCountNMS = keep.where((d) => d.cls == 1).length;
    debugPrint('📊 NMS Result: ripe=$ripeCountNMS, unripe=$unripeCountNMS');

    return keep;
  }

  double _iou(_Det a, _Det b) {
    final ax1 = a.x - a.w / 2,
        ay1 = a.y - a.h / 2,
        ax2 = a.x + a.w / 2,
        ay2 = a.y + a.h / 2;
    final bx1 = b.x - b.w / 2,
        by1 = b.y - b.h / 2,
        bx2 = b.x + b.w / 2,
        by2 = b.y + b.h / 2;

    final interX1 = math.max(ax1, bx1);
    final interY1 = math.max(ay1, by1);
    final interX2 = math.min(ax2, bx2);
    final interY2 = math.min(ay2, by2);

    final interW = math.max(0.0, interX2 - interX1);
    final interH = math.max(0.0, interY2 - interY1);
    final interArea = interW * interH;

    final areaA = (ax2 - ax1) * (ay2 - ay1);
    final areaB = (bx2 - bx1) * (by2 - by1);
    final union = areaA + areaB - interArea + 1e-6;

    return interArea / union;
  }
}

class _Det {
  final double x, y, w, h, conf;
  final int cls;
  _Det(this.x, this.y, this.w, this.h, this.conf, this.cls);
}
