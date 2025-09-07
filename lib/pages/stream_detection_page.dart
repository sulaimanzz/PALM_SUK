import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:palm_app/app_route/app_route.dart';
import 'package:palm_app/color/colors.dart';
import 'package:palm_app/controller/detection_controller.dart';
import 'package:palm_app/pages/report_page.dart';
import 'package:palm_app/pages/test.dart';

class StreanDetectionPage extends GetView<DetectionController> {
  const StreanDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // เปลี่ยนสีrenderBox
    Color getBorderColor(String detectedClass) {
      switch (detectedClass) {
        case 'ripe':
          return PGreen;
        default:
          return PRed;
      }
    }

    List<Widget> renderMarkers(Size screen) {
      // แก้ไขจาก imageHeight/imageWidth เป็น imgH/imgW
      if (controller.imgH.value == 0.0 || controller.imgW.value == 0.0) {
        return [];
      }

      // แก้ไขจาก imageHeight/imageWidth เป็น imgH/imgW
      double factorX = screen.width / controller.imgW.value;
      double factorY = screen.height / controller.imgH.value;

      return controller.recognitions.map((re) {
        if (re["confidenceInClass"] as double >= 0.5) {
          // คำนวณตำแหน่งของจุดกลางของปาล์ม
          double xCenter = re["rect"]["x"] + re["rect"]["w"] / 2;
          double yCenter = re["rect"]["y"] + re["rect"]["h"] / 2;

          return Positioned(
            left: xCenter * factorX - 5, // ลดขนาดจุดเพื่อให้เป็นจุด
            top: yCenter * factorY - 5, // ลดขนาดจุดเพื่อให้เป็นจุด
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: getBorderColor(
                  re["detectedClass"],
                ), // ใช้สีตามประเภท (สีเขียวสำหรับสุก, สีแดงสำหรับดิบ)
              ),
            ),
          );
        } else {
          return const SizedBox.shrink(); // ถ้าความมั่นใจน้อยกว่า 50% ไม่แสดงอะไร
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
            icon: Icon(Icons.save,color: PWhite,),
            onPressed: () {
              // นำทางไปยังหน้า ReportPage
              // นำทางไปยังหน้า ReportPage โดยใช้ Get.toNamed
              // Get.toNamed(AppRoutes.reportPage);
              Get.to(() => const ReportPage()); 
            },
          ),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            // ครึ่งบน: กล้อง
            Expanded(
              flex: 5,
              child: Container(
                // margin: EdgeInsets.symmetric(vertical: 0, horizontal: 40),
                color: Pbgcolor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 40,
                  ),
                  child: SizedBox(
                    child: Center(
                      child: Container(
                        color: Pbgcolor,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              Obx(() {
                                if (controller.isInitialized.value) {
                                  return Stack(
                                    children: [
                                      CameraPreview(
                                        controller.cameraController,
                                      ),
                                      ...renderMarkers(size), // ส่ง size เข้าไป
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
                ),
              ),
            ),
            // ครึ่งล่าง: ผลลัพธ์
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(color: Pbgcolor),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      left: 40,
                      right: 40,
                      bottom: 30,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  top: 25,
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
                            const SizedBox(height: 10),
                            _buildResultRow(
                              'ผลปาล์มดิบ',
                              PRed,
                              controller.unripeCount.value,
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => controller.toggleCamera(),
                                  child: Obx(
                                    () => Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 25,
                                      ),
                                      width: 140,
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
                                SizedBox(width: 10.0,),
                                GestureDetector(
                                   onTap: () async {
                                    await controller.savePalmRecord(); // บันทึกข้อมูล
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 25,
                                    ),
                                    width: 140,
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
