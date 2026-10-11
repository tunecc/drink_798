# Tasks

## 1. 签名模块

- [x] 1.1 在 `pubspec.yaml` 的 `dependencies` 中显式声明 `crypto: ^3.0.7`，执行 `flutter pub get`，确认 `pubspec.lock` 中 crypto 仍为 3.0.7 且未引入新的传递依赖 <!-- comet-task:42585f1e-4356-445e-98f1-0ee3af43474a -->
- [x] 1.2 创建 `lib/core/services/drink_api_signer.dart`，实现 `serialize`：参数键字典序升序、`k=v` 以 `&` 连接、布尔转 `true`/`false`、空值跳过，并写单元测试覆盖 spec「参数序列化规则」三个场景（含 `{"did":"123","upgrade":true,"rcp":false}` → `did=123&rcp=false&upgrade=true`） <!-- comet-task:8a819ae2-9d75-4831-97bf-550d54e20865 -->
- [x] 1.3 实现 ObjC 兼容编码器 `objcEncode`：放行 `A-Z a-z 0-9` 加 `- . _ ~ ! $ & ' ( ) * + ; = ? @ /`，其余按 UTF-8 逐字节转 `%XX`，写测试覆盖 spec「请求编码规则」三个场景（等号与和号不编码、特殊字符逐字节编码、与 `Uri.encodeQueryComponent` 结果不同） <!-- comet-task:18ae2623-b303-4e62-b87c-57efae11168f -->
- [x] 1.4 实现密钥派生：四个常量 `eZ`/`kzyZ`/`null`/`hn` 的 MD5 作为 `k1`-`k4`，写测试断言四个摘要值与手算一致 <!-- comet-task:4ae4de1e-5649-493d-8601-5ef0ea8d7f44 -->
- [x] 1.5 实现 `shortSign`：按 `序列化参数 + k1[1] + k2[25].upper() + k3[0] + k4[18] + k2[21] + k3[23] + k1[15] + "dF6hJ9kL2nP" + "rT8wY1" + "G" + "iM7oQ" + "v"` 拼接，先经 `objcEncode` 再取 MD5，写测试覆盖 spec「短签名计算」两个场景（可复现、不含时间与身份信息） <!-- comet-task:43b69d81-4f8f-411b-9c0f-4f472fe55342 -->
- [x] 1.6 实现 `longSign`：在短签名拼接基础上，于序列化参数后插入 `ts`、token 后 8 位、uid 后 8 位，其中 `ts = 30 * ((毫秒 + lat - lng) / 30000)` 取整、lat/lng 恒 0，写测试覆盖 spec「长签名计算」五个场景（含时间档位、同档一致、跨档不同、token 不足 8 位置空、uid 空串） <!-- comet-task:10c14c00-c74e-41c2-91cb-d16ca251fca2 -->
- [x] 1.7 写测试固定「签名先于 sign 入参计算」的顺序约束：构造与 `startDrinking` 相同的参数 Map，断言签名结果与手动按顺序计算一致，防止重构打乱顺序 <!-- comet-task:b302c4fa-22c2-4289-b86d-9cb2430c88a0 -->

## 2. 接口接入

