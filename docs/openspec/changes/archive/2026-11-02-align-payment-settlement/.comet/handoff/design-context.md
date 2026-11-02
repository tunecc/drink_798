# Comet Design Handoff

- Change: align-payment-settlement
- Phase: design
- Mode: compact
- Context hash: 972b52bb441e76947a395b84fe607c2c32635534dc058185d5e53234069eff86

Generated-by: comet-handoff.sh
Task hash policy: task-content-v1. Read tasks.md for live completion; excerpts are design-time context.

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## docs/openspec/changes/align-payment-settlement/proposal.md

- Source: docs/openspec/changes/align-payment-settlement/proposal.md
- Lines: 1-35
- SHA256: 1c604df8bc7dd412524348bb2727d5ccf874055e379661626a0bd670e95be1ed

```md
# Proposal: align-payment-settlement

## Why

The 慧生活798 server settles each water session with a fixed cascade — score deduction first, then wallet gift credit, then wallet balance, and only the remainder via Alipay — whenever the client starts the session with wallet payment (`ptype=91`). drink_798 already sends `ptype=91`, but (1) it shows none of the resulting bill, so users cannot see score deductions that already happen, and (2) when the wallet payment is rejected for any reason, `HomeController.startDrinking` silently retries with Alipay password-free payment (`ptype=21`), which charges the user's Alipay for the full amount and bypasses the score/wallet cascade entirely. The sibling third-party client (life-798 / WaterWidget, same gateway) relies on the cascade and surfaces the bill breakdown; this change brings drink_798 to the same behavior.

## What Changes

- Remove the silent `ptype=91 → ptype=21` fallback in `HomeController.startDrinking`. A wallet-payment rejection now surfaces the server's reason instead of switching payment method.
- Map known server rejection codes to actionable prompts: `-52` account arrears, `-82` payment required, `-88` no Alipay withholding agreement signed, `-87` withholding agreement expired. `-99` (session expired) keeps the existing re-login flow; other codes keep passing the server message through.
- After a session ends (manual settle via `dev/end`, or the status poll detecting idle), fetch the settlement bill (`type=91`, `status=3`, `cata=6`) and show a per-session consumption summary: total, score-discount part (`promo.type=4` → `discount`), and the wallet-paid part. A short poll tolerates settlement latency, matching the reference implementation's approach.
- Add wallet balance (`/acc/wallet/owner`) and score balance (`/acc/score/acc-score`) fetching, and display both on the home page; refresh after a settlement.
- No change to the `dev/start` request shape: `ptype` stays `91`. No score missions/check-in, no recharge/Alipay top-up flow, no signing changes.

## Capabilities

### New Capabilities

- `payment-settlement`: How a water session is paid for and reported — wallet-first payment type, no silent payment-method fallback, server rejection reasons surfaced in Chinese prompts, and per-session consumption reporting with the score-discount breakdown.
- `account-balance`: Wallet and score balance visibility — fetching and parsing the two balance endpoints, displaying them on the home page, and refreshing them after settlement.

### Modified Capabilities

<!-- none: drink-api-signing, home-page-ui and login-page-ui requirements are unchanged.
     New home-page UI for balances must follow home-page-ui rules but does not alter them. -->

## Impact

- `lib/core/services/drink_api_service.dart`: new bill-query, wallet-balance and score-balance methods plus response models/parsers.
- `lib/core/models/`: new models for settlement bill/consumption and account balances.
- `lib/features/home/home_controller.dart`: remove fallback, add error-code mapping, post-settlement bill fetch and balance state.
- `lib/features/home/home_page.dart`: balance display section (must follow `home-page-ui` visual rules).
- Tests: `drink_api_service_request_test.dart` and controller tests extended for the new endpoints and the no-fallback behavior.
- Real-device verification required: whether the token held by this app (sent without an `ApplicationType` header) is accepted by `/acc/wallet/owner` and `/acc/score/acc-score`; the reference client sends those with `ApplicationType: 1,1`. If rejected, the fallback plan is decided in design/build, not by scope expansion here.
- Verified reference behavior: score deduction is recorded in bill details as `promo.type=4` / `discount`, bills are `type=91` / `status=3` / `cata=6`, wallet parts are in `payment`; score stream entries are `type=107` with `spend`.

```

