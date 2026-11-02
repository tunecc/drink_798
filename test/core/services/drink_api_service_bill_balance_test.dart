import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/models/settlement_bill.dart';
import 'package:drink_water_app/core/services/drink_api_service.dart';

/// 捕获请求参数与 URL 的测试 adapter。
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? captured;
  final List<RequestOptions> requests = [];
  String responseBody = '{"code":0,"data":{}}';

  /// 按 URL 路径片段返回不同响应体，用于一次用例里打两个不同接口。
  final Map<String, String> responseBodyByPath = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    requests.add(options);
    final path = options.uri.path;
    final body = responseBodyByPath.entries
        .where((e) => path.contains(e.key))
        .map((e) => e.value)
        .firstOrNull;
    return ResponseBody.fromString(
      body ?? responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 钱包余额响应 fixture（对照 life-798 WalletResponseParser 已核验形状）：
/// data.aw 为主钱包，data.eps[] 为分端点钱包，balance 单位为元。
/// aw 的 id 与测试账号 eid=e1 匹配，应优先取它。
const _walletResponse = '''
{"code":0,"data":{
  "aw":{"id":"e1","name":"主钱包","balance":12.5},
  "eps":[
    {"id":"ep1","ownerId":"o1","name":"生活区","balance":3.2},
    {"id":"ep2","ownerId":"o2","name":"教学区","balance":8.8}
  ]
}}
''';

/// 无端点匹配且仅一条钱包条目：取唯一条目。
const _walletSingleResponse = '''
{"code":0,"data":{"eps":[{"id":"ep9","ownerId":"o9","name":"唯一钱包","balance":3.2}]}}
''';

/// 无端点匹配且多条钱包：无法唯一判定，应返回 null。
const _walletAmbiguousResponse = '''
{"code":0,"data":{"eps":[
  {"id":"ep1","ownerId":"o1","name":"生活区","balance":3.2},
  {"id":"ep2","ownerId":"o2","name":"教学区","balance":8.8}
]}}
''';

/// 积分余额响应 fixture（对照 life-798 ScoreUiState 已核验形状）。
const _scoreResponse = '''
{"code":0,"data":{"validScore":4200,"totalScore":5100}}
''';

/// 账单列表响应 fixture（对照 life-798 WaterBillParser 已核验形状）：
/// type=91 且 status=3 的已完成饮水账单；cata=6 为饮水类目。
const _billListResponse = '''
{"code":0,"data":{"records":[
  {"id":"b3","type":91,"status":3,"cata":6,"payment":0.35,
   "utime":1730000004000,"dev":{"id":"dev1"}},
  {"id":"b2","type":91,"status":3,"cata":6,"payment":0.2,
   "utime":1730000003000,"dev":{"id":"dev2"}},
  {"id":"b1","type":91,"status":1,"cata":6,"payment":0,
   "utime":1730000002000,"dev":{"id":"dev1"}}
]}}
''';

/// 账单详情响应 fixture：积分抵扣只在详情的 promo.type=4/discount。
const _billDetailResponse = '''
{"code":0,"data":{"bill":{
  "id":"b3","type":91,"status":3,"cata":6,"payment":0.35,
  "promo":{"type":4,"discount":0.65},
  "utime":1730000004000,"dev":{"id":"dev1"}
}}}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrinkApiService 余额接口请求形状', () {
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

    test('accountBalance 并行请求两个余额接口且只带 Authorization', () async {
      adapter.responseBodyByPath['/acc/wallet/owner'] = _walletResponse;
      adapter.responseBodyByPath['/acc/score/acc-score'] = _scoreResponse;
      final api = DrinkApiService();
      await api.isLoggedIn();
      final balance = await api.accountBalance();

      expect(balance, isNotNull);
      expect(balance!.walletYuan, 12.5, reason: '优先取端点匹配账户 eid 的钱包条目');
      expect(balance.score, 4200, reason: '取 validScore');
      final paths = adapter.requests.map((r) => r.uri.path).toList();
      expect(paths.where((p) => p.contains('/acc/wallet/owner')), isNotEmpty);
      expect(
        paths.where((p) => p.contains('/acc/score/acc-score')),
        isNotEmpty,
      );
      for (final r in adapter.requests) {
        expect(r.headers['Authorization'], 'abcdefgh12345678');
        expect(r.headers.containsKey('ApplicationType'), isFalse);
      }
    });

    test('钱包无端点匹配时唯一条目可用、多条时不猜测', () async {
      adapter.responseBody = _walletSingleResponse;
      final api = DrinkApiService();
      await api.isLoggedIn();
      expect(await api.accountBalance(), isNotNull,
          reason: '仅一条钱包条目，直接采用');

      adapter.responseBody = _walletAmbiguousResponse;
      expect(await api.accountBalance(), isNull,
          reason: '多条且无端点匹配时不能猜余额，积分侧也失败时整体为 null');
    });

    test('未登录时不发余额请求并返回 null', () async {
      SharedPreferences.setMockInitialValues({
        'drink_water_app_is_login': false,
      });
      final api = DrinkApiService();
      await api.isLoggedIn();

      expect(await api.accountBalance(), isNull);
      expect(adapter.captured, isNull);
    });

    test('单边失败时成功一侧仍然返回', () async {
      adapter.responseBodyByPath['/acc/wallet/owner'] =
          '{"code":0,"data":{"oops":1}}';
      adapter.responseBodyByPath['/acc/score/acc-score'] = _scoreResponse;
      final api = DrinkApiService();
      await api.isLoggedIn();

      final balance = await api.accountBalance();
      expect(balance!.walletYuan, isNull);
      expect(balance.score, 4200);
    });

    test('异常形状与请求失败返回 null 而不是抛错', () async {
      adapter.responseBody = 'not-json';
      final api = DrinkApiService();
      await api.isLoggedIn();
      expect(await api.accountBalance(), isNull);
    });
  });

  group('DrinkApiService 账单接口请求形状', () {
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

    test('billList 请求 /bill/lst-owner 分页参数并解析记录', () async {
      adapter.responseBody = _billListResponse;
      final api = DrinkApiService();
      await api.isLoggedIn();
      final bills = await api.billList();

      expect(adapter.captured?.uri.path, contains('/bill/lst-owner'));
      expect(adapter.captured?.uri.queryParameters['page'], '0');
      expect(adapter.captured?.uri.queryParameters['size'], '20');
      expect(bills.length, 3);
      expect(bills.first['id'], 'b3');
    });

    test('billDetail 请求 /bill/view-full 并解析 data.bill', () async {
      adapter.responseBody = _billDetailResponse;
      final api = DrinkApiService();
      await api.isLoggedIn();
      final bill = await api.billDetail(billId: 'b3');

      expect(adapter.captured?.uri.path, contains('/bill/view-full'));
      expect(adapter.captured?.uri.queryParameters['id'], 'b3');
      expect(bill, isNotNull);
      expect(bill!['id'], 'b3');
    });

    test('失败或形状异常时返回空列表 / null', () async {
      adapter.responseBody = 'nope';
      final api = DrinkApiService();
      await api.isLoggedIn();
      expect(await api.billList(), isEmpty);
      expect(await api.billDetail(billId: 'b3'), isNull);
    });
  });

  group('SettlementBillParser', () {
    final listRecords = _recordsOf(_billListResponse);
    final detailBill = _billOf(_billDetailResponse);

    test('latestFromList 只取已完成且匹配设备与时间的最新一条', () {
      final candidate = SettlementBillParser.latestFromList(
        listRecords,
        deviceId: 'dev1',
        since: DateTime.fromMillisecondsSinceEpoch(1730000001000),
      );
      expect(candidate, isNotNull);
      expect(candidate!.billId, 'b3', reason: 'b1 未结算，b2 设备不匹配，应取 b3');
    });

    test('fromDetail 从 promo.type=4 提取积分抵扣并合成三段金额', () {
      final consumption = SettlementBillParser.fromDetail(
        detailBill,
        deviceId: 'dev1',
      );
      expect(consumption, isNotNull);
      expect(consumption!.billId, 'b3');
      expect(consumption.scoreYuan, closeTo(0.65, 1e-9));
      expect(consumption.walletYuan, closeTo(0.35, 1e-9));
      expect(consumption.totalYuan, closeTo(1.0, 1e-9));
      expect(consumption.noCharge, isFalse);
    });

    test('无 promo 或其他 promo 类型时积分为 0、总额等于钱包支付', () {
      final noPromo = Map<String, dynamic>.from(detailBill)
        ..remove('promo');
      final consumption = SettlementBillParser.fromDetail(
        noPromo,
        deviceId: 'dev1',
      );
      expect(consumption!.scoreYuan, 0);
      expect(consumption.totalYuan, closeTo(0.35, 1e-9));

      final otherPromo = Map<String, dynamic>.from(detailBill)
        ..['promo'] = {'type': 7, 'discount': 9.9};
      final other = SettlementBillParser.fromDetail(otherPromo, deviceId: 'dev1');
      expect(other!.scoreYuan, 0, reason: '只有 promo.type=4 是积分抵扣');
      expect(other.totalYuan, closeTo(0.35, 1e-9));
    });

    test('积分全额抵扣的账单 payment=0 也能正确解析', () {
      final covered = Map<String, dynamic>.from(detailBill)
        ..['payment'] = 0;
      final consumption = SettlementBillParser.fromDetail(covered, deviceId: 'dev1');
      expect(consumption!.walletYuan, 0);
      expect(consumption.totalYuan, closeTo(0.65, 1e-9));
      expect(consumption.noCharge, isFalse);
    });

    test('零元账单视为未产生费用', () {
      final free = Map<String, dynamic>.from(detailBill)
        ..['payment'] = 0
        ..remove('promo');
      final consumption = SettlementBillParser.fromDetail(free, deviceId: 'dev1');
      expect(consumption!.noCharge, isTrue);
    });

    test('设备不匹配或金额异常时拒绝解析', () {
      expect(
        SettlementBillParser.fromDetail(detailBill, deviceId: 'other'),
        isNull,
      );
      final bad = Map<String, dynamic>.from(detailBill)..['payment'] = -1;
      expect(SettlementBillParser.fromDetail(bad, deviceId: 'dev1'), isNull);
    });
  });
}

/// 从 fixture JSON 提取 records 数组。
List<Map<String, dynamic>> _recordsOf(String body) {
  final data = (jsonDecodeMap(body) ?? const {})['data'] as Map<String, dynamic>;
  return (data['records'] as List).cast<Map<String, dynamic>>();
}

/// 从 fixture JSON 提取 data.bill。
Map<String, dynamic> _billOf(String body) {
  final data = (jsonDecodeMap(body) ?? const {})['data'] as Map<String, dynamic>;
  return data['bill'] as Map<String, dynamic>;
}

Map<String, dynamic>? jsonDecodeMap(String body) {
  try {
    final value = jsonDecode(body);
    return value is Map ? value.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}
