import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 惠生活798 接口签名。
///
/// 算法从官方 App 3.1.8 逆向还原。官方对业务请求追加 `?sign=<MD5>` 查询参数，
/// 服务端据此校验请求合法性。
///
/// 签名流程分两步：
/// 1. 把参数序列化为 `k=v` 以 `&` 连接的字符串（[serialize]）
/// 2. 按固定顺序拼接密钥片段后，经 [objcEncode] 编码再取 MD5
///
/// 注意：MD5 的输入是**编码后**的字符串，且编码规则必须匹配 ObjC 的
/// `URLQueryAllowedCharacterSet`（放行 `=`、`&` 等字符），不能使用 Dart 的
/// `Uri.encodeQueryComponent`。
class DrinkApiSigner {
  DrinkApiSigner._();

  /// 序列化请求参数。
  ///
  /// 参数键按字典序升序排列，格式化为 `键=值`，以 `&` 连接。
  /// 布尔值转写为小写的 `true` / `false`。值为 null 或空字符串的参数被跳过。
  static String serialize(Map<String, dynamic> params) {
    final keys = params.keys
        .where((k) => params[k] != null && params[k] != '')
        .toList()
      ..sort();
    return keys.map((k) {
      final value = params[k];
      final text = value is bool ? (value ? 'true' : 'false') : '$value';
      return '$k=$text';
    }).join('&');
  }

  /// ObjC 兼容的百分号编码。
  ///
  /// 放行集对应 ObjC 的 `URLQueryAllowedCharacterSet` 去掉 `{}":,` 后的结果：
  /// 英文字母、数字，以及 `-` `.` `_` `~` `!` `$` `&` `'` `(` `)` `*` `+`
  /// `;` `=` `?` `@` `/`。其余字符按 UTF-8 字节逐字节编码为 `%XX`。
  static String objcEncode(String input) {
    final bytes = utf8.encode(input);
    final buffer = StringBuffer();
    for (final byte in bytes) {
      if (_isAllowed(byte)) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write('%');
        buffer.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  static bool _isAllowed(int byte) {
    final isAlphaNumeric = (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5A) ||
        (byte >= 0x61 && byte <= 0x7A);
    return isAlphaNumeric || _unreservedMarks.contains(byte);
  }

  static const Set<int> _unreservedMarks = {
    0x2D, // -
    0x2E, // .
    0x5F, // _
    0x7E, // ~
    0x21, // !
    0x24, // $
    0x26, // &
    0x27, // '
    0x28, // (
    0x29, // )
    0x2A, // *
    0x2B, // +
    0x3B, // ;
    0x3D, // =
    0x3F, // ?
    0x40, // @
    0x2F, // /
  };

  /// 四个密钥的 MD5 摘要，按序为 k1..k4。
  static final String key1 = md5Hex('eZ');
  static final String key2 = md5Hex('kzyZ');
  static final String key3 = md5Hex('null');
  static final String key4 = md5Hex('hn');

  static String md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

  /// 固定盐值，按官方算法的拼接顺序。
  static const String _salt1 = 'dF6hJ9kL2nP';
  static const String _salt2 = 'rT8wY1';
  static const String _salt3 = 'G';
  static const String _salt4 = 'iM7oQ';
  static const String _salt5 = 'v';

  /// 短签名，用于登录类接口。
  ///
  /// 拼接顺序：序列化参数、密钥字符片段、固定盐值。字符片段依次为
  /// `k1[1]`、`k2[25]` 转大写、`k3[0]`、`k4[18]`、`k2[21]`、`k3[23]`、`k1[15]`
  /// （下标 1-based）。拼接结果经 [objcEncode] 后取 MD5。
  ///
  /// 短签名不含时间戳与身份信息，相同参数必然得到相同结果。
  static String shortSign(Map<String, dynamic> params) {
    final query = serialize(params);
    return md5Hex(objcEncode(_keyFragments(query)));
  }

  /// 取摘要字符串中第 [index] 个字符（0-based）。
  ///
  /// 摘要固定 32 位，下标越界返回空串——与官方在密钥异常时的降级行为一致。
  static String _charAt(String source, int index) {
    if (index < 0 || index >= source.length) return '';
    return source[index];
  }

  /// 长签名，用于设备操作类接口。
  ///
  /// 在 [shortSign] 的拼接顺序基础上，于序列化参数之后插入三段：
  /// 时间档位值、token 的后 8 个字符、uid 的后 8 个字符。
  ///
  /// 时间档位值为 `30 * ((nowMillis + lat - lng) / 30000)`，整数除法，
  /// 每 30 秒一档。lat 与 lng 为位置修正值，本项目恒取 0——官方从
  /// `NSUserDefaults` 读取定位缓存，客户端不引入定位权限。
  ///
  /// token 或 uid 长度小于 8 时，对应片段置为空串，与官方降级行为一致。
  static String longSign(
    Map<String, dynamic> params, {
    required String token,
    required String uid,
    int? nowMillis,
  }) {
    final query = serialize(params);
    final tick = _timeTick(nowMillis ?? DateTime.now().millisecondsSinceEpoch);
    return md5Hex(
      objcEncode('$query$tick${_tail8(token)}${_tail8(uid)}${_keyFragments()}'),
    );
  }

  /// 密钥字符片段与固定盐值的拼接，两个签名共用。
  ///
  /// 顺序：`k1[1]`、`k2[25]` 转大写、`k3[0]`、`k4[18]`、`k2[21]`、`k3[23]`、
  /// `k1[15]`，随后五个固定盐值。下标均为 1-based。
  static String _keyFragments([String prefix = '']) {
    final buffer = StringBuffer(prefix)
      ..write(_charAt(key1, 1))
      ..write(_charAt(key2, 25).toUpperCase())
      ..write(_charAt(key3, 0))
      ..write(_charAt(key4, 18))
      ..write(_charAt(key2, 21))
      ..write(_charAt(key3, 23))
      ..write(_charAt(key1, 15))
      ..write(_salt1)
      ..write(_salt2)
      ..write(_salt3)
      ..write(_salt4)
      ..write(_salt5);
    return buffer.toString();
  }

  /// 时间档位：每 30 秒一档。
  static int _timeTick(int millis) {
    const lat = 0;
    const lng = 0;
    return 30 * ((millis + lat - lng) ~/ 30000);
  }

  /// 取字符串后 8 个字符；不足 8 个时返回空串。
  static String _tail8(String value) {
    if (value.length < 8) return '';
    return value.substring(value.length - 8);
  }
}
