# Verification Report — refactor-home-page-ui

- Change: `docs/openspec/changes/refactor-home-page-ui`
- verify_mode: full · review_mode: standard · build_mode: autonomous · tdd_mode: tdd
- Baseline: `88167ac` → `7d30503` — implementation `9d3edf7`, rounds 2–6 `978537f`·`3b889e2`·`345ad5f`·`137dc3a`·`590d08b`, round 7 `3ddb1f0`, round 8 `01964ee`, round 9 `350ea7b`, verification report `7d30503`
- Method: `openspec-verify-change` across Completeness, Correctness and Coherence, plus three independent reviews — the whole-change final integration review, a scoped re-check of that review's fix round, and a final sign-off on the last increment (§7)
- Line numbers refer to the tree at `350ea7b`. Test cases are cited by name because names survive every round; bare numbers did not survive rounds 8 and 9.
- Outcome: **PASS**

Nine review rounds. Rounds 1–6 and 8 each returned to Build through
`comet state transition refactor-home-page-ui verify-fail` (`verify_failures = 8` at the final
transition); rounds 7 and 9 were driven by review findings and completed inside Build. No finding was
absorbed as an accepted deviation without being either fixed or recorded with its failure mode.

## 1. Completeness

| Check | Evidence | Result |
| --- | --- | --- |
| Tasks | 60/60 checked in `tasks.md` (`grep -c '^- \[x\]'` = 60); build guard `[PASS] tasks.md all tasks checked`, 14/14 | pass |
| Spec coverage | 9 Requirements, **20 Scenarios** (`grep -c '^#### Scenario'` = 3+3+4+3+2+2+1+1+1); every scenario maps to at least one test (§2) | pass |
| Build/tests | `comet check run refactor-home-page-ui build --local -- fvm flutter test --no-pub` → exit 0, **125 passed** (`26341550`), 51 of them in the home UI suite | pass |
| Static analysis | `fvm flutter analyze --no-pub` → **No issues found** (`09f30fd8`) | pass |
| Artefact validity | `comet classic openspec -- validate refactor-home-page-ui` → valid | pass |
| Handoff | `comet handoff … design --write` → `2c8dd198b9c4084cde559de528742373a6399f6bbcc7e460c8662c49d063f68c`; `--hash-only` → `FRESH` | pass |

## 2. Correctness — requirement → scenario → test

| Requirement | Scenario | Test(s) in `test/features/home/home_page_ui_test.dart` |
| --- | --- | --- |
| R1 Idle page keeps a brand anchor | Idle page top region | `idle page anchors the top instead of one flat fill` (439) — no two-stop no-op gradient survives anywhere on the page, the page base is provably not the global `#F5F9FF`, and at least one painted layer is darker (more saturated) than the base, which is the anchor |
| | Idle page bottom region | `the idle gradient lands exactly on the scaffold colour` (1782) — in both schemes the gradient's stop at t=1.0 equals the `Scaffold` background, so no hard edge appears above the safe area; the card that sits there is measured against the surface actually painted behind it (`resting card separates from the page by fill plus a second channel`, 466, which samples per position) |
| | Session in progress keeps its own accent state | `in-progress background and bubbles survive the new palette` (1220), `accent state stays readable at the lightest point of its gradient` (635) |
| R2 Adjacent surfaces stay separable | Resting card on the page background | 466, dark copy `dark mode keeps the same separation` (490) |
| | Selected card differs from resting card | `selection changes two channels and never glues the tile back` (518), `selection marker clears 3.0 against the tile and 4.5 for its glyph` (1446), `selection still reads after the hue is stripped away` (1511) |
| | Elevated sheet separates from the page | `device management sheet sits on its own surface role` (977), `both sheets carry a grabber that reads against the sheet face` (1572), `the sheet covers the page behind it` (1620), `every dialog face separates from the page in both modes` (1813) |
| R3 Text keeps a legible hierarchy | Hierarchy levels are distinguishable | `the page carries five distinct hierarchy levels` (668) — five sizes pinned item by item, weights beside them |
| | Secondary text is not brighter than primary text | `text on its own surface clears the contrast floors` (555), `de-emphasized text resolves through one role per face` (2083) |
| | Prompts the page raises stay legible | `the three prompt kinds are legible and keep distinct hues` (1897), `the plain blocking notice stays legible and carries no hue` (1997), `the note-save prompt the page raises itself is legible` (2041) |
| | Text on the accent state at its weakest point | 635, measured against the lightest stop of the accent gradient. Honest scope: it pumps the light scheme only, as does `in-progress background and bubbles survive the new palette` (1220); `_HomeT.accentFill` is a `const` shared by both palettes and the label is an unconditional `Colors.white`, so the figure transfers to dark without a dark pump — recorded in §5 as a coverage limit rather than claimed as both-scheme proof |
| R4 Primary action is focal and states availability | Device selected | `enabled action is the focal control and its label clears 4.5` (860) — height, full-row width, label contrast and the scenario's own `Ionicons.play_circle` |
| | No device selected | `unselected device leaves the action inactive and untappable` (891), `the disabled action paints nothing of its own` (1261) |
| | Session in progress | `settle state keeps its label readable` (912) — `stop_circle` present, `play_circle` absent — and `the in-card progress bar exists only while water is running` (1763) |
| R5 Device item states without shrinking targets | Grid and list layouts keep item states | `grid layout expresses the same selection language` (711): grid selection language, then a tap that moves the controller's selection with the marker following, then a long-press that opens that device's note editor. List side: `touch targets stay at or above the recorded baseline` (686) and the sweep's own tap/long-press (1072/1077) |
| | Reorder mode reads as a mode | `reorder mode keeps handles and the selected device` (759), `reorder hint sits on a surface distinct from normal browsing` (1478), `reorder mode survives 320x568 at 1.3 text scale` (1603) |
| R6 Home-owned sheets and dialogs | Device management sheet | 977, `the sheets carry the rows and icons the spec names` (2175), `delete still asks before removing a device` (1039) |
| | Settings sheet | `settings sheet keeps 关于 and 退出登录 on the same surface` (1001), 2175 (per-row leading icons), 1813 (version dialog face, exit confirmation) |
| R7 Dark mode follows the same hierarchy | Dark scheme device | 490, `dark mode carries the same floors for tiles, sheets and glyphs` (1300), `the tinted chip glyph clears the non-text floor in dark` (2221), 1813 (both modes) |
| R8 Usable at small sizes and large text | Small screen with enlarged text | `empty state survives a small screen at large text scale` (783), `device list survives a small screen at large text scale` (799), `grid layout survives 320x568 at 1.3 text scale` (1552), 1603 |
| R9 Existing interactions remain reachable | Full interaction sweep | `every entry the page had before is still reachable` (1061) — refresh, settings, layout toggle, reorder, scan-to-add, select, edit note, start, settle, manage, delete, empty-state scan — closing on `tester.takeException()` is null |

