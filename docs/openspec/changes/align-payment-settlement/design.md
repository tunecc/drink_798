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

- Bill endpoints confirmed from the reference client: list `GET /bill/lst-owner?page=0&size=20`, detail `GET /bill/view-full?id=<billId>` (`data.bill` envelope); the list does not carry the score-discount promo, hence the two-step flow in D3.
