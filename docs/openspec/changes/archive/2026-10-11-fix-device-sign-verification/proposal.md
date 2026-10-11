# Proposal

## Why

官方 App 3.1.8 在所有业务接口的 URL 上追加了 `?sign=<MD5>` 签名参数，服务端据此校验请求合法性。我们的 `drink_798` 客户端没有实现这套签名，`dev/start`、`dev/end` 等请求被服务端直接拒绝并返回 `code != 0`，用户看到的是"设备无响应，请检查设备状态"——而设备本身完全正常。

这不是设备故障，也不是官方关闭了接口，而是官方加强了接口验证。逆向官方 App 后已完整还原签名算法，可以在客户端复现。

## What Changes

- 新增接口签名能力 `drink-api-signing`：按官方算法对请求参数生成 `sign` 值，短签名（登录）与长签名（设备操作）两个变体
- `dev/start`、`dev/end`、`dev/favo` 请求追加 `sign` 查询参数
- `acc/login`、`acc/login/code` 请求追加 `sign` 查询参数
- 请求头对齐官方客户端：移除未使用的 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`，保留 `Authorization`、`VersionCode`、`User-Agent`
- `isDeviceAvailable` 的 `ui/app/dev/status` 按逆向结论不带 `sign`，本次不改其调用方式，仅修正其对返回码的处理

不改动：UI 层、扫码流程、设备收藏数据结构、本地存储格式。

## Capabilities

### New Capabilities

- `drink-api-signing`: 惠生活798接口签名能力。定义参数序列化规则、密钥派生、短签名与长签名两种算法，以及哪些接口必须携带 `sign` 参数。

### Modified Capabilities

无。项目此前没有任何 OpenSpec 规格，本次新建第一个能力规格。

## Impact

**涉及代码**

- `lib/core/services/drink_api_service.dart` — 全部改动集中在此
- 新增 `lib/core/services/drink_api_signer.dart`（或同等命名）— 签名算法实现

**涉及接口**

| 接口 | 签名变体 | 现状 |
| --- | --- | --- |
| `dev/start` | 长签名 | 被拒，界面提示"设备无响应" |
| `dev/end` | 长签名 | 被拒，界面提示"结算可能未成功" |
| `dev/favo` | 长签名 | 收藏/取消收藏失败 |
| `acc/login` | 短签名 | 登录失败 |
| `acc/login/code` | 短签名 | 短信验证码下发失败 |
| `checkToken` | 长签名 | 客户端未调用，仅说明 |
| `ui/app/dev/status` | 不带签名 | 行为不变 |

**依赖**

- 需要 Dart 侧 MD5 实现。`crypto 3.0.7` 已作为间接依赖存在于 `pubspec.lock`，显式声明为直接依赖即可，不新增传递依赖树。

**已知限制（非本次目标）**

- "使用已有 Token 登录"路径把 `uid` 存为空字符串。长签名需要 `uid` 后 8 位，官方 App 在 `uid` 不足 8 位时退化为空串拼接。此路径下签名与服务端预期不一致，能否成功未经验证。本次只保证短信验证码登录路径可用；token 登录用户如需接水，需改用短信登录。此限制记录在案，不在本次修复范围内。

**风险**

- 签名依赖服务器时间窗口（`ts = 30 * (毫秒 / 30000)`，30 秒一档）。客户端时钟偏差超过窗口时签名失效。属官方算法固有属性，客户端无法规避，但应在设计文档中说明。
- 签名算法中的密钥与盐值从官方 App 二进制还原。官方后续版本可能更换密钥，届时需重新逆向。
