import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';


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

/// 惠生活798 饮水API服务
class DrinkApiService {
  static final DrinkApiService _instance = DrinkApiService._internal();
  factory DrinkApiService() => _instance;

  DrinkApiService._internal() {
    _tokenInitialized = _initToken();
  }

  // 请求头与官方客户端对齐：只发 VersionCode 与 User-Agent，
  // Authorization 由 _authOptions() 按请求注入。
  // 历史上还发送 ApplicationType、Accept、Accept-Encoding、Connection，
  // 逆向确认官方客户端不使用这些头，服务端也不校验，故移除。
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

  /// 支付类型。官方默认值，集中定义便于按实测调整。
  static const int _paymentType = 0;

  /// 接水次数。官方默认值，集中定义便于按实测调整。
  static const int _drinkCount = 1;

  static const String _baseUrl = "https://i.ilife798.com/api/v1";
  static const String _clientVersion = "3.1.8";
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
    // 与 acc/login 一致：该接口不校验签名，见 login() 内的说明。
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
    // 参数集与官方一致：openCode、un、authCode。
    // 曾多传 cid，官方不发送该参数；它参与签名计算导致服务端返回
    // 「验签失败」(code -1)，登录永远无法成功。
    Map<String, dynamic> data = {
      "openCode": "",
      "authCode": smsCode,
      "un": phone,
    };

    // acc/login 不校验签名。实测同一种 authCode：不带 sign、带空 sign、
    // 带错误 sign，服务端均返回「短信验证码错误」；而带上按官方算法算出
    // 的 sign 反而返回「验签失败」。逆向之前本项目不带签名即可登录。
    // 设备接口（dev/start 等）仍需要签名，见各方法内的 longSign 调用。
    const url = "$_baseUrl/acc/login";

    try {
      final response = await _dio.post(url, data: data);
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
  Future<bool> toggleFavoriteDevice({
    required String deviceId,
    required bool isRemove,
  }) async {
    String url = "$_baseUrl/dev/favo";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId, "remove": isRemove};

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
  Future<DrinkResult> startDrinking({required String deviceId}) async {
    String url = "$_baseUrl/dev/start";
    Options options = await _authOptions();

    // 业务参数对齐官方：did、upgrade、ptype、args、rcp、cnt。
    // args 对饮水设备为空串（官方仅在洗衣机、吹风机、触碰开锁三类设备填 JSON）。
    Map<String, dynamic> params = {
      "did": deviceId,
      "upgrade": true,
      "ptype": _paymentType,
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

  /// 结束接水
  Future<DrinkResult> stopDrinking({required String deviceId}) async {
    String url = "$_baseUrl/dev/end";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId};

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
  Future<bool> isDeviceAvailable({required String deviceId}) async {
    String url = "$_baseUrl/ui/app/dev/status";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId, "more": true, "promo": false};

    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      return response.data["data"]["device"]["gene"]["status"] == 99;
    } catch (e) {
      // 出错时按“仍在使用”处理，避免网络抖动导致提前自动结算
      return false;
    }
  }
}
