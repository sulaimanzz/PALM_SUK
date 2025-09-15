import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:palm_app/controller/detection_controller.dart';
import 'package:palm_app/color/colors.dart';

class ReportPage extends GetView<DetectionController> {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'รายงานผล',
          style: TextStyle(
            color: PWhite,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: PBrown,
      ),
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนบน: Dashboard UI
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: PBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildDashboardRow(
                        label: 'ผลรวมทั้งหมด',
                        color: PBlue,
                        count:
                            controller.savedRipeTotal.value +
                            controller.savedUnripeTotal.value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // บรรทัดที่สอง: ผลรวมของปาล์มสุกและปาล์มดิบ
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDashboardRow(
                          label: 'ปาล์มสุก',
                          color: PGreen,
                          count: controller.savedRipeTotal.value,
                        ),
                        _buildDashboardRow(
                          label: 'ปาล์มดิบ',
                          color: PRed,
                          count: controller.savedUnripeTotal.value,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ตัวกรองเลือกวันที่
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ข้อมูลการบันทึก',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: PBrown,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // ฟังก์ชันกรองวันที่
                    },
                    child: Text(
                      'เลือกวันที่',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: PWhite,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PBrown,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

              // ส่วนล่าง: ตารางข้อมูลการบันทึก
              const SizedBox(height: 10),

              // ตารางแสดงข้อมูล
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          'เวลาและวันที่',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'ปาล์มสุก',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'ปาล์มดิบ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    rows: controller.palmRecords.map((record) {
                      return DataRow(
                        cells: [
                          DataCell(Text(record['date'])),
                          DataCell(Text(record['ripeCount'].toString())),
                          DataCell(Text(record['unripeCount'].toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้าง Row สำหรับแสดงใน Dashboard
  Widget _buildDashboardRow({
    required String label,
    required Color color,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "ทะลาย",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
