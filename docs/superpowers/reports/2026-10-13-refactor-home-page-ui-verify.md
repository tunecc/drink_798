# Verification Report — refactor-home-page-ui (round 1: FAIL)

- Date: 2026-10-13
- Change: `docs/openspec/changes/refactor-home-page-ui`
- verify_mode: full · review_mode: standard · build_mode: autonomous · tdd_mode: tdd
- Baseline: `88167ac` → `9d3edf7` (11 files)
- Outcome: **FAIL**, recorded through `comet state transition refactor-home-page-ui verify-fail` (`verify_failures=1`), returned to Build.

## Checks at the time of round 1

| Check | Evidence | Result |
| --- | --- | --- |
| Tasks | 27/27 checked in `tasks.md` | pass |
| Build/tests | `fvm flutter test --no-pub` = 104 passed | pass |
| Static analysis | `fvm flutter analyze --no-pub` = No issues found | pass |
| Security | no secrets, no new unsafe I/O | pass |
| Integration review (independent reviewer) | general-purpose reviewer over the full diff | **found the failures below** |

## Failures that drove the transition

| # | Item | Severity | Evidence |
| --- | --- | --- | --- |
| 1 | Dark mode violates "Adjacent surfaces stay separable": the status card sits on the brand band, and `cardDark #1A222B` vs `bandTopDark #15293C` is **1.082** against the 1.15 floor. The band was lighter than the card, so the card read as a hole. | CRITICAL | recomputed with the WCAG formula in `home_page_ui_test.dart` |
| 2 | The tests covering it measured the wrong surface: `contrast(surfaceColor(card), pageBaseColor())` compares against the gradient's *last* stop, which is only painted at the bottom of the screen. | CRITICAL | `home_page_ui_test.dart` light and dark separation tests |
| 3 | The "second channel" assertion was a tautology — `card.border != null \|\| boxShadow.isNotEmpty` is true for every card ever built, so it could never fail. | IMPORTANT | same tests |
| 4 | Selection check marker hardcoded `accentStart`; on the dark selected tile that is **2.57**, under the 3.0 non-text floor, and a white glyph on it is unreadable. | IMPORTANT | `home_page.dart` marker container |
| 5 | Note-edit chip filled with `p.card` inside a resting tile that is also `p.card` — **1.000**, the affordance survived only as a 1px hairline. | IMPORTANT | `home_page.dart` `deviceEditKey` container |
| 6 | `HomeController.loadDevices()` returns early on the expired-session branch from inside `try`, skipping the tail that consumes `_reloadQueued`; the next load then fired a whole extra round of requests. The note dialog also built its `TextEditingController` in the `showDialog` builder and never disposed it. | IMPORTANT | `home_controller.dart`, `home_page.dart` |
| 7 | Spec Requirement 5 says the 拖动调整顺序 hint sits "on a surface distinct from normal browsing"; it was a bare `Text` on the page gradient. | IMPORTANT | `home_page.dart` `_buildReorderList` |

Two reviewer claims did not survive verification and were **not** acted on: both sheets already carried a grabber, and the in-progress indicator plus the 320×568 / 1.3 non-empty-list cases were already covered by tests.

## Reported, deliberately out of scope

- The about dialog hardcodes `版本: 1.0.4` while `pubspec.yaml` is at 1.0.6.
- `main.dart` forces `statusBarIconBrightness: Brightness.dark`, which is wrong over a dark band; pre-existing, outside this change's stated boundary of not touching global theme defaults.

## Handoff to Build

Round 2 was scoped to items 1–7: re-tuned dark surface tokens, a `backgroundBehind()` sampler that measures the gradient at each widget's own position, a measured three-channel separation assertion, mode-aware marker colors, chip and grabber fills moved onto the tint role, a real reorder-mode surface, the reload-flag clear, and a stateful note dialog that disposes its controller. Recorded under `tasks.md` group 8 and in the "Verify round 2" table of `design.md`.
