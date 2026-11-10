---
change: align-score-deduction
design-doc: docs/openspec/changes/align-score-deduction/design.md
base-ref: e61f6f4fff769a194de3902c7a647f0aa6690cdf
archived-with: 2026-11-10-align-score-deduction
---

# Score Deduction Switch Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Task progress is tracked in the Comet task authority file.

<!-- comet-task-authority: docs/openspec/changes/align-score-deduction/tasks.md -->

**Goal:** Make the server actually deduct score during water sessions by syncing the account-level score-deduction switch (`acc/upt` `useScore=1`) before every wallet-paid start, aborting the start when the sync fails.

**Architecture:** One new unsigned POST method (`setUseScore`) on `DrinkApiService`, called from `HomeController.startDrinking` after the device precheck and before the single `dev/start` request; any sync failure surfaces a dedicated prompt and skips the start. Adopt/takeover and settlement flows are untouched.

**Tech Stack:** Dart, Flutter, dio, `flutter_test` with the existing capturing-adapter and `FakeHomeApiService` widget-test harness.

**Spec:** `docs/openspec/changes/align-score-deduction/specs/payment-settlement/spec.md` and `design.md`.

## Global Constraints

- Request: `POST acc/upt`, JSON body exactly `{"useScore":1}` — no other keys (partial-update semantics of `acc/upt` are unverified; mirror the reference body verbatim).
- Headers: `Authorization` via `_authOptions()` plus the global `VersionCode: 3.1.8` / `User-Agent: Android_ilife798_3.1.8`; MUST NOT carry `ApplicationType`; MUST NOT carry `sign` (query or body).
- `Content-Type: application/json` on the sync request (same as `acc/login` / `acc/login/code`).
- Sync fires only when a start request is about to be sent; the adopt/takeover path sends no sync.
- Any sync failure — DioException or server `code != 0` — ends the attempt: dedicated prompt, no `dev/start`, no automatic retry (including `-98`).
- Existing behaviors untouched: `ptype=91` only, no payment-method fallback, rejection prompts (-52/-82/-87/-88/-99), bill reporting, balance display.
- No new dependencies.

## Review Focus

- A failed sync must never leak into a start request — the user must not be charged without deduction silently (pinned by both failure tests).
- Extra body keys on `acc/upt` could reset unknown account fields — the body-keys assertion pins `{"useScore":1}` exactly.
- `ApplicationType` or `sign` reappearing on the sync request would contradict the approved channel (pinned by header/query assertions).
- The busy-device adopt path must not gain a sync call (pinned by the adoption test).
- The sync failure prompt must be distinct from the generic "设备无响应" copy so the user can tell the two failures apart (checked by prompt-text assertion in the failure tests).

---

### Task 1: `setUseScore` API method (task 1.1)

<!-- comet-task-ref:1411c31a-2aa0-4260-8742-49faf38509af -->

**Files:**
- Modify: `lib/core/services/drink_api_service.dart`
- Test: `test/core/services/drink_api_service_request_test.dart`

**Interfaces:**
- Produces: `Future<DrinkResult> setUseScore({int value = 1})` — resolves via `_toResult`, network errors return `const DrinkResult(success: false)`.
- Consumes: existing `_authOptions()`, `_toResult`, `_baseUrl` (no new members beyond the method).

- **Step 1: Write the failing tests** in the `drink_api_service_request_test.dart` main block as a new group:

