---
comet_change: align-score-deduction
role: technical-design
canonical_spec: openspec
archived-with: 2026-11-10-align-score-deduction
status: final
---

# Design

## Context

See proposal.md — Why. Technical facts that shape the approach:

- The settlement cascade lives entirely on the server; the client's only levers are the start payment type (`ptype=91`, already sent) and the account-level switch `useScore`, synced via `POST acc/upt {"useScore":0|1}`.
- Evidence for the switch: official iOS 3.1.9 binary contains the `acc/upt` endpoint, a `Tq,N,V_useScore` property on the account model (`KZYAccountModel`), and the 「开启自动抵扣」/「消费直接抵现金」 copy in `KZYDevicePaymentView.nib`; ilife798 (`shared/.../DeviceController.kt:791-811`) calls `api.setUseScore(...)` before every `devStart` and comments that the cascade is triggered by `useScore=1` + `ptype=91` together; its widget path (`DeviceWidgetStartService.kt:277-291`) aborts the start when the sync fails.
- `DrinkApiService` already has the needed request shapes: GET+query for device/balance/bill calls, POST with a JSON body for `acc/login` and `acc/login/code` (lib/core/services/drink_api_service.dart). All non-login requests are unsigned and header-branded only with `VersionCode` + `User-Agent` + per-request `Authorization` (per `drink-api-signing` spec).
- Bill reporting (`promo.type=4`/`discount`) and score-balance display already exist from align-payment-settlement and need no change — once the server actually deducts, they surface it.

## Goals / Non-Goals

**Goals:**

- Make the server cascade actually deduct score for sessions started by this app, robustly against the flag being turned off elsewhere (official app, other clients).
- Keep the client surface minimal: one new API method, one call site, no UI beyond a failure prompt.

**Non-Goals:**

- No in-app toggle for `useScore` (scope confirmed by user: always sync `1` before start).
- No payment-method fallback, no `dev/start` shape change, no `ApplicationType` header, no signing changes.
- No score missions/check-in/exchange features.

## Decisions

1. **Sync per start, not per login.** The server-side flag can be reset by any other client at any time (that is how the regression appeared), so the only robust point is immediately before each start. ilife798 does the same ("启动前把积分抵扣开关同步到服务端"). Alternative — set once at login — rejected: leaves the reported bug reproducing after any external flag flip.
2. **Request shape mirrors ilife798 exactly**: `POST acc/upt`, JSON body `{"useScore":1}`, `Content-Type: application/json`, `Authorization` header, no `sign`, no `ApplicationType`. Rationale: ilife798 is the only reference that actively manages the switch and demonstrably works; the official iOS binary has no `ApplicationType` string at all, the current spec forbids the header, and the 1.0.9 real-device check already proved this header-less token channel works for `/acc/*` endpoints. Alternatives — adding `ApplicationType: 1,1` or signing — rejected: contradicts the verified spec without evidence they are needed.
3. **Sync failure aborts the start** (user-confirmed). Any failure — Dio network error or non-zero server `code` — ends the attempt with a dedicated prompt; no `dev/start` is sent; retry is user-initiated. Rationale: proceeding would silently charge without deduction, i.e. the exact defect this change fixes, now intermittent and hidden; aborting matches the project's no-silent-deviation behavior (`payment-settlement` requirements) and ilife798's widget path. Alternative — warn-and-continue — rejected for that reason.
4. **No automatic retry, including `-98` rate limiting.** The sync fires once per explicit user action, so rate-limit pressure is minimal; a `-98` is surfaced like any other failure (server message when present, generic prompt otherwise). Automatic retries are deferred until observed in practice — observable failure beats hidden retry loops for a money-adjacent call.
5. **Call placement: `HomeController.startDrinking`, after the device precheck, immediately before the single start request.** The adopt/takeover branch (busy device, no start request) is untouched — no sync, consistent with the spec. The settlement/bill flow is untouched.

## Risks / Trade-offs

- [One extra round trip before every start] → acceptable: a single request on an explicit user action; failure prompts are immediate and actionable.
- [`acc/upt` semantics beyond `useScore` unverified — a partial body could theoretically reset other account fields] → mitigation: send exactly the reference body `{"useScore":1}` (ilife798 has shipped this for its account flows), and verify on a real device that account name/avatar and balances are unaffected after a start.
- [Flag flipped off by another client between sync and settlement] → outside client control; per-start sync minimizes the window. Accept.
- [Server rejects the token channel for `acc/upt`] → would surface through the abort prompt. Contingency (only with device evidence): revisit headers in a follow-up, do not preemptively add `ApplicationType`.

## Migration Plan

Single release; no data migration; rollback is reverting the commit (the sync call site and the new method are additive). Verification requires a real device: start a session with score > 0 and confirm (a) the bill shows `promo.type=4`/`discount`, (b) the score balance decreases, (c) wallet/Alipay covers only the remainder.

## Open Questions

None blocking. Prompt copy and the failure-prompt error-code mapping are build-level details within the confirmed behavior (abort with prompt).