## docs/openspec/changes/align-payment-settlement/design.md

- Source: docs/openspec/changes/align-payment-settlement/design.md
- Lines: 1-82
- SHA256: 26d2815017ecb96f7081e759434fd1bdb710459dff0d3e7fd02fd84aa39c52a7

[TRUNCATED]

```md
---
comet_change: align-payment-settlement
role: technical-design
canonical_spec: openspec
---

# Design: align-payment-settlement

## Context

drink_798 is a Flutter client for the 慧生活798 gateway (`i.ilife798.com/api/v1`). Today `DrinkApiService.startDrinking` sends `/dev/start` with `ptype=91` (wallet payment), and `HomeController.startDrinking` retries once with `ptype=21` (Alipay password-free) on any rejection except `-99`. `stopDrinking` only sends `/dev/end` and reports "已结算"; nothing in the app reads bills, scores or wallet state. Request headers carry only `VersionCode` and `User-Agent` (no `ApplicationType`), and `/dev/start` works that way in production.

Verified reference behavior from life-798 (WaterWidget, same gateway):

- Settlement bills are records with `type=91`, `status=3`, `cata=6`; score deduction is recorded in the bill as `promo.type=4` with a `discount` amount; wallet-paid money is in `payment`; a fully score-covered bill has `payment=0`.
- Score stream entries are `type=107` with `spend`.
- Wallet balance: `GET /acc/wallet/owner` → `data.aw` (primary wallet object) and `data.eps[]` (endpoint wallets), balance on each; dashboard uses the entry matching the account's endpoint, else the single entry.
- Score balance: `GET /acc/score/acc-score` → `data.validScore` (usable) and `data.totalScore`.
- Neither balance endpoint requires request signing in the reference client; both are sent with `Authorization` and `ApplicationType: 1,1`.
- Rejection codes: `-52` arrears, `-82` payment required, `-88` no withholding agreement, `-87` agreement expired, `-99` session expired, `-21` wrong login type, `-19` device preparing.

See proposal.md for motivation and the two spec deltas for requirements.

## Goals / Non-Goals

**Goals:**

- Make the server's settlement cascade authoritative: wallet payment only, rejections surfaced, settlement made visible (bill + balances).
- Keep the existing request pipeline (single Dio instance, `Authorization` header, no extra headers) and the existing prompt/snackbar UX.

**Non-Goals:**

- Score missions/check-in, recharge or Alipay top-up UI, bill history pages.
- Changing request shapes for `/dev/start` `/dev/end`, or any signing logic (governed by `drink-api-signing`).
- Persisting consumption history locally (life-798's usage-history store).

## Decisions

### D1. Remove the ptype=21 fallback entirely (no confirmation dialog)

The fallback is deleted, not gated behind a user prompt. Rationale: with a dialog, the "yes" path still bypasses the score/wallet cascade and charges Alipay in full — the exact behavior this change exists to stop — and users will habitually confirm. life-798's behavior (report and stop) is the proven reference. Alternative considered (confirm-before-fallback dialog) rejected for that reason; it also adds a dialog flow the specs would need to own.

### D2. Error-code mapping lives in a pure function next to the existing prompt helper

`drinkFailurePrompt` already centralizes `-99` handling. The four new codes (`-52/-82/-88/-87`) join that same mapping as pure data + function, so controller and tests share one source of truth. Codes keep their Chinese prompt text as product copy. Unmapped codes keep the pass-through behavior (server `msg`, then generic fallback) — unchanged from today.

### D3. Bill reporting via a bounded two-step poll (list → detail) after settle

Settlement bills appear with latency, and the score-discount breakdown is only available in the bill detail — the reference client's own note is explicit: the list of the latest 20 bills does not include the score deduction; each bill must be read individually (`ConfigActivity.kt` "逐笔读详情才能包含积分抵扣"). After `dev/end` succeeds **or** the status poll detects idle, the controller therefore:

1. Polls `GET /bill/lst-owner?page=0&size=20` (a few attempts, seconds apart, reusing the existing timer idiom) filtered to the current device, to records newer than the session start, and to settled water bills (`type=91`, `status=3`, `cata=6`), taking the latest match.
2. Fetches `GET /bill/view-full?id=<billId>` (response envelope `data.bill`) and parses the score part from `promo.type=4` / `discount` and the wallet part from `payment`.

If the detail cannot be fetched within the poll window, reporting stays silent rather than showing a wrong amount — a fully score-covered bill lists `payment=0`, so reporting the list alone would misreport ¥0. Parsing mirrors life-798's verified field semantics but only for the current session — no local history store.

### D4. Balances fetched with the existing token and headers; header fallback only if the server refuses

The two balance endpoints are added to `DrinkApiService` as plain GETs with the current `Authorization`-only header set, matching this app's proven minimal-header approach (`dev/start` works without `ApplicationType`). If the server rejects these endpoints for the missing `ApplicationType` (verified on a real device during build), the contingency is to add `ApplicationType: 1,1` **to those two requests only**, not globally. Wallet parsing takes the endpoint-matching entry else the single entry (`data.aw` then `data.eps[]`); score parsing takes `data.validScore`.

### D5. Balance UI is a compact home-page section driven by controller state

`HomeController` exposes `walletBalance` / `scoreBalance` (nullable observable; `null` = unknown/hidden), fetched on device load and refreshed after settlement reporting; failures degrade to hidden values without dialogs. `home_page.dart` renders the section only when logged in, following `home-page-ui` surface/hierarchy rules. A nullable model type (`AccountBalance` with yuan + points) keeps parsing and UI decoupled.

## Risks / Trade-offs

- [Token type mismatch: `/acc/wallet/owner` or `/acc/score/acc-score` may reject the app's token without `ApplicationType`] → D4 contingency; real-device check is an explicit build task before UI work.
- [Bill record shape may vary by device/account (missing `cata`, other promo types)] → Parser treats `promo.type=4` as the only score-discount source and ignores other promos; unmatched bills fall back to reporting total `payment` only, never a wrong breakdown.
- [Poll adds requests after every session] → Bounded to a handful of attempts with a hard stop; idle-detection poll already exists so the pattern adds no new failure mode.
- [Removing the fallback may surprise users who relied on Alipay auto-pay when the wallet is empty] → The rejection prompts now tell them exactly why (arrears / agreement), which is the intended behavior change; accepted explicitly in scope.
- [comet CLI on this machine carries a local `pubspec.lock` allowlist patch that is lost on upgrade] → Recorded in project knowledge; unrelated to app code but noted because verification runs depend on `comet` state commands.

## Migration Plan

Single app release; no data migration. Rollback = revert the change (the fallback returns; no persistent state is introduced).

## Open Questions

- Whether the server returns score changes and wallet deductions in a single bill or separate records for some device types: the parser handles the verified shapes; deviations found on a real device are handled under the bill-parsing fallback (total only, never reporting a covered bill as zero).

## Resolved During Design

```

