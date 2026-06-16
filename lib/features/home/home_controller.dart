import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_controller.dart';
import '../../core/models/device_model.dart';
import '../../core/services/drink_api_service.dart';
import '../login/login_page.dart';
import '../scanner/scanner_page.dart';

/// 主页控制器
class HomeController extends GetxController {
  final DrinkApiService _apiService = DrinkApiService();
  SharedPreferences? _prefs;

  // 设备列表
  final RxList<DeviceModel> deviceList = <DeviceModel>[].obs;

  // 当前选中的设备索引
  final RxInt selectedDeviceIndex = (-1).obs;

  // 状态
  final RxBool isLoading = false.obs;
  final RxBool isDrinking = false.obs;

  // 定时器
  Timer? _statusTimer;

  @override
  void onInit() {
    super.onInit();
    _initPrefs();
    loadDevices();
  }

  /// 初始化 SharedPreferences
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  void onClose() {
    _statusTimer?.cancel();
    super.onClose();
  }

  /// 加载设备列表
  Future<void> loadDevices() async {
    isLoading.value = true;
    try {
      final devices = await _apiService.getDeviceList();

      // 检查是否登录失效
      if (devices.isNotEmpty && devices[0]["name"] == "登录已过期") {
        Get.snackbar(
          '提示',
          '登录已过期，请重新登录',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        Get.offAll(() => const LoginPage());
        return;
      }

      deviceList.value = devices.map((e) => DeviceModel.fromJson(e)).toList();

      // 加载备注
      await _loadDeviceNotes();

      // 自动选择第一个设备
      if (deviceList.isNotEmpty && selectedDeviceIndex.value == -1) {
        selectedDeviceIndex.value = 0;
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '加载设备失败',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载设备备注
  Future<void> _loadDeviceNotes() async {
    if (_prefs == null) {
      await _initPrefs();
    }

    for (var device in deviceList) {
      final note = _prefs?.getString('device_note_${device.id}');
      if (note != null && note.isNotEmpty) {
        device.note = note;
      }
    }
  }

  /// 保存设备备注
  Future<void> saveDeviceNote(String deviceId, String note) async {
    if (_prefs == null) {
      await _initPrefs();
    }

    await _prefs?.setString('device_note_$deviceId', note);

    // 更新设备列表中的备注
    final index = deviceList.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      deviceList[index].note = note;
      deviceList.refresh();
    }
  }

  /// 获取当前选中的设备
  DeviceModel? get currentDevice {
    if (selectedDeviceIndex.value >= 0 &&
        selectedDeviceIndex.value < deviceList.length) {
      return deviceList[selectedDeviceIndex.value];
    }
    return null;
  }

  /// 选择设备
  void selectDevice(int index) {
    if (isDrinking.value) {
      Get.snackbar(
        '提示',
        '正在接水中，请先结算',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    selectedDeviceIndex.value = index;
  }

  /// 开始接水
  Future<void> startDrinking() async {
    if (currentDevice == null) {
      Get.snackbar('提示', '请先选择设备', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final success = await _apiService.startDrinking(
        deviceId: currentDevice!.id,
      );

      if (success) {
        isDrinking.value = true;
        _startStatusCheck();
        Get.snackbar(
          '成功',
          '开始接水',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
      } else {
        Get.snackbar(
          '失败',
          '设备无响应，请检查设备状态',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '操作失败',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 结束接水
  Future<void> stopDrinking() async {
    if (currentDevice == null) return;

    try {
      final success = await _apiService.stopDrinking(
        deviceId: currentDevice!.id,
      );

      _statusTimer?.cancel();
      isDrinking.value = false;

      if (success) {
        Get.snackbar(
          '成功',
          '已结算',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
      } else {
        Get.snackbar(
          '提示',
          '结算可能未成功，请检查',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      isDrinking.value = false;
      _statusTimer?.cancel();
    }
  }

  /// 开始状态检查
  void _startStatusCheck() {
    int idleCount = 0;
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (currentDevice == null) {
        timer.cancel();
        return;
      }

      final isAvailable = await _apiService.isDeviceAvailable(
        deviceId: currentDevice!.id,
      );

      if (isAvailable && idleCount > 3) {
        // 设备空闲，自动结算
        isDrinking.value = false;
        timer.cancel();
      } else if (isAvailable) {
        idleCount++;
      } else {
        idleCount = 0;
      }
    });
  }

  /// 扫码添加设备
  Future<void> scanAndAddDevice() async {
    final result = await Get.to(() => const ScannerPage());
    
    if (result != null && result is String) {
      // 提取设备ID
      String deviceId = result;
      if (result.contains("/")) {
        deviceId = result.split("/").last;
      }

      try {
        final success = await _apiService.toggleFavoriteDevice(
          deviceId: deviceId,
          isRemove: false,
        );

        if (success) {
          Get.snackbar(
            '成功',
            '设备添加成功',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          loadDevices();
        } else {
          Get.snackbar(
            '失败',
            '添加设备失败',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          '错误',
          '添加设备时出错',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  /// 删除设备
  Future<void> removeDevice(DeviceModel device) async {
    try {
      final success = await _apiService.toggleFavoriteDevice(
        deviceId: device.id,
        isRemove: true,
      );

      if (success) {
        deviceList.removeWhere((d) => d.id == device.id);
        if (selectedDeviceIndex.value >= deviceList.length) {
          selectedDeviceIndex.value = deviceList.isEmpty ? -1 : 0;
        }
        Get.snackbar(
          '成功',
          '已删除设备',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '删除失败',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 登出
  Future<void> logout() async {
    await AppController.to.logout();
  }
}
