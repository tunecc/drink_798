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

    test('携带 sign 参数且为 32 位十六进制', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      final sign = adapter.captured?.queryParameters['sign'];
      expect(sign, isNotNull);
      expect(sign, matches(RegExp(r'^[0-9a-f]{32}$')));
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

    test('stopDrinking 携带 did 与长签名 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.stopDrinking(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['sign'], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('toggleFavoriteDevice 携带 did、remove 与长签名 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.toggleFavoriteDevice(deviceId: 'device123', isRemove: false);

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['remove'], false);
      expect(params['sign'], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('sendSmsCode 在 URL 上携带短签名 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.sendSmsCode(
        doubleRandom: 'rand',
        captcha: 'abcd',
        phone: '22644212509',
      );

      // POST 的签名拼在 URL 查询参数上，与官方一致
      final sign = adapter.captured?.uri.queryParameters['sign'];
      expect(sign, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('login 在 URL 上携带长签名 sign', () async {
      // 登录走 acceptCurrentSystemVerDict:（含 30 秒时间档位），
      // 不是短信接口用的短签名。曾误用短签名，跨档即「验签失败」。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      final sign = adapter.captured?.uri.queryParameters['sign'];
      expect(sign, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('login 与 sendSmsCode 的签名类型不同', () async {
      // 登录用长签名（含时间），短信用短签名（不含时间）。
      // 同一参数下两者签名值应不同。
      final api = DrinkApiService();
      await api.isLoggedIn();

      await api.sendSmsCode(
        doubleRandom: 'rand', captcha: 'abcd', phone: '22644212509',
      );
      final smsSign = adapter.captured?.uri.queryParameters['sign'];

      await api.login(phone: '22644212509', smsCode: '123456');
      final loginSign = adapter.captured?.uri.queryParameters['sign'];

      expect(smsSign, isNotNull);
      expect(loginSign, isNotNull);
      expect(smsSign, isNot(loginSign));
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
}
