/// 饮水结算账单模型与解析。
///
/// 字段语义对照 life-798（WaterWidget）已核验的实现：
/// - 结算账单记录 `type=91`、`status=3`、`cata=6`（类目存在时）。
/// - 积分抵扣只记录在详情的 `promo.type=4` / `discount`，列表不含 promo，
///   积分全额抵扣时列表 `payment` 可以为零。
/// - 金额单位为元；比较与合成按毫（千分之一元）取整，避免二进制浮点误差。
library;

/// 账单列表里筛出的候选账单：仅含定位与排序所需字段。
class SettlementBillCandidate {
  const SettlementBillCandidate({required this.billId, required this.occurredAt});

  final String billId;
  final DateTime occurredAt;
}

/// 一次结算消费的三段金额。
class SettlementConsumption {
  const SettlementConsumption({
    required this.billId,
    required this.totalYuan,
    required this.scoreYuan,
    required this.walletYuan,
    required this.occurredAt,
  });

  final String billId;

  /// 总额 = 钱包支付 + 积分抵扣。
  final double totalYuan;

  /// 积分抵扣部分（promo.type=4 / discount），无抵扣时为 0。
  final double scoreYuan;

  /// 钱包（含礼品金）支付部分，即账单 `payment` 字段。
  final double walletYuan;

  final DateTime occurredAt;

  bool get noCharge => totalYuan <= 0;
}

/// 从服务端记录中解析结算账单的纯函数集合。
class SettlementBillParser {
  SettlementBillParser._();

  /// 从账单列表中筛选「已完成饮水账单」，取时间最新且匹配设备、
  /// 不早于 [since] 的一条；找不到返回 null。
  static SettlementBillCandidate? latestFromList(
    List<Map<String, dynamic>> records, {
    required String deviceId,
    required DateTime since,
  }) {
    SettlementBillCandidate? latest;
    for (final record in records) {
      if (!_isCompletedWaterBill(record)) continue;
      final explicitDevice = _deviceIdOf(record);
      if (explicitDevice != null && explicitDevice != deviceId) continue;
      final occurredAt = _occurredAtOf(record);
      if (occurredAt.isBefore(since)) continue;
      final id = _billIdOf(record);
      if (id == null) continue;
      if (latest == null || occurredAt.isAfter(latest.occurredAt)) {
        latest = SettlementBillCandidate(billId: id, occurredAt: occurredAt);
      }
    }
    return latest;
  }

  /// 从账单详情（`data.bill`）解析三段金额。
  ///
  /// 只有 `promo.type=4` 视为积分抵扣，其他 promo 类型一律忽略；
  /// 设备不匹配、未结算或金额异常（非有限、为负）时返回 null。
  static SettlementConsumption? fromDetail(
    Map<String, dynamic> bill, {
    required String deviceId,
  }) {
    final explicitDevice = _deviceIdOf(bill);
    if (explicitDevice != null && explicitDevice != deviceId) return null;
    if (!_isCompletedWaterBill(bill)) return null;

    final paymentMilli = _milliOf(bill['payment']);
    if (paymentMilli == null) return null;
    final scoreMilli = _promoTypeOf(bill) == 4
        ? (_milliOf(_promoOf(bill)?['discount']) ?? 0)
        : 0;
    if (scoreMilli < 0) return null;

    final id = _billIdOf(bill) ?? '';
    return SettlementConsumption(
      billId: id,
      totalYuan: (paymentMilli + scoreMilli) / 1000,
      scoreYuan: scoreMilli / 1000,
      walletYuan: paymentMilli / 1000,
      occurredAt: _occurredAtOf(bill),
    );
  }

  static bool _isCompletedWaterBill(Map<String, dynamic> record) =>
      _intOf(record['type']) == 91 &&
      _intOf(record['status']) == 3 &&
      (!record.containsKey('cata') || _intOf(record['cata']) == 6);

  static String? _billIdOf(Map<String, dynamic> record) {
    for (final key in const ['id', 'billId', 'bill_id', 'orderId', 'sn']) {
      final value = record[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static String? _deviceIdOf(Map<String, dynamic> record) {
    final dev = record['dev'];
    if (dev is Map) {
      final id = dev['id'];
      if (id != null && id.toString().trim().isNotEmpty) return id.toString();
    }
    for (final key in const ['did', 'deviceId', 'device_id']) {
      final value = record[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static DateTime _occurredAtOf(Map<String, dynamic> record) {
    final raw = _intOf(record['utime']) ?? _intOf(record['ctime']) ?? 0;
    final millis = raw <= 0
        ? 0
        : raw < 10000000000
            ? raw * 1000
            : raw;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Map<String, dynamic>? _promoOf(Map<String, dynamic> bill) {
    final promo = bill['promo'];
    return promo is Map ? promo.cast<String, dynamic>() : null;
  }

  static int? _promoTypeOf(Map<String, dynamic> bill) =>
      _intOf(_promoOf(bill)?['type']);

  /// 金额转毫（千分之一元）；非数字或为负返回 null。
  static int? _milliOf(Object? value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return (amount * 1000).round();
  }

  static int? _intOf(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }
}
