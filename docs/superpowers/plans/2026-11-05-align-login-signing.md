---
change: align-login-signing
design-doc: docs/openspec/changes/align-login-signing/design.md
base-ref: 1258918045f582dc81d07489ffabab2154fbf7ca
---

# Login Signing Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Task progress is tracked in the Comet task authority file.

<!-- comet-task-authority: docs/openspec/changes/align-login-signing/tasks.md -->

**Goal:** Make `acc/login` carry the official signature and the client identity the server validates, so phone/SMS login works again.

**Architecture:** A dedicated `loginSign` computation in `DrinkApiSigner` (serialize → append fixed constant → objc-encode → MD5), applied by `DrinkApiService.login` with per-request iOS identity headers and a two-field body. Device long-signing and the global Android 3.1.8 headers are untouched.

**Tech Stack:** Dart, Flutter, dio, `flutter_test` with a capturing `HttpClientAdapter`.

**Spec:** `docs/openspec/changes/align-login-signing/specs/drink-api-signing/spec.md` and `design.md`.

## Global Constraints

- `LOGIN_SALT = "aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v"` — verbatim.
- Login vector: `authCode=123456`, `un=13800138000` → `93f9b2ec2c30df3ef4c8b9caeea3013b`.
- Login identity headers: `User-Agent: iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9`, `VersionCode: 3.1.9`, no `ApplicationType`.
- Login body keys: exactly `authCode` and `un`.
- Non-login requests keep `VersionCode: 3.1.8` and `User-Agent: Android_ilife798_3.1.8`.
- `acc/login/code` and `ui/app/dev/status` carry no `sign`.
- No new dependencies.

## Review Focus

- Empty or missing `smsCode` must not silently sign a placeholder — the request still fails as before.
- A login body that accidentally keeps `openCode` would change the signed set; the body-keys assertion pins it.
- Global headers leaking into the login request (e.g. `ApplicationType`) would be rejected by the server.
- Non-login requests must not pick up the iOS identity.
- Constant drift: the vector test is the single failure signal.

---

### Task 1: Login signature computation (task 1.1)

<!-- comet-task-ref:028c2d09-aa57-486a-b483-8152b1c4fb2c -->

**Files:**
- Modify: `lib/core/services/drink_api_signer.dart`
- Test: `test/core/services/drink_api_signer_test.dart`

**Interfaces:**
- Produces: `static String loginSign(Map<String, dynamic> params)`; `static const String LOGIN_SALT`.

- **Step 1: Write the failing test**

```dart
group('DrinkApiSigner.loginSign', () {
  test('matches the verified vector', () {
    expect(
      DrinkApiSigner.loginSign({'authCode': '123456', 'un': '13800138000'}),
      '93f9b2ec2c30df3ef4c8b9caeea3013b',
    );
  });

  test('changes when the sms code changes', () {
    expect(
      DrinkApiSigner.loginSign({'authCode': '111111', 'un': '13800138000'}),
      isNot(DrinkApiSigner.loginSign({'authCode': '222222', 'un': '13800138000'})),
    );
  });
});
```

- **Step 2: Run it and confirm RED**

Run: `flutter test test/core/services/drink_api_signer_test.dart`
Expected: FAIL — `loginSign` is not defined.

- **Step 3: Implement**

In `DrinkApiSigner`, next to the other signing members:

```dart
static const String LOGIN_SALT = 'aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v';

/// 登录签名：序列化参数后追加官方登录固定串，按官方编码规则编码后取 MD5。
static String loginSign(Map<String, dynamic> params) {
  return md5Hex(objcEncode('${serialize(params)}$LOGIN_SALT'));
}
```

Document that `objcEncode` is a no-op for `authCode`/`un` but kept for protocol fidelity.

- **Step 4: Run it and confirm GREEN**

Run: `flutter test test/core/services/drink_api_signer_test.dart`
Expected: PASS.

### Task 2: Remove the unused short signature (task 1.2)

<!-- comet-task-ref:cf431032-e61f-4ca3-9ac3-6c66cf54d295 -->

**Files:**
- Modify: `lib/core/services/drink_api_signer.dart`
- Test: `test/core/services/drink_api_signer_test.dart`

**Interfaces:**
- Removes: `shortSign`; `longSign` keeps using the shared key fragments.

- **Step 1: Delete the `shortSign` test group and the method**

Remove the `DrinkApiSigner.shortSign` group from the test file and the `shortSign` method from the signer; keep `_keyFragments` used by `longSign`, adjusting its doc comment so it no longer references `shortSign`.

