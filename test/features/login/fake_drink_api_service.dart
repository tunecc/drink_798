import 'dart:async';
import 'dart:typed_data';

import 'package:drink_water_app/core/services/drink_api_service.dart';

/// 1×1 透明 PNG，够让 Image.memory 完成解码且不依赖网络。
/// chunk 结构与 CRC 已逐段校验，改动这里请先确认仍能解码。
final Uint8List kTestPngBytes = Uint8List.fromList(const <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
  0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 2, 0, 0,
  5, 0, 1, 122, 94, 171, 63, 0, 0, 0, 0, 73, 69, 78, 68, 174,
  66, 96, 130,
]);

/// 登录页 widget 测试使用的 API 替身：不发包，只记录调用。
///
/// 超类构造必须写 `DrinkApiService.test()`：唯一的无参生成式构造是它，
/// `DrinkApiService()` 是工厂构造，Dart 不接受它作为超类构造器。
class FakeDrinkApiService extends DrinkApiService {
  FakeDrinkApiService({
    this.smsCodeResult = const DrinkResult(success: true, code: 0),
    this.loginResult = const DrinkResult(success: true, code: 0),
    this.tokenLoginResult = true,
  }) : super.test();

  int captchaCalls = 0;
  int sendSmsCodeCalls = 0;
  int loginCalls = 0;
  int tokenLoginCalls = 0;

  final DrinkResult smsCodeResult;
  final DrinkResult loginResult;
  final bool tokenLoginResult;

  String? lastCaptcha;
  String? lastPhone;
  String? lastSmsCode;

  @override
  Future<Uint8List> getCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) async {
    captchaCalls++;
    return kTestPngBytes;
  }

  @override
  Future<DrinkResult> sendSmsCode({
    required String doubleRandom,
    required String captcha,
    required String phone,
  }) async {
    sendSmsCodeCalls++;
    lastCaptcha = captcha;
    lastPhone = phone;
    return smsCodeResult;
  }

  @override
  Future<DrinkResult> login({
    required String phone,
    required String smsCode,
  }) async {
    loginCalls++;
    lastPhone = phone;
    lastSmsCode = smsCode;
    return loginResult;
  }

  @override
  Future<bool> loginWithToken(String token) async {
    tokenLoginCalls++;
    return tokenLoginResult;
  }
}

/// 验证码请求一直挂起的替身，用于断言"图片未返回"这一中间态。
class HangingCaptchaApiService extends FakeDrinkApiService {
  final Completer<Uint8List> _gate = Completer<Uint8List>();

  @override
  Future<Uint8List> getCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) => _gate.future;
}
