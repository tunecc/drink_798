# 验证报告：fix-device-sign-verification

- Change: fix-device-sign-verification
- 日期: 2026-10-11
- verify_mode: full
- review_mode: standard
- 基线: 3d85201 → HEAD 85d73de
- 改动: 8 文件，+843 / -35

## 问题背景回顾

官方 App 3.1.8 对 `dev/start`、`dev/end`、`dev/favo`、`acc/login`、`acc/login/code` 追加 `?sign=<MD5>` 签名参数，客户端未实现导致服务端拒绝请求，界面提示「设备无响应，请检查设备状态」——而设备本身正常。

逆向已完整还原签名算法（密钥 `eZ`/`kzyZ`/`null`/`hn`，短签名与长签名两个变体，ObjC 兼容百分号编码）。

---

## 一、Completeness（完整性）

| 项 | 结果 |
|---|---|
| tasks.md 任务完成 | 19/19 已勾选 `[x]` |
| delta spec 需求数 | 11 条 |
| delta spec 场景数 | 33 个 |
| 变更文件与 tasks 描述一致 | 是 |

tasks.md 中「已知限制」一节记录了原 4.3/4.4/4.5 三项真机验证，经用户确认从任务清单移出，**不视为已验证**。

---

## 二、Correctness（正确性）

### 需求实现映射

| 需求 | 实现位置 | 状态 |
|---|---|---|
| 参数序列化规则 | `drink_api_signer.dart:24` `serialize` | ✓ |
| 请求编码规则 | `drink_api_signer.dart:41` `objcEncode` | ✓ |
| 密钥派生 | `drink_api_signer.dart:83-86` `key1..key4` | ✓ |
| 短签名计算 | `drink_api_signer.dart:104` `shortSign` | ✓ |
| 长签名计算 | `drink_api_signer.dart:127` `longSign` | ✓ |
| 设备启动参数表 | `drink_api_service.dart:293` `startDrinking` | ✓ |
| 签名附加到请求 | `drink_api_service.dart` 5 处 | ✓ |
| 接口签名类型映射 | GET 走 `queryParameters`，POST 拼 URL | ✓ |
| 请求头对齐 | `drink_api_service.dart:52` `BaseOptions.headers` | ✓ |
| 服务端拒绝时的错误呈现 | `home_controller.dart:26` `drinkFailurePrompt` | ✓ |
| token 登录路径的限制 | `serialize` 空值跳过 + 降级路径 | ~ 部分 |

### 场景覆盖

**32/33 个场景有测试覆盖。**

唯一切换为真机验证的场景：`token 登录可查看设备列表`（需可用账号与设备，见已知限制）。

部分覆盖：`token 登录下设备操作签名不完整` —— `serialize` 空值跳过与 `longSign` uid 空串两个降级行为均有测试，但「服务端是否拒绝」需真机确认。

### 关键正确性验证

**签名算法交叉验证**：Dart 实现与 Python 独立实现（同一算法、ObjC 放行集编码）逐位一致：

```
un=22644212509&authCode=123456  → d75a96c18f30e951079f27df9c672c65
六参 dev/start 形状             → 2dff0e2f79d7a174de7bfc26930c9003
token/uid 不足 8 位降级         → 6d5b7c026507132337fd0acda2926e0f
```

**编码规则验证**：测试断言 ObjC 编码器与 Dart 的 `Uri.encodeQueryComponent` 结果不同（`did=123&rcp=false` vs `did%3D123%26rcp%3Dfalse`）。这是本次修复的技术核心——若误用 Dart 标准函数，签名必然无效。

**顺序约束验证**：测试证明「先算签名后加 sign」与「先加 sign 后算」结果不同，防止重构打乱顺序。

---

## 三、Coherence（一致性）

### Design Doc 决策落实

| 决策 | 落实 |
|---|---|
| 1. 独立 `DrinkApiSigner` | ✓ 独立文件，纯静态方法 |
| 2. 自实现 ObjC 兼容编码器 | ✓ `objcEncode` |
| 3. 序列化自行实现 | ✓ `serialize`，不复用 dio 输出 |
| 4. `sign` 作为查询参数 | ✓ 3 处 `params["sign"]`，先算后加 |
| 5. `ptype`/`cnt` 命名常量 | ✓ `_paymentType=0`、`_drinkCount=1` |
| 6. `args` 饮水设备空串 | ✓ |
| 7. `lat`/`lng` 恒 0 | ✓ `_timeTick` 内常量 |
| 8. MD5 用 `package:crypto` | ✓ `crypto: ^3.0.7` |
| 9. 错误码区分提示 | ✓ `drinkFailurePrompt` |
| 10. 密钥硬编码 | ✓ 私有常量，无日志外泄 |