```dart
group('DrinkApiService.setUseScore 请求形状', () {
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

  test('POST acc/upt 且 body 恰为 {"useScore":1}', () async {
    final api = DrinkApiService();
    await api.isLoggedIn();
    await api.setUseScore();

    expect(adapter.captured?.method, 'POST');
    expect(adapter.captured?.uri.path, '/api/v1/acc/upt');
    expect(adapter.captured?.data, {'useScore': 1});
  });

  test('携带 Authorization 与 application/json,不带 ApplicationType 与 sign', () async {
    final api = DrinkApiService();
    await api.isLoggedIn();
    await api.setUseScore();

    expect(adapter.captured?.headers['Authorization'], 'abcdefgh12345678');
    expect(adapter.captured?.contentType, contains('application/json'));
    expect(adapter.captured?.headers.containsKey('ApplicationType'), isFalse);
    expect(adapter.captured?.data.containsKey('sign'), isFalse);
  });

  test('服务端非零 code 返回失败结果', () async {
    adapter.responseBody = '{"code":-98,"msg":"操作频繁"}';
    final api = DrinkApiService();
    await api.isLoggedIn();
    final result = await api.setUseScore();

    expect(result.success, isFalse);
    expect(result.code, -98);
    expect(result.message, '操作频繁');
  });

  test('网络异常返回失败结果', () async {
    DrinkApiService().setHttpClientAdapter(_ThrowingAdapter());
    final api = DrinkApiService();
    await api.isLoggedIn();
    final result = await api.setUseScore();

    expect(result.success, isFalse);
  });
});
```

- **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/core/services/drink_api_service_request_test.dart`
Expected: FAIL — `setUseScore` isn't defined on `DrinkApiService`.

- **Step 3: Implement `setUseScore` in `drink_api_service.dart`** next to `startDrinking`:

One paragraph of approach: mirror the `startDrinking` body pattern — build URL from `_baseUrl`, await `_authOptions()`, `_dio.post(url, data: data, options: options)`, return `_toResult(response.data)` inside `try`, `catch` returning `const DrinkResult(success: false)`. Signature `Future<DrinkResult> setUseScore({int value = 1})` with `data: {"useScore": value}`; no query parameters, no extra headers beyond `_authOptions()` (dio sets `Content-Type: application/json` from the Map body, matching the login POSTs). Comment cites the evidence: server cascade needs `useScore=1` + `ptype=91`; official iOS binary has no `ApplicationType`.

- **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/core/services/drink_api_service_request_test.dart`
Expected: PASS (all groups).

- **Step 5: Commit**

```bash
git add lib/core/services/drink_api_service.dart test/core/services/drink_api_service_request_test.dart
git commit -m "feat: add unsigned acc/upt setUseScore for score-deduction switch"
```

---

### Task 2: Sync-before-start wiring with abort-on-failure (task 2.1)

<!-- comet-task-ref:a38616c5-636f-4b58-82f8-76e507e6c890 -->

**Files:**
- Modify: `lib/features/home/home_controller.dart` (start flow only, around lines 405-413)
- Modify: `test/features/home/fake_home_api_service.dart`
- Test: `test/features/home/home_page_ui_test.dart`

**Interfaces:**
- Consumes: `Future<DrinkResult> setUseScore({int value = 1})` from Task 1.
- Produces: `FakeHomeApiService` gains `setUseScoreResult` (default `DrinkResult(success: true, code: 0)`), `setUseScoreCalls` counter, and `callLog` recording `'setUseScore'` / `'startDrinking'` / `'stopDrinking'` in order; `startDrinking`/`stopDrinking` overrides append to the same log.

- **Step 1: Extend the fake + write the failing widget tests** in `home_page_ui_test.dart` (primary-action group):

Fake additions (constructor param `this.setUseScoreResult = const DrinkResult(success: true, code: 0)`; fields `int setUseScoreCalls = 0;` and `final List<String> callLog = [];`; override):

```dart
@override
Future<DrinkResult> setUseScore({int value = 1}) async {
  setUseScoreCalls++;
  callLog.add('setUseScore');
  return setUseScoreResult;
}
```

…and append `'startDrinking'` / `'stopDrinking'` inside the existing overrides.

New tests:

