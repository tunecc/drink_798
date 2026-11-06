# Comet Design Handoff

- Change: align-login-signing
- Phase: design
- Mode: compact
- Context hash: 42906e5c1ce00ad91f61069098c567e3a265e56ad98fd7a0d721a5776c58417e

Generated-by: comet-handoff.sh
Task hash policy: task-content-v1. Read tasks.md for live completion; excerpts are design-time context.

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## docs/openspec/changes/align-login-signing/proposal.md

- Source: docs/openspec/changes/align-login-signing/proposal.md
- Lines: 1-31
- SHA256: 4a052cfb10b2e07c118c85308de5983cd447799e2ad43ff01b42bf7f135b3dd0

```md
# Proposal: align-login-signing

## Why

The 慧生活798 server now enforces a signature on `POST /acc/login`: an unsigned request is rejected with 「请升级最新版应用」. drink_798 still posts the login request without a signature (its code comment records the now-obsolete assumption that the endpoint does not verify), so phone/SMS login is broken and the water flow cannot be used at all. The sibling client life-798 has already been updated and verified against the live server; this change brings drink_798 to the same verified login behavior.

## What Changes

- Sign the login request with a dedicated login signature (`loginSign`), using the fixed protocol constant verified against the live server.
- Send the login request with the client identity the server validates: iOS client `User-Agent`, `VersionCode: 3.1.9`, and no `ApplicationType` header. Only the login request uses this identity; every other request keeps the existing headers.
- Send only `authCode` and `un` in the login body; drop `openCode` so the body matches the signed parameter set.
- Keep `DrinkApiSigner.longSign` and its key-derived fragments/salt untouched. Device requests are already sent unsigned (`09a1c08`); this change does not add signing to them, and the spec is corrected to say so.
- Correct the capability spec to the verified behavior: only `/acc/login` carries a signature; `/acc/login/code`, `dev/start`, `dev/end`, `dev/favo` and `ui/app/dev/status` do not. Add the login-specific signing requirement and restate the long-signature requirement self-contained after the short signature is removed.
- Verify that score balance (`/acc/score/acc-score`) and settlement bill reads still work with a token obtained through the new login. No code change is expected there; if verification fails, the finding is recorded as a follow-up instead of widening this change.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `drink-api-signing`: the login request must carry a signature computed with the verified login constant; the login request uses a dedicated client identity; the signature-type mapping and header requirements are corrected to the verified behavior.

## Impact

- `lib/core/services/drink_api_service.dart`: login request construction (headers, query, body).
- `lib/core/services/drink_api_signer.dart`: new login signing entry point and its fixed constant; unused `shortSign` removed; `longSign` unchanged (no production caller).
- `test/core/services/`: login request-shape and signature-vector tests.
- No UI changes, no signing added to device endpoints, no 1,5 (Alipay) login support.

```

## docs/openspec/changes/align-login-signing/design.md

- Source: docs/openspec/changes/align-login-signing/design.md
- Lines: 1-80
- SHA256: f6a5573118c37ae02460e8134eed2068693cacb664e3bafb97c65238e3740bf3

