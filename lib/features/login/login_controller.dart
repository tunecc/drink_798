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
  final tokenController = TextEditingController();

  // 状态
  final RxBool isLoading = false.obs;
  final RxBool isSendingSms = false.obs;
  final RxBool isSmsSent = false.obs;
  final RxBool isTokenLogin = false.obs;
  final RxBool isTokenVisible = false.obs;
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
    tokenController.dispose();
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
      final result = await _apiService.sendSmsCode(
        doubleRandom: _doubleRandom,
        captcha: captchaController.text,
        phone: phoneController.text,
      );

      if (result.success) {
        isSmsSent.value = true;
        Get.snackbar(
          '成功',
          '验证码已发送至 ${phoneController.text}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        // 透出服务端原因，区分「图形验证码错误」与网络/格式异常
        Get.snackbar(
          '失败',
          result.message ?? '发送失败',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        refreshCaptcha();
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '发送失败：$e',
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
      final result = await _apiService.login(
        phone: phoneController.text,
        smsCode: smsCodeController.text,
      );

      if (result.success) {
        Get.snackbar(
          '成功',
          '登录成功！',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAll(() => const HomePage());
      } else {
        // 透出服务端原因。code 为 null 表示请求未完成或响应无法解析，
        // 此时 message 是具体的技术原因，不能一律说成验证码错误。
        final detail = result.message ?? '登录失败';
        Get.snackbar(
          result.code == null ? '登录异常' : '登录失败',
          result.isSessionExpired ? '登录已过期，请重试' : detail,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '登录失败：$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 校验并保存用户手动输入的 Token。
  Future<void> loginWithToken() async {
    if (tokenController.text.trim().isEmpty) {
      Get.snackbar('提示', '请输入 Token', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isLoading.value = true;
    try {
      final success = await _apiService.loginWithToken(tokenController.text);
      if (success) {
        Get.snackbar(
          '成功',
          'Token 验证成功，已登录',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAll(() => const HomePage());
      } else {
        Get.snackbar(
          '失败',
          'Token 无效或已过期，请检查后重试',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
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

  void showTokenLogin() {
    isSmsSent.value = false;
    isTokenLogin.value = true;
  }

  void showPhoneLogin() {
    isTokenLogin.value = false;
  }
}
