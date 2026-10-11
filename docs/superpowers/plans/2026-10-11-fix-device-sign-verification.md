---
change: fix-device-sign-verification
design-doc: docs/openspec/changes/fix-device-sign-verification/design.md
base-ref: 3d85201c80ceb98751a1c5fc74d03e6128ded843
---

# 实施计划：修复设备接口签名验证

<!-- comet-task-authority: docs/openspec/changes/fix-device-sign-verification/tasks.md -->

## 背景与约束

官方 App 3.1.8 对 `dev/start`、`dev/end`、`dev/favo`、`acc/login`、`acc/login/code` 追加 `?sign=<MD5>` 签名参数，客户端未实现导致服务端拒绝。算法已从 IDA 逆向完整还原。

关键实现约束（来自 design.md）：

1. **签名 MD5 输入是 ObjC 编码后的字符串**。ObjC 的 `URLQueryAllowedCharacterSet` 去掉 `{}":,` 后放行 `= & + ; ? @ /`，Dart 的 `Uri.encodeQueryComponent` 全部编码。必须自实现编码器，这是唯一无替代方案的约束。
2. **签名必须在 `sign` 加入 params 之前算**，否则自引用。
3. **dio 不排序查询参数不影响正确性**——官方 App 同样签名算排序串、URL 用原始序。
4. **`ptype` 与 `cnt` 是运行时状态**，静态分析无法确证，按 `cnt=1`、`ptype=0` 取默认并集中为命名常量。
5. **`args` 对饮水设备恒为空串**——官方仅在洗衣机、吹风机、触碰开锁三类设备填 JSON。
6. **`lat`/`lng` 恒为 0**，不引入定位权限。

TDD 模式：每个实现任务先写测试确认失败（RED），再实现使测试通过（GREEN）。

---

## 第 1 组：签名模块（纯函数，无 IO）

<!-- comet-task-ref:42585f1e-4356-445e-98f1-0ee3af43474a -->
### 1.1 声明 crypto 依赖

范围：`pubspec.yaml`。
依赖：无。
约束：`crypto 1.19.1` 已在 `pubspec.lock` 中作为间接依赖，显式声明不新增传递依赖树。

步骤：
1. 在 `dependencies` 中加 `crypto: ^3.0.7`
2. 执行 `flutter pub get`

验收：`pubspec.lock` 中 crypto 仍为 3.0.7，`git diff pubspec.lock` 只显示依赖关系从 transitive 变为 direct main。

<!-- comet-task-ref:8a819ae2-9d75-4831-97bf-550d54e20865 -->
### 1.2 实现 serialize

范围：`lib/core/services/drink_api_signer.dart`（新建）、`test/core/services/drink_api_signer_test.dart`（新建）。
依赖：无。

RED：写测试断言三个场景，此时 `DrinkApiSigner` 不存在，测试编译失败。
GREEN：实现 `serialize`。

```dart
static String serialize(Map<String, dynamic> params) {
  final keys = params.keys
      .where((k) => params[k] != null && params[k] != '')
      .toList()..sort();
  return keys.map((k) {
    final v = params[k];
    final s = v is bool ? (v ? 'true' : 'false') : '$v';
    return '$k=$s';
  }).join('&');
}
```

验收：`flutter test test/core/services/drink_api_signer_test.dart` 通过，覆盖：
- `{"did":"123","upgrade":true,"rcp":false}` → `did=123&rcp=false&upgrade=true`
- 布尔真 → `true` 而非 `1` 或 `True`
- 空串值被跳过且不产生多余 `&`

<!-- comet-task-ref:18ae2623-b303-4e62-b87c-57efae11168f -->
### 1.3 实现 objcEncode

范围：同上两个文件。
依赖：无（与 1.2 无耦合，但同文件顺序实现）。

RED：写测试断言三个场景。
GREEN：实现编码器。

放行集：`A-Z a-z 0-9` 加 `- . _ ~ ! $ & ' ( ) * + ; = ? @ /`。其余按 UTF-8 逐字节转 `%XX`（大写十六进制）。

