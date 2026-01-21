import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/login/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DrinkWaterApp());
}

class DrinkWaterApp extends StatelessWidget {
  const DrinkWaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 初始化全局控制器
    final appController = Get.put(AppController());
    
    return GetMaterialApp(
      title: '智能饮水',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: FutureBuilder<bool>(
        future: appController.checkAndGetLoginStatus(),
        builder: (context, snapshot) {
          // 显示简单的加载状态（几乎瞬间完成）
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // 根据登录状态直接进入对应页面
          if (snapshot.data == true) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
