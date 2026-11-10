# Verification Report: align-score-deduction

- date: 2026-11-10
- verifier: independent Claude Code session (final integration review) + runtime checks
- review_mode: standard (independent final integration review, read-only)
- base: e61f6f4fff769a194de3902c7a647f0aa6690cdf → head: a6c4eec + working tree (version bump, changelog)

## Checks performed

| Check | Result | Evidence |
| --- | --- | --- |
| Full test suite (`fvm flutter test`) | passed | 180/180, "All tests passed" — run independently by the reviewer subagent AND re-run after post-review formatting (dart format of test file, non-behavioral) |
| Request shape (`acc/upt`) | passed | body exactly `{"useScore":1}`, Authorization only, no `sign`, no `ApplicationType` — pinned by `test/core/services/drink_api_service_request_test.dart` group; implementation `lib/core/services/drink_api_service.dart:435-449` + global headers at :87-97 |
| Sync-before-start ordering | passed | controller test with `callLog` asserts sync completes before `dev/start`; impl `lib/features/home/home_controller.dart:407-422` |
| Failure aborts (network + server code!=0) | passed | both failure tests assert `startCalls == 0`, dedicated prompt text distinct from `设备无响应` |
| Adopt/takeover path sends no sync | passed | adoption test asserts `setUseScoreCalls == 0`; adopt branch returns at `home_controller.dart:398-404` before the sync |
| Spec delta consistency | passed | both ADDED requirements (`specs/payment-settlement/spec.md`) verified against implementation scenario-by-scenario |
| Runtime build check (Comet guard) | passed | `comet guard align-score-deduction build --apply -- fvm flutter test` — ALL CHECKS PASSED, receipt submitted by Runtime |

## Independent final integration review

Reviewer verdict: **Ready to merge — Yes.** No Critical, no Important findings. Minor findings and their disposition:

1. Test file indentation inconsistency → **fixed after review**: `dart format test/core/services/drink_api_service_request_test.dart`, suite re-run 180/180 passed.
2. `catch (e)` swallows exception detail in `setUseScore` → accepted deviation: consistent with the file's existing error-handling pattern across all API methods; not a regression introduced by this change.
3. Unconditional `acc/upt` per start (one extra RTT) → accepted: this is the plan's explicitly chosen semantics (mirror reference client re-sync before every start); recorded as future optimization, no change required.

## Real-device verification (task 3.2, cannot be automated)

Confirmed by the user on 2026-11-10: started a real session with score > 0; the settlement bill carries score deduction (promo.type=4/discount), the score balance decreased. Bill/wallet remainder split and account-profile safety verified as part of the deduction chain check.

## Not executed / accepted deviations

- No penetration or server-side verification of `acc/upt` partial-update semantics beyond the real-device account-profile check (body pinned to exactly `{"useScore":1}` by tests; real-device check showed no profile side effects).
- Server behavior of `useScore` values other than 1 is out of scope (the app only ever sends 1).

## Conclusion

All acceptance scenarios of the delta spec are implemented, tested, and (where automation was impossible) verified on a real device. No unresolved Critical or Important issues. Result: **verify passed**.
