# Comet Design Handoff

- Change: align-score-deduction
- Phase: design
- Mode: compact
- Context hash: 5deee17ff41733a483540e8ad9727940a6f9eede04b583c84dd5ba5f3147715b

Generated-by: comet-handoff.sh
Task hash policy: task-content-v1. Read tasks.md for live completion; excerpts are design-time context.

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## docs/openspec/changes/align-score-deduction/proposal.md

- Source: docs/openspec/changes/align-score-deduction/proposal.md
- Lines: 1-30
- SHA256: afc3ee127220fd837c80beae15db4e0175b614083a0c4fedf565ae4341e9f2d8

```md
# Proposal: align-score-deduction

## Why

drink_798 already starts every session with the wallet payment type (`ptype=91`), but users report that score deduction never happens: sessions are paid entirely from the wallet (or Alipay) while the score balance stays untouched. Investigation across three independent sources — the official iOS 3.1.9 binary (reverse-engineered from `慧生活798_3.1.9.ipa`), the ilife798 KMP reference client, and the life-798 (WaterWidget) reference client — shows the server cascade (score → wallet gift → wallet balance → Alipay) is **not** triggered by `ptype=91` alone: it also requires the account-level score-deduction switch `useScore` to be on, which the client must sync via `POST acc/upt {"useScore":1}`. The official app exposes this as the 「开启自动抵扣」 toggle on its device payment page; ilife798 re-syncs the switch before every device start and documents that the cascade fires from `useScore=1` + `ptype=91` together; life-798 never syncs it and only works because its account flag was already set elsewhere. drink_798 has never sent `acc/upt`, so whenever the account flag is off the server skips score deduction entirely — which is exactly the reported behavior.

## What Changes

- Add a `setUseScore` API method: `POST acc/upt` with JSON body `{"useScore":1}`, Authorization header only — no signature (matching the unsigned treatment of every non-login request) and no `ApplicationType` header (the official iOS binary does not contain that string, and the existing spec forbids sending it).
- Sync the switch automatically before every wallet-paid session start in `HomeController.startDrinking` (`useScore=1`, per the user-confirmed scope: always-on, no in-app toggle UI). The adopt/takeover path that does not send a start request stays unchanged.
- On the server-rejection side nothing changes: `ptype=91` remains the only start type, no fallback is introduced, and existing rejection prompts (-52/-82/-87/-88/-99) are untouched.
- No changes to `dev/start` request shape, signing rules, or balance/bill endpoints.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `payment-settlement`: add the requirement that a wallet-paid session start is preceded by syncing the server-side score-deduction switch (`acc/upt` with `useScore=1`), and make explicit that the settlement cascade applies score deduction only when that switch is on. Existing requirements (wallet-payment only, no fallback, rejection prompts, bill reporting) are unchanged.

## Impact

- `lib/core/services/drink_api_service.dart`: new `setUseScore` method (POST with JSON body — the service already uses this shape for `acc/login` and `acc/login/code`).
- `lib/features/home/home_controller.dart`: one sync call inserted before the single start request.
- Tests: request-shape tests for the new endpoint and controller tests for the sync-before-start ordering and failure handling.
- Real-device verification: after the change, a session's settlement bill carries `promo.type=4` / `discount` and the score balance decreases — the pre-existing bill-parsing and balance-display code then reports the deduction without modification.
- Design decisions deferred to `design.md`: behavior when the switch sync fails (abort vs warn-and-continue), and rate-limit (-98) handling for `acc/upt`.

```

## docs/openspec/changes/align-score-deduction/design.md

- Source: docs/openspec/changes/align-score-deduction/design.md
- Lines: 1-46
- SHA256: 5750891f78651677509b85a175635a51de796614b2fff2dbf390a213aa1749b3

```md
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

```

## docs/openspec/changes/align-score-deduction/tasks.md

- Source: docs/openspec/changes/align-score-deduction/tasks.md
- Lines: 1-14
- SHA256: 1e9e30a9439214fbd4fd0aba8d2923a9fafabc7738d8f9a5561bb921dd612b56

