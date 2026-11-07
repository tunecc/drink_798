import 'dart:async';

import 'package:drink_water_app/core/models/account_balance.dart';
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
    this.balanceSequence = const [
      AccountBalance(walletYuan: 9.9, score: 100),
      AccountBalance(walletYuan: 9.55, score: 60),
    ],
    this.billListPages = const [],
    this.billDetailBills = const {},
    this.loggedIn = true,
    this.statusQueue = const [],
    this.setUseScoreResult = const DrinkResult(success: true, code: 0),
  }) : super.test();

  final List<Map<String, dynamic>> devices;
  final DrinkResult startResult;
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

  /// accountBalance 按调用次序返回的序列；耗尽后重复最后一个。
  final List<AccountBalance?> balanceSequence;

  /// billList 依次返回的账单记录页；耗尽后重复最后一个，空表默认返回 []。
  final List<List<Map<String, dynamic>>> billListPages;

  /// billDetail 按 billId 返回的账单详情；缺失的 id 返回 null。
  final Map<String, Map<String, dynamic>> billDetailBills;

  /// isLoggedIn 的替身返回；默认视为已登录。
  final bool loggedIn;

  /// deviceStatus 依次返回的显式状态队列；耗尽后回落到默认逻辑。
  final List<DeviceStatus> statusQueue;

  /// setUseScore 的替身返回；默认成功，供同步失败用例覆写。
  final DrinkResult setUseScoreResult;

  int deviceListCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int statusCalls = 0;
  int availableCalls = 0;
  int toggleCalls = 0;
  int resolveCalls = 0;
  int balanceCalls = 0;
  int billListCalls = 0;
  int billDetailCalls = 0;
  int setUseScoreCalls = 0;
  final List<int> startPtypes = [];

  /// 按发生次序记录的请求名，用于断言「同步先于启动」。
  final List<String> callLog = [];
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
  Future<bool> isLoggedIn() async => loggedIn;

  @override
  Future<DrinkResult> setUseScore({int value = 1}) async {
    setUseScoreCalls++;
    callLog.add('setUseScore');
    return setUseScoreResult;
  }

  @override
  Future<DrinkResult> startDrinking({
    required String deviceId,
    int ptype = DrinkApiService.walletPaymentType,
  }) async {
    startCalls++;
    startPtypes.add(ptype);
    callLog.add('startDrinking');
    return startResult;
  }

  @override
  Future<DrinkResult> stopDrinking({required String deviceId}) async {
    stopCalls++;
    callLog.add('stopDrinking');
    return stopResult;
  }

  @override
  Future<DeviceStatusResult> deviceStatus({required String deviceId}) async {
    statusCalls++;
    if (statusQueue.isNotEmpty) {
      final index = statusCalls - 1;
      final status = statusQueue[index < statusQueue.length
          ? index
          : statusQueue.length - 1];
      return DeviceStatusResult(success: true, code: 0, status: status);
    }
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

  @override
  Future<AccountBalance?> accountBalance() async {
    if (!loggedIn) return null;
    balanceCalls++;
    if (balanceSequence.isEmpty) return null;
    final index = balanceCalls - 1;
    return balanceSequence[index < balanceSequence.length
        ? index
        : balanceSequence.length - 1];
  }

  @override
  Future<List<Map<String, dynamic>>> billList() async {
    billListCalls++;
    if (billListPages.isEmpty) return const [];
    final index = billListCalls - 1;
    return billListPages[index < billListPages.length
        ? index
        : billListPages.length - 1];
  }

  @override
  Future<Map<String, dynamic>?> billDetail({required String billId}) async {
    billDetailCalls++;
    return billDetailBills[billId];
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
