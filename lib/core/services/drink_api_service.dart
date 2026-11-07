import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drink_api_signer.dart';

import '../models/account_balance.dart';
import '../models/device_status.dart';

/// 饮水操作的结果。
///
/// 携带服务端返回码与错误信息，使调用方能区分「登录已过期」
/// 「余额不足」「设备离线」等不同原因，而不是一律提示设备无响应。
class DrinkResult {
  const DrinkResult({
    required this.success,
    this.code,
    this.message,
  });

  /// 服务端返回码为 0 时为真。
  final bool success;

  /// 服务端返回码；网络异常等未取得响应时为 null。
  final int? code;

  /// 服务端返回的错误信息；成功时为 null。
  final String? message;

  /// 登录态过期。服务端以 -99 表示。
  bool get isSessionExpired => code == -99;
}

/// 设备状态查询的结果：[DrinkResult] 的返回码语义加一个解析出的
/// [DeviceStatus]。
class DeviceStatusResult {
  const DeviceStatusResult({
    required this.success,
    this.code,
    this.message,
    this.status,
  });

  final bool success;

  /// 服务端返回码；网络异常等未取得响应时为 null。
  final int? code;

  /// 服务端返回的错误信息；成功时为 null。
  final String? message;

  /// 解析出的设备状态；响应形状异常时为 null。
  final DeviceStatus? status;

  bool get isSessionExpired => code == -99;
}

/// 惠生活798 饮水API服务
class DrinkApiService {
  static final DrinkApiService _instance = DrinkApiService._internal();
  factory DrinkApiService() => _instance;

  DrinkApiService._internal() {
    _tokenInitialized = _initToken();
  }

  /// 仅供测试使用的生成式构造。
  ///
  /// 生产代码必须继续用 `DrinkApiService()` 取单例。之所以要新开一个构造：
  /// Dart 里工厂构造不能作为超类构造器，子类必须重定向到一个生成式构造，
  /// 否则 `extends DrinkApiService` 直接编译失败。
  ///
  /// Token 初始化照常走 [_initToken]（它本身吞掉所有异常），这样即使误用于
  /// 生产也只是拿到一个未登录的服务，不会像预完成 Future 那样带着空
  /// Authorization 请求、被设备列表判定过期并清掉已保存的 Token。
  @visibleForTesting
  DrinkApiService.test() {
    _tokenInitialized = _initToken();
  }

