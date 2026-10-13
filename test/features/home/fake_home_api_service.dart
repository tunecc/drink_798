import 'dart:async';

import 'package:drink_water_app/core/services/drink_api_service.dart';

/// 首页 widget 测试用的 API 替身：不发包，只记录调用。
///
/// 超类构造写 `DrinkApiService.test()`：工厂构造在 Dart 里不能当超类构造器，
/// 见 test/features/login/fake_drink_api_service.dart 的同名说明。
class FakeHomeApiService extends DrinkApiService {
  FakeHomeApiService({
    this.devices = const [
      {'id': '101', 'name': '1栋101'},
      {'id': '102', 'name': '1栋102'},
    ],
    this.startResult = const DrinkResult(success: true, code: 0),
    this.stopResult = const DrinkResult(success: true, code: 0),
    this.deviceAvailable = false,
    this.toggleResult = true,
  }) : super.test();

  final List<Map<String, dynamic>> devices;
  final DrinkResult startResult;
  final DrinkResult stopResult;
  final bool deviceAvailable;
  final bool toggleResult;

  int deviceListCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int availableCalls = 0;
  int toggleCalls = 0;
  String? lastToggleDeviceId;
  bool? lastToggleIsRemove;

  @override
  Future<List<Map<String, dynamic>>> getDeviceList() async {
    deviceListCalls++;
    return devices;
  }

  @override
  Future<DrinkResult> startDrinking({required String deviceId}) async {
    startCalls++;
    return startResult;
  }

  @override
  Future<DrinkResult> stopDrinking({required String deviceId}) async {
    stopCalls++;
    return stopResult;
  }

  @override
  Future<bool> isDeviceAvailable({required String deviceId}) async {
    availableCalls++;
    return deviceAvailable;
  }

  @override
  Future<bool> toggleFavoriteDevice({
    required String deviceId,
    required bool isRemove,
  }) async {
    toggleCalls++;
    lastToggleDeviceId = deviceId;
    lastToggleIsRemove = isRemove;
    return toggleResult;
  }
}

/// 设备列表请求一直挂起的替身，用于断言加载中状态。
///
/// 用 Completer 而不是 Future.delayed：测试收尾时不能留下 pending Timer。
class HangingDeviceListApiService extends FakeHomeApiService {
  HangingDeviceListApiService({
    super.devices = const [
      {'id': '101', 'name': '1栋101'},
      {'id': '102', 'name': '1栋102'},
    ],
  });

  final Completer<List<Map<String, dynamic>>> _gate = Completer();

  /// 释放挂起的请求；每个用这个替身的测试都必须在断言后调用。
  /// 交出去的是配置里那份列表，所以"登录已过期"这类特殊返回也能走这条路径。
  void release() {
    if (!_gate.isCompleted) _gate.complete(devices);
  }

  @override
  Future<List<Map<String, dynamic>>> getDeviceList() {
    deviceListCalls++;
    return _gate.future;
  }
}