```md
---
comet_change: align-login-signing
role: technical-design
canonical_spec: openspec
---

# Design

## Context

See proposal.md — Why. Current constraints that shape the approach:

- `DrinkApiService` builds one Dio instance with global headers `VersionCode: 3.1.8` and `User-Agent: Android_ilife798_3.1.8`; login posts to `/acc/login` with no signature.
- Device requests (`dev/start`, `dev/end`, `dev/favo`) are sent **unsigned**: the sign was removed in commit `09a1c08` after the server stopped verifying it, and the request tests assert its absence. `DrinkApiSigner.longSign` therefore has no production caller; it stays in the codebase with unchanged fragments and salt. `shortSign` is unused and removed by this change.
- Verified against the live server with a real SMS code (sibling client life-798, same gateway): an unsigned or wrongly signed login returns 「请升级最新版应用」/「验签失败」; an iOS-client identity plus the fixed login constant succeeds and returns a usable token; that token is accepted by read endpoints under the regular Android identity.

## Goals / Non-Goals

**Goals:**

- Restore phone/SMS login against the current server behavior with the smallest possible request-shape change.
- Keep every non-login request (device control, score balance, settlement bills) on its current identity and request shape; device requests stay unsigned.
- Make the capability spec describe only verified behavior.

**Non-Goals:**

- Changing `longSign`'s generation or its salt (it currently has no production caller).
- Adding Alipay (1,5) login or score-task features.
- Any UI change.

## Decisions

### D1 — Login uses the official iOS client identity, login only

The login request sends `User-Agent: iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9` and `VersionCode: 3.1.9`, and omits `ApplicationType`. These headers are applied per request via `Options`, so the global Dio headers (Android, 3.1.8) remain untouched for all other endpoints.

Alternatives considered:

- Keep the Android identity and sign with the Android salt. Rejected for this change: the Android login salt could not be confirmed against the live server, while the iOS combination was verified end-to-end with a real SMS code.
- Switch the whole client to the iOS identity. Rejected: it would put every device request on an unverified identity and risk the water flow, which is out of scope.

### D2 — Login signature is a dedicated computation with a fixed constant

`DrinkApiSigner.loginSign(params)` computes `MD5(objcEncode(serialize(params) + LOGIN_SALT))` where `serialize` is the existing sorted `k=v&…` serialization and `LOGIN_SALT = "aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v"`. For the login parameter set the encoding step is a no-op, but keeping it preserves the official pipeline.

Alternatives considered:

- Re-derive the four key strings so the existing fragment builder yields the login constant. Rejected: `longSign` shares that builder, so its output (currently unused) would change silently.
- Reuse `shortSign`. Rejected: it appends a different, unverified constant; the server rejects it with 「验签失败」.

### D3 — Remove `shortSign` and its capability requirement

After D2 no endpoint uses `shortSign`. Keeping it would leave a requirement that describes behavior no interface has. `longSign` keeps its own fragment builder and is not touched.

### D4 — Login body contains only `authCode` and `un`

The server validates the signature over the received parameters; `openCode` and `cid` change that set and are not sent by the verified client. The login body therefore drops `openCode`.

### D6 — The spec states only verified request shapes

After the final integrated review, the delta spec is corrected to the verified reality: only `acc/login` carries `sign`; `acc/login/code`, `dev/start`, `dev/end`, `dev/favo` and `ui/app/dev/status` do not. The `长签名计算` requirement is restated self-contained because its former wording referenced the short signature this change removes. The design and proposal drop the earlier claim that device endpoints use `longSign`.

### D5 — Score chain is verified, not modified

Score balance (`/acc/score/acc-score`) and settlement bill reads are unchanged code paths. They are checked once with a token obtained through the new login; a failure would be recorded as a follow-up change rather than widening this one.

## Risks / Trade-offs

- [Protocol constant can rotate with a client release] → The constant comes from the official client; a future rotation breaks login with a clear server message, and the fix is a constant update covered by the existing signature-vector test.
- [Mixed identity: iOS for login, Android afterwards] → Verified in the sibling client that tokens are not bound to the login identity (read endpoints accepted the token under Android headers). If the server later enforces identity binding, the fallback is to move login onto the Android identity once its salt is confirmed.
- [Removing `shortSign`] → Only tests reference it; the task list updates those tests and the signature-vector coverage moves to `loginSign`.
- [Users keep stale tokens] → Existing saved tokens continue to work for reads; a new login simply replaces them.

## Migration Plan

No data migration. Ship in the next build; users log in again with a phone number and SMS code. Rollback is reverting the commit — no server-side state is created by the client beyond a normal login token.

## Open Questions

- Whether the server also accepts the Android identity with its own salt is unverified; it is not needed for this change and can be established later without changing the specs.

```

## docs/openspec/changes/align-login-signing/tasks.md

- Source: docs/openspec/changes/align-login-signing/tasks.md
- Lines: 1-36
- SHA256: 9b3ba96aa3525aa75610284d6089053a2ba6fc0138c31c224572ffdb7c888f9d