  // 请求头与官方客户端对齐：只发 VersionCode 与 User-Agent，
  // Authorization 由 _authOptions() 按请求注入。
  // 历史上还发送 ApplicationType、Accept、Accept-Encoding、Connection，
  // 逆向确认官方客户端不使用这些头，故移除。
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'VersionCode': _clientVersion,
        'User-Agent': 'Android_ilife798_$_clientVersion',
      },
    ),
  );
  final Map<String, dynamic> _token = {"uid": "", "eid": "", "token": ""};
  late final Future<void> _tokenInitialized;

  /// 替换底层 HTTP adapter，仅供测试注入。
  void setHttpClientAdapter(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }

  /// 支付类型。91 为钱包支付，21 为支付宝免密支付（与官方客户端运行时
  /// 取值一致，经上游项目实测）。旧值 0 来自静态逆向、支付语义未确证。
  static const int walletPaymentType = 91;

  /// 接水次数。官方默认值，集中定义便于按实测调整。
  static const int _drinkCount = 1;

  static const String _baseUrl = "https://i.ilife798.com/api/v1";
  static const String _clientVersion = "3.1.8";

  /// 登录请求使用的官方 iOS 客户端身份与 API 版本。
  static const String _loginUserAgent =
      "iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9";
  static const String _loginVersionCode = "3.1.9";
  static const String _tokenKey = "drink_water_app_token";
  static const String _loginKey = "drink_water_app_is_login";

  Future<Options> _authOptions() async {
    await _tokenInitialized;
    return Options(headers: {'Authorization': _token['token']});
  }

  /// 初始化Token
  ///
  /// 本地存储损坏时保持未登录状态，不能让 [_tokenInitialized]
  /// 变成失败 Future 拖垮所有认证请求。
  Future<void> _initToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? tokenStr = prefs.getString(_tokenKey);
      if (tokenStr != null) {
        final map = jsonDecode(tokenStr);
        if (map is! Map) {
          // 不是 JSON 对象：清掉坏数据，等待重新登录覆盖
          await prefs.remove(_tokenKey);
          return;
        }
        map.forEach((key, value) {
          _token[key] = value;
        });
      }
    } catch (_) {
      // jsonDecode 失败等异常按未登录处理，坏数据会在下次登录时被覆盖
    }
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    await _tokenInitialized;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_loginKey) ?? false) &&
        (_token["token"] as String).isNotEmpty;
  }

  /// 获取图形验证码
  Future<Uint8List> getCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) async {
    Options options = Options(responseType: ResponseType.bytes);
    String url = "$_baseUrl/captcha/";
    Map<String, dynamic> params = {"s": doubleRandom, "r": timestamp};
    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data;
  }

  /// 发送短信验证码
  ///
  /// 与 [login] 一样区分「服务端拒绝」和「请求未完成」，避免把网络异常
  /// 说成「图形验证码错误」。
  Future<DrinkResult> sendSmsCode({
    required String doubleRandom,
    required String captcha,
    required String phone,
  }) async {
    Map<String, dynamic> data = {
      "s": doubleRandom,
      "authCode": captcha,
      "un": phone,
    };
    // 验证码下发接口不附加签名（官方实测形状）；只有 acc/login 需要签名。
    const url = "$_baseUrl/acc/login/code";

    try {
      final response = await _dio.post(url, data: data);
      final result = response.data;
      if (result is! Map) {
        return const DrinkResult(success: false, message: '服务端返回格式异常');
      }
      if (result['code'] == 0) {
        return const DrinkResult(success: true, code: 0);
      }
      final message = result['msg'];
      return DrinkResult(
        success: false,
        code: result['code'] is int ? result['code'] : null,
        message: message is String && message.isNotEmpty ? message : '发送失败',
      );
    } on DioException catch (e) {
      return DrinkResult(success: false, message: '网络错误：${e.message}');
    } catch (e) {
      return DrinkResult(success: false, message: '请求失败：$e');
    }
  }

  /// 登录
  ///
  /// 返回值区分三种失败，避免把解析失败或网络异常一律说成「验证码错误」：
  /// - [DrinkResult.success] 为真：登录成功
  /// - [DrinkResult.code] 非 null：服务端明确拒绝，[DrinkResult.message] 是其原因
  /// - [DrinkResult.code] 为 null：请求未完成或响应无法解析，[DrinkResult.message]
  ///   为具体的技术原因
  Future<DrinkResult> login({
    required String phone,
    required String smsCode,
  }) async {
    // 参数集与官方一致：只发 un、authCode；这两个参数同时参与登录签名。
    // 曾多传 cid/openCode，它们会改变签名覆盖的参数集，服务端返回「验签失败」。
    final Map<String, dynamic> data = {
      "authCode": smsCode,
      "un": phone,
    };

    // 服务端对 acc/login 强制验签：签名缺失或错误返回「请升级最新版应用」。
    // 登录请求单独使用官方 iOS 身份；其余请求仍用全局 Android 3.1.8 身份。
    final sign = DrinkApiSigner.loginSign(data);
    final url = "$_baseUrl/acc/login?sign=$sign";
    final options = Options(headers: {
      "User-Agent": _loginUserAgent,
      "VersionCode": _loginVersionCode,
    });

    try {
      final response = await _dio.post(url, data: data, options: options);
      final result = response.data;

      if (result is! Map) {
        return const DrinkResult(
          success: false,
          message: '服务端返回格式异常',
        );
      }

      final code = result['code'];
      if (code != 0) {
        final message = result['msg'];
        return DrinkResult(
          success: false,
          code: code is int ? code : null,
          message: message is String && message.isNotEmpty ? message : '登录被拒绝',
        );
      }

      // code == 0 即登录成功。凭据字段缺失属于响应形状问题，
      // 不能反过来说成「验证码错误」——那会掩盖真实故障。
      final payload = result['data'];
      final account = payload is Map ? payload['al'] : null;
      if (account is! Map) {
        return const DrinkResult(
          success: false,
          message: '登录已被接受，但响应缺少账号信息，请反馈此问题',
        );
      }

      await _saveLoginToken({
        "uid": account['uid'] ?? "",
        "eid": account['eid'] ?? "",
        "token": account['token'] ?? "",
      });
      return const DrinkResult(success: true, code: 0);
    } on DioException catch (e) {
      return DrinkResult(success: false, message: '网络错误：${e.message}');
    } catch (e) {
      return DrinkResult(success: false, message: '解析响应失败：$e');
    }
  }

  /// 使用已有 Token 登录。先向服务端校验，避免保存已过期或无效的 Token。
  Future<bool> loginWithToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) return false;

    try {
      final response = await _dio.get(
        "$_baseUrl/ui/app/master",
        options: Options(headers: {"Authorization": normalizedToken}),
      );
      final data = response.data;
      if (data is! Map ||
          data['code'] != 0 ||
          data['data'] is! Map ||
          data['data']['account'] == null) {
        return false;
      }

      await _saveLoginToken({"uid": "", "eid": "", "token": normalizedToken});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveLoginToken(Map<String, dynamic> tokenData) async {
    // 防止启动时尚未读完旧 Token，随后覆盖刚保存的新 Token。
    await _tokenInitialized;
    _token["uid"] = tokenData["uid"] ?? "";
    _token["eid"] = tokenData["eid"] ?? "";
    _token["token"] = tokenData["token"] ?? "";

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(_token));
    await prefs.setBool(_loginKey, true);
  }

  /// 登出
  Future<void> logout() async {
    await _tokenInitialized;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginKey, false);
    await prefs.remove(_tokenKey);
    _token["uid"] = "";
    _token["eid"] = "";
    _token["token"] = "";
  }

  /// 获取设备列表
  Future<List<Map<String, dynamic>>> getDeviceList() async {
    String url = "$_baseUrl/ui/app/master";
    Options options = await _authOptions();

    try {
      Response response = await _dio.get(url, options: options);
      final result = response.data;
      
      if (result["data"]["account"] == null) {
        // Token 失效
        await logout();
        return [{"id": "error", "name": "登录已过期"}];
      }

      if (result["data"]["favos"] == null) {
        return [];
      }

      final List favos = result["data"]["favos"];
      return favos
          .map<Map<String, dynamic>>((e) => {
                "id": e["id"].toString(),
                "name": e["name"].toString(),
              })
          .toList()
          .reversed
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 收藏/取消收藏设备
  ///
  /// `remove` 以 1/0 上线（与官方一致，上游实测形状）；
  /// 布尔 true/false 的形式未实测过。
  Future<bool> toggleFavoriteDevice({
    required String deviceId,
    required bool isRemove,
  }) async {
    String url = "$_baseUrl/dev/favo";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId, "remove": isRemove ? 1 : 0};

    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      return response.data["code"] == 0;
    } catch (e) {
      return false;
    }
  }

  /// 开始接水
  ///
  /// [ptype] 缺省为钱包支付（91），它是唯一的开始请求类型；被拒时
  /// 调用方按错误码如实提示，不存在改用其他支付方式的重试。
  Future<DrinkResult> startDrinking({
    required String deviceId,
    int ptype = walletPaymentType,
  }) async {
    String url = "$_baseUrl/dev/start";
    Options options = await _authOptions();

    // 业务参数对齐官方：did、upgrade、ptype、args、rcp、cnt。
    // args 对饮水设备为空串（官方仅在洗衣机、吹风机、触碰开锁三类设备填 JSON）。
    Map<String, dynamic> params = {
      "did": deviceId,
      "upgrade": true,
      "ptype": ptype,
      "args": "",
      "rcp": false,
      "cnt": _drinkCount,
    };


    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      return _toResult(response.data);
    } catch (e) {
      return const DrinkResult(success: false);
    }
  }

  /// 同步账户级积分抵扣开关。
  ///
  /// 服务端结算级联（积分 → 钱包 → 支付宝）只有在账户开关 useScore
  /// 开启时才扣积分；官方 App 在设备支付页提供「开启自动抵扣」开关，
  /// 参考客户端 ilife798 在每次启动设备前以 `POST acc/upt
  /// {"useScore":1}` 同步。与所有非登录请求一致：不签名、不带
  /// ApplicationType（官方 iOS 客户端不发送该头）。
  Future<DrinkResult> setUseScore({int value = 1}) async {
    String url = "$_baseUrl/acc/upt";
    Options options = await _authOptions();

    try {
      Response response = await _dio.post(
        url,
        data: {"useScore": value},
        options: options,
      );
      return _toResult(response.data);
    } catch (e) {
      return const DrinkResult(success: false);
    }
  }

  /// 结束接水
  ///
  /// `rcp=false` 与官方客户端一致（上游实测形状）。
  Future<DrinkResult> stopDrinking({required String deviceId}) async {
    String url = "$_baseUrl/dev/end";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId, "rcp": false};

    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      return _toResult(response.data);
    } catch (e) {
      return const DrinkResult(success: false);
    }
  }

  /// 把服务端响应转为 [DrinkResult]。
  ///
  /// 响应形状为 `{"code": <int>, "msg": <string>}`。
  DrinkResult _toResult(dynamic data) {
    if (data is! Map) {
      return const DrinkResult(success: false);
    }
    final code = data['code'];
    final message = data['msg'];
    return DrinkResult(
      success: code == 0,
      code: code is int ? code : null,
      message: message is String && message.isNotEmpty ? message : null,
    );
  }

  /// 检查设备状态
  ///
  /// 出错时按“仍在使用”处理（返回 false），避免网络抖动导致提前自动结算。
  Future<bool> isDeviceAvailable({required String deviceId}) async {
    final result = await deviceStatus(deviceId: deviceId);
    if (!result.success || result.status == null) return false;
    return result.status!.isAvailable;
  }

  /// 查询设备状态并解析为 [DeviceStatus]。
  ///
  /// 请求形状对齐官方客户端：`did` + `more=false`，不带 `promo`、
  /// 不带 `sign`（上游实测形状）。
  Future<DeviceStatusResult> deviceStatus({required String deviceId}) async {
    String url = "$_baseUrl/ui/app/dev/status";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId, "more": false};

    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      final data = response.data;
      if (data is! Map || data['code'] != 0) {
        final code = data is Map && data['code'] is int ? data['code'] : null;
        final message = data is Map && data['msg'] is String ? data['msg'] : null;
        return DeviceStatusResult(
          success: false,
          code: code,
          message: message,
        );
      }
      return DeviceStatusResult(
        success: true,
        code: 0,
        status: DeviceStatus.fromJson(data['data']),
      );
    } catch (e) {
      return const DeviceStatusResult(success: false);
    }
  }

  /// 扫码解析设备：用二维码末段换取真实设备 ID（`qr/use`）。
  ///
  /// 返回解析出的设备 ID；无法解析时为空串，调用方可回退二维码末段。
  /// [qrId] 为空时直接返回空串，不发起请求。
  Future<String> resolveQrDevice({required String qrId}) async {
    if (qrId.isEmpty) return '';

    String url = "$_baseUrl/qr/use";
    Options options = await _authOptions();

    try {
      Response response = await _dio.get(
        url,
        queryParameters: {"id": qrId},
        options: options,
      );
      final data = response.data;
      if (data is! Map || data['code'] != 0) return '';
      final payload = data['data'];
      final dev = payload is Map ? payload['dev'] : null;
      if (dev is! Map) return '';
      return dev['id']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 查询账户余额：钱包（`/acc/wallet/owner`）与积分（`/acc/score/acc-score`）。
  ///
  /// 两个接口并行请求，形状对照 life-798 已核验实现（无签名、仅
  /// Authorization）。未登录不发请求；某侧失败该侧为 null，全部失败
  /// 返回 null。解析失败不抛错。
  Future<AccountBalance?> accountBalance() async {
    if (!await isLoggedIn()) return null;
    final walletFuture = _fetchWalletYuan();
    final scoreFuture = _fetchScore();
    final walletYuan = await walletFuture;
    final score = await scoreFuture;
    final balance = AccountBalance(walletYuan: walletYuan, score: score);
    if (balance.walletYuan == null && balance.score == null) return null;
    return balance;
  }

  Future<double?> _fetchWalletYuan() async {
    try {
      Response response = await _dio.get(
        "$_baseUrl/acc/wallet/owner",
        options: await _authOptions(),
      );
      final data = _successData(response.data);
      if (data == null) return null;
      return _parseWalletYuan(data, endpointId: _token["eid"]?.toString());
    } catch (_) {
      return null;
    }
  }

  Future<int?> _fetchScore() async {
    try {
      Response response = await _dio.get(
        "$_baseUrl/acc/score/acc-score",
        options: await _authOptions(),
      );
      final data = _successData(response.data);
      if (data == null) return null;
      final score = data['validScore'];
      // 服务端可能把整数积分发成 JSON double（4200.0），一并接受。
      return score is num ? score.toInt() : int.tryParse('$score');
    } catch (_) {
      return null;
    }
  }

  /// 钱包余额：优先取端点 ID 匹配账户 eid 的唯一条目，否则仅当
  /// 全部条目唯一时取那一条；无法唯一判定时不猜测，返回 null。
  ///
  /// 服务端形状为 `data.aw`（主钱包）与 `data.eps[]`（分端点钱包），
  /// 各条目带 `id`（端点）与 `balance`（元）。对照 life-798
  /// `WalletResponseParser.dashboardBalance` 的已核验语义。
  double? _parseWalletYuan(Map<dynamic, dynamic> data, {String? endpointId}) {
    final entries = <Map<dynamic, dynamic>>[
      if (data['aw'] is Map) data['aw'] as Map<dynamic, dynamic>,
      if (data['eps'] is List)
        ...(data['eps'] as List).whereType<Map<dynamic, dynamic>>(),
    ];
    double? balanceOf(Map<dynamic, dynamic> entry) {
      final value = entry['balance'];
      return value is num ? value.toDouble() : null;
    }
    if (endpointId != null && endpointId.isNotEmpty) {
      final matched = entries
          .where((entry) => entry['id']?.toString() == endpointId)
          .toList();
      if (matched.length == 1) return balanceOf(matched.single);
    }
    if (entries.length == 1) return balanceOf(entries.single);
    return null;
  }

  /// 账单列表：最近一页结算记录（`/bill/lst-owner`）。
  ///
  /// 请求失败或形状异常返回空列表，由调用方按「暂未出账」处理。
  Future<List<Map<String, dynamic>>> billList() async {
    try {
      Response response = await _dio.get(
        "$_baseUrl/bill/lst-owner",
        queryParameters: const {"page": 0, "size": 20},
        options: await _authOptions(),
      );
      final data = _successData(response.data);
      if (data == null) return const [];
      final records = data['records'] ?? data['items'] ?? data['list'];
      if (records is! List) return const [];
      return records.whereType<Map>().map(_stringKeyMap).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 账单详情（`/bill/view-full`），积分抵扣只在这里的 promo 里。
  ///
  /// 失败或形状异常返回 null。
  Future<Map<String, dynamic>?> billDetail({required String billId}) async {
    try {
      Response response = await _dio.get(
        "$_baseUrl/bill/view-full",
        queryParameters: {"id": billId},
        options: await _authOptions(),
      );
      final data = _successData(response.data);
      final bill = data?['bill'];
      return bill is Map ? _stringKeyMap(bill) : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _successData(dynamic body) {
    if (body is! Map || body['code'] != 0) return null;
    final data = body['data'];
    return data is Map ? _stringKeyMap(data) : null;
  }

  Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> value) =>
      value.map((key, value) => MapEntry('$key', value));
}
