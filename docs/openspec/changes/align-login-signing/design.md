---
comet_change: align-login-signing
role: technical-design
canonical_spec: openspec
---

# Design

## Context

See proposal.md — Why. Current constraints that shape the approach:

- `DrinkApiService` builds one Dio instance with global headers `VersionCode: 3.1.8` and `User-Agent: Android_ilife798_3.1.8`; login posts to `/acc/login` with no signature.
- `DrinkApiSigner.longSign` is used by device endpoints (`dev/start`, `dev/end`, `dev/favo`) and must keep its current key-derived fragments and salt. `shortSign` exists but no production code calls it.
- Verified against the live server with a real SMS code (sibling client life-798, same gateway): an unsigned or wrongly signed login returns 「请升级最新版应用」/「验签失败」; an iOS-client identity plus the fixed login constant succeeds and returns a usable token; that token is accepted by read endpoints under the regular Android identity.

## Goals / Non-Goals

**Goals:**

- Restore phone/SMS login against the current server behavior with the smallest possible request-shape change.
- Keep every non-login request (device control, score balance, settlement bills) on its current identity and signature.
- Make the capability spec describe only verified behavior.

**Non-Goals:**

- Changing long-signature generation or the device-endpoint salt.
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

- Re-derive the four key strings so the existing fragment builder yields the login constant. Rejected: `longSign` shares that builder, so the device-endpoint salt would change silently.
- Reuse `shortSign`. Rejected: it appends a different, unverified constant; the server rejects it with 「验签失败」.

### D3 — Remove `shortSign` and its capability requirement

After D2 no endpoint uses `shortSign`. Keeping it would leave a requirement that describes behavior no interface has. `longSign` keeps its own fragment builder and is not touched.

### D4 — Login body contains only `authCode` and `un`

The server validates the signature over the received parameters; `openCode` and `cid` change that set and are not sent by the verified client. The login body therefore drops `openCode`.

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
