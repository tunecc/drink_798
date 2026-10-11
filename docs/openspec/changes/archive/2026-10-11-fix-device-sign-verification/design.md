---
comet_change: fix-device-sign-verification
role: technical-design
canonical_spec: openspec
archived-with: 2026-10-11-fix-device-sign-verification
status: final
---

# Design

## Context

动机见 proposal.md - Why。行为契约见 `specs/drink-api-signing/spec.md`。

当前 `DrinkApiService` 用 `dio` 直接拼 URL 与查询参数，没有任何签名环节：

```dart
String url = "$_baseUrl/dev/start";
Map<String, dynamic> params = {"did": deviceId, "upgrade": true, "rcp": false, "stype": 5};
Response response = await _dio.get(url, queryParameters: params, options: options);
return response.data["code"] == 0;
```

逆向官方 App 得到的算法已完整还原。实现前核对了三项外部事实：

**事实 1：签名是对编码后的字符串取 MD5**

```objc
NSString *encoded = [s stringByAddingPercentEncodingWithAllowedCharacters:allowedSet];
NSString *sign = encoded.md5String;
```

`allowedSet` 由 `URLQueryAllowedCharacterSet` 经 `removeCharactersInString:@"{}\":,"` 得到，实际放行的字符集为：

```
A-Z a-z 0-9  - . _ ~ ! $ & ' ( ) * + ; = ? @ /
```

注意 `=`、`&`、`+`、`;`、`?`、`@`、`/` **不编码**。Dart 的 `Uri.encodeQueryComponent` 把这些全部编码：

```
输入      did=123&rcp=false&upgrade=true
ObjC      did=123&rcp=false&upgrade=true
Dart      did%3D123%26rcp%3Dfalse%26upgrade%3Dtrue
```

MD5 输入不同 → 签名必然不同。这是本次唯一没有替代方案的约束。

**事实 2：dio 不排序查询参数**

dio 5.11.1 的 `encodeMap`（`lib/src/utils.dart:47`）走 `sub.forEach`，即 Map 插入序。签名序列化按字典序，两者不一致。但官方 App 同样如此——签名算排序串，URL 用原始序发，服务端只校验签名值本身。故不影响正确性，无需处理。

**事实 3：服务端错误码（实测）**

```
dev/end     → {"code":-99,"msg":"登录状态已过期"}
dev/favo    → {"code":-99,"msg":"登录状态已过期"}
acc/login/code → {"code":-100,"msg":"系统错误"}
```

`-99` 即登录态过期，是错误码区分要识别的目标。

**事实 4：`ptype` 与 `cnt` 是运行时状态**

官方 App 的 `dev/start` 发六个业务参数：`did`、`upgrade`、`ptype`、`args`、`rcp`、`cnt`。其中 `ptype`（支付类型）与 `cnt`（接水次数）来自视图控制器状态，静态分析无法确证其默认值。按 `cnt=1`、`ptype=0` 取默认，集中为命名常量，集成测试后如需调整只改一处。

`args` 对饮水设备按官方代码路径为空字符串——官方仅在 `gtype==6`（洗衣机）、`dtype==10`（吹风机）、`openType==3`（触碰开锁）三类设备上填充 JSON。

**依赖现状**：`crypto 3.0.7` 已在 `pubspec.lock` 中作为间接依赖存在，显式声明不新增传递依赖树。

## Goals / Non-Goals

**Goals:**

- 签名算法与官方逐位一致，可独立单元测试
- 签名逻辑与网络请求逻辑解耦，调用方只关心"要不要签名、用哪种"
- 序列化与编码规则集中一处，避免各接口各自拼串导致漂移
- `dev/start` 业务参数表对齐官方
- 请求头一次性对齐官方，不遗留历史头
- 服务端拒绝时区分登录过期与其他业务错误，不再一律"设备无响应"

**Non-Goals:**

- 不做 token 登录路径的 uid 补全（已知限制，见 spec 最后一条）
- 不实现洗衣机、吹风机、触碰开锁三类设备的 `args` JSON 填充逻辑
- 不引入代理、抓包或任何绕过手段
- 不改 `ui/app/dev/status` 的调用方式（该接口不带签名）
- 不做签名结果的缓存或复用
- 不做自动校时

## Decisions

### 决策 1：独立 `DrinkApiSigner`，不塞进 `DrinkApiService`