验收：测试通过，覆盖：
- `did=123&rcp=false` 中 `=` 与 `&` 保持原样
- 非 ASCII 字符按 UTF-8 逐字节编码
- 与 `Uri.encodeQueryComponent` 结果不同（差异断言锁住规则）

**本任务是整个修复的关键**。若编码规则有偏差，签名必然无效，后续所有任务白做。

<!-- comet-task-ref:4ae4de1e-5649-493d-8601-5ef0ea8d7f44 -->
### 1.4 实现密钥派生

范围：同上。
依赖：无。

RED：写测试断言四个摘要值。
GREEN：定义四个常量并计算 MD5。

密钥：`eZ`、`kzyZ`、`null`、`hn`。摘要记为 `k1`-`k4`。

验收：测试通过，四个摘要值与 `md5("eZ")` 等手算值一致。

<!-- comet-task-ref:43b69d81-4f8f-411b-9c0f-4f472fe55342 -->
### 1.5 实现 shortSign

范围：同上。
依赖：1.2、1.3、1.4。

RED：写测试断言两个场景。
GREEN：实现短签名。

拼接顺序：`serialize(params)` + `k1[1]` + `k2[25].upper()` + `k3[0]` + `k4[18]` + `k2[21]` + `k3[23]` + `k1[15]` + `"dF6hJ9kL2nP"` + `"rT8wY1"` + `"G"` + `"iM7oQ"` + `"v"`，再经 `objcEncode`，最后取 MD5。

字符位置均为 1-based。

验收：测试通过，覆盖：
- 相同参数两次计算结果一致
- 拼接串不含时间戳、token、uid

<!-- comet-task-ref:10c14c00-c74e-41c2-91cb-d16ca251fca2 -->
### 1.6 实现 longSign

范围：同上。
依赖：1.5。

RED：写测试断言五个场景。
GREEN：实现长签名。

拼接顺序：在短签名基础上，于 `serialize(params)` 之后插入三段：`ts`、token 后 8 位、uid 后 8 位。

`ts = 30 * ((毫秒 + lat - lng) / 30000)`，整数除法，lat/lng 恒 0。

token 长度 < 8 时该片段为空串；uid 长度 < 8 时该片段为空串。

为可测试，时间需可注入：

```dart
static String longSign(
  Map<String, dynamic> params, {
  required String token,
  required String uid,
  int? nowMillis,
})
```

验收：测试通过，覆盖：
- 拼接串含时间档位值
- 30 秒窗口内两次计算一致
- 相隔超 30 秒两次计算不同
- token 长度 5 时片段为空串
- uid 空串时片段为空串

<!-- comet-task-ref:b302c4fa-22c2-4289-b86d-9cb2430c88a0 -->
### 1.7 顺序约束测试

范围：`test/core/services/drink_api_signer_test.dart`。
依赖：1.6。

本任务无新实现，只加固测试。构造与 `startDrinking` 相同的六参 Map，手动按「先算签名、后加 sign」的顺序计算，断言与 `longSign` 直接调用结果一致。

目的：防止后续重构把 `params["sign"] = ...` 提到签名计算之前。

验收：测试通过。可通过临时调换 `startDrinking` 中的顺序验证该测试能捕获回归（验证后改回）。

---

## 第 2 组：接口接入

<!-- comet-task-ref:47e6459c-4dc0-482d-881a-7458c5708797 -->
### 2.1 改造 startDrinking

范围：`lib/core/services/drink_api_service.dart`。
依赖：1.6、1.7。

改动：
1. 业务参数从四项（`did`、`upgrade`、`rcp`、`stype`）改为六项（`did`、`upgrade`、`ptype`、`args`、`rcp`、`cnt`）
2. 新增命名常量 `_paymentType = 0`、`_drinkCount = 1`
3. 去掉 `stype`
4. `args` 传空串
5. 签名计算后把 `sign` 写回同一 Map