Full source: docs/openspec/changes/align-payment-settlement/design.md

## docs/openspec/changes/align-payment-settlement/tasks.md

- Source: docs/openspec/changes/align-payment-settlement/tasks.md
- Lines: 1-33
- SHA256: faf81ef53b8640f30edef6be47b095e83527ae58be95ab23b605d0b5699f8c15

```md
# Tasks: align-payment-settlement

## 1. API service: bill query and balances

- [ ] 1.1 Capture the wallet-owner / acc-score / bill-list / bill-detail response envelopes from the reference client (life-798 `IlifeApi`, endpoints confirmed in design D3: `/acc/wallet/owner`, `/acc/score/acc-score`, `/bill/lst-owner`, `/bill/view-full`) as test fixtures. Verify: fixtures recorded in the change's build context and reflected in 1.2/1.3 tests. <!-- comet-task:eaf980c2-df03-4f00-98fb-49791d52ad44 -->
- [ ] 1.2 Add `AccountBalance` model plus wallet-balance (`/acc/wallet/owner`) and score-balance (`/acc/score/acc-score`) methods to `DrinkApiService`; parse the endpoint-matching (else single) wallet entry and `data.validScore`; unexpected shapes parse to null. Verify: request-shape and parser unit tests pass via `flutter test`. <!-- comet-task:e81d3cb2-2717-4dc2-b039-cd568387461f -->
- [ ] 1.3 Add the settlement bill query and parser: filter to `type=91`/`status=3`/`cata=6` records for the current device newer than session start, take the latest, extract total (`payment` + promo discount), score part (`promo.type=4` → `discount`) and wallet part; ignore other promo types; tolerate `payment=0`. Verify: parser unit tests cover full-score-covered, no-promo, other-promo-ignored and no-bill cases. <!-- comet-task:4be1b4f8-6ed1-4e56-b9fd-a53c5d8d326d -->

## 2. Controller: no-fallback start and error mapping

- [ ] 2.1 Extend `drinkFailurePrompt` with `-52`/`-82`/`-88`/`-87` Chinese prompts; keep `-99` re-login and the server-message pass-through for unmapped codes. Verify: prompt unit tests for all mapped codes plus pass-through. <!-- comet-task:560143cb-e198-4e45-89f9-ad81a9259ed9 -->
- [ ] 2.2 Remove the `ptype=21` retry in `HomeController.startDrinking`; a wallet-payment rejection surfaces its prompt and sends no further start request; session-expired flow unchanged. Verify: controller tests assert exactly one start request on rejection (updated former fallback tests). <!-- comet-task:a810f378-8192-471e-9e8d-6d85cf551342 -->
- [ ] 2.3 Add nullable `walletBalance`/`scoreBalance` observables fetched on device load when logged in; failures and not-logged-in degrade to hidden values with no dialogs and no requests when logged out. Verify: controller tests with a fake API service cover success, failure and logged-out. <!-- comet-task:315cde1b-3574-443b-9c5e-ef07d0cb7f53 -->

## 3. Settlement reporting and balance refresh

- [ ] 3.1 After manual settle (`dev/end` success) and after idle-detection completion, run a bounded bill poll (few attempts, seconds apart) and show the consumption summary prompt: total, score-deducted and wallet-paid parts; full-score-covered and no-charge variants; silent expiry when no bill appears. Verify: controller tests with scripted bill availability timing. <!-- comet-task:7e9bfb2c-8b41-47ca-8398-761a4e195bd7 -->
- [ ] 3.2 Re-fetch both balances once the settlement report completes; keep previously displayed values if the refresh fails. Verify: controller test asserts refresh call and failure tolerance. <!-- comet-task:0c4fde85-ee27-4415-87fc-177a13bdeb94 -->

## 4. Home page UI

- [ ] 4.1 Render a balance section (wallet yuan + score points) visible only when logged in, placeholder while unknown, following `home-page-ui` surface/hierarchy/contrast rules in light and dark modes. Verify: widget tests for logged-in, not-logged-in and load-failure states; `flutter analyze` clean. <!-- comet-task:d8a2c4fc-f96c-471f-88ac-c3e5ed944e8f -->
- [ ] 4.2 Ensure the consumption summary uses the existing prompt styling (no new dialog surface). Verify: covered by 3.1 tests plus a manual visual check on a real device in 5.2. <!-- comet-task:e8b052f7-aef3-41ff-86e6-7c28e46f810f -->

## 5. Verification

- [ ] 5.1 `flutter analyze` and `flutter test` fully green. Verify: commands exit 0 with all new and existing tests passing. <!-- comet-task:4d857319-4247-4aad-88c1-bbe34f7d1c22 -->
- [ ] 5.2 Real-device integration check with the user's account: start a session (wallet payment), force a rejection path to confirm no Alipay retry, confirm the bill report shows the score-discount breakdown, and confirm balances load and refresh. Verify: observed behavior recorded in the change's build context; deviations from D4/D3 contingencies noted before proceeding. <!-- comet-task:56a733a5-1464-4911-a9c7-abff83c8329c -->

## Workflow follow-up

- Build phase final review (per `review_mode: standard`) and the Verify phase integration review happen in their own phases; no tracked task here.
- Real-device checks in 5.2 need the user's device/account available during build or verify.

```

