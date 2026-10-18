import 'dart:async';

import 'package:drink_water_app/core/models/device_status.dart';
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
    this.secondStartResult,
    this.stopResult = const DrinkResult(success: true, code: 0),
    this.deviceAvailable = false,
    this.toggleResult = true,
    // 预检（deviceStatus 第一次调用）默认返回空闲可用，保持既有测试的
    // 「start 成功」路径不被新增的预检拦下。
    this.precheckStatus = const DeviceStatus(deviceStatus: 1, geneStatus: 99),
    this.statusFailure,
    this.pollStatusFailure,
    this.hangStatus = false,
    this.resolveQrResponse = '',
  }) : super.test();

  final List<Map<String, dynamic>> devices;
  final DrinkResult startResult;

  /// 第二次 startDrinking（钱包支付失败后的回退请求）返回的结果；
  /// 为 null 时所有调用都返回 [startResult]。
  final DrinkResult? secondStartResult;
  final DrinkResult stopResult;

  /// 轮询阶段（deviceStatus 预检之后）设备是否空闲可用。
  final bool deviceAvailable;
  final bool toggleResult;

  /// 预检返回的设备状态，默认空闲。
  final DeviceStatus precheckStatus;

  /// 非 null 时所有 deviceStatus 调用一律返回该失败结果。
  final DeviceStatusResult? statusFailure;

  /// 非 null 时预检之后的 deviceStatus 调用返回该失败结果（轮询期故障）。
  final DeviceStatusResult? pollStatusFailure;

  /// 置真时 deviceStatus 一直挂起，等 [releaseStatus] 放行。
  final bool hangStatus;

  /// resolveQrDevice 返回的设备 ID；空串表示服务端没能解析。
  final String resolveQrResponse;

  int deviceListCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int statusCalls = 0;
  int availableCalls = 0;
  int toggleCalls = 0;
  int resolveCalls = 0;
  final List<int> startPtypes = [];
  String? lastToggleDeviceId;
  bool? lastToggleIsRemove;
  String? lastQrId;

  bool _precheckDone = false;
  Completer<DeviceStatusResult>? _statusGate;

  /// 释放挂起的 deviceStatus 请求（配合 [hangStatus]）。
  void releaseStatus() {
    if (_statusGate == null || _statusGate!.isCompleted) return;
    _statusGate!.complete(
      DeviceStatusResult(success: true, code: 0, status: precheckStatus),
    );
  }

  /// 轮询阶段按 [deviceAvailable] 派生状态：非空闲视为仍在运行。
  DeviceStatus get _pollStatus => DeviceStatus(
        deviceStatus: 1,
        geneStatus: deviceAvailable ? 99 : 1,
      );

  @override
  Future<List<Map<String, dynamic>>> getDeviceList() async {
    deviceListCalls++;
    return devices;
  }

  @override
  Future<DrinkResult> startDrinking({
    required String deviceId,
    int ptype = DrinkApiService.walletPaymentType,
  }) async {
    startCalls++;
    startPtypes.add(ptype);
    if (startCalls == 2 && secondStartResult != null) {
      return secondStartResult!;
    }
    return startResult;
  }

  @override
  Future<DrinkResult> stopDrinking({required String deviceId}) async {
    stopCalls++;
    return stopResult;
  }

  @override
  Future<DeviceStatusResult> deviceStatus({required String deviceId}) async {
    statusCalls++;
    if (hangStatus) {
      final gate = _statusGate ??= Completer<DeviceStatusResult>();
      return gate.future;
    }
    if (statusFailure != null) return statusFailure!;
    if (pollStatusFailure != null && _precheckDone && statusCalls > 1) {
      return pollStatusFailure!;
    }
    if (!_precheckDone) {
      _precheckDone = true;
      return DeviceStatusResult(success: true, code: 0, status: precheckStatus);
    }
    return DeviceStatusResult(success: true, code: 0, status: _pollStatus);
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

  @override
  Future<String> resolveQrDevice({required String qrId}) async {
    resolveCalls++;
    lastQrId = qrId;
    return resolveQrResponse;
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
