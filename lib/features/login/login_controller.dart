import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/drink_api_service.dart';
import '../home/home_page.dart';

/// 登录页面控制器
class LoginController extends GetxController {
  final DrinkApiService _apiService = DrinkApiService();

  // 输入控制器
  final phoneController = TextEditingController();
  final captchaController = TextEditingController();
  final smsCodeController = TextEditingController();

  // 状态
  final RxBool isLoading = false.obs;
  final RxBool isSendingSms = false.obs;
  final RxBool isSmsSent = false.obs;
  final Rx<Uint8List?> captchaImage = Rx<Uint8List?>(null);

  // 随机参数
  String _doubleRandom = "";
  String _timestamp = "";

  @override
  void onInit() {
    super.onInit();
    refreshCaptcha();
  }

  @override
  void onClose() {
    phoneController.dispose();
    captchaController.dispose();
    smsCodeController.dispose();
    super.onClose();
  }

  /// 刷新图形验证码
  Future<void> refreshCaptcha() async {
    try {
      _doubleRandom = Random().nextDouble().toString();
      _timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final data = await _apiService.getCaptcha(
        doubleRandom: _doubleRandom,
        timestamp: _timestamp,
      );
      captchaImage.value = data;
    } catch (e) {
      Get.snackbar(
        '错误',
        '获取验证码失败，请点击重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 发送短信验证码
  Future<void> sendSmsCode() async {
    if (phoneController.text.isEmpty) {
      Get.snackbar('提示', '请输入手机号', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (captchaController.text.isEmpty) {
      Get.snackbar('提示', '请输入图形验证码', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSendingSms.value = true;
    try {
      final success = await _apiService.sendSmsCode(
        doubleRandom: _doubleRandom,
        captcha: captchaController.text,
        phone: phoneController.text,
      );

      if (success) {
        isSmsSent.value = true;
        Get.snackbar(
          '成功',
          '验证码已发送至 ${phoneController.text}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          '失败',
          '图形验证码错误，请重试',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        refreshCaptcha();
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '发送失败，请检查网络',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSendingSms.value = false;
    }
  }

  /// 登录
  Future<void> login() async {
    if (phoneController.text.isEmpty) {
      Get.snackbar('提示', '请输入手机号', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (smsCodeController.text.isEmpty) {
      Get.snackbar('提示', '请输入短信验证码', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isLoading.value = true;
    try {
      final success = await _apiService.login(
        phone: phoneController.text,
        smsCode: smsCodeController.text,
      );

      if (success) {
        Get.snackbar(
          '成功',
          '登录成功！',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAll(() => const HomePage());
      } else {
        Get.snackbar(
          '失败',
          '验证码错误或已过期',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '登录失败，请检查网络',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 重置状态回到第一步
  void resetToFirstStep() {
    isSmsSent.value = false;
    captchaController.clear();
    smsCodeController.clear();
    refreshCaptcha();
  }
}