```md
# Tasks

## 1. Score-deduction switch API

- [ ] 1.1 Add `setUseScore` to `DrinkApiService`: `POST acc/upt` with JSON body `{"useScore":1}`, `Content-Type: application/json`, `Authorization` header only; no `sign` parameter, no `ApplicationType` header. Verify: request-shape test in `test/core/services/drink_api_service_request_test.dart` asserting method, path, body and headers, including the absence of `sign` and `ApplicationType`. <!-- comet-task:1411c31a-2aa0-4260-8742-49faf38509af -->

## 2. Controller wiring

- [ ] 2.1 In `HomeController.startDrinking`, call the switch sync after the device precheck and before the single start request; on any sync failure show the dedicated prompt and abort without sending `dev/start`; leave the adopt/takeover path and the settlement flow untouched. Verify: controller tests with the fake service covering success ordering (sync completes, then start), failure abort on a network error and on a server rejection (no start request sent), and no sync on the adoption path. <!-- comet-task:a38616c5-636f-4b58-82f8-76e507e6c890 -->

## 3. Regression and device verification

- [ ] 3.1 Run the full test suite and confirm no regressions. Verify: `fvm flutter test` exits 0 with the new tests included. <!-- comet-task:78732593-6827-432d-b4e7-bb044be0a094 -->
- [ ] 3.2 Real-device verification of the deduction chain. Verify: with score > 0, a started session ends with a bill carrying `promo.type=4`/`discount`, the score balance decreases, the wallet/Alipay part covers only the remainder, and the account name/avatar are unchanged after the sync (upt body safety). <!-- comet-task:7abe0898-474d-49a8-99ac-b81d0c25149a -->

```

## docs/openspec/changes/align-score-deduction/.openspec.yaml

- Source: docs/openspec/changes/align-score-deduction/.openspec.yaml
- Lines: 1-2
- SHA256: cb72bd9217510d5461ddb5384ca197195a83da2d8dfbd237178f7ed662291c68

```md
schema: spec-driven
created: 2026-11-07

```

## docs/openspec/changes/align-score-deduction/specs/payment-settlement/spec.md

- Source: docs/openspec/changes/align-score-deduction/specs/payment-settlement/spec.md
- Lines: 1-31
- SHA256: 560ce87205e7c4ddb97963d9351b110cafe19496fd4d4e77d05bd0399df18501

```md
# Spec Delta: payment-settlement

## ADDED Requirements

### Requirement: Wallet-paid starts sync the score-deduction switch first

The system SHALL enable the account-level score-deduction switch (`acc/upt` with `useScore=1`) before every wallet-paid session start, so the server settlement cascade deducts score first (it applies score only while this switch is on). When the sync fails — network error or server rejection — the system SHALL NOT send that start request and SHALL surface a dedicated failure prompt. The sync SHALL be sent only when a start request is about to be sent; the adopt/takeover path SHALL NOT send it.

#### Scenario: Switch sync precedes every wallet-paid start

- **WHEN** the user starts a session on an available device
- **THEN** the switch-sync request completes before the start request is sent, and the start request still uses the wallet payment type with no other request in between

#### Scenario: Failed switch sync blocks the start

- **WHEN** the switch-sync request fails with a network error or a server rejection
- **THEN** no start request is sent for that attempt, and the user sees a dedicated failure prompt explaining the session was not started

#### Scenario: Adopted session does not re-sync

- **WHEN** the device is already running and the app adopts the session without sending a start request
- **THEN** no switch-sync request is sent for that adoption

### Requirement: Switch-sync request carries no signature or branding

The switch-sync request (`acc/upt`) SHALL NOT carry a `sign` parameter and SHALL NOT carry an `ApplicationType` header, consistent with every other non-login request of the app.

#### Scenario: Sync request shape stays unsigned and unbranded

- **WHEN** the system constructs the switch-sync request
- **THEN** the request carries no `sign` parameter and no `ApplicationType` header

```