### Spec 与 Design 无矛盾

Build 阶段扩大了范围（`dev/start` 业务参数表对齐官方六项），已通过 Spec Patch 回写 delta spec（新增「设备启动参数表」需求 + 修改「签名附加到请求」场景）与 design.md，无残留矛盾。

### 代码模式一致性

新代码遵循项目既有风格：dart 文件置于 `lib/core/services/`，测试镜像置于 `test/core/services/`，命名与既有 `DrinkApiService` 一致，注释用中文。

---

## 四、集成代码审查（review_mode: standard）

对最终 diff（3d85201..85d73de）执行了独立审查。

### 审查发现

**无 CRITICAL 问题。**

**无 IMPORTANT 问题。**

**SUGGESTION（不阻断，记录在案）:**

1. `drink_api_signer.dart:83-86` 四个密钥摘要为公开静态字段。这些是从官方二进制还原的固定常量，无安全含义（官方 App 同样硬编码且仅做 XOR 混淆），但公开暴露了内部细节。影响：无实际风险；若在意可改为私有 + 仅供内部使用。**决定：保持公开**，测试需断言其值，且逆向产物不构成秘密。

2. `drink_api_service.dart:60` `setHttpClientAdapter` 是仅为测试添加的公开方法。影响：生产 API 面多一个方法。**决定：保留**，已注释标明用途，是无注入点时断言真实请求形状的唯一途径。

3. `drink_api_signer.dart:136` 长签名用字符串插值拼接，`_keyFragments()` 用 `StringBuffer`。两处写法不一致。影响：无可读性问题。**决定：保留**，插值写法更短且 `flutter analyze` 通过。

### 安全检查

| 项 | 结果 |
|---|---|
| 硬编码密钥 | 是，但属逆向产物，design.md 决策 10 明确记录 |
| 动态代码执行 | 无 |
| 进程调用 | 无 |
| 日志外泄密钥/token | 无 |
| 不安全 IO | 无 |

---

## 五、检查命令与结果

| 命令 | 结果 |
|---|---|
| `flutter analyze` | `No issues found! (ran in 2.8s)` |
| `flutter test --no-pub` | `40/40 All tests passed` |
| `comet guard build --apply` | 14/14 PASS |

---

## 六、未验证项（需真机与可用账号）

以下三项已从 tasks.md 移出并记录为已知限制，**本次未验证**：

1. **真机集成验证**：短信登录 → 设备列表 → 开始接水 → 结算全链路。已由单元测试覆盖的部分：请求形状（六个业务参数 + `sign` + 三个请求头）、签名值经独立复算一致。
2. **`ptype` 与 `cnt` 取值核对**：当前 `ptype=0`、`cnt=1`。这两个值来自官方 App 运行时状态，静态分析无法确证。若真机接水被拒，调整 `DrinkApiService._paymentType` / `_drinkCount` 两个常量即可，改动限于一处。
3. **token 登录路径回归**：uid 为空导致长签名 uid 片段置空，服务端可能拒绝。已由测试覆盖的部分：`serialize` 空值跳过、`drinkFailurePrompt` 无服务端信息时退回 fallback。需真机确认不崩溃且提示引导改用短信登录。

---

## 结论

| 维度 | 状态 |
|---|---|
| Completeness | 19/19 任务，11 需求，33 场景 |
| Correctness | 32/33 场景有测试覆盖，签名算法经独立复算验证 |
| Coherence | 10/10 设计决策落实，spec 与 design 无矛盾 |
| 集成审查 | 无 CRITICAL，无 IMPORTANT，3 项 SUGGESTION 已记录 |
| 安全检查 | 通过 |

**无 CRITICAL 或 IMPORTANT 问题。**

验证通过。3 项真机验证因缺少可用账号与设备未执行，已明确记录为已知限制，不视为已验证。
