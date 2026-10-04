import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 惠生活798 饮水API服务
class DrinkApiService {
  static final DrinkApiService _instance = DrinkApiService._internal();
  factory DrinkApiService() => _instance;

  DrinkApiService._internal() {
    _tokenInitialized = _initToken();
  }

  // 使用参考脚本中 App (ApplicationType 1,1) 的请求头。
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'ApplicationType': '1,1',
        'VersionCode': '3.1.7',
        'User-Agent': 'Android_ilife798_3.1.7',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip',
        'Connection': 'Keep-Alive',
      },
    ),
  );
  final Map<String, dynamic> _token = {"uid": "", "eid": "", "token": ""};
  late final Future<void> _tokenInitialized;

  static const String _baseUrl = "https://i.ilife798.com/api/v1";
  static const String _tokenKey = "drink_water_app_token";
  static const String _loginKey = "drink_water_app_is_login";

  Future<Options> _authOptions() async {
    await _tokenInitialized;
    return Options(headers: {'Authorization': _token['token']});
  }

  /// 初始化Token
  Future<void> _initToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? tokenStr = prefs.getString(_tokenKey);
    if (tokenStr != null) {
      Map<String, dynamic> map = jsonDecode(tokenStr);
      map.forEach((key, value) {
        _token[key] = value;
      });
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
  Future<bool> sendSmsCode({
    required String doubleRandom,
    required String captcha,
    required String phone,
  }) async {
    String url = "$_baseUrl/acc/login/code";
    Map<String, dynamic> data = {
      "s": doubleRandom,
      "authCode": captcha,
      "un": phone,
    };
    Response response = await _dio.post(url, data: data);
    return response.data["code"] == 0;
  }

  /// 登录
  Future<bool> login({
    required String phone,
    required String smsCode,
  }) async {
    String url = "$_baseUrl/acc/login";
    Map<String, dynamic> data = {
      "openCode": "",
      "authCode": smsCode,
      "un": phone,
      "cid": "drinkwaterapp123456789",
    };
    
    try {
      Response response = await _dio.post(url, data: data);
      final result = response.data;
      
      if (result["code"] == 0) {
        await _saveLoginToken({
          "uid": result["data"]["al"]["uid"],
          "eid": result["data"]["al"]["eid"],
          "token": result["data"]["al"]["token"],
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
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
  Future<bool> startDrinking({required String deviceId}) async {
    String url = "$_baseUrl/dev/start";
    Options options = await _authOptions();

    Map<String, dynamic> params = {
      "did": deviceId,
      "upgrade": true,
      "rcp": false,
      "stype": 5,
    };

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

  /// 结束接水
  Future<bool> stopDrinking({required String deviceId}) async {
    String url = "$_baseUrl/dev/end";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": deviceId};

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
