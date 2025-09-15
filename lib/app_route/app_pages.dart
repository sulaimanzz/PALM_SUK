import 'package:get/route_manager.dart';
import 'package:palm_app/app_route/app_route.dart';
import 'package:palm_app/binding/detection_binding.dart';
import 'package:palm_app/pages/report_page.dart';
import 'package:palm_app/pages/stream_detection_page.dart';


class AppPages {
  static final pages = [
    // GetPage(name: AppRoutes.homePage, page: () => const HomePage()),
    // GetPage(
    //   binding: DetectionBinding(),
    //   name: AppRoutes.detectionPage,
    //   page: () => DetectionPicture(),
    // ),
    GetPage(
      name: AppRoutes.streamPage,
      binding: DetectionBinding(),
      page: () => const StreanDetectionPage(),
    ),
    // เส้นทางสำหรับหน้า PalmReportPage
    
  ];
}