## docs/openspec/changes/align-payment-settlement/.openspec.yaml

- Source: docs/openspec/changes/align-payment-settlement/.openspec.yaml
- Lines: 1-2
- SHA256: 71e91d8f42848565b00ec7bb4da95cf19e2182f4adc440c230b10a0f3345023b

```md
schema: spec-driven
created: 2026-11-02

```

## docs/openspec/changes/align-payment-settlement/specs/account-balance/spec.md

- Source: docs/openspec/changes/align-payment-settlement/specs/account-balance/spec.md
- Lines: 1-40
- SHA256: 0b44a425420aec7751a5ba6746b5221ad1e86528db87cde891e451222a1ede98

```md
# Spec Delta: account-balance

## Purpose

Defines how the app makes the user's wallet balance and score balance visible: fetching the two account balances, displaying them on the home page, and keeping them current after settlements, so the user can see the funds the payment cascade draws from before and after each session.

## ADDED Requirements

### Requirement: Home page shows wallet and score balances

When the user is logged in, the home page SHALL display the account's wallet balance (as CNY) and the score balance (as points, using the server's valid-score value). The balances SHALL be fetched with the account's existing credentials from the wallet-owner and account-score endpoints, and the display SHALL follow the home page's existing visual rules for surfaces, hierarchy and contrast. When the user is not logged in, the home page SHALL NOT show balance values.

#### Scenario: Balances shown for a logged-in user

- **WHEN** a logged-in user opens the home page and both balance queries succeed
- **THEN** the home page shows the wallet balance in yuan and the valid score balance in points

#### Scenario: Not logged in

- **WHEN** no valid login exists
- **THEN** the home page shows no balance values and does not send balance requests

#### Scenario: Balance query fails

- **WHEN** a balance query fails or returns an unparseable response while the user is logged in
- **THEN** the balance section degrades gracefully (placeholder instead of a number, with no error dialog interrupting the user), and the rest of the home page keeps working

### Requirement: Balances refresh after settlement

After a session's settlement completes, the system SHALL re-fetch both balances so the displayed values reflect the deduction that settlement caused.

#### Scenario: Balances update after a session ends

- **WHEN** a water session settles (manually or by idle detection) and the bill is reported
- **THEN** the displayed wallet and score balances are refreshed to match the server state

#### Scenario: Refresh failure after settlement

- **WHEN** the post-settlement balance refresh fails
- **THEN** the previously displayed values remain, with no error dialog interrupting the user

```