```md
# Tasks

## 1. Login signature support

- [x] 1.1 Add `DrinkApiSigner.LOGIN_SALT = 'aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v'` and `loginSign(Map<String, dynamic> params)`, computed as `md5Hex(objcEncode(serialize(params) + LOGIN_SALT))`; document that the encoding step is a no-op for login parameters but kept for protocol fidelity. Verify: signer unit test asserts `loginSign({'authCode': '123456', 'un': '13800138000'}) == '93f9b2ec2c30df3ef4c8b9caeea3013b'` and that changing the code changes the value. <!-- comet-task:028c2d09-aa57-486a-b483-8152b1c4fb2c -->
- [x] 1.2 Remove `shortSign` and its tests, since no endpoint uses it after login moves to `loginSign`. Verify: `grep -rn "shortSign" lib test` returns nothing and `flutter test test/core/services/drink_api_signer_test.dart` passes. <!-- comet-task:cf431032-e61f-4ca3-9ac3-6c66cf54d295 -->

## 2. Login request shape

- [x] 2.1 Change `DrinkApiService.login` to post to `/acc/login?sign=<loginSign({authCode, un})>` with per-request headers `User-Agent: iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9` and `VersionCode: 3.1.9`, no `ApplicationType`, and body `{authCode, un}` only. Verify: service test with a mock adapter asserts the request URL query, the two headers, the absence of `ApplicationType`, and the exact body keys. <!-- comet-task:f73672ee-51bd-47cc-96f8-bf7df7737d6d -->
- [x] 2.2 Update the existing login tests/comments that claimed the endpoint is unsigned, keeping the three-way failure distinction (server rejection vs network error vs malformed response). Verify: `flutter test test/core/services/drink_api_service_test.dart` passes and no comment still states that `acc/login` is not verified. <!-- comet-task:0d854160-fbd8-47d7-99c0-29766376c500 -->
- [x] 2.3 Confirm non-login requests keep the global identity. Verify: a service test asserts a device or balance request still carries `VersionCode: 3.1.8` and `Android_ilife798_3.1.8` and no iOS headers. <!-- comet-task:d6b3f659-5267-44a1-b3f5-7847a11c204e -->

## 3. Score and settlement read verification

- [x] 3.1 With a token obtained through the new login, call `/acc/score/acc-score` and the settlement bill endpoints used by the app against the live server and record the result (status, `code`, whether the expected fields parse). Verify: recorded command output shows `code: 0` for both, or the failure is written up as a follow-up finding with the raw response. <!-- comet-task:4cb9fdc0-a20e-4f23-816c-89f76cf1bb9a -->

## 4. Spec and documentation consistency

- [x] 4.1 Ensure the code documentation matches the updated `drink-api-signing` delta: login signing constant and identity, `acc/login/code` unsigned, `shortSign` removed. Verify: `grep -rn "不校验签名\|不校验" lib/core/services` returns nothing and the design/proposal texts agree with the implemented shape. <!-- comet-task:c6c6ccc0-6362-457c-b256-1407e1c7aa66 -->

## Workflow follow-up

- Archive the change and commit only this change's files after the OpenSpec and Comet checks pass.

## 5. Review fixes (final integrated review)

- [x] 5.1 Correct the delta spec so device endpoints (`dev/start`, `dev/end`, `dev/favo`) and `ui/app/dev/status` carry no `sign`, leaving only `acc/login` signed; update the affected scenarios. Verify: the delta has no claim that device requests carry a signature and its scenarios match the request tests. <!-- comet-task:c80fd6fb-449c-4ae2-abba-1894980bbb93 -->
- [x] 5.2 Make the `长签名计算` requirement self-contained by removing its reference to the deleted short signature, as a MODIFIED requirement in the delta. Verify: the delta describes the fragment/salt order without naming shortSign. <!-- comet-task:dccdd861-3e36-4632-9596-a4edd8d36679 -->
- [x] 5.3 Align `design.md` and `proposal.md` statements about `longSign` usage with the code (device requests are unsigned). Verify: no document claims device endpoints use longSign. <!-- comet-task:b5999dbd-f1f9-4e6c-bd7b-18eef793bae2 -->
- [x] 5.4 Remove the dead `prefix` parameter from `_keyFragments`, document both signing paths in the class comment, and add a login network-error test (DioException → `code == null`, message starts with 网络错误). Verify: `flutter test` passes with the new test. <!-- comet-task:d561b9be-033c-4ce4-848f-616c189b1643 -->

## 6. Documentation consistency follow-up

- [x] 6.1 Remove the remaining statements in `design.md`, `proposal.md` and the `longSign` doc comment that imply device endpoints use long signatures. Verify: no document or comment claims device endpoints send a signature. <!-- comet-task:443f3907-a16b-4531-abef-7ce3fb3cbcd1 -->
- [x] 6.2 Add a MODIFIED `token 登录路径的限制` requirement to the delta so the archived capability spec no longer claims device operations carry a long signature tied to uid. Verify: the delta contains the requirement and its scenarios describe unsigned device requests. <!-- comet-task:ad67f900-a27e-4550-8608-009ac5d1f269 -->

```

## docs/openspec/changes/align-login-signing/.openspec.yaml

- Source: docs/openspec/changes/align-login-signing/.openspec.yaml
- Lines: 1-2
- SHA256: 9b4b840064a33a6866a0ebc375b496fbdc2387a324f6c8fb4f21b270218c0d37

