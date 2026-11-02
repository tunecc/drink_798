---
change: align-payment-settlement
design-doc: docs/openspec/changes/align-payment-settlement/design.md
base-ref: 7380c52c9475661507bd4e3ba5b39611e394f2e9
---

<!-- comet-task-authority: docs/openspec/changes/align-payment-settlement/tasks.md -->

# Plan: align-payment-settlement

Execution: `autonomous` + `tdd` + `standard` review. Every implementation task follows RED → GREEN: write the test against the not-yet-implemented behavior, record the real failing command and its failure reason, implement, then record the passing command. Verification commands run from the repo root: `flutter test <file>` per task, `flutter analyze` + `flutter test` for the full suite (task 5.1). Fixtures come from the reference client (life-798) response shapes cited in design.md D3/D4.

## Task 1.1 — Fixture capture

<!-- comet-task-ref:eaf980c2-df03-4f00-98fb-49791d52ad44 -->

Scope: record reference response shapes as Dart test fixtures under `test/`: wallet-owner (`data.aw` + `data.eps[]` with balances), acc-score (`data.validScore`, `data.totalScore`), bill list (`/bill/lst-owner` record with `type=91`/`status=3`/`cata=6`, `payment`, device ref, `utime`/`ctime`), bill detail (`data.bill` with `promo.type=4` + `discount`, and a variant without promo). Dependencies: none. Acceptance: fixtures compile in 1.2/1.3 tests; shapes cited in a note in the change's build context (`.comet/build-context.md` in the change dir).

## Task 1.2 — Balance endpoints in DrinkApiService

<!-- comet-task-ref:e81d3cb2-2717-4dc2-b039-cd568387461f -->

Scope: `AccountBalance` model (wallet yuan double, score int); `walletBalance()` GET `/acc/wallet/owner`, `scoreBalance()` GET `/acc/score/acc-score` with the standard `Authorization` header only; parsers pick the endpoint-matching (else single) wallet entry from `aw`/`eps[]`, `data.validScore` for score; unexpected shapes return null instead of throwing. RED first: request-shape tests (URL, query, headers) + parser tests against 1.1 fixtures. Acceptance: `flutter test test/drink_api_service_request_test.dart` green.

## Task 1.3 — Settlement bill query + parser

<!-- comet-task-ref:4be1b4f8-6ed1-4e56-b9fd-a53c5d8d326d -->

Scope: bill list query method (GET `/bill/lst-owner?page=0&size=20`) and a pure parser: filter `type=91`/`status=3`/`cata=6`, device match, `utime|ctime` ≥ session start, take latest; produce total (`payment` + promo discount), score part (only `promo.type=4` → `discount`), wallet part (`payment`); other promo types ignored; `payment=0` handled; no bill → null. RED first with 1.1 fixtures incl. full-score-covered and other-promo cases. Acceptance: parser unit tests green.

## Task 2.1 — Failure prompt mapping

<!-- comet-task-ref:560143cb-e198-4e45-89f9-ad81a9259ed9 -->

Scope: extend `drinkFailurePrompt` with `-52` 欠费请充值 / `-82` 需要支付 / `-88` 未签约代扣协议 / `-87` 签约过期 Chinese prompts; `-99` and server-message pass-through unchanged. RED first: prompt unit tests for each mapped code + one unmapped code + pass-through. Acceptance: prompt tests green.

## Task 2.2 — Remove silent fallback

<!-- comet-task-ref:a810f378-8192-471e-9e8d-6d85cf551342 -->

Scope: in `HomeController.startDrinking`, delete the `ptype: 21` retry branch (keep precheck and session-expiry handling). RED first: rewrite the existing fallback tests to assert exactly ONE start request on wallet rejection and that the rejection prompt is surfaced. Acceptance: controller tests green; no `ptype: 21` reference remains in `lib/`.

## Task 2.3 — Balance state in controller

<!-- comet-task-ref:315cde1b-3574-443b-9c5e-ef07d0cb7f53 -->

Scope: nullable `walletBalance`/`scoreBalance` observables on `HomeController`; fetch after device list load when logged in; failures and logged-out → null without dialogs, no requests when logged out. RED first with a fake API service. Acceptance: controller tests green.

## Task 3.1 — Settlement reporting poll

<!-- comet-task-ref:7e9bfb2c-8b41-47ca-8398-761a4e195bd7 -->

Scope: after manual settle success and after idle-detection completion, run the bounded poll: list query (few attempts, seconds apart, hard stop) → detail fetch → emit consumption summary prompt via existing prompt styling (total / score part / wallet part; full-score-covered variant; no-charge variant); silent finish when no bill or no detail within the window. RED first: scripted fake API with bill appearing on Nth poll, never appearing, detail-failing. Acceptance: controller tests green.

## Task 3.2 — Balance refresh after settlement

<!-- comet-task-ref:0c4fde85-ee27-4415-87fc-177a13bdeb94 -->

Scope: re-fetch both balances once the settlement report completes (or the window expires); keep stale values on refresh failure. RED first. Acceptance: controller test asserts refresh calls and failure tolerance.

## Task 4.1 — Home page balance section

<!-- comet-task-ref:d8a2c4fc-f96c-471f-88ac-c3e5ed944e8f -->

Scope: balance section on `home_page.dart` — wallet yuan + score points, visible only when logged in, placeholder while unknown, silent degradation on load failure; follows `home-page-ui` surface/hierarchy/contrast rules in light and dark mode. RED first: widget tests for the three states in both modes. Acceptance: widget tests + `flutter analyze` clean.

## Task 4.2 — Consumption summary styling

<!-- comet-task-ref:e8b052f7-aef3-41ff-86e6-7c28e46f810f -->

Scope: confirm the summary prompt from 3.1 uses the existing snackbar styling path (no new dialog surface); adjust if needed. Depends: 3.1. Acceptance: covered by 3.1 controller tests; manual visual check deferred to 5.2.

## Task 5.1 — Full local verification

<!-- comet-task-ref:4d857319-4247-4aad-88c1-bbe34f7d1c22 -->

Scope: `flutter analyze` and `flutter test` fully green from repo root. Depends: all above. Acceptance: both commands exit 0; record via `comet check run` for build evidence.

## Task 5.2 — Real-device integration check

<!-- comet-task-ref:56a733a5-1464-4911-a9c7-abff83c8329c -->

Scope: with the user's account/device: start a session (wallet payment), confirm no Alipay retry on a rejection path, bill report shows the score-discount breakdown, balances load and refresh. Requires the user's device available; coordinate timing. Acceptance: observed behavior recorded in the change's build context; D3/D4 contingency decisions noted if shapes differ.
