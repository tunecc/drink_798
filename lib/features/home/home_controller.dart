import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_controller.dart';
import '../../core/models/device_model.dart';
import '../../core/models/settlement_bill.dart';
import '../../core/utils/device_order.dart';
import '../../core/services/drink_api_service.dart';
import '../login/login_controller.dart';
import '../login/login_page.dart';
import '../scanner/scanner_page.dart';
import 'home_prompt_colors.dart';

/// 失败提示的呈现内容。
class DrinkFailurePrompt {
  const DrinkFailurePrompt({
    required this.title,
    required this.message,
    required this.isSessionExpired,
  });

  final String title;
  final String message;

  /// 是否为登录态过期。用于选择提示配色。
  final bool isSessionExpired;
}

/// 钱包支付被拒时按服务端返回码给出可操作的提示。
///
/// 结算级联由服务端执行（积分 → 钱包 → 支付宝），客户端不切换支付方式，
/// 因此这些拒绝都必须落到明确的用户动作上：充值或完成签约。
const _paymentRejectionPrompts = <int, String>{
  -52: '账户欠费，请充值后再使用',
  -82: '本次接水需要支付，请确认账户余额或完成支付',
  -88: '未签约支付宝代扣协议，请先在服务端完成签约后再使用',
  -87: '代扣签约已过期，请重新签约后再使用',
};

/// 把服务端返回转换为用户可读的失败提示。
///
/// 登录态过期（code -99）单独引导重新登录；钱包支付被拒的已知码
/// （-52/-82/-88/-87）给出可操作提示；其他业务错误透出服务端信息；
/// 都没有时退回 [fallback]。
DrinkFailurePrompt drinkFailurePrompt(
  DrinkResult result, {
  required String fallback,
}) {
  if (result.isSessionExpired) {
    return const DrinkFailurePrompt(
      title: '登录已过期',
      message: '请重新登录后再试',
      isSessionExpired: true,
    );
  }

  final rejection =
      result.code == null ? null : _paymentRejectionPrompts[result.code];
  if (rejection != null) {
    return DrinkFailurePrompt(
      title: '失败',
      message: rejection,
      isSessionExpired: false,
    );
  }

  return DrinkFailurePrompt(
    title: '失败',
    message: result.message ?? fallback,
    isSessionExpired: false,
  );
}

/// 主页控制器
class HomeController extends GetxController {
  /// [apiService] 仅供测试注入替身；生产代码保持省略，沿用同一份单例。
  HomeController({DrinkApiService? apiService})
    : _apiService = apiService ?? DrinkApiService();

  final DrinkApiService _apiService;
  SharedPreferences? _prefs;

  // 设备列表
  final RxList<DeviceModel> deviceList = <DeviceModel>[].obs;

  // 当前选中的设备索引
  final RxInt selectedDeviceIndex = (-1).obs;

  /// Device list layout: 'list' (compact single column) or 'grid' (two columns)
  final RxString layoutMode = 'list'.obs;

  /// Whether the home list is in drag-reorder mode
  final RxBool isReordering = false.obs;

  // 状态
  final RxBool isLoading = false.obs;
  final RxBool isDrinking = false.obs;

  /// 账户余额。null 表示未知/隐藏：未登录、接口失败或还没加载到。
  final RxnDouble walletBalance = RxnDouble();
  final RxnInt scoreBalance = RxnInt();

  /// 余额区是否展示：登录后才展示（失败时以占位符呈现，不弹错误）。
  final RxBool balanceVisible = false.obs;

  /// 本次接水的开始时刻。结算账单必须不早于它，避免把别人的账单算进来。
  /// 非本人发起的会话（预检发现占用）为 null，不做结算上报。
  DateTime? _sessionStartedAt;

  /// 结算上报轮询。出账有延迟：有界轮询账单列表，命中后拉详情拿积分抵扣。
  Timer? _reportTimer;

