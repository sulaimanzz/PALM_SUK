import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:palm_app/app_route/app_route.dart';
import 'package:palm_app/color/colors.dart';
import 'package:palm_app/controller/detection_controller.dart';
import 'package:palm_app/pages/report_page.dart';

class StreanDetectionPage extends GetView<DetectionController> {
  const StreanDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // เปลี่ยนสีrenderBox
    Color getBorderColor(String detectedClass) {
      switch (detectedClass) {
        case 'unripe':
          return PRed;
        // case 'ripe':
        //   return PRed;
        default:
          return PGreen;
      }
    }

    // ในไฟล์ stream_detection_page.dart
    // ...
    List<Widget> renderBoxes(Size screen) {
      if (controller.imgW.value == 0.0 || controller.imgH.value == 0.0) {
        return [];
      }

      return controller.recognitions.map((re) {
        if (re["confidenceInClass"] as double >= 0.2) {
          final rect = re["rect"];

          // คำนวณพิกัดใหม่เพื่อแก้ไขการหมุนและสะท้อน
          final double normalizedX =
              (controller.imgH.value - (rect["y"] + rect["h"])) /
              controller.imgH.value;
          final double normalizedY = rect["x"] / controller.imgW.value * 1.88 ;
          final double normalizedW = rect["h"] / controller.imgH.value * 1.1;
          final double normalizedH = rect["w"] / controller.imgW.value * 1.38;

          // คำนวณขนาดจริงของ camera preview ที่แสดงบนหน้าจอ
          final double cameraAspectRatio =
              controller.imgW.value / controller.imgH.value;
          final double screenAspectRatio = screen.width / screen.height;

          double previewWidth, previewHeight;
          double offsetX = 0, offsetY = 0;

          if (cameraAspectRatio > screenAspectRatio) {
            previewWidth = screen.width;
            previewHeight = screen.width / cameraAspectRatio;
            offsetY = (screen.height - previewHeight) / 2;
          } else {
            previewHeight = screen.height;
            previewWidth = screen.height * cameraAspectRatio;
            offsetX = (screen.width - previewWidth) / 2;
          }

          // แปลงเป็น screen coordinates
          final double screenX = offsetX + (normalizedX * previewWidth);
          final double screenY = offsetY + (normalizedY * previewHeight);
          final double screenW = normalizedW * previewWidth;
          final double screenH = normalizedH * previewHeight;

          // ... ส่วนที่เหลือของโค้ด Container
          return Positioned(
            left: screenX,
            top: screenY,
            width: screenW,
            height: screenH,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(
                  color: getBorderColor(re["detectedClass"]),
                  width: 2,
                ),
              ),
              child: Text(
                "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  background: Paint()
                    ..color = getBorderColor(re["detectedClass"]),
                  color: PWhite,
                  fontSize: 12.0,
                ),
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      }).toList();
    }

    // ต้องดึงขนาดของหน้าจอมาใช้ก่อนใน build method
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PALM SUK',
          style: TextStyle(
            color: PWhite,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: PBrown,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: PWhite),
            onPressed: () {
              // นำทางไปยังหน้า ReportPage
              // นำทางไปยังหน้า ReportPage โดยใช้ Get.toNamed
              // Get.toNamed(AppRoutes.reportPage);
              Get.to(() => const ReportPage());
            },
          ),
        ],
      ),
      backgroundColor: Pbgcolor,
      body: Obx(
        () => Column(
          children: [
            // ครึ่งบน: กล้อง
            Expanded(
              flex: 43,
              child: AspectRatio(
                aspectRatio:
                    (controller.imgW.value > 0 && controller.imgH.value > 0)
                    ? controller.imgW.value / controller.imgH.value
                    : 640 / 480, // กำหนดค่า default เมื่อยังไม่มีค่า
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20 ,bottom: 15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Obx(() {
                          if (controller.isInitialized.value) {
                            return Stack(
                              children: [
                                CameraPreview(controller.cameraController),
                                ...renderBoxes(
                                  Size(
                                    controller.imgW.value > 0
                                        ? controller.imgW.value
                                        : 640,
                                    controller.imgH.value > 0
                                        ? controller.imgH.value
                                        : 480,
                                  ),
                                ), // ส่ง size เข้าไป
                              ],
                            );
                          } else {
                            return Image.asset(
                              'assets/models/palmsuk1.jpg', // เปลี่ยนเป็น path ของ icon รูปกล้องที่คุณเตรียมไว้
                            );
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ครึ่งล่าง: ผลลัพธ์
            Expanded(
              flex: 21,
              child: Stack(
                children: [
                  Container(color: Pbgcolor),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      left: 20,
                      right: 20,
                      bottom: 30,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: [
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 15,
                                  bottom: 15,
                                ),
                                child: Text(
                                  'ผลการวิเคราะห์',
                                  style: TextStyle(
                                    color: PBrown,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 1),
                            _buildResultRow(
                              'ผลปาล์มสุก',
                              PGreen,
                              controller.ripeCount.value,
                            ),
                            const SizedBox(height: 5.0),
                            _buildResultRow(
                              'ผลปาล์มดิบ',
                              PRed,
                              controller.unripeCount.value,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => controller.toggleCamera(),
                                  child: Obx(
                                    () => Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 25,
                                      ),
                                      width: 110,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: PBrown,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            controller.isCameraRunning.value
                                                ? Icons.videocam_off
                                                : Icons.videocam,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            controller.isCameraRunning.value
                                                ? 'STOP '
                                                : 'START ',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.0),
                                GestureDetector(
                                  onTap: () async {
                                    await controller
                                        .savePalmRecord(); // บันทึกข้อมูล
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 25,
                                    ),
                                    width: 110,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: PBrown,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save, color: Colors.white),
                                        const SizedBox(width: 10),
                                        Text(
                                          'SAVE',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, Color color, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label : $count',
            style: const TextStyle(
              fontSize: 16,
              color: PGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
