import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:palm_app/controller/detection_controller.dart';
import 'package:palm_app/color/colors.dart';
import 'package:intl/intl.dart';

class ReportPage extends GetView<DetectionController> {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'รายงานผล',
          style: TextStyle(
            color: PWhite,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: PBrown,
        elevation: 0,
      ),
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard UI
              _buildDashboard(),
              const SizedBox(height: 20),

              // Filter and Heading Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ข้อมูลการบันทึก',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: PBrown,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => controller.selectDate(context),
                    icon: const Icon(Icons.calendar_today, color: PWhite),
                    label: Text(
                      controller.selectedDate.value == null
                          ? 'เลือกวันที่'
                          : DateFormat(
                              'dd-MM-yyyy',
                            ).format(controller.selectedDate.value!),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: PWhite,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PBrown,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Data Table
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: PBrown.withOpacity(0.05), // สีพื้นหลังตาราง
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DataTable(
                        headingRowColor:
                            MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) =>
                                  PBrown.withOpacity(0.15), // สีหัวตาราง
                            ),
                        border: TableBorder.all(
                          color: PBrown.withOpacity(0.1), // สีเส้นขอบตาราง
                          width: 1,
                        ),
                        columns: const [
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'เวลาและวันที่',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: PBrown, // สีข้อความหัวตาราง
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'ปาล์มสุก',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: PGreen,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'ปาล์มดิบ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: PRed,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                        rows: controller.palmRecords.map((record) {
                          final time = DateFormat(
                            'HH:mm:ss',
                          ).format(DateTime.parse(record['date']));
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    time,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    record['ripeCount'].toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: PGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    record['unripeCount'].toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: PRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPalmCard(
                'ปาล์มสุก',
                PGreen,
                controller.savedRipeTotal.value,
              ),
              _buildPalmCard(
                'ปาล์มดิบ',
                PRed,
                controller.savedUnripeTotal.value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PBlue.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            'ผลรวมทั้งหมด',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PWhite,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${controller.savedRipeTotal.value + controller.savedUnripeTotal.value}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: PWhite,
            ),
          ),
          const SizedBox(height: 5),
          const Text('ทะลาย', style: TextStyle(fontSize: 16, color: PWhite)),
        ],
      ),
    );
  }

  Widget _buildPalmCard(String label, Color color, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text("ทะลาย", style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }
}