  /// 上报轮询的并发挡板与次数上限。
  bool _reporting = false;
  static const int _maxReportAttempts = 5;

  /// 设备列表请求是否在途。普通字段而不是 Rx：它不驱动界面，
  /// 只用来挡住连点刷新造成的并发请求（后到的结果会覆盖前一条列表）。
  bool _loadInFlight = false;

  /// 在途期间又有人要求重载。不能直接丢掉：扫码添加后就是靠这一次重载
  /// 把新设备列出来。当前请求返回后补跑一次。
  bool _reloadQueued = false;

  /// 在途的开始请求标记。预检加两次支付尝试让单次开始变成最多三个请求，
  /// 不挡住连点的话会把队列打爆。
  bool _starting = false;

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
    final savedLayout = _prefs?.getString('device_list_layout');
    if (savedLayout == 'list' || savedLayout == 'grid') {
      layoutMode.value = savedLayout!;
    }
  }

  @override
  void onClose() {
    _statusTimer?.cancel();
    _reportTimer?.cancel();
    super.onClose();
  }

  /// 拉取钱包与积分余额。
  ///
  /// 未登录时隐藏余额区；已登录但接口失败时保留已展示的旧值（首次
  /// 加载时旧值本为 null，即占位符），都不弹错误打断用户。
  Future<void> _loadBalances() async {
    try {
      if (!await _apiService.isLoggedIn()) {
        balanceVisible.value = false;
        walletBalance.value = null;
        scoreBalance.value = null;
        return;
      }
      balanceVisible.value = true;
      final balance = await _apiService.accountBalance();
      if (balance == null) return;
      walletBalance.value = balance.walletYuan;
      scoreBalance.value = balance.score;
    } catch (_) {
      // 刷新失败保留旧值，不清成占位符。
    }
  }

  /// 加载设备列表
  Future<void> loadDevices() async {
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }
    _loadInFlight = true;
    isLoading.value = true;
    try {
      final devices = await _apiService.getDeviceList();

      // 检查是否登录失效
      if (devices.isNotEmpty && devices[0]["name"] == "登录已过期") {
        Get.snackbar(
          '提示',
          '登录已过期，请重新登录',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: HomePromptColors.warning,
          colorText: HomePromptColors.label,
        );
        // 与 AppController.logout 一致：登录页控制器是单例注册，
        // 不删除就会沿用上次的 isSmsSent/isTokenLogin 而停在错误步骤。
        Get.delete<LoginController>();
        Get.offAll(() => const LoginPage());
        // 这条分支从 try 里直接 return，末尾的补跑不会执行；标记不清掉，
        // 下次进首页加载完就会多发一整轮请求。
        _reloadQueued = false;
        return;
      }

      deviceList.value = devices.map((e) => DeviceModel.fromJson(e)).toList();

      // 余额与设备列表并行感知即可，不阻塞列表渲染。
      unawaited(_loadBalances());

      // 加载备注
      await _loadDeviceNotes();

      // 应用本地自定义顺序
      await _applySavedOrder();

      // 自动选择第一个设备
      if (deviceList.isNotEmpty && selectedDeviceIndex.value == -1) {
        selectedDeviceIndex.value = 0;
      }
    } catch (e) {
      _err('加载设备失败');
    } finally {
      _loadInFlight = false;
      isLoading.value = false;
    }
    // 登录过期那条分支已经在 try 里 return 了，不会走到这里补跑。
    if (_reloadQueued) {
      _reloadQueued = false;
      return loadDevices();
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

  /// 按本地 order 重排设备列表
  Future<void> _applySavedOrder() async {
    if (_prefs == null) {
      await _initPrefs();
    }
    final order = _prefs?.getStringList('device_order') ?? <String>[];
    if (order.isEmpty) return;

    final selectedId = currentDevice?.id;
    deviceList.value = applyDeviceOrder(deviceList.toList(), order);

    if (selectedId != null) {
      final newIndex = deviceList.indexWhere((d) => d.id == selectedId);
      selectedDeviceIndex.value =
          newIndex >= 0 ? newIndex : (deviceList.isEmpty ? -1 : 0);
    }
  }

  /// 将当前设备顺序写入本地
  Future<void> _saveDeviceOrder() async {
    if (_prefs == null) {
      await _initPrefs();
    }
    final ids = deviceList.map((d) => d.id).toList();
    await _prefs?.setStringList('device_order', ids);
  }

  /// 切换列表布局：'list' | 'grid'
  Future<void> setLayoutMode(String mode) async {
    if (mode != 'list' && mode != 'grid') return;
    if (layoutMode.value == mode) return;
    layoutMode.value = mode;
    if (_prefs == null) {
      await _initPrefs();
    }
    await _prefs?.setString('device_list_layout', mode);
  }

  /// 进入 / 退出拖拽排序模式
  void toggleReorderMode() {
    if (isDrinking.value) {
      Get.snackbar(
        '提示',
        '正在接水中，请先结算',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.notice,
        colorText: HomePromptColors.label,
      );
      return;
    }
    if (deviceList.isEmpty) return;
    isReordering.value = !isReordering.value;
  }

  /// 拖拽重排（ReorderableListView 回调）
  void reorderDevices(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= deviceList.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= deviceList.length) return;

    final selectedId = currentDevice?.id;
    final item = deviceList.removeAt(oldIndex);
    deviceList.insert(target, item);

    if (selectedId != null) {
      selectedDeviceIndex.value =
          deviceList.indexWhere((d) => d.id == selectedId);
    }

    _saveDeviceOrder();
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
        backgroundColor: HomePromptColors.notice,
        colorText: HomePromptColors.label,
      );
      return;
    }
    selectedDeviceIndex.value = index;
  }

  /// 开始接水
  ///
  /// 先查设备状态做预检：离线、禁用直接拦截，设备被他人使用中则同步为
  /// 可结算态而不重发开始请求。开始请求只发钱包支付（ptype=91），结算
  /// 级联（积分 → 钱包 → 支付宝）由服务端执行，被拒按错误码如实提示，
  /// 不存在支付方式回退；登录态过期不重试。
  Future<void> startDrinking() async {
    if (currentDevice == null) {
      Get.snackbar(
        '提示',
        '请先选择设备',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.notice,
        colorText: HomePromptColors.label,
      );
      return;
    }
    if (_starting) return;
    _starting = true;
    try {
      final deviceId = currentDevice!.id;

      // 预检：状态接口本身失败时不拦截（保留旧行为，让开始请求自己暴露错误）。
      final precheck = await _apiService.deviceStatus(deviceId: deviceId);
      if (precheck.success && precheck.status != null) {
        final status = precheck.status!;
        if (status.isOffline) {
          _err('设备离线，请稍后再试');
          return;
        }
        if (status.isDisabled) {
          _err('设备已被禁用，请联系管理员');
          return;
        }
        if (!status.isAvailable) {
          // 设备正在运行：同步为可结算状态，避免重复发起启动。
          isDrinking.value = true;
          _startStatusCheck();
          _notice('设备正在使用中，可点击结算结束本次使用');
          return;
        }
      }

      // 服务端结算级联（积分 → 钱包 → 支付宝）只有在账户级积分抵扣开关
      // useScore 开启时才扣积分；官方 App 在设备支付页提供「开启自动抵扣」，
      // 参考客户端在每次启动设备前同步该开关。这里同样先同步再启动；
      // 同步失败则中止本次启动——绝不在开关未开时静默扣款。不自动重试。
      final switchSync = await _apiService.setUseScore();
      if (!switchSync.success) {
        // 专用提示，与启动被拒的码位提示分开：明确本次没有开始接水，
        // 服务端原因非空时附在括号里。
        final reason = switchSync.message;
        _err(
          reason == null || reason.isEmpty
              ? '积分抵扣开关同步失败，本次未开始接水'
              : '积分抵扣开关同步失败（$reason），本次未开始接水',
        );
        return;
      }

      // ptype=91（钱包支付）是唯一的开始请求类型：结算级联（积分 → 钱包
      // → 支付宝）由服务端执行，被拒时按错误码如实提示，不存在回退。
      final startedAt = DateTime.now();
      final result = await _apiService.startDrinking(
        deviceId: deviceId,
        ptype: DrinkApiService.walletPaymentType,
      );

      if (result.success) {
        isDrinking.value = true;
        _sessionStartedAt = startedAt;
        _startStatusCheck();
        _ok('开始接水');
      } else {
        _fail(result, fallback: '设备无响应，请检查设备状态');
      }
    } catch (e) {
      _err('操作失败');
    } finally {
      _starting = false;
    }
  }

  /// 结束接水
  Future<void> stopDrinking() async {
    if (currentDevice == null) return;
    final deviceId = currentDevice!.id;

    try {
      final result = await _apiService.stopDrinking(deviceId: deviceId);

      _statusTimer?.cancel();
      isDrinking.value = false;

      if (result.success) {
        _ok('已结算');
        // 结算已完成：先刷新余额，再等出账后上报消费明细。
        unawaited(_loadBalances());
        _startSettlementReport(deviceId);
      } else {
        _fail(result, fallback: '结算可能未成功，请检查');
      }
    } catch (e) {
      isDrinking.value = false;
      _statusTimer?.cancel();
    }
  }

  /// 结算上报：有界轮询账单列表，命中本次会话的账单后拉详情报三段金额。
  ///
  /// 出账有延迟且积分抵扣只在详情里（列表不含 promo），所以是
  /// 列表 → 详情两步。窗口耗尽或详情始终拿不到时静默结束——积分全额
  /// 抵扣的账单在列表里 payment 为零，只报列表会把 ¥0 误当全额，宁可不报。
  void _startSettlementReport(String deviceId) {
    // 读取即清除：会话起点只服务一次上报。预检「接管」的会话没有自己的
    // 起点，不得复用上一次会话的起点把他人账单算进来。
    final since = _sessionStartedAt;
    _sessionStartedAt = null;
    if (since == null) return;
    _reportTimer?.cancel();
    var attempts = 0;
    _reportTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_reporting) return;
      _reporting = true;
      attempts++;
      try {
        final bills = await _apiService.billList();
        final candidate = SettlementBillParser.latestFromList(
          bills,
          deviceId: deviceId,
          since: since,
        );
        if (candidate != null) {
          final bill = await _apiService.billDetail(billId: candidate.billId);
          final consumption = bill == null
              ? null
              : SettlementBillParser.fromDetail(bill, deviceId: deviceId);
          if (consumption != null) {
            timer.cancel();
            _reportTimer = null;
            _notice(_consumptionPrompt(consumption));
            await _loadBalances();
            return;
          }
        }
        if (attempts >= _maxReportAttempts) {
          timer.cancel();
          _reportTimer = null;
          await _loadBalances();
        }
      } catch (_) {
        if (attempts >= _maxReportAttempts) {
          timer.cancel();
          _reportTimer = null;
        }
      } finally {
        _reporting = false;
      }
    });
  }

  /// 消费明细的提示文案：无费用、积分抵扣、钱包支付三种信息按需出现。
  String _consumptionPrompt(SettlementConsumption consumption) {
    if (consumption.noCharge) return '本次未产生费用';
    final total = consumption.totalYuan.toStringAsFixed(2);
    if (consumption.scoreYuan <= 0) return '本次消费 ¥$total';
    final score = consumption.scoreYuan.toStringAsFixed(2);
    if (consumption.walletYuan <= 0) {
      return '本次消费 ¥$total（积分抵扣 ¥$score）';
    }
    final wallet = consumption.walletYuan.toStringAsFixed(2);
    return '本次消费 ¥$total（积分抵扣 ¥$score · 钱包支付 ¥$wallet）';
  }

  /// 按服务端返回码呈现失败原因。
  ///
  /// 登录态过期时引导重新登录，其他错误透出服务端信息；
  /// 都没有时退回 [fallback]，不再一律提示设备无响应。
  void _fail(DrinkResult result, {required String fallback}) {
    final prompt = drinkFailurePrompt(result, fallback: fallback);
    if (prompt.isSessionExpired) {
      Get.snackbar(
        prompt.title,
        prompt.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.warning,
        colorText: HomePromptColors.label,
      );
      return;
    }

    Get.snackbar(
      prompt.title,
      prompt.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: HomePromptColors.error,
      colorText: HomePromptColors.label,
    );
  }

  /// 开始状态检查
  ///
  /// 轮询设备状态：设备自动停水变成空闲后收起「接水中」。
  /// 连续 4 次空闲才收起——启动瞬间设备状态可能仍是空闲。
  /// 30 分钟上限防止异常情况下定时器长期驻留；轮询中登录过期则终止
  /// 轮询并引导重新登录，但不打断用户正在看的页面。
  void _startStatusCheck() {
    int idleCount = 0;
    final startedAt = DateTime.now();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (currentDevice == null) {
        timer.cancel();
        return;
      }
      if (DateTime.now().difference(startedAt) > const Duration(minutes: 30)) {
        timer.cancel();
        return;
      }

      try {
        final result = await _apiService.deviceStatus(
          deviceId: currentDevice!.id,
        );
        if (!result.success || result.status == null) return;

        final isAvailable = result.status!.isAvailable;
        if (isAvailable && idleCount > 3) {
          // 设备空闲，自动结算
          isDrinking.value = false;
          timer.cancel();
          // 非本人发起的会话没有会话起点，不做结算上报（见 _startSettlementReport）。
          _startSettlementReport(currentDevice!.id);
        } else if (isAvailable) {
          idleCount++;
        } else {
          idleCount = 0;
        }
      } catch (_) {
        // 单次轮询失败不打断：下一秒继续。
      }
    });
  }

  /// 扫码添加设备
  ///
  /// 二维码末段先经 `qr/use` 换取真实设备 ID（官方扫码入口走同一接口），
  /// 解析失败时回退二维码末段本身，尽量保持添加能力。
  Future<void> scanAndAddDevice() async {
    final result = await Get.to(() => const ScannerPage());

    if (result != null && result is String) {
      // 提取设备ID
      String deviceId = result;
      if (result.contains("/")) {
        deviceId = result.split("/").last;
      }

      try {
        final resolved = await _apiService.resolveQrDevice(qrId: deviceId);
        if (resolved.isNotEmpty) {
          deviceId = resolved;
        }

        final success = await _apiService.toggleFavoriteDevice(
          deviceId: deviceId,
          isRemove: false,
        );

        if (success) {
          _ok('设备添加成功');
          loadDevices();
        } else {
          Get.snackbar(
            '失败',
            '添加设备失败',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: HomePromptColors.error,
            colorText: HomePromptColors.label,
          );
        }
      } catch (e) {
        Get.snackbar(
          '错误',
          '添加设备时出错',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: HomePromptColors.error,
          colorText: HomePromptColors.label,
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
        await _saveDeviceOrder();
        _ok('已删除设备');
      }
    } catch (e) {
      _err('删除失败');
    }
  }

  /// 登出
  Future<void> logout() async {
    await AppController.to.logout();
  }

  void _err(String msg) => Get.snackbar(
        '错误',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.error,
        colorText: HomePromptColors.label,
      );

  void _notice(String msg) => Get.snackbar(
        '提示',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.notice,
        colorText: HomePromptColors.label,
      );

  void _ok(String msg) => Get.snackbar(
        '成功',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: HomePromptColors.success,
        colorText: HomePromptColors.label,
        duration: const Duration(seconds: 1),
      );
}