- [x] 2.1 改造 `startDrinking`：业务参数改为 `did`、`upgrade`、`ptype`、`args`、`rcp`、`cnt` 六项（`ptype=0`、`cnt=1`、`args` 空串，定义为命名常量），去掉 `stype`；先算长签名再把 `sign` 写回同一 Map，用 dio 带 `queryParameters` 发请求，并验证 spec「设备启动参数表」四个场景与「签名附加到请求」第一个场景 <!-- comet-task:47e6459c-4dc0-482d-881a-7458c5708797 -->
- [x] 2.2 改造 `stopDrinking`：参数仅 `did`，追加长签名 `sign` <!-- comet-task:7082daf9-76e5-42fd-a15f-2d331da6255d -->
- [x] 2.3 改造 `toggleFavoriteDevice`：追加长签名 `sign` <!-- comet-task:6ba05c49-533b-49fe-a52a-5d617dcc6dfc -->
- [x] 2.4 改造 `sendSmsCode`：改用短签名 `DrinkApiSigner.shortSign` <!-- comet-task:662baa52-a23e-4579-ba85-2d5d2d785c06 -->
- [x] 2.5 改造 `login`：改用短签名 `DrinkApiSigner.shortSign` <!-- comet-task:75512d19-7d6a-4d74-93b3-788ffaa742bc -->
- [x] 2.6 检查 `getDeviceList`、`isDeviceAvailable`、`getCaptcha`、`loginWithToken`：确认 `ui/app/master`、`ui/app/dev/status`、`captcha` 按逆向结论不带签名、调用方式不变，若有误一并修正 <!-- comet-task:54f620d5-482a-4037-ab74-6d995508729a -->

## 3. 请求头与错误呈现

- [x] 3.1 收敛 `DrinkApiService` 的 `BaseOptions.headers`，只保留 `VersionCode` 与 `User-Agent`，移除 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`，写测试断言请求头集合符合 spec「请求头对齐」三个场景 <!-- comet-task:e08ae155-eb33-4f86-8084-0613719cd04e -->
- [x] 3.2 让服务端返回的 `msg` 能透出：`startDrinking`/`stopDrinking` 在 `code != 0` 时携带服务端错误信息返回，而非只返回 `false` <!-- comet-task:0afe58b1-280a-4056-8e1d-aacb7a5e2c37 -->
- [x] 3.3 改 `home_controller.dart` 的提示分发：`code == -99` 提示重新登录，其他业务错误透出服务端信息，不再一律提示「设备无响应，请检查设备状态」，覆盖 spec「服务端拒绝时的错误呈现」两个场景 <!-- comet-task:b1aab188-94e5-4d64-89e7-496f187aedb9 -->

## 4. 验证

- [x] 4.1 执行 `flutter analyze`，确认无新增告警 <!-- comet-task:7bfafe45-a3f0-4701-8a53-c0f0d9badb47 -->
- [x] 4.2 执行 `flutter test`，确认签名模块测试与既有测试（`drink_api_service_corrupt_token_test.dart`、`drink_api_service_init_test.dart`、`device_order_test.dart`）全部通过 <!-- comet-task:cccd1a7f-4cc0-4d25-b960-d20aae9e152f -->
- [x] 4.6 用 `curl` 复现签名缺失时的服务端返回，与修复后客户端实际请求的 `sign` 值比对，确认签名算法与服务端预期一致 <!-- comet-task:f361a968-3743-49ff-84ae-73b8506a4fab -->

## 已知限制（原 4.3 / 4.4 / 4.5，需真机与可用账号，本次未执行）

以下三项需要可用的惠生活798账号（手机号 + 短信验证码）与在线饮水设备，无法在无凭据环境下完成。经用户确认从任务清单移出，记录为已知限制，不视为已验证：

- **真机集成验证**：短信登录 → 设备列表 → 开始接水 → 结算的全链路。已验证的部分：请求形状（六个业务参数 + `sign` + 三个请求头）由单元测试断言，签名值经 Python 独立复算一致。
- **`ptype` 与 `cnt` 取值核对**：当前取默认 `ptype=0`、`cnt=1`，定义为 `DrinkApiService._paymentType` 与 `_drinkCount` 命名常量。这两个值来自官方 App 的运行时状态，静态分析无法确证；若真机接水被拒，按服务端返回调整这两个常量即可，改动限于一处。
- **token 登录路径回归**：该路径 uid 为空，长签名 uid 片段置空，服务端可能拒绝。已验证的部分：`serialize` 对空值的跳过行为有测试覆盖，`drinkFailurePrompt` 对无服务端信息时退回 fallback 有测试覆盖。需真机确认不崩溃且提示引导改用短信登录。