## docs/openspec/changes/align-payment-settlement/specs/payment-settlement/spec.md

- Source: docs/openspec/changes/align-payment-settlement/specs/payment-settlement/spec.md
- Lines: 1-78
- SHA256: 1ee06efb18f1c2aa53a5a4579ba9dbe115d4d993eba36ebd2ba2a073d2018940

```md
# Spec Delta: payment-settlement

## Purpose

Defines how a water session is paid for and reported: the payment type used to start a session, what happens when the server rejects the payment, and how the finished session's consumption (including score deductions) is reported to the user. The platform server settles each session with a fixed cascade — score deduction, then wallet gift credit, then wallet balance, then Alipay for any remainder — so the client's job is to request wallet payment and make the server's settlement visible, never to silently switch payment methods.

## ADDED Requirements

### Requirement: Session start uses wallet payment without payment-method fallback

The system SHALL start a water session with the wallet payment type (`ptype=91`) and MUST NOT automatically retry the start request with a different payment type when the server rejects it. Before starting, the system SHALL keep its existing device precheck behavior: offline and disabled devices are blocked with a dedicated prompt, and a device already in use is adopted into the settle-able state without re-sending the start request.

#### Scenario: Start succeeds with wallet payment

- **WHEN** the user starts a session on an available device and the server accepts the wallet-payment start request
- **THEN** the session starts, the app enters the in-session state, and no other payment request is sent

#### Scenario: Wallet payment rejected — no automatic Alipay retry

- **WHEN** the server rejects the wallet-payment start request with any non-authentication failure (for example account arrears or a payment requirement)
- **THEN** the system surfaces that rejection to the user and MUST NOT send a second start request with the Alipay password-free payment type

#### Scenario: Login expiry is not retried

- **WHEN** the server rejects the start request because the login session has expired
- **THEN** the system prompts re-login and does not send any further start request

### Requirement: Server payment rejections are surfaced with actionable prompts

The system SHALL translate known server rejection codes — `-52` account arrears, `-82` payment required, `-88` no Alipay withholding agreement signed, `-87` withholding agreement expired — into actionable Chinese prompts, and MUST treat each as terminal for that start attempt. For any other rejection code, the system SHALL show the server-provided message when present, and fall back to a generic failure prompt otherwise. Network-level failures keep their existing technical prompt.

#### Scenario: Account arrears blocks start without method switch

- **WHEN** a start request is rejected with code `-52`
- **THEN** the user sees the arrears prompt telling them to top up, and no Alipay payment request is sent

#### Scenario: Missing withholding agreement

- **WHEN** a start request is rejected with code `-88`
- **THEN** the user sees the prompt explaining that no Alipay withholding agreement is signed

#### Scenario: Unknown rejection passes server message through

- **WHEN** a start request is rejected with a code the system does not map and the server provides a message
- **THEN** the user sees the server's message

### Requirement: Finished session reports consumption with score-discount breakdown

After a water session ends — via manual settle or idle detection — the system SHALL fetch the session's settlement bill and report one summary with the total amount, the score-deducted part and the wallet-paid part. The score part SHALL come from the bill's promotion record (promotion type 4, `discount`), the wallet part from the bill's `payment` field, so a fully score-covered session is reported as such. The report SHALL use the home page's existing prompt styling.

#### Scenario: Consumption paid by score and wallet

- **WHEN** a finished session's bill records a score discount and a wallet payment
- **THEN** the summary shows the total consumption, the score-deducted amount, and the wallet-paid amount

#### Scenario: Session fully covered by score deduction

- **WHEN** a finished session's bill has a score discount and a zero `payment` field
- **THEN** the summary reports the consumption as fully covered by score deduction, with no wallet amount implied

#### Scenario: No charge for the session

- **WHEN** a finished session's bill records no payment and no score discount
- **THEN** the summary reports that the session produced no charge

### Requirement: Settlement bill lookup tolerates reporting latency

The system SHALL briefly re-query for the settlement bill when it is not queryable immediately after the session ends, and SHALL finish quietly without blocking the user when no bill appears within that re-query window.

#### Scenario: Bill is not yet available

- **WHEN** the settlement bill is not queryable immediately after the session ends
- **THEN** the system briefly re-queries for the bill and reports as soon as it appears

#### Scenario: Bill never becomes available

- **WHEN** the settlement bill does not appear within the short re-query window
- **THEN** the system finishes quietly without blocking the user and without reporting a wrong amount

```