```dart
static const int _paymentType = 0;
static const int _drinkCount = 1;

Future<bool> startDrinking({required String deviceId}) async {
  final params = <String, dynamic>{
    "did": deviceId,
    "upgrade": true,
    "ptype": _paymentType,
    "args": "",
    "rcp": false,
    "cnt": _drinkCount,
  };
  final options = await _authOptions();
  params["sign"] = DrinkApiSigner.longSign(
    params, token: _token["token"], uid: _token["uid"],
  );
  try {
    final response = await _dio.get("$_baseUrl/dev/start",
        queryParameters: params, options: options);
    return response.data["code"] == 0;
  } catch (e) {
    return false;
  }
}
```

约束：`sign` 赋值必须在 `longSign` 调用之后，由 1.7 的测试守护。

验收：`flutter test` 全绿；spec「设备启动参数表」四个场景与「签名附加到请求」第一个场景有对应测试。

<!-- comet-task-ref:7082daf9-76e5-42fd-a15f-2d331da6255d -->
### 2.2 改造 stopDrinking

范围：同上。
依赖：2.1。

参数仅 `did`，追加长签名。签名输入只有一项，是最简单的长签名用例。

验收：`flutter test` 全绿。

<!-- comet-task-ref:6ba05c49-533b-49fe-a52a-5d617dcc6dfc -->
### 2.3 改造 toggleFavoriteDevice

范围：同上。
依赖：2.1。

参数 `did` 与 `remove`（布尔）。注意 `remove` 是布尔值，序列化时需转写为 `true`/`false`——这正是 1.2 测试覆盖的行为。

验收：`flutter test` 全绿。

<!-- comet-task-ref:662baa52-a23e-4579-ba85-2d5d2d785c06 -->
### 2.4 改造 sendSmsCode

范围：同上。
依赖：1.5。

改用短签名。参数 `s`、`authCode`、`un`。

注意：这是第一个使用短签名的接口，需确认短签名不需要 token/uid。

验收：`flutter test` 全绿。

<!-- comet-task-ref:75512d19-7d6a-4d74-93b3-788ffaa742bc -->
### 2.5 改造 login

范围：同上。
依赖：1.5。

改用短签名。参数 `openCode`、`authCode`、`un`、`cid`。

注意：`openCode` 为空串时应被 `serialize` 跳过。

验收：`flutter test` 全绿。

<!-- comet-task-ref:54f620d5-482a-4037-ab74-6d995508729a -->
### 2.6 核对不带签名的接口

范围：`lib/core/services/drink_api_service.dart`。
依赖：2.1-2.5。

只读核对任务。确认 `getDeviceList`（`ui/app/master`）、`isDeviceAvailable`（`ui/app/dev/status`）、`getCaptcha`（`captcha`）、`loginWithToken`（`ui/app/master`）按逆向结论不带签名、调用方式不变。

逆向结论：这四个接口的调用方在官方 App 中未追加 `?sign=`。`ui/app/master` 在 `loginWithToken` 中用于校验 token 有效性，官方通过 `checkToken` 做这件事，但 `ui/app/master` 本身不带签名。

若发现任一接口实际需要签名，记录下来但不擅自添加——需回到 Step 4 评估是否属范围变化。

验收：逐个接口确认并记录结论；无实际改动则说明核对结果。

---

## 第 3 组：请求头与错误呈现

<!-- comet-task-ref:e08ae155-eb33-4f86-8084-0613719cd04e -->
### 3.1 收敛请求头

范围：`lib/core/services/drink_api_service.dart`、`test/core/services/`。
依赖：2.6。

