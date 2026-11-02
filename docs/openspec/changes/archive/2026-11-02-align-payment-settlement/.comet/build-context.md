# Build Context: align-payment-settlement

## Response-shape fixtures（任务 1.1 记录）

来源：参照项目 life-798（WaterWidget）已核验代码，与 design.md D3/D4 一致。

- 钱包余额 `GET /acc/wallet/owner` → `data.aw`（主钱包条目）+ `data.eps[]`（分端点钱包），条目含 `id`（端点）、`ownerId`、`balance`（元）。选择语义对齐 `WalletResponseParser.dashboardBalance(response, account.eid)`：端点匹配账户 eid 的唯一条目优先；否则仅当全部条目唯一时采用；无法唯一判定不猜（返回 null）。
- 积分余额 `GET /acc/score/acc-score` → `data.validScore`（可用积分）、`data.totalScore`。
- 账单列表 `GET /bill/lst-owner?page=0&size=20` → `data.records[]`，结算饮水账单 `type=91`/`status=3`/`cata=6`（cata 存在时），`payment`（钱包支付部分，元），`dev.id`/`did` 设备引用，`utime`/`ctime`（秒或毫秒自动归一）。
- 账单详情 `GET /bill/view-full?id=<billId>` → `data.bill`，积分抵扣仅在详情的 `promo.type=4` / `discount`。列表不含 promo；积分全额抵扣时列表 `payment=0`。

fixtures 内联于 `test/core/services/drink_api_service_bill_balance_test.dart`（钱包三种形态 / 积分 / 列表 / 详情）与 `test/features/home/home_page_ui_test.dart`（结算上报组）。

## TDD 证据（autonomous + tdd）

每个实现任务 RED→GREEN 均以真实 `flutter test` 命令执行：

- 任务 1.2/1.3：RED = 编译失败（walletBalance/billDetail/SettlementBillParser 未定义，失败原因即待实现行为）；GREEN = `flutter test test/core/services/drink_api_service_bill_balance_test.dart` 14/14。
- 任务 2.1：RED = 4 个新码断言失败（透传服务端 msg）；GREEN = `flutter test test/features/home/drink_failure_prompt_test.dart` 7/7。
- 任务 2.2：RED = 反转断言失败（startCalls=2、startPtypes=[91,21]、无充值提示）；GREEN = `flutter test test/features/home/` 65/65。
- 任务 2.3/3.1/3.2：RED = walletBalance 等字段未定义；GREEN = 结算上报组 9/9。期间修复两处非本次范围的既有故障：① 旧 build/ 缓存 shader 资产与新 SDK 不兼容（flutter clean 解决，干净树复现确认）；② double-tap 测试新增的结算上报 Timer 窗口（15s 自停）未泵尽导致 pending-timer 断言（测试补泵 16s，实现本身有界）。
- 任务 4.1：RED = balanceSectionKey 未定义；GREEN = 余额区组 4/4。
- 任务 5.1：`flutter analyze` 2 条存量 deprecation info（干净树已有，SDK 演进所致，不在本次 diff 内）；`flutter test` 171/171。

## 实现偏差记录

- 设计 D5 原文写"AccountBalance 模型承载 yuan+points"，实现为 `AccountBalance(walletYuan, score)` 双可空字段 + `accountBalance()` 并行拉取两接口组合返回——与设计意图（解析与 UI 解耦、可空降级）一致。
- 钱包条目选择按参照项目实测语义实现（eid 匹配优先、唯一才用），比 Open 阶段口头方案更严格。
- idle 自动结算的结算上报仅在会话起点存在（本人发起的会话）时执行，且起点「读取即清除」——预检接管他人的会话不归属本次上报，也不会复用上一次会话的起点。

## 独立审查（review_mode: standard，复查 1 轮上限）

初审（独立 reviewer 子代理）：**CHANGES_REQUIRED**——I-1 刷新失败把已展示余额清成占位符（违反 account-balance spec 的 Refresh failure 场景）；I-2 `_sessionStartedAt` 从不复位，接管他人会话会复用旧起点误上报。另有 M-1 过时注释、M-2 validScore 小数被拒、M-3 未登录多余空隙、M-4 fake 死代码与 S-1 Completer 死重等。

复审修复：I-1 非空才赋值 + 回归测试；I-2 读取即清除 + void 化（顺带 S-1）+ 回归测试（FakeHomeApiService 新增 statusQueue 驱动两次会话）；M-1~M-4 全部修复。S-2（纯钱包文案）、S-3（时钟 slack）未采纳，理由：S-2 钱包段与总额重复无信息增益；S-3 失败方向安全（静默不报符合 spec），不加 slack 以保持 spec 字面语义。

复审后：`flutter test` 173/173（含 2 条新回归测试），`flutter analyze` 仅 2 条存量 deprecation info。

## 任务 5.2 真机集成检查（用户执行，2026-11-02）

测试包：`releases/drink_798_v1.0.7-test-align-payment_android_arm64-v8a.apk`（v1.0.7+7 release，arm64，SHA-256 前 16 位 d056091dbd8d1948）。

用户报告：**测试通过**。覆盖清单：主页余额条展示、结算后消费明细提示（含积分抵扣拆分）与余额刷新、欠费场景不重试支付宝、未登录隐藏余额条。无异常上报。
