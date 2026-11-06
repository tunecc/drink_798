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