签名算法是纯函数，没有 IO、没有状态。放进 `DrinkApiService` 会让这个已有 300 行的类继续膨胀，也没法单独测。

```dart
// lib/core/services/drink_api_signer.dart
class DrinkApiSigner {
  static String serialize(Map<String, dynamic> params);
  static String shortSign(Map<String, dynamic> params);
  static String longSign(
    Map<String, dynamic> params, {
    required String token,
    required String uid,
  });
  static String objcEncode(String s);
}
```

`DrinkApiService` 构造 URL 后调用签名，把结果作为 `sign` 加进 `params`。

**备选**：作为 `DrinkApiService` 的私有方法。否决原因——无法单独测试，密钥与算法细节散落在业务类里。

### 决策 2：自实现 ObjC 兼容编码器

签名算法的 MD5 输入是 ObjC 编码后的字符串。必须复现 ObjC 的放行集，不能用 `Uri.encodeQueryComponent`。

```dart
static String objcEncode(String s) {
  final bytes = utf8.encode(s);
  final buf = StringBuffer();
  for (final b in bytes) {
    if (_isAllowed(b)) {
      buf.writeCharCode(b);
    } else {
      buf.write('%');
      buf.write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buf.toString();
}
```

放行集按 spec「请求编码规则」实现：`A-Z a-z 0-9` 加 `- . _ ~ ! $ & ' ( ) * + ; = ? @ /`。

**备选**：找一个现成的 Dart 包。否决原因——ObjC 的 `URLQueryAllowedCharacterSet` 语义特殊（放行 `=` 与 `&`），没有包精确匹配；自实现约 20 行，可控可测。

### 决策 3：签名用的序列化自己实现，不复用 dio 的输出

官方序列化规则：`key` 字典序升序 → `k=v` → `&` 连接 → 布尔转 `true`/`false` → 空值跳过。

```dart
static String serialize(Map<String, dynamic> params) {
  final keys = params.keys
      .where((k) => params[k] != null && params[k] != '')
      .toList()
    ..sort();
  return keys.map((k) {
    final v = params[k];
    final s = v is bool ? (v ? 'true' : 'false') : '$v';
    return '$k=$s';
  }).join('&');
}
```

这里只用于**签名输入**。实际发请求时 `sign` 加进 `params`，由 dio 负责编码。两条路径序列化结果一致，因为规则相同。

**备选**：强制 dio 用我们的序列化结果。否决原因——需要把整个 query string 手工拼进 URL，反而更容易出错。

### 决策 4：`sign` 作为普通查询参数加入 `params`

```dart
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
  final response = await _dio.get("$_baseUrl/dev/start",
      queryParameters: params, options: options);
  return response.data["code"] == 0;
}
```

`params` 先构造、后签名、再把 `sign` 写回同一个 Map。签名计算时 `params` 里还没有 `sign`，避免自引用。

**关键顺序约束**：签名必须在 `sign` 加入 `params` **之前**算。这个顺序靠测试锁住，否则重构时容易被打乱。

### 决策 5：`ptype` 与 `cnt` 为命名常量

```dart
static const int _paymentType = 0;   // 支付类型，官方默认值
static const int _drinkCount = 1;    // 接水次数
```

这两个值属运行时状态，静态分析无法确证。集中为常量而非散落在调用处，集成测试验证后可单点调整。

**代价**：若官方默认值不同，首次集成测试会失败。这是可接受的一次定位成本。

### 决策 6：`args` 对饮水设备恒为空字符串

官方代码路径中 `args` 仅在洗衣机（`gtype==6`）、吹风机（`dtype==10`）、触碰开锁（`openType==3`）三类设备上填充 JSON。本项目只做饮水流程，恒传空串。

**非目标**：不为其他设备类型实现 `args` 填充。

### 决策 7：`lat` / `lng` 恒为 0

官方从 `NSUserDefaults` 读 `kzySystemVerLocalLat` / `kzySystemVerLocalLng`，本项目没有任何定位写入。项目也不该为了签名去加定位权限。

`ts = 30 * ((毫秒 + lat - lng) / 30000)` 中 lat/lng 为 0 时，档位仍由服务器时间决定，客户端与服务端在同一档内即可。

**备选**：读设备 GPS 填真实值。否决原因——引入权限申请，且官方这两个值来自服务端下发的定位缓存，不是设备实时定位。

