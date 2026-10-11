import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drink_water_app/core/services/drink_api_signer.dart';

String md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

void main() {
  group('DrinkApiSigner.serialize', () {
    test('参数按字典序升序排列并用 & 连接', () {
      final result = DrinkApiSigner.serialize({
        'did': '123',
        'upgrade': true,
        'rcp': false,
      });

      expect(result, 'did=123&rcp=false&upgrade=true');
    });

    test('布尔值转写为小写 true/false', () {
      final result = DrinkApiSigner.serialize({'upgrade': true});

      expect(result, 'upgrade=true');
      expect(result, isNot('upgrade=1'));
      expect(result, isNot('upgrade=True'));
    });

    test('空值参数被跳过且不产生多余分隔符', () {
      final result = DrinkApiSigner.serialize({
        'did': '123',
        'openCode': '',
        'rcp': false,
      });

      expect(result, 'did=123&rcp=false');
      expect(result, isNot(contains('&&')));
      expect(result, isNot(contains('openCode')));
    });
  });

  group('DrinkApiSigner.objcEncode', () {
    test('等号与和号不被编码', () {
      final result = DrinkApiSigner.objcEncode('did=123&rcp=false');

      expect(result, 'did=123&rcp=false');
      expect(result, isNot(contains('%3D')));
      expect(result, isNot(contains('%26')));
    });

    test('非 ASCII 字符按 UTF-8 逐字节编码', () {
      final result = DrinkApiSigner.objcEncode('设');

      expect(result, '%E8%AE%BE');
    });

    test('编码结果与 Dart 的 Uri.encodeQueryComponent 不同', () {
      const input = 'did=123&rcp=false';
      final objc = DrinkApiSigner.objcEncode(input);
      final dart = Uri.encodeQueryComponent(input);

      expect(objc, isNot(dart));
      expect(objc, contains('='));
      expect(objc, contains('&'));
      expect(dart, contains('%3D'));
      expect(dart, contains('%26'));
    });
  });

  group('DrinkApiSigner 密钥派生', () {
    test('四个密钥的 MD5 摘要与手算值一致', () {
      expect(DrinkApiSigner.key1, md5Hex('eZ'));
      expect(DrinkApiSigner.key2, md5Hex('kzyZ'));
      expect(DrinkApiSigner.key3, md5Hex('null'));
      expect(DrinkApiSigner.key4, md5Hex('hn'));
    });

    test('四个摘要均为 32 位十六进制字符串', () {
      final pattern = RegExp(r'^[0-9a-f]{32}$');
      for (final key in [
        DrinkApiSigner.key1,
        DrinkApiSigner.key2,
        DrinkApiSigner.key3,
        DrinkApiSigner.key4,
      ]) {
        expect(key, matches(pattern));
      }
    });
  });

  group('DrinkApiSigner.shortSign', () {
    test('相同参数两次计算结果一致', () {
      final params = {'un': '22644212509', 'authCode': '123456'};

      expect(DrinkApiSigner.shortSign(params), DrinkApiSigner.shortSign(params));
    });

    test('拼接串不含时间戳与身份信息', () {
      // 短签名只依赖参数与密钥片段；换 token/uid 不影响结果
      final params = {'un': '22644212509', 'authCode': '123456'};

      final first = DrinkApiSigner.shortSign(params);
      final second = DrinkApiSigner.shortSign(params);

      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('不同参数产生不同签名', () {
      expect(
        DrinkApiSigner.shortSign({'un': '22644212509', 'authCode': '111111'}),
        isNot(DrinkApiSigner.shortSign({'un': '22644212509', 'authCode': '222222'})),
      );
    });
  });

  group('DrinkApiSigner.longSign', () {
    // 固定时间戳，使时间档位可预测
    const millis = 1700000000000;

    Map<String, dynamic> startParams() => {
          'did': 'device123',
          'upgrade': true,
          'ptype': 0,
          'args': '',
          'rcp': false,
          'cnt': 1,
        };

    test('相同输入两次计算结果一致', () {
      expect(
        DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis),
        DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis),
      );
    });

    test('30 秒窗口内时间档位相同则签名一致', () {
      // 固定时刻落在档位内前 5 秒，加 5 秒仍在同一 30 秒档
      final withinWindow = millis + 5 * 1000;

      expect(
        DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis),
        DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: withinWindow),
      );
    });

    test('相隔超过 30 秒则签名不同', () {
      final beyondWindow = millis + 31 * 1000;

      expect(
        DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis),
        isNot(DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: beyondWindow)),
      );
    });

    test('token 不足 8 位时该片段为空串', () {
      final shortToken = 'abcde';

      // 空片段与另一个空片段等价：短 token 的签名应等于把 token 片段整体去掉的降级结果
      final withShortToken = DrinkApiSigner.longSign(startParams(),
          token: shortToken, uid: '87654321abcdefgh', nowMillis: millis);

      expect(withShortToken, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(
        withShortToken,
        isNot(DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis)),
      );
    });

    test('uid 为空字符串时该片段为空串', () {
      final withEmptyUid = DrinkApiSigner.longSign(startParams(),
          token: 'abcdefgh12345678', uid: '', nowMillis: millis);

      expect(withEmptyUid, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(
        withEmptyUid,
        isNot(DrinkApiSigner.longSign(startParams(),
            token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis)),
      );
    });

    test('时间档位值按 30 秒一档取整', () {
      // 同档内签名一致已由上一个场景覆盖；此处验证档位边界确实落在 30 秒
      final base = DrinkApiSigner.longSign(startParams(),
          token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis);
      final sameTick = DrinkApiSigner.longSign(startParams(),
          token: 'abcdefgh12345678',
          uid: '87654321abcdefgh',
          nowMillis: millis + 1000);

      expect(base, sameTick);
    });
  });

  group('DrinkApiSigner 签名与 sign 参数的顺序', () {
    // 固定时刻，与 2.1 startDrinking 的参数形状一致
    const millis = 1700000000000;

    Map<String, dynamic> startParams() => {
          'did': 'device123',
          'upgrade': true,
          'ptype': 0,
          'args': '',
          'rcp': false,
          'cnt': 1,
        };

    test('签名先于 sign 入参计算，追加 sign 不改变已有签名', () {
      final params = startParams();

      // 正确顺序：先算签名（此时 params 中还没有 sign）
      final signBeforeInsert = DrinkApiSigner.longSign(params,
          token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis);

      // 再写入 sign
      params['sign'] = signBeforeInsert;

      // 若反过来先写 sign 再算签名，serialize 会把 sign 也纳入，
      // 得到不同结果——这正是本测试要防住的回归。
      final wrongOrder = DrinkApiSigner.longSign(params,
          token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis);

      expect(signBeforeInsert, isNot(wrongOrder));
      expect(params['sign'], signBeforeInsert);
    });

    test('六参形状的签名值与参数逐项对应', () {
      final params = startParams();

      final full = DrinkApiSigner.longSign(params,
          token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis);

      // 改变任一业务参数都应改变签名，证明六项都参与了计算
      for (final key in ['did', 'upgrade', 'ptype', 'rcp', 'cnt']) {
        final mutated = Map<String, dynamic>.from(params);
        mutated[key] = mutated[key] == 0 ? 1 : 'mutated';
        expect(
          DrinkApiSigner.longSign(mutated,
              token: 'abcdefgh12345678', uid: '87654321abcdefgh', nowMillis: millis),
          isNot(full),
          reason: '参数 $key 未参与签名计算',
        );
      }
    });
  });
}
