import 'package:get/get.dart';

import '../features/login/login_page.dart';
import 'services/drink_api_service.dart';

/// 全局应用控制器
class AppController extends GetxController {
  static AppController get to => Get.find();

  final DrinkApiService _apiService = DrinkApiService();

  // 登录状态
  final RxBool isLoggedIn = false.obs;

  // 加载状态
  final RxBool isLoading = false.obs;

  /// 检查登录状态并返回结果
  Future<bool> checkAndGetLoginStatus() async {
    isLoading.value = true;
    try {
      isLoggedIn.value = await _apiService.isLoggedIn();
      return isLoggedIn.value;
    } finally {
      isLoading.value = false;
    }
  }

  /// 登出
  Future<void> logout() async {
    await _apiService.logout();
    isLoggedIn.value = false;
    Get.offAll(() => const LoginPage());
  }
}