```dart
testWidgets('a wallet start syncs the score switch first', (tester) async {
  final api = await pumpHomePage(tester);
  await tester.tap(find.byKey(primaryActionKey));
  await tester.pump();

  expect(api.setUseScoreCalls, 1);
  expect(api.callLog, ['setUseScore', 'startDrinking'],
      reason: '同步必须先于启动请求完成');
  await dismissSnack(tester);
});

testWidgets('a failed sync aborts the start without it', (tester) async {
  final api = await pumpHomePage(
    tester,
    api: FakeHomeApiService(
      setUseScoreResult: const DrinkResult(
        success: false,
        code: -98,
        message: '操作频繁',
      ),
    ),
  );
  final controller = Get.find<HomeController>();

  await tester.tap(find.byKey(primaryActionKey));
  await tester.pump();
  await tester.pump();

  expect(api.setUseScoreCalls, 1);
  expect(api.startCalls, 0, reason: '同步失败不得发送启动请求');
  expect(controller.isDrinking.value, isFalse);
  expect(find.textContaining('积分抵扣开关同步失败'), findsOneWidget,
      reason: '同步失败要有可分辨的专用提示');
  await dismissSnack(tester);
});

testWidgets('adopting a busy device sends no sync', (tester) async {
  final api = await pumpHomePage(
    tester,
    api: FakeHomeApiService(
      // 预检返回非空闲(geneStatus != 99 视为运行中)→ 走接管分支。
      precheckStatus: const DeviceStatus(deviceStatus: 1, geneStatus: 1),
    ),
  );
  await tester.tap(find.byKey(primaryActionKey));
  await tester.pump();

  expect(api.setUseScoreCalls, 0, reason: '接管路径不发起启动,也不同步开关');
  expect(api.startCalls, 0);
  await dismissSnack(tester);
});
```

(Adapt `find.textContaining` copy if the final prompt wording differs — the pinned prefix is 「积分抵扣开关同步失败」.)

- **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/features/home/home_page_ui_test.dart`
Expected: FAIL — the fake's `setUseScore` override never fires (`setUseScoreCalls` stays 0) because the controller doesn't call it yet.

- **Step 3: Wire the sync into `HomeController.startDrinking`**

After the precheck block (after the adopt branch returns, before `final startedAt = DateTime.now();`):

```dart
// 服务端级联只有账户级积分抵扣开关(useScore)开启时才扣积分。
// 每次启动前先同步开关;失败则中止本次启动,绝不在开关未开时静默扣款。
final sync = await _apiService.setUseScore();
if (!sync.success) {
  _fail(sync, fallback: '积分抵扣开关同步失败，本次未开始接水');
  return;
}
```

The adopt branch (busy device) returns earlier and must stay above this code. No retry loop; `-98` follows the same abort path.

- **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/features/home/home_page_ui_test.dart`
Expected: PASS — including the pre-existing start/settle and rejection tests (the fake defaults keep them green).

- **Step 5: Commit**

```bash
git add lib/features/home/home_controller.dart test/features/home/fake_home_api_service.dart test/features/home/home_page_ui_test.dart
git commit -m "feat: sync score-deduction switch before wallet start, abort on failure"
```

---

### Task 3: Full regression run (task 3.1)

<!-- comet-task-ref:78732593-6827-432d-b4e7-bb044be0a094 -->

**Files:** none (verification only)

- **Step 1: Run the whole suite**

Run: `fvm flutter test`
Expected: PASS — zero failures across request-shape, signer, controller/UI, and login tests.

- **Step 2: Record the result**

Paste the tail of the run into the verification notes (task 3.1 checkbox stays with the task authority file).

---

### Task 4: Real-device deduction-chain verification (task 3.2)

<!-- comet-task-ref:7abe0898-474d-49a8-99ac-b81d0c25149a -->

**Files:** none (manual verification; outcome recorded in the Verify report)

- **Step 1: On a real device with score > 0**, start a session and let it settle. Confirm: the bill shows `promo.type=4`/`discount` > 0, the score balance decreased, the wallet/Alipay part covers only the remainder.
- **Step 2: Account-safety check**: after the same start, confirm account name/avatar and wallet balances are unchanged (guards the `acc/upt` partial-body risk).
- **Step 3: Negative check**: with the sync forced to fail (airplane mode before tapping start), confirm the app shows the dedicated prompt and sends no start request (settlement bill list gains no new type=91 entry).

If device verification is not possible in this session, record the blocker in the task and leave task 3.2 unchecked for the user to complete before release.
