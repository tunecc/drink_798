# Proposal: align-login-signing

## Why

The 慧生活798 server now enforces a signature on `POST /acc/login`: an unsigned request is rejected with 「请升级最新版应用」. drink_798 still posts the login request without a signature (its code comment records the now-obsolete assumption that the endpoint does not verify), so phone/SMS login is broken and the water flow cannot be used at all. The sibling client life-798 has already been updated and verified against the live server; this change brings drink_798 to the same verified login behavior.

## What Changes

- Sign the login request with the official short-sign scheme, using the fixed signing constant verified against the live server.
- Send the login request with the client identity the server validates: iOS client `User-Agent`, `VersionCode: 3.1.9`, and no `ApplicationType` header. Only the login request uses this identity; every other request keeps the existing headers.
- Send only `authCode` and `un` in the login body; drop `openCode` so the body matches the signed parameter set.
- Keep the existing key-derived short/long signatures and their salt untouched, so device endpoints (`dev/start`, `dev/end`, `dev/favo`) keep working as they do today.
- Correct the capability spec to the verified behavior: `/acc/login` requires a signature, `/acc/login/code` does not; add the login-specific signing requirement.
- Verify that score balance (`/acc/score/acc-score`) and settlement bill reads still work with a token obtained through the new login. No code change is expected there; if verification fails, the finding is recorded as a follow-up instead of widening this change.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `drink-api-signing`: the login request must carry a signature computed with the verified login constant; the login request uses a dedicated client identity; the signature-type mapping and header requirements are corrected to the verified behavior.

## Impact

- `lib/core/services/drink_api_service.dart`: login request construction (headers, query, body).
- `lib/core/services/drink_api_signer.dart`: login signing entry point and its fixed constant; existing short/long signing untouched.
- `test/core/services/`: login request-shape and signature-vector tests.
- No UI changes, no device-endpoint signature changes, no 1,5 (Alipay) login support.