- **Step 2: Verify**

Run: `grep -rn "shortSign" lib test`
Expected: no output.
Run: `flutter test test/core/services/drink_api_signer_test.dart`
Expected: PASS.

### Task 3: Signed login request (task 2.1)

<!-- comet-task-ref:f73672ee-51bd-47cc-96f8-bf7df7737d6d -->

**Files:**
- Modify: `lib/core/services/drink_api_service.dart` (`login`)
- Test: `test/core/services/drink_api_service_request_test.dart`

**Interfaces:**
- Consumes: `DrinkApiSigner.loginSign`.

- **Step 1: Write the failing test**

Replace the existing `login 不带 sign` test with:

```dart
test('login 使用官方签名与 iOS 身份', () async {
  final api = DrinkApiService();
  api.setHttpClientAdapter(adapter);
  await api.login(phone: '22644212509', smsCode: '123456');
  final options = adapter.captured!;
  expect(options.uri.path, '/api/v1/acc/login');
  expect(options.uri.queryParameters['sign'],
      DrinkApiSigner.loginSign({'authCode': '123456', 'un': '22644212509'}));
  expect(options.headers['User-Agent'],
      'iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9');
  expect(options.headers['VersionCode'], '3.1.9');
  expect(options.headers.containsKey('ApplicationType'), isFalse);
  expect((options.data as Map).keys.toSet(), {'authCode', 'un'});
});
```

- **Step 2: Run it and confirm RED**

Run: `flutter test test/core/services/drink_api_service_request_test.dart --plain-name 'login 使用官方签名与 iOS 身份'`
Expected: FAIL — no `sign`, Android UA.

- **Step 3: Implement in `login`**

Build `sign = DrinkApiSigner.loginSign({'authCode': smsCode, 'un': phone})`, request `"$_baseUrl/acc/login?sign=$sign"` with `Options(headers: {'User-Agent': '<iOS string>', 'VersionCode': '3.1.9'})` and body `{'authCode': smsCode, 'un': phone}`. The per-request `Options` must not override `Authorization` handling for other calls.

- **Step 4: Run it and confirm GREEN**

Run: `flutter test test/core/services/drink_api_service_request_test.dart`
Expected: PASS (other tests may still assert the old shape — task 4 fixes them in the same session before the suite is required green).

### Task 4: Update login tests and comments (task 2.2)

<!-- comet-task-ref:0d854160-fbd8-47d7-99c0-29766376c500 -->

**Files:**
- Modify: `test/core/services/drink_api_service_request_test.dart`
- Modify: `lib/core/services/drink_api_service.dart` (comments only)

- **Step 1: Replace stale assertions**

Update `login 与 sendSmsCode 都不带 sign`, `login 参数集不含 cid` and the `DrinkApiService.login 失败分类` group so they match the signed shape: login has a `sign` and no `cid`/`openCode`; `sendSmsCode` still has no `sign`. Keep the three failure classifications.

- **Step 2: Remove the stale comments**

Delete the comment block claiming `acc/login` does not verify signatures in `login()` and in `sendSmsCode()`; state that `acc/login/code` carries no signature while `acc/login` does.

- **Step 3: Verify**

Run: `flutter test test/core/services/drink_api_service_request_test.dart`
Expected: PASS.

### Task 5: Non-login identity stays Android (task 2.3)

<!-- comet-task-ref:d6b3f659-5267-44a1-b3f5-7847a11c204e -->

**Files:**
- Test: `test/core/services/drink_api_service_request_test.dart`

- **Step 1: Add the test**

```dart
test('非登录请求保持 Android 3.1.8 身份', () async {
  final api = DrinkApiService();
  api.setHttpClientAdapter(adapter);
  await api.accountBalance();
  final options = adapter.captured!;
  expect(options.headers['VersionCode'], '3.1.8');
  expect(options.headers['User-Agent'], 'Android_ilife798_3.1.8');
  expect(options.headers['User-Agent'], isNot(contains('iOS_ilife798')));
});
```

- **Step 2: Run it**

Run: `flutter test test/core/services/drink_api_service_request_test.dart --plain-name '非登录请求保持 Android 3.1.8 身份'`
Expected: PASS (no production change expected; if it fails, stop and investigate).

### Task 6: Live score/settlement read check (task 3.1)

<!-- comet-task-ref:4cb9fdc0-a20e-4f23-816c-89f76cf1bb9a -->

**Files:**
- No code change expected.

