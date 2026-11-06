# Verification Report: align-login-signing

- Date: 2026-11-05
- Mode: full (scale: 13 tasks, 1 delta-spec capability, 4 changed files)
- Implementation commits: `2e70bd1` (login signing), `329d03c` (spec alignment), `229141b` (doc consistency)
- Base ref: `1258918`

## Summary

| Dimension | Status |
|---|---|
| Completeness | 13/13 tasks completed; delta requirements (5 added, 1 modified, 4 removed) all implemented |
| Correctness | All requirements and scenarios covered by unit tests or the live read check |
| Coherence | Design decisions D1–D6 followed; final integrated review found no open Critical/Important issues |

## Checks

| Check | Command / evidence | Result |
|---|---|---|
| Full test suite | `flutter test` | 173/173 pass |
| Build guard | `comet guard align-login-signing build --apply -- flutter test` | pass |
| Live read verification | fresh appToken from the new login (real SMS), requests with `VersionCode: 3.1.8` + `Android_ilife798_3.1.8` | `acc-score` → `code 0` (points payload parsed), `bill/lst-owner` → `code 0`, `wallet/owner` → `code 0` |
| Integrated review #1 | 1258918..2e70bd1, independent reviewer | 2 Important (delta claimed device signatures; dangling short-signature reference) → fixed in `329d03c` |
| Integrated review #2 | 2e70bd1..329d03c, independent reviewer | both Important resolved, no new Critical/Important; 4 Minor doc leftovers → fixed in `229141b` |
| Security scan | manual read of the diff | no credentials added; `LOGIN_SALT` is the official client protocol constant, not a server secret; the signature covers only the phone number and SMS code |

## Requirement coverage

| Requirement (delta) | Implementation | Evidence |
|---|---|---|
| 登录请求签名 (ADDED) | `DrinkApiSigner.loginSign` + `LOGIN_SALT` | `test/core/services/drink_api_signer_test.dart` vector `93f9b2ec…`, code-change test |
| 登录请求身份 (ADDED) | per-request `Options` in `DrinkApiService.login` | `test/core/services/drink_api_service_request_test.dart` (URL sign, iOS UA, 3.1.9, no `ApplicationType`, body keys) |
| 签名附加规则 (ADDED) | login carries `sign`; others do not | request tests: login `sign` present; `sendSmsCode`, device and status requests unsigned |
| 接口签名映射 (ADDED) | same as above | request tests; `shortSign` absent from `lib/` and `test/` |
| token 登录与设备请求 (ADDED) | device requests unsigned regardless of login path | `test/core/services/drink_api_service_request_test.dart` non-login identity test |
| 签名附加到请求 / 接口签名类型映射 / token 登录路径的限制 (REMOVED) | superseded by the three ADDED requirements above | `openspec validate align-login-signing` → valid |
| 长签名计算 (MODIFIED, self-contained) | `longSign` retained, no production caller | pinned vector `5b9ad263…` (fragment order unchanged) |
| 短签名计算 (REMOVED) | method and tests deleted | `grep -rn shortSign lib test` → none |

## Review findings and disposition

- Important #1 — delta claimed device endpoints carry `sign`: fixed; delta now states only `acc/login` is signed.
- Important #2 — dangling reference to the removed short signature: fixed; `长签名计算` restated self-contained.
- Minor #1–#4 — leftover `longSign` usage statements in design/proposal/comment, and the stale token-login requirement: fixed in `229141b`.

## Archive validation note

The first archive attempt failed at the OpenSpec archive step because a MODIFIED requirement replaces its whole block and OpenSpec refuses to drop existing scenarios. The delta was restructured to express the three superseded requirements as REMOVED + ADDED (behaviour unchanged), and `openspec validate align-login-signing` now passes. The Comet Runtime then re-opened Open on the same Run; the scope, design and delivery choice were unchanged and their existing approvals were reused.

## Known limitations

- Device control (`dev/start`, `dev/end`) was not exercised with a token from the new login; this change does not alter device requests and the water flow is outside its scope.
- The live read check consumed one real SMS code; it is not reproducible in CI.
- The login constant is a client protocol constant; if the official client rotates it, login fails with a clear server message and the signature-vector test is the failure signal.
- Alipay (1,5) login does not exist in this client and remains out of scope.

## Conclusion

All checks pass, no open Critical or Important findings. **Ready for archive.**