### 决策 8：MD5 用 `package:crypto`

`crypto` 已在 `pubspec.lock` 中（1.19.1）。在 `pubspec.yaml` 显式声明，从间接依赖提升为直接依赖。

```yaml
dependencies:
  crypto: ^3.0.7
```

**备选**：自己写 MD5。否决原因——无收益，`crypto` 已是传递依赖，显式声明不增加安装体积。

### 决策 9：错误码区分，不再一律"设备无响应"

当前 `startDrinking` 失败后 `home_controller.dart` 统一弹"设备无响应，请检查设备状态"。签名修好后这个提示仍会掩盖真实原因（登录过期、余额不足、设备离线）。

`DrinkApiService` 增加携带服务端 `msg` 的返回，`home_controller` 按码区分提示：`-99` 提示重新登录，其他透出服务端信息。

**边界**：只改提示文案的分发，不改交互流程。

### 决策 10：密钥硬编码在 signer 内

密钥从官方二进制还原，属逆向产物。硬编码为 `DrinkApiSigner` 的私有常量，不放进配置文件。

**已知代价**：官方换密钥时必须重新逆向并改代码。这是第三方客户端的固有属性，无法通过设计规避。

## Risks / Trade-offs

**[客户端时钟偏差导致签名失效]** → 服务端按 `30 * (毫秒 / 30000)` 校验，客户端时钟偏差超过窗口即被拒。属官方算法固有属性。缓解：设计文档与代码注释标注该约束；若后续出现集中反馈，可考虑在 UI 提示时钟同步。本次不做自动校时。

**[`ptype` 与 `cnt` 取值未确证]** → 两者为运行时状态，静态分析无法确定。按 `cnt=1`、`ptype=0` 取默认，集中为命名常量。缓解：集成测试（任务 4.3）一次定位，改动限于常量定义处。

**[官方更换密钥或算法]** → 所有请求再次失效，需要重新逆向。缓解：密钥与算法集中在 `DrinkApiSigner` 一处，更换时只改一个文件；单元测试会立即暴露不匹配。

**[ObjC 与 Dart 编码差异]** → 若编码规则实现有偏差，签名无效。缓解：自实现编码器 + 与 `Uri.encodeQueryComponent` 的差异断言测试，锁住放行集。

**[签名输入序列化与 dio 实际编码不一致]** → 签名算的是 A 串，服务端收到的是 B 串，若两者不等则签名无效。缓解：为序列化写针对性测试，锁定字典序、布尔转写、空值跳过三个行为；`sign` 加进 `params` 的顺序由测试固定。

**[`args` 空串是否被服务端接受]** → 饮水设备按官方代码路径即空串，但未实测。缓解：集成测试验证；若被拒，需重新审视饮水设备在官方分类中的归属。

**[`crypto` 提升为直接依赖影响构建]** → 已在 lock 中存在（3.0.7，间接依赖），`flutter pub get` 不引入新包。缓解：构建后确认 `pubspec.lock` 中 crypto 条目版本不变、仅 `dependency` 字段从 transitive 变为 `direct main`。

**[token 登录路径签名不完整]** → 该路径 uid 为空，长签名 uid 片段置空，服务端可能拒绝。已作为已知限制写入 spec，本次不修。缓解：该路径下发起接水失败时，提示中引导改用短信登录。

**[移除 `ApplicationType` 等头影响其他接口]** → 这些头历史上被发送但服务端不校验（逆向确认官方客户端只发三个头）。缓解：登录、设备列表、接水、结算全链路回归。

## Migration Plan

纯客户端改动，无数据迁移。

**部署**：修改 `drink_api_service.dart` 与 `home_controller.dart`，新增 `drink_api_signer.dart`，提升 `crypto` 为直接依赖。构建发布新版本。

**回滚**：还原本次改动即回到签名缺失状态。无服务端协调、无数据格式变更，回滚成本仅一次发版。

**验证顺序**：

1. 单元测试（序列化 + 两种签名 + 编码器 + 顺序约束）
2. `flutter analyze` 与 `flutter test`
3. 集成验证（真机短信登录 → 设备列表 → 开始接水 → 结算）
4. 回归（token 登录路径不崩溃）

## Open Questions

无。算法已完整还原，密钥与盐值已确认，lat/lng 处理已定，token 登录限制已定界，`ptype`/`cnt` 默认值已定并集中可调。
