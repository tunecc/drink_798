# Verification Report: align-payment-settlement

- Date: 2026-11-02
- Mode: full (scale: 12 tasks, 2 delta-spec capabilities, 16 changed files)
- Implementation commit: `9186fd0` (feature) + `56dd6fe` (lockfile chore)
- Base ref: `7380c52`

## Summary

| Dimension    | Status |
|--------------|--------|
| Completeness | 12/12 tasks complete; 2/2 delta specs implemented (6 requirements) |
| Correctness  | 16/16 spec scenarios covered by tests or the user's device run |
| Coherence    | Design decisions D1–D5 followed; divergences documented; no spec drift |

## Completeness

- tasks.md: 12/12 checked (`[x]`), including task 5.2 real-device integration check performed by the user on the test APK (`v1.0.7+7`, arm64, sha256 `d056091d…`).
- Requirements implemented and evidenced:
  - `payment-settlement` — wallet-first start without payment-method fallback (`home_controller.dart` startDrinking; request-shape tests assert `ptype=91` and exactly one start request on rejection); rejection prompts `-52/-82/-88/-87` (`drinkFailurePrompt` mapping + unit tests); per-session consumption reporting with score-discount breakdown (`_startSettlementReport` + `SettlementBillParser`); bounded two-step list→detail poll; balance display and post-settlement refresh (`accountBalance`, `home_page.dart` balance strip).
  - `account-balance` — both endpoints fetched with the existing credentials; logged-in-only visibility; placeholder degradation; refresh after settlement.

## Correctness — scenario coverage matrix

| Spec scenario | Evidence |
| --- | --- |
| Start succeeds with wallet payment | `tapping starts and settles through the injected service`; request-shape tests (`ptype=91`) |
| Wallet rejection — no automatic Alipay retry | `a wallet-payment rejection never switches payment method` (startCalls=1, ptypes=[91]) |
| Login expiry is not retried | `a session-expired start error does not retry with alipay` |
| Account arrears (-52) blocks without method switch | prompt unit test + `an arrears rejection (-52) prompts a top-up, not alipay` |
| Missing withholding agreement (-88) / expired (-87) / payment required (-82) | `drink_failure_prompt_test.dart` mapped-code tests |
| Unknown rejection passes server message | pass-through unit test (unchanged legacy tests) |
| Consumption paid by score and wallet | `manual settle reports consumption with the score breakdown` |
| Session fully covered by score deduction | `a fully score-covered bill reports the deduction as the total` |
| No charge for the session | `a zero-cost bill reports no charge` |
| Bill not yet available | `a bill appearing late is still reported within the window` |
| Bill never becomes available | `a bill that never appears finishes quietly…`; `a missing bill detail never reports a wrong amount` |
| Balances shown for a logged-in user | `balances load with the device list…`; balance-section widget tests (light + dark) |
| Not logged in | `hides the section when logged out`; service test asserts no request |
| Balance query fails | `shows placeholders while balances are unknown`; `failed balance lookup degrades to hidden` |
| Balances update after settlement | manual/idle settle tests assert refreshed values (9.55/60) |
| Refresh failure keeps previously shown values | `a failed balance refresh keeps the previously shown values` (regression test from review round 1) |

Additional regression coverage beyond spec: `an adopted busy session is not reported as our own` (session-start hygiene), precheck offline/disabled/busy tests (existing), parser edge cases (other promo types ignored, negative/invalid amounts rejected, second-precision timestamps).

## Coherence

- D1 (no fallback, no dialog): implemented; no `ptype=21` remains in `lib/` (grep-verified by reviewer).
- D2 (mapping in the shared pure helper): `drinkFailurePrompt` extended; `-99` and pass-through unchanged.
- D3 (two-step bounded poll): implemented as designed; endpoints confirmed from the reference client and recorded in build context; open question resolved during design.
- D4 (existing token/headers; ApplicationType contingency): primary route shipped and device-verified; contingency not needed.
- D5 (nullable balance state + home-page section): implemented; `AccountBalance(walletYuan, score)` dual-nullable per design intent.
- Documented deviations (`.comet/build-context.md`): wallet entry selection follows the reference client's stricter eid-matching semantics; adopted sessions never report. Neither contradicts a delta spec.
- Design doc: `docs/openspec/changes/align-payment-settlement/design.md` (canonical, frontmatter `role: technical-design`); no separate Superpowers design file; no drift between delta specs and design doc after the design-phase refinement (D3 endpoints recorded in "Resolved During Design").

## Check evidence

- `flutter test`: 173/173 passing (reviewer independently re-ran; verify check re-run via `comet guard verify --report … --apply`).
- `flutter analyze`: 2 pre-existing deprecation infos outside this diff (SDK evolution; present on the clean base tree).
- Independent review (review_mode: standard): round 1 CHANGES_REQUIRED (I-1 refresh failure cleared balances; I-2 stale session start mis-attributed adopted sessions) → fixed with regression tests; round 2 APPROVED. Post-approval delta: one docstring reword (comment-only) confirmed against the final diff.
- Real-device integration (task 5.2): passed by the user on the test APK — balance strip, consumption report with score breakdown, no Alipay retry on arrears, logged-out hiding.

## Issues

- CRITICAL: none.
- WARNING: none.
- SUGGESTION: partial-refresh semantics — if `accountBalance` returns non-null with one side null, that side is shown as placeholder rather than keeping the previous value; both spec readings are defensible, reviewer accepted current behavior (recorded for future hardening).

## Final assessment

All checks passed. Ready for archive.
