import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/services/drink_api_service.dart';
import 'package:drink_water_app/core/services/drink_api_signer.dart';

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

/// 直接抛出网络异常的测试 adapter。
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'boom',
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
      // ptype 对齐上游实测：91 为钱包支付，21 为支付宝免密。
      // 本项目旧值 0 来自静态逆向、语义未确证；91/21 来自上游运行时取值。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['upgrade'], true);
      expect(params['ptype'], 91);
      expect(params['args'], '');
      expect(params['rcp'], false);
      expect(params['cnt'], 1);
      expect(params.containsKey('stype'), isFalse);
    });

    test('显式传入 ptype 时按传入值发送', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.startDrinking(deviceId: 'device123', ptype: 21);

      expect(adapter.captured?.queryParameters['ptype'], 21);
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

  group('DrinkApiService.setUseScore 请求形状', () {
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

    test('POST acc/upt 且 body 恰为 {"useScore":1}', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.setUseScore();

      expect(adapter.captured?.method, 'POST');
      expect(adapter.captured?.uri.path, '/api/v1/acc/upt');
      expect(adapter.captured?.data, {'useScore': 1});
    });

    test(
      '携带 Authorization 与 application/json,不带 ApplicationType 与 sign',
      () async {
        final api = DrinkApiService();
        await api.isLoggedIn();
        await api.setUseScore();

        final headers = adapter.captured?.headers;
        expect(headers?['Authorization'], 'abcdefgh12345678');
        expect(adapter.captured?.contentType, contains('application/json'));
        expect(headers?.containsKey('ApplicationType'), isFalse);
        expect((adapter.captured?.data as Map).containsKey('sign'), isFalse);
      },
    );

    test('服务端非零 code 返回失败结果', () async {
      adapter.responseBody = '{"code":-98,"msg":"操作频繁"}';
      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.setUseScore();

      expect(result.success, isFalse);
      expect(result.code, -98);
      expect(result.message, '操作频繁');
    });

    test('网络异常返回失败结果', () async {
      DrinkApiService().setHttpClientAdapter(_ThrowingAdapter());
      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.setUseScore();

      expect(result.success, isFalse);
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

    test('stopDrinking 携带 did 与 rcp 且不带 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.stopDrinking(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      expect(params['rcp'], false);
      expect(params.containsKey('sign'), isFalse);
    });

    test('toggleFavoriteDevice 携带 did、remove 且不带 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.toggleFavoriteDevice(deviceId: 'device123', isRemove: false);

      final params = adapter.captured?.queryParameters;
      expect(params, isNotNull);
      expect(params!['did'], 'device123');
      // remove 以 1/0 上线，与官方(false=0)一致；旧的 true/false 上线未实测。
      expect(params['remove'], 0);
      expect(params.containsKey('sign'), isFalse);
    });

    test('sendSmsCode 不带 sign', () async {
      // 验证码下发接口不附加签名（官方实测形状）；登录接口才需要签名。
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.sendSmsCode(
        doubleRandom: 'rand',
        captcha: 'abcd',
        phone: '22644212509',
      );

      expect(
        adapter.captured?.uri.queryParameters.containsKey('sign'),
        isFalse,
      );
    });

    test('login 使用官方签名与 iOS 身份', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      final options = adapter.captured!;
      expect(options.uri.path, '/api/v1/acc/login');
      expect(
        options.uri.queryParameters['sign'],
        DrinkApiSigner.loginSign({'authCode': '123456', 'un': '22644212509'}),
      );
      expect(
        options.headers['User-Agent'],
        'iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9',
      );
      expect(options.headers['VersionCode'], '3.1.9');
      expect(options.headers.containsKey('ApplicationType'), isFalse);
      expect((options.data as Map).keys.toSet(), {'authCode', 'un'});
    });

    test('login 带签名而 sendSmsCode 不带签名', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();

      await api.sendSmsCode(
        doubleRandom: 'rand',
        captcha: 'abcd',
        phone: '22644212509',
      );
      expect(
        adapter.captured?.uri.queryParameters.containsKey('sign'),
        isFalse,
      );

      await api.login(phone: '22644212509', smsCode: '123456');
      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isTrue);
    });

    test('非登录请求保持 Android 3.1.8 身份', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.accountBalance();

      final options = adapter.captured!;
      expect(options.headers['VersionCode'], '3.1.8');
      expect(options.headers['User-Agent'], 'Android_ilife798_3.1.8');
      expect(options.headers['User-Agent'], isNot(contains('iOS_ilife798')));
      expect(options.uri.queryParameters.containsKey('sign'), isFalse);
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

  group('DrinkApiService 设备状态解析', () {
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

    test('deviceStatus 解析出离线 / 禁用 / 空闲 / 运行中', () async {
      final api = DrinkApiService();

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":0,"gene":{"status":0}}}}';
      var result = await api.deviceStatus(deviceId: 'd');
      expect(result.success, isTrue);
      expect(result.status!.isOffline, isTrue);
      expect(result.status!.isAvailable, isFalse);

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":1,"gene":{"status":98}}}}';
      result = await api.deviceStatus(deviceId: 'd');
      expect(result.status!.isDisabled, isTrue);
      expect(result.status!.isAvailable, isFalse);

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":1,"gene":{"status":99}}}}';
      result = await api.deviceStatus(deviceId: 'd');
      expect(result.status!.isAvailable, isTrue);

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":1,"gene":{"status":1}}}}';
      result = await api.deviceStatus(deviceId: 'd');
      expect(result.status!.isAvailable, isFalse);
      expect(result.status!.isOffline, isFalse);
      expect(result.status!.isDisabled, isFalse);
    });

    test('deviceStatus 服务端拒绝时透出 code 与 msg', () async {
      adapter.responseBody = '{"code":-99,"msg":"登录状态已过期"}';

      final api = DrinkApiService();
      final result = await api.deviceStatus(deviceId: 'd');

      expect(result.success, isFalse);
      expect(result.code, -99);
      expect(result.message, '登录状态已过期');
      expect(result.isSessionExpired, isTrue);
    });

    test('deviceStatus 请求形状：did 与 more=false，无 promo、无 sign', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.deviceStatus(deviceId: 'device123');

      final params = adapter.captured?.queryParameters;
      expect(params!['did'], 'device123');
      expect(params['more'], false);
      expect(params.containsKey('promo'), isFalse);
      expect(params.containsKey('sign'), isFalse);
    });

    test('isDeviceAvailable 三态映射：离线与禁用不可用，空闲可用', () async {
      final api = DrinkApiService();

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":0,"gene":{"status":0}}}}';
      expect(await api.isDeviceAvailable(deviceId: 'd'), isFalse);

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":1,"gene":{"status":98}}}}';
      expect(await api.isDeviceAvailable(deviceId: 'd'), isFalse);

      adapter.responseBody =
          '{"code":0,"data":{"device":{"status":1,"gene":{"status":99}}}}';
      expect(await api.isDeviceAvailable(deviceId: 'd'), isTrue);
    });

    test('resolveQrDevice 从 qr/use 提取设备 ID', () async {
      adapter.responseBody = '{"code":0,"data":{"dev":{"id":"dev-9"}}}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.resolveQrDevice(qrId: 'abc');

      expect(result, 'dev-9');
      expect(adapter.captured?.uri.path, contains('qr/use'));
      expect(adapter.captured?.queryParameters['id'], 'abc');
    });

    test('resolveQrDevice 响应不含设备时回退为空串', () async {
      adapter.responseBody = '{"code":0,"data":{}}';

      final api = DrinkApiService();
      await api.isLoggedIn();
      expect(await api.resolveQrDevice(qrId: 'abc'), '');
    });

    test('resolveQrDevice 空编号直接拒绝且不发包', () async {
      final api = DrinkApiService();
      await api.isLoggedIn();
      final capturedBefore = adapter.captured;

      expect(await api.resolveQrDevice(qrId: ''), '');

      expect(adapter.captured, same(capturedBefore), reason: '空编号不应发起请求');
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

    test('网络异常时返回网络错误且 code 为 null', () async {
      DrinkApiService().setHttpClientAdapter(_ThrowingAdapter());

      final api = DrinkApiService();
      await api.isLoggedIn();
      final result = await api.login(phone: '22644212509', smsCode: '123456');

      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(result.message, startsWith('网络错误'));
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

    test('login 不使用本地残留 token', () async {
      // 登录以签名与手机号/验证码为准：请求带 sign，且不带 Authorization。
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token':
            '{"uid":"87654321abcdefgh","eid":"e1","token":"abcdefgh12345678"}',
        'drink_water_app_is_login': true,
      });

      final api = DrinkApiService();
      await api.isLoggedIn();
      await api.login(phone: '22644212509', smsCode: '123456');

      expect(adapter.captured?.uri.queryParameters.containsKey('sign'), isTrue);
      expect(adapter.captured?.headers.containsKey('Authorization'), isFalse);
    });
  });
}
