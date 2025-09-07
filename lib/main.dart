import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:palm_app/app_route/app_pages.dart';
import 'package:palm_app/app_route/app_route.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      initialRoute: AppRoutes.streamPage,
      getPages: AppPages.pages,
    );
  }
}