```md
schema: spec-driven
created: 2026-11-06

```

## docs/openspec/changes/align-login-signing/specs/drink-api-signing/spec.md

- Source: docs/openspec/changes/align-login-signing/specs/drink-api-signing/spec.md
- Lines: 1-168
- SHA256: 85723051cf786e1fa210920a5cc254820bdef80d43ceb3d2c2285a7547dbd740

[TRUNCATED]

```md
# Spec Delta: drink-api-signing

## ADDED Requirements

### Requirement: 登录请求签名

系统 SHALL 为 `acc/login` 计算登录签名：只取 `authCode` 与 `un` 两个参数，按既有序列化规则得到 `authCode=<短信验证码>&un=<手机号>`，追加固定串 `aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v`，再按既有编码规则编码后取 MD5，输出小写十六进制。

#### Scenario: 固定参数得到固定签名

- **WHEN** 短信验证码为 `123456`、手机号为 `13800138000`
- **THEN** 登录签名等于 `93f9b2ec2c30df3ef4c8b9caeea3013b`

#### Scenario: 签名只覆盖两个参数

- **WHEN** 系统计算登录签名
- **THEN** 参与签名的参数只有 `authCode` 与 `un`，不包含时间、token、uid 或请求头

#### Scenario: 验证码变化导致签名变化

- **WHEN** 同一手机号先后使用两个不同的短信验证码
- **THEN** 两次登录签名不同

### Requirement: 登录请求身份

系统 SHALL 以官方 iOS 客户端的身份发送 `acc/login`：`User-Agent` 为 `iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9`，`VersionCode` 为 `3.1.9`，且 SHALL NOT 发送 `ApplicationType`。登录请求体 SHALL 只包含 `authCode` 与 `un`。

#### Scenario: 登录请求头使用 iOS 身份

- **WHEN** 用户提交手机号与短信验证码登录
- **THEN** 请求包含 iOS `User-Agent` 与 `VersionCode: 3.1.9`
- **AND** 请求不包含 `ApplicationType`

#### Scenario: 登录请求体只包含两个参数

- **WHEN** 用户提交登录
- **THEN** 请求体只包含 `authCode` 与 `un`，不包含 `openCode` 或 `cid`

#### Scenario: 其他请求保持原身份

- **WHEN** 已登录用户发起设备或账单请求
- **THEN** 请求仍使用 `Android_ilife798_3.1.8` 身份，不使用登录所用的 iOS 身份

## MODIFIED Requirements

### Requirement: 长签名计算

系统 SHALL 保留长签名能力（当前没有接口使用）。长签名 SHALL 在序列化参数之后依次插入时间档位值、token 后 8 个字符、uid 后 8 个字符，再拼接固定密钥片段：`k1[1]`、`k2[25]` 转大写、`k3[0]`、`dF6hJ9kL2nP`、`k4[18]`、`rT8wY1`、`k2[21]`、`G`、`k3[23]`、`iM7oQ`、`k1[15]`、`v`（`k1`–`k4` 为四个固定密钥各自的 MD5 摘要），最后按既有编码规则编码并取 MD5。

时间档位值 SHALL 按 `30 * ((当前毫秒时间戳 + lat - lng) / 30000)` 计算，除法取整。`lat` 与 `lng` 为位置修正值，未提供时 SHALL 取 0。

当 token 长度小于 8 时，token 片段 SHALL 置为空串。当 uid 长度小于 8 时，uid 片段 SHALL 置为空串。

#### Scenario: 长签名包含时间档位

- **WHEN** 在时刻 T 计算长签名
- **THEN** 拼接串中包含 `30 * ((T + lat - lng) / 30000)` 的整数值

#### Scenario: 同一时间档位内签名一致

- **WHEN** 在 30 秒时间窗口内的两个不同时刻，用相同参数、token、uid 计算长签名
- **THEN** 两次签名值相同

#### Scenario: 跨时间档位签名不同

- **WHEN** 在相隔超过 30 秒的两个时刻，用相同参数、token、uid 计算长签名
- **THEN** 两次签名值不同

#### Scenario: token 不足 8 位时置空

- **WHEN** token 长度为 5 个字符
- **THEN** 拼接串中 token 片段为空串，签名仍能正常计算

#### Scenario: uid 不足 8 位时置空

- **WHEN** uid 为空字符串
- **THEN** 拼接串中 uid 片段为空串，签名仍能正常计算

## ADDED Requirements


```

Full source: docs/openspec/changes/align-login-signing/specs/drink-api-signing/spec.md