从 `BaseOptions.headers` 中只保留 `VersionCode` 与 `User-Agent`，移除 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`。

`Authorization` 由 `_authOptions()` 按请求注入，不放在 `BaseOptions` 中。

验收：测试断言已登录请求含三个头、未登录请求不含 `Authorization`、任意请求不含四个废弃头。

<!-- comet-task-ref:0afe58b1-280a-4056-8e1d-aacb7a5e2c37 -->
### 3.2 透出服务端错误信息

范围：`lib/core/services/drink_api_service.dart`。
依赖：2.1、2.2。

当前 `startDrinking`/`stopDrinking` 只返回 `bool`，失败时丢弃服务端 `msg`。改为返回携带错误信息的结果。

```dart
class DrinkResult {
  final bool success;
  final int? code;
  final String? message;
  const DrinkResult({required this.success, this.code, this.message});
}
```

约束：这是公开行为变化，`home_controller.dart` 的调用方需同步适配（见 3.3）。不破坏既有测试的导入与构造。

验收：测试覆盖 `code != 0` 时 `message` 携带服务端返回的 `msg` 字段。

<!-- comet-task-ref:b1aab188-94e5-4d64-89e7-496f187aedb9 -->
### 3.3 错误码区分的提示分发

范围：`lib/features/home/home_controller.dart`。
依赖：3.2。

`startDrinking` 失败时：
- `code == -99` → 提示登录已过期，引导重新登录
- 其他 → 透出服务端 `message`
- 不再一律提示「设备无响应，请检查设备状态」

`stopDrinking` 失败时同样区分。

边界：只改提示文案分发，不改交互流程、不改接水状态机。

验收：spec「服务端拒绝时的错误呈现」两个场景有对应测试；手动核对 `home_controller.dart` 中不再出现无条件的「设备无响应」提示。

---

## 第 4 组：验证

<!-- comet-task-ref:7bfafe45-a3f0-4701-8a53-c0f0d9badb47 -->
### 4.1 flutter analyze

范围：全项目。

验收：`flutter analyze` 无新增告警（与改动前基线对比）。

<!-- comet-task-ref:cccd1a7f-4cc0-4d25-b960-d20aae9e152f -->
### 4.2 flutter test

范围：全项目。

验收：`flutter test` 全部通过，含既有三个测试文件：
- `test/core/services/drink_api_service_corrupt_token_test.dart`
- `test/core/services/drink_api_service_init_test.dart`
- `test/core/utils/device_order_test.dart`

<!-- comet-task-ref:f361a968-3743-49ff-84ae-73b8506a4fab -->
### 4.6 签名值比对

范围：命令行。
依赖：4.2。

用 `curl` 复现签名缺失时的服务端返回（预期 `code != 0`），与修复后客户端实际请求的 `sign` 值比对，确认算法与服务端预期一致。

方法：从客户端日志或抓包取得实际 `sign`，用 Python 按逆向算法独立计算同参数的签名，两者应一致。

验收：记录比对结果。若不一致，回到 1.3 检查编码规则。

---

## 风险与回退

| 风险 | 影响任务 | 缓解 |
|---|---|---|
| `objcEncode` 规则偏差 | 1.3 及之后全部 | 1.3 的差异断言测试 + 4.6 独立复算 |
| `ptype`/`cnt` 取值错误 | 4.3 | 4.4 单点调整常量 |
| 时钟偏差超 30 秒窗口 | 4.3 | 属官方算法固有属性，文档标注；若集中出现再评估 |
| 无测试账号导致 4.3 阻塞 | 4.3-4.5 | 记录阻塞，不伪造通过 |

回退：还原本次改动即回到签名缺失状态，无数据格式变更，回退成本仅一次发版。

---

## 已知限制（原 4.3 / 4.4 / 4.5）

经用户确认，这三项从任务清单移出，记录为已知限制，**不视为已验证**。需要可用的惠生活798账号（手机号 + 短信验证码）与在线饮水设备：

- **真机集成验证**：短信登录 → 设备列表 → 接水 → 结算全链路。已验证：请求形状（六参 + sign + 三请求头）由单元测试断言；签名值经 Python 独立复算一致。
- **`ptype` 与 `cnt` 取值核对**：默认 `ptype=0`、`cnt=1`，位于 `DrinkApiService._paymentType` / `_drinkCount`。这两个值来自官方 App 运行时状态，静态分析无法确证；真机若被拒，按服务端返回调整这两个常量，改动限于一处。
- **token 登录路径回归**：uid 为空导致长签名 uid 片段置空，服务端可能拒绝。已验证：`serialize` 空值跳过、`drinkFailurePrompt` 无信息时退回 fallback 均有测试覆盖。需真机确认不崩溃且提示引导改用短信登录。