- **Step 1: Obtain a token through the new login**

Use the existing interactive login path (phone + SMS code) to sign in and obtain a fresh token.

- **Step 2: Call the read endpoints**

Call `/acc/score/acc-score` and the bill list endpoint (`/bill/lst-owner?page=0&size=20`) with the Android 3.1.8 headers and `Authorization: <token>`; record status, `code`, and whether the expected fields parse.

- **Step 3: Record the result**

Append the observed output to the build checkpoint. `code: 0` for both closes the task; any failure is written up as a follow-up finding with the raw response (no code change in this change).

### Task 7: Documentation consistency (task 4.1)

<!-- comet-task-ref:c6c6ccc0-6362-457c-b256-1407e1c7aa66 -->

**Files:**
- Modify: `lib/core/services/drink_api_service.dart` / `drink_api_signer.dart` doc comments if any stale statement remains.

- **Step 1: Grep for stale claims**

Run: `grep -rn "不校验签名" lib/core/services`
Expected: no output.

- **Step 2: Full test run**

Run: `flutter test`
Expected: PASS (entire suite).

## Workflow follow-up

- Record the build check, run `comet guard align-login-signing build --apply`, then continue to Verify.

## Review-fix tasks (final integrated review)

### Task 8: Delta spec corrections (tasks 5.1 and 5.2)

<!-- comet-task-ref:c80fd6fb-449c-4ae2-abba-1894980bbb93 -->
<!-- comet-task-ref:dccdd861-3e36-4632-9596-a4edd8d36679 -->

**Files:**
- Modify: `docs/openspec/changes/align-login-signing/specs/drink-api-signing/spec.md`

- **Step 1:** In `签名附加到请求`, keep `acc/login` signed; state that `acc/login/code`, `dev/start`, `dev/end`, `dev/favo` and `ui/app/dev/status` carry no `sign`; replace the three device-signature scenarios with device endpoints not carrying `sign`.
- **Step 2:** In `接口签名类型映射`, map only `acc/login` to the login signature; every other listed endpoint is unsigned.
- **Step 3:** Add a MODIFIED `长签名计算` requirement that describes the key-fragment/salt order inline, without referring to the removed short signature.
- **Step 4:** Verify: the delta contains no claim that device requests carry a signature and no `shortSign` reference.

### Task 9: Align design and proposal statements (task 5.3)

<!-- comet-task-ref:b5999dbd-f1f9-4e6c-bd7b-18eef793bae2 -->

**Files:**
- Modify: `docs/openspec/changes/align-login-signing/design.md`, `proposal.md`

- **Step 1:** Replace the claim that device endpoints use `longSign` with the fact that device requests are currently unsigned and `longSign` has no production caller (kept, unchanged, out of scope).
- **Step 2:** Verify with `grep -n "longSign"` across the change directory: no statement says it is in use.

### Task 10: Signer cleanup and network-error test (task 5.4)

<!-- comet-task-ref:d561b9be-033c-4ce4-848f-616c189b1643 -->

**Files:**
- Modify: `lib/core/services/drink_api_signer.dart`, `test/core/services/drink_api_service_request_test.dart`

- **Step 1:** Change `_keyFragments([String prefix = ''])` to `_keyFragments()` and drop the prefix argument from the buffer initialization.
- **Step 2:** Extend the class doc to describe both signing paths (`loginSign`, `longSign`).
- **Step 3:** Add a test where the adapter throws `DioException`, asserting `code == null` and the message starts with `网络错误`.
- **Step 4:** Verify: `flutter test` passes.

### Task 11: Documentation consistency follow-up (tasks 6.1 and 6.2)

<!-- comet-task-ref:443f3907-a16b-4531-abef-7ce3fb3cbcd1 -->
<!-- comet-task-ref:ad67f900-a27e-4550-8608-009ac5d1f269 -->

**Files:**
- Modify: `design.md`, `proposal.md`, `lib/core/services/drink_api_signer.dart` (comment only), `specs/drink-api-signing/spec.md`

- **Step 1:** Remove every remaining statement implying device endpoints use `longSign` from the change documents and the `longSign` doc comment.
- **Step 2:** Add a MODIFIED `token 登录路径的限制` requirement to the delta stating that device operation requests carry no signature regardless of the token-login path.
- **Step 3:** Verify: `grep -rn "设备操作.*长签名\|device endpoints.*signature"` across the change directory returns nothing except the corrected statements; `flutter test` still passes (no code behavior changed).
