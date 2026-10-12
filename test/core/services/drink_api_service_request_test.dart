import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/services/drink_api_service.dart';

/// 捕获请求参数与 URL 的测试 adapter。
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? captured;
  String responseBody = '{"code":0,"data":{}}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrinkApiService.startDrinking 请求形状', () {
    late _CapturingAdapter adapter;

    setUp(() {
      adapter = _CapturingAdapter();
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token':
            '{"uid":"87654321abcdefgh","eid":"e1","token":"abcdefgh12345678"}',
        'drink_water_app_is_login': true,
      });
      DrinkApiService().setHttpClientAdapter(adapter);
    });

    test('发送六个业务参数且不含 stype', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['upgrade'], true);
      expect(params['ptype'], 0);
      expect(params['args'], '');
      expect(params['rcp'], false);
      expect(params['cnt'], 1);
      expect(params.containsKey('stype'), isFalse);
    });

    test('startDrinking 不带 sign', () async {
      // 实测服务端不校验该接口签名：不带 sign 返回 code:0，
      // 带上按官方算法算出的 sign 反而返回「验签失败」。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      expect(adapter.captured?.queryParameters.containsKey('sign'), isFalse);
    });

    test('URL 中布尔参数序列化为 true/false', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      final query = adapter.captured?.queryParameters;
      expect(query, isNotNull);
      // dio 保留原始类型，但签名序列化会转写为小写 true/false；
      // 这里断言签名输入与 dio 输出在语义上一致。
      expect(query!['upgrade'].toString(), 'true');
      expect(query['rcp'].toString(), 'false');
    });

    test('请求头只含 VersionCode 与 User-Agent，登录后加 Authorization', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      final headers = adapter.captured?.headers;
      expect(headers, isNotNull);
      expect(headers!.containsKey('VersionCode'), isTrue);
      expect(headers.containsKey('User-Agent'), isTrue);
      expect(headers.containsKey('Authorization'), isTrue);
      expect(headers.containsKey('ApplicationType'), isFalse);
      expect(headers.containsKey('Accept-Encoding'), isFalse);
      expect(headers.containsKey('Connection'), isFalse);
    });
  });

  group('DrinkApiService 其他接口签名', () {
    late _CapturingAdapter adapter;

    setUp(() {
      adapter = _CapturingAdapter();
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token':
            '{"uid":"87654321abcdefgh","eid":"e1","token":"abcdefgh12345678"}',
        'drink_water_app_is_login': true,
      });
      DrinkApiService().setHttpClientAdapter(adapter);
    });

    test('stopDrinking 携带 did 且不带 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.stopDrinking(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params.containsKey('sign'), isFalse);
    });

    test('toggleFavoriteDevice 携带 did、remove 且不带 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.toggleFavoriteDevice(deviceId: 'device123', isRemove: false);

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['remove'], false);
      expect(params.containsKey('sign'), isFalse);
    });

    test('sendSmsCode 不带 sign', () async {
      // 该接口不校验签名，见 login 测试内的说明。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.sendSmsCode(
        doubleRandom: 'rand',
        captcha: 'abcd',
        phone: '22644212509',
      );

      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isFalse);
    });

    test('login 不带 sign', () async {
      // acc/login 不校验签名。实测同一种 authCode：不带 sign、带空 sign、
      // 带错误 sign 服务端均返回「短信验证码错误」；带上按官方算法算出的
      // sign 反而返回「验签失败」。逆向之前本项目不带签名即可登录。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isFalse);
    });

    test('login 与 sendSmsCode 都不带 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();

      await api.sendSmsCode(
        doubleRandom: 'rand', captcha: 'abcd', phone: '22644212509',
      );
      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isFalse);

      await api.login(phone: '22644212509', smsCode: '123456');
      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isFalse);
    });

    test('login 参数集不含 cid', () async {
      // 曾多传 cid，官方不发送该参数。cid 参与签名计算，
      // 导致服务端返回「验签失败」(code -1)，登录永远无法成功。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      final body = adapter.captured?.data;
      expect(body, isNotNull);
      final text = body is String ? body : '$body';
      expect(text, isNot(contains('cid')));
      expect(text, contains('un'));
      expect(text, contains('authCode'));
    });
  });

  group('DrinkApiService.login 失败分类', () {
    late _CapturingAdapter adapter;

    setUp(() {
      adapter = _CapturingAdapter();
      SharedPreferences.setMockInitialValues({});
      DrinkApiService().setHttpClientAdapter(adapter);
    });

    test('服务端拒绝时透出 code 与 msg', () async {
      adapter.responseBody = '{"code":-1,"msg":"短信验证码错误"}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.login(phone: '22644212509', smsCode: '000000');

      expect(result.success, isFalse);
      expect(result.code, -1);
      expect(result.message, '短信验证码错误');
    });

    test('登录被接受但缺少账号信息时不说成验证码错误', () async {
      // 曾在此处抛异常并被 catch 吞掉，用户看到误导性的「验证码错误或已过期」。
      adapter.responseBody = '{"code":0,"data":{"foo":"bar"}}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.login(phone: '22644212509', smsCode: '123456');

      expect(result.success, isFalse);
      expect(result.message, isNot(contains('验证码')));
      expect(result.message, contains('账号信息'));
    });

    test('登录成功时返回 success 且无错误信息', () async {
      adapter.responseBody =
          '{"code":0,"data":{"al":{"uid":"u1","eid":"e1","token":"t1"}}}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.login(phone: '22644212509', smsCode: '123456');

      expect(result.success, isTrue);
      expect(result.code, 0);
      expect(result.message, isNull);
    });

    test('响应不是 JSON 对象时给出技术原因', () async {
      adapter.responseBody = 'not json at all';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.login(phone: '22644212509', smsCode: '123456');

      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(result.message, isNotNull);
      expect(result.message, isNot(contains('验证码')));
    });
  });

  group('DrinkApiService 错误信息透出', () {
    late _CapturingAdapter adapter;

    setUp(() {
      adapter = _CapturingAdapter();
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token':
            '{"uid":"87654321abcdefgh","eid":"e1","token":"abcdefgh12345678"}',
        'drink_water_app_is_login': true,
      });
      DrinkApiService().setHttpClientAdapter(adapter);
    });

    test('code != 0 时携带服务端 msg 与 code', () async {
      adapter.responseBody = '{"code":-99,"msg":"登录状态已过期"}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.startDrinking(deviceId: 'device123');

      expect(result.success, isFalse);
      expect(result.code, -99);
      expect(result.message, '登录状态已过期');
    });

    test('code == 0 时 success 为真且无错误信息', () async {
      adapter.responseBody = '{"code":0,"data":{}}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.startDrinking(deviceId: 'device123');

      expect(result.success, isTrue);
      expect(result.code, 0);
      expect(result.message, isNull);
    });

    test('stopDrinking 同样透出服务端错误信息', () async {
      adapter.responseBody = '{"code":-100,"msg":"系统错误"}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.stopDrinking(deviceId: 'device123');

      expect(result.success, isFalse);
      expect(result.code, -100);
      expect(result.message, '系统错误');
    });

    test('login 不受本地残留 token 影响', () async {
      // 登录请求不带 sign，残留 token 无从影响它。
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token':
            '{"uid":"87654321abcdefgh","eid":"e1","token":"abcdefgh12345678"}',
        'drink_water_app_is_login': true,
      });

      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isFalse);
    });
  });
}