Requirement 3's 3.0 heading floor is asserted for both headings the page renders, in both schemes
(added in rounds 8 and 9); Requirement 7's "no text pair falls below the contrast floor" now has a
dark heading row rather than inheriting the light one.

## 3. Coherence — design decisions against the tree

| Decision | Where it lives | Verified as |
| --- | --- | --- |
| D6 gradient behind a real `FilledButton` | `home_page.dart:949–962` | `backgroundColor: Colors.transparent`, `elevation: 0`, `shadowColor: Colors.transparent`; wrapper and button read one shared `BorderRadius` variable (`home_page.dart:910`), 26 / 22 compact |
| D7 tiles keep structure, only paint changes | tile builders + test 686 | `GestureDetector`/`Container` and `ReorderableListView` retained; note chip 26×26 baseline asserted |
| D8 type scale | `_HomeT` + test 668 | six levels as inline `TextStyle`s (22/w700, 20/w700, 17/w700, 15/w600, 13/w400, 13/w500); family inherited through `DefaultTextStyle`, so `GoogleFonts.notoSansSc` still wins |
| D9 sheets and dialogs read the page tokens | `home_page.dart:1034` (the sheet `Material`'s `color: p.card`) + four `AlertDialog` `backgroundColor` sites | dark sheet role `#1E2934`; `showCupertinoModalBottomSheet` kept, its own `backgroundColor` staying transparent |
| D10 compact branch | `_HomePalette.isCompact` (`home_page.dart:145–147`) | height < 640 **or** `textScaler.scale(14) > 16.8`; asserted at 320×568 @ 1.3 |
| D11 test seam | `home_controller.dart:56`, `home_page.dart:210–212` | optional ctor param + `Get.isRegistered` guard; test 375 proves no real request |
| D12 keys | `home_page.dart` key constants | 64 `byKey` lookups in the suite |
| Boundary | `git diff 88167ac..HEAD -- lib/core lib/features/login lib/features/scanner` | empty — `app_theme.dart` untouched, login and scanner unchanged |

## 4. Round history — what each verify-fail bought

| Round | Opened by | Returned to Build for | Recorded in |
| --- | --- | --- | --- |
| 1 | independent review of `88167ac..9d3edf7` | dark band lighter than the card (1.082 vs the 1.15 floor), tests measuring the gradient's last stop instead of the surface behind each widget, a tautological second-channel assertion, a 2.57 selection marker in dark, a note chip at 1.000 inside its own tile, a skipped `_reloadQueued` tail, a bare reorder hint `Text`, an undisposed note dialog controller | design "Verify round 2", tasks group 8 |
| 2–3 | reviews of the round-2/3 diffs | palette and contrast items closed; stale records; a disabled-state regression where `disabledBackgroundColor` was missing and M3 `onSurface`@0.12 washed the face | groups 9–10 |
| 4 | closing coverage check | scenarios the spec names but no test reached (dialog faces in dark, grabber, sheet barrier, progress-bar absence) | group 10, "Verify round 4" |
| 5 | prompt contrast audit | eleven `Get.snackbar` sites on `Colors.orange/red/green` at 2.155/3.682/2.780 and four raising no face at all, landing on GetX's `Colors.grey.withOpacity(0.2)` default | `home_prompt_colors.dart`, "Build round 5", Spec Patch **P6** |
| 6 | whole-change review | two spec clauses with no assertion, dark-side floors measured in light only, records claiming the controller gained no behaviour while the coalescing is real, wrong numbers in permanent artefacts | groups 11–12, "Verify round 6" |
| 7 | final integration review of `88167ac..590d08b` | D3/D9 still describing the round-1 stack; 1.06→1.111, 4.4/4.6→3.51/4.09/4.80, 1.062→1.171, 1.398→1.348, 1156→1155; the spec-named play icon unasserted; an unfalsifiable `sizes.length >= 4` | group 13, "Build round 7" |
| 8 | final integration review of `88167ac..3ddb1f0` (0 CRITICAL / 2 IMPORTANT / 6 MINOR) | the grid half of an item-state clause never exercised; Requirement 3's heading floor with no heading enumerated; a test named for a face round 5 replaced; four non-reproducing records (20 scenarios not 16, radius 26/22 not 24, no `textTheme` mechanism, 1.115 not 1.113, 25.96° distance vs 5.96° slack) | group 14, "Build rounds 8 and 9" |
| 9 | scoped re-check of `3ddb1f0..01964ee` | `tasks.md` 5.2 still naming the retired radius while the amendment ledger claimed it corrected; the heading floor added for light only | group 15, same design section |

## 5. Accepted limits (deliberate, not oversights)

Each of these is a place where "the tests are green" means less than it looks. They are listed in
`design.md` — "Accepted limits of this suite" and "Accepted limits added in round 5" — and restated
here so an archive reader does not have to assemble them from nine tables.

- Requirement 3 is verified on **enumerated text pairs**, not by sweeping every `Text`; a new pair
  needs its assertion added by hand. The single-role guard proves *one value* across the six labels it
  enumerates, not that the value was reached through a named identifier.
- The two decorative chips' fill steps (in-progress 1.348 / 1.457, tint 1.214 light / 1.390 dark) are
  computed from the tokens and asserted by nobody; the suite gates the glyph on the chip. Both chips
  are insets inside a surface that already separates, so they sit outside the two-channel rule.
- The accent text floor is **pumped in the light scheme only** (tests 635 and 1220). It transfers to
  dark because `_HomeT.accentFill` is one `const` shared by both palettes and the label is an
  unconditional `Colors.white`, but nothing in the suite renders the in-progress card in dark, so a
  future change that branches the accent fill by scheme would not be caught here.
- "Keeps animating" is proven as presence/absence of the in-card progress indicator, not as motion.
- Snackbar hue separation: amber and red sit 25.96° apart against the suite's 20° floor, so the slack
  is 5.96° and the test prints the distance rounded to 26°; the neutral face sits 1.119 above the dark
  card; six of eleven prompt sites are covered by sharing a measured constant rather than by their own
  route.
- `dialogMaterial.last` can read the wrong nested `Material` — a false green if a nested face carries a
  distinct colour, a loud false alarm if it carries none — accepted for today's four dialogs.
- Text scale is exercised up to 1.3 because that is the number the spec names; type sizes are pinned as
  literals by D8.
- `版本:` is the anchor two tests share, because the dialog's version line is a literal. That literal
  was recorded as stale (`版本: 1.0.4` against `1.0.6+6`) and was corrected to `1.0.7` in the release
  commit without touching either test — which is the prefix-matching choice being proven rather than
  argued.
- Rounds 8 and 9 added coverage guards, not observed RED: every assertion they introduced passed on
  first write, and the only `lib/` edit across both rounds is a comment character.
- Taste is not a test: the suite proves relationships and floors; the on-device pass
  (`fvm flutter run`) stays with the user by their recorded preference. That pass was made on
  2026-10-14 by the user driving the app on an iPhone 14 Pro simulator, and reported as good — the
  record here says so because it is the one acceptance gate no automated check could close.

## 6. Reported, deliberately out of scope

- `LoginController` raises nine white-on-`Colors.red`/`Colors.green` prompts
  (`login_controller.dart:66,97,106,116,147,159,169,192,201`) — outside this change's boundary.
- `ScannerPage` overflows by 12px at 320×568 with a 1.3 text scale.
- ~~The about dialog hardcodes `版本: 1.0.4` while `pubspec.yaml` is at `1.0.6+6`.~~ Closed at the 1.0.7
  release commit (the user asked for it there): the line now reads `版本: 1.0.7`. It is still a literal
  rather than a value derived from the build, so it must be edited on every release — that part stays
  out of this change's boundary.
- `main.dart:15` forces `statusBarIconBrightness: Brightness.dark`, wrong over a dark band.

## 7. Final integration review and its disposition

**Review 1 — whole change, `88167ac..3ddb1f0` (independent reviewer, not the implementer).**
Verdict FAIL: 0 CRITICAL / 2 IMPORTANT / 6 MINOR. It explicitly cleared behaviour, boundary, security
and every shipped contrast figure, independently re-derived the prompt maths and GetX's fallback face,
and confirmed all eleven prompt sites. All eight findings were recomputed before being accepted and
all eight reproduced; each was fixed in round 8 (group 14) and the disposition recorded in
`design.md`'s "Build rounds 8 and 9" table.

**Review 2 — scoped re-check, `3ddb1f0..01964ee`.**
Verdict FAIL: 7 of its 8 items CLOSED, with three new items: the verification report's own counts and
line citations had rotted (55/55 against 60/60 tasks, 61 against 64 `byKey` lookups, ~30 citations at
pre-round-8 positions), the recorded handoff was STALE rather than FRESH, and two leftovers required
Build — `tasks.md` 5.2's retired radius and the light-only heading floor. All three were closed in
round 9 plus this rewrite: the handoff is refreshed (FRESH, `2c8dd198…`), the report's numbers were
regenerated from the final tree, and both headings now clear 3.0 in dark.

Review 2 also verified the falsifiability of round 8's new assertions rather than trusting them: the
grid marker assertion can only pass in two-column layout because `checkmark_circle` appears solely in
`_buildGridDeviceItem` (`home_page.dart:812`) while the list uses `Ionicons.checkmark` (`:710`), and
the long-press assertion resolves through the grid tile's own `onLongPress` (`:764`) into a
device-specific dialog title.

**Review 3 — final sign-off on the increment `01964ee..7d30503`.**
Verdict **PASS**, 0 CRITICAL / 0 IMPORTANT / 1 MINOR plus one nit, all of them about this report
rather than the product. It confirmed the increment touched six paths and no `lib/` file, that both
round-8 leftovers are closed (the only surviving "24"s are ledger lines that describe the retired
draft, and the dark headings measure the faces they paint on — white on `#1E2934` recomputes to 14.77,
the headline 17.57 through `contrastOnPageText`'s min over base and band), that the new assertions
fail loudly rather than green when a colour or widget goes missing (no self-reads, `StateError` on a
null ink, `gradient!` on a null face, no `skip:` in the file), and that 20+ of this report's own
counts and `(line)` citations reproduce — including the guard's 14 checks, which it confirmed is a
fixed rule count rather than something derived from this change.

Its findings were two claims this rewrite had just introduced, both corrected above rather than
excused: §2 attributed per-position gradient sampling to test 439, whose body contains no sampler at
all (the bottom-region proof is 1782, one row away), and §2 described test 635's accent measurement as
"both schemes" when it pumps light only. The `home_page.dart:1030` citation was one line short of the
sheet face. Every count in this report was regenerated from the tree rather than copied forward — task
count from `grep -c '^- \[x\]'`, scenario count from `grep -c '^#### Scenario'`, the `byKey` count from
`grep -c byKey`, and each `(line)` citation from the `testWidgets('` declarations — because review 2
had just caught this document quoting the previous round's numbers.

## Final assessment

No CRITICAL or IMPORTANT item is open. Tasks 60/60; 125 tests green including 51 in the home UI suite;
analyzer clean; `openspec validate` valid; handoff FRESH; the boundary holds (empty diff for
`lib/core/theme`, `lib/features/login`, `lib/features/scanner`); every numeric claim a reader can
re-derive has been re-derived with the harness's own rounding, and the four cases where rounding was
got wrong are recorded rather than quietly re-edited.

**Archived.** The archive commit is `ab9bc62` on `main` (`docs/openspec/changes/archive/2026-10-14-refactor-home-page-ui/`,
main spec `docs/openspec/specs/home-page-ui/spec.md` merged from the delta), and it stays local —
nothing was pushed and no PR was opened. The user's own on-device pass, the one gate this suite never
claimed to cover, came back good on 2026-10-14.
