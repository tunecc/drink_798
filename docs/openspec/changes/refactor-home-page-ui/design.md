---
comet_change: refactor-home-page-ui
role: technical-design
canonical_spec: openspec
---

# Design

## Context

`lib/features/home/home_page.dart` is 1156 lines holding the page, both bottom sheets, five dialogs and the bubble animation. Four facts shape the approach:

- The idle background is a bug-shaped gradient: `colors` is `[scaffoldBackgroundColor, scaffoldBackgroundColor]` when `isDrinking` is false, so the `AnimatedContainer` paints one flat `#F5F9FF`, and white `cardColor` on it is a surface ratio of **1.057** — measurable, but far below anything a user reads as layering.
- The accent colors already in use fail WCAG against their own text: white on the `#00D4FF → #0099CC` water gradient is **1.77–2.38:1**, and white on `Colors.orange` (the 结算 state) is **2.16:1**. The page is not just flat, it is low-legibility exactly where it is loudest.
- `themeMode: ThemeMode.system` in `lib/main.dart` makes dark mode the default on dark-scheme devices, so a palette that only works in light mode is a defect, not a preference.
- `HomePage.build` calls `Get.put(HomeController())` and `HomeController` builds `DrinkApiService()` itself, so the page cannot be driven from a widget test without real requests. `LoginPage` already solved both halves: it guards registration with `Get.isRegistered` and accepts an injected service (`LoginController({DrinkApiService? apiService})`), which is what `test/features/login/login_page_ui_test.dart` relies on.

Project memory for the login change fixes two more constraints used below: widget tests that can raise `Get.snackbar` need `GetMaterialApp` (a bare `MaterialApp` throws in `SnackbarController._configureOverlay`), and a fake service must extend through the generative `DrinkApiService.test()` constructor because a factory constructor cannot be a super constructor.

All contrast figures in this document are WCAG 2.x relative-luminance ratios computed with `lin(c) = c/12.92 | ((c+0.055)/1.055)^2.4`, `L = 0.2126R + 0.7152G + 0.0722B`, `(Lhi+0.05)/(Llo+0.05)`, with translucent foregrounds composited over their own background first. The Build phase re-implements the same two functions in test code so no value is asserted from memory.

See `proposal.md - Why` for motivation and `specs/home-page-ui/spec.md` for the requirements.

## Goals / Non-Goals

**Goals:**

- A token-driven layering system for this page — named surface roles, a fixed type scale, one background treatment per state — where every adjacency and every text/accent pairing is backed by a computed number.
- Structure `home_page.dart` the way the login page is structured (one file, private widget classes, keys on assertable elements) rather than adding a widgets directory or a second theme file.
- Every spec scenario assertable from the widget tree, in both brightness modes.
- Keep the controller's business logic, all persisted `SharedPreferences` keys and every server call unchanged.

**Non-Goals:**

- No new information (water volume, session duration, per-device statistics) and no information-architecture reorganization — the user fixed the depth at "same features, visual hierarchy only".
- No change to global `AppTheme` defaults (`scaffoldBackgroundColor`, `cardColor`, `colorScheme.surface`, button themes), so `login_page.dart` and `scanner_page.dart` render exactly as they do now.
- No restyle of `Get.snackbar` feedback, no change to the scanner page or the bubble animation internals.
- No animation or performance work beyond keeping current bubble behavior intact.

## Decisions

### D1 — Reuse the login page's settled visual language

Light body plus a brand-gradient header band anchored at the top, expressed the way `LoginPage` does it: a `Positioned` band whose gradient starts at `colorScheme.primary.withValues(alpha: 0.16)` and dissolves into the body color.

*Alternatives considered and rejected by the user:* an immersive dark water theme (would leave two visual languages in one app, and the most dark-mode work) and a cardless hairline layout (weakens the in-progress state and forces deleting the bubbles).

### D2 — Page-private tokens, not shared theme defaults

Every value below is a `static const` on a private `_HomeTokens` holder inside `home_page.dart`, read through a `bool isDark` branch. The page paints its own base surface with `Positioned.fill` inside the existing `Stack`, so no global default has to move.

*Why:* the user bounded the blast radius at the home page. Writing surface roles into `AppTheme` would change the login and scanner pages' defaults and pull their regression tests into this change.
*Trade-off:* values are duplicated with the login page's local constants. Accepted — a shared `AppSurfaces` table is a separate change.

### D3 — Verified surface role table

| Role | Light | Dark | Adjacency proof |
| --- | --- | --- | --- |
| Page base | `#E4EEF8` | `#0F1417` | vs card **1.174** / **1.154** |
| Band top (primary α .16 over base) | `#C5E0F7` | primary α .14 over base | vs page **1.163** |
| Resting card / sheet | `#FFFFFF` | `#1A222B` | grabber + heavier shadow + barrier |
| Selected card | `#FFFFFF` + `#2196F3` 1.6px border + `#DCEBF9` icon chip + solid check chip | `#22303E` + `#3A9BDC` border | card→page still **1.174**; dark card→selected **1.193** |
| Accent (in-progress card, enabled primary action) | `#0277BD → #00619E` | same | white label **4.80** at the lightest stop |
| Settle action | `#B45309` | same | white label **5.02** |
| Disabled action | `#C6D3DE` + `#5A6B7B` label | `#232B33` + `#7C8894` label | inactive; exempt under WCAG 1.4.3 |

Two corrections this table forced on the Open-stage draft:

1. **Selected tiles do not change fill in light mode.** A tinted selection (`#F5FAFF`) measures only **1.118** against the new page base, i.e. selecting a device would visually glue the tile back into the background — the opposite of the intent. Selection is carried by border + icon-chip tint + solid check chip + elevation; dark mode keeps the fill tint because there it *strengthens* the step (1.193). The spec's selected-state scenario was patched to "at least two of fill, border, elevation, marker" (Spec Patch P2) to match the math.
2. **The page base must not be lighter.** `#F5F9FF` yields 1.057 against white cards; no amount of shadow tuning makes that read as layering. `#E4EEF8` is the minimum change that clears 1.15.

### D4 — Text tokens, and why not `onSurfaceVariant`

| Token | Light | Dark | Measured |
| --- | --- | --- | --- |
| Primary | `Colors.black87` | `Colors.white` | 13.71 on page, 16.10 on card / 16.06 on dark card |
| Secondary (card) | `Colors.black.withValues(alpha: 0.60)` | `Colors.white.withValues(alpha: 0.70)` | 5.74 on card / 8.50 on dark card |
| Secondary (page base) | same α .60 | same α .70 | 5.48 on page / 9.33 on dark page |
| Brand glyph on tint chip | `#1565A8` | `#64B5F6` | 5.00 on `#DCEBF9` / 7.25 on dark card |
| Neutral glyph on page base | `#5A6B7B` | `#9AA7B4` | 4.68 (non-text floor 3.0) |

`Theme.colorScheme.onSurfaceVariant` is `Colors.black54` from the login change. Composited over the new page base it measures **4.44:1**, below the 4.5 floor the spec sets for caption text, so the home page carries its own secondary token at α .60 and uses it on every surface. Non-text elements (icons, borders) are held to 3.0:1, which is why the existing `AppTheme.primaryColor` glyph on a 10%-primary chip (**2.57**) is replaced by `_brandOnTint`.

De-emphasis below the floor is expressed through size and weight, never through alpha: the in-progress caption at `white.withValues(alpha: 0.85)` measures **3.92:1** on the accent gradient, so it becomes full white at 13/w400 under a 22/w700 headline.

### D5 — One background per state, never a two-stop no-op

`_HomeBackground` holds two named three-stop gradients — idle (brand tint → band → page base) and in-progress (accent water → page base) — both ending exactly on the page base color, applied to a `Positioned.fill` `AnimatedContainer` that keeps the current 800ms cross-fade. Because each gradient's terminal stop is a literal token rather than `Theme.of(context).scaffoldBackgroundColor`, no state can collapse into a flat field again, and the bubbles overlay stays unchanged above it.

### D6 — Primary action: gradient painted behind a real `FilledButton`

The control stays a `FilledButton` so `onPressed: null` continues to produce the correct disabled semantics, ripple, focus traversal and label/icon layout. Its gradient comes from a wrapping `DecoratedBox` while the button itself sets `backgroundColor: Colors.transparent`, `elevation: 0` and `shadowColor: Colors.transparent`; Flutter paints the `DecoratedBox` before its child, so the ink overlay lands on top of the gradient.

The mandatory detail: the button's `shape` radius must equal the wrapper's (24), otherwise the ripple is clipped to `AppTheme`'s 16 and the pressed state visibly cuts the corner. Height 64. When disabled the wrapper paints the flat neutral fill and the label moves to the neutral label token.

*Alternatives considered:* an `InkWell` over a gradient container — rejected, it loses `Semantics(enabled: false)` and needs manual focus; a solid `FilledButton` with only a glow shadow — rejected, the gradient is the visible part of the request; `ShaderMask` over the button — rejected, it also masks the ink and any child icon tint.

### D7 — Device tiles keep their structure, states change only paint

`_buildCompactDeviceItem` and `_buildGridDeviceItem` keep `GestureDetector` + `Container` and every existing child, including the note-edit chip measured today at **26×26** (`EdgeInsets.all(6)` + `Icon(size: 14)`), the row height and the toolbar icon buttons. Those numbers become explicit minimums asserted by test, so "no hit area shrinks" is checked rather than promised. Reorder mode keeps `ReorderableListView` and the drag handle and only gains a distinct surface for the hint row.

*Alternatives considered:* `ListTile`/`Card` — rejected, the border-and-fill control is the point; wrapping tiles in `InkWell` for ripple — deferred, it changes tap feel the user did not ask to change.

### D8 — Type scale as constants

Six named levels: screen title 20/w700, status headline 22/w700, status caption 13/w400 (secondary token), section title 17/w700, item title 15/w600, secondary action 13/w500. Applied through `Theme.of(context).textTheme` copies where possible so `GoogleFonts.notoSansSc` keeps winning.

### D9 — Sheets and dialogs read the same tokens

Both bottom sheets keep `showCupertinoModalBottomSheet` (already gives the drag-to-dismiss feel) and change paint only: the two `Material(color: Theme.of(context).scaffoldBackgroundColor)` sites become the sheet role (`#FFFFFF` / `#1A222B`), plus grabber, title and row tokens. `AlertDialog` resolves its background from `colorScheme.surface`, which is `#F5F9FF` today and would now read as a third gray, so each dialog passes `backgroundColor` = sheet role locally.

*Alternatives considered:* migrating to `showModalBottomSheet` — rejected as churn with no visual gain; changing `colorScheme.surface` globally — rejected, it would repaint the login page.

### D10 — Small-screen and large-text-scale guard

The current `Column` mixes `Spacer()` with a fixed 64px action and a fixed-height status card, which overflows a `RenderFlex` at small heights and grows worse under accessibility text scaling. The redesign keeps the `Spacer` structure (the user asked for no layout reorganization) but binds paddings and gaps to a compact branch when `MediaQuery.size.height < 640` or `textScaleFactor > 1.2`, and proves it with a 320×568 @ textScale 1.3 pump asserting `tester.takeException()` is null. This became Spec Patch P4 because it is an acceptance condition, not a style preference.

### D11 — Test seam matching the login page

`HomeController({DrinkApiService? apiService}) : _apiService = apiService ?? DrinkApiService()`, and `HomePage.build` becomes `Get.isRegistered<HomeController>() ? Get.find() : Get.put(HomeController())`, mirroring `LoginPage`. Production wiring is unchanged.

*Alternatives considered:* swapping a Dio adapter into the singleton (`setHttpClientAdapter`) — rejected, it couples page tests to the transport and still needs parsed device payloads; registering the fake as a Get service — rejected, `DrinkApiService` is a factory singleton and is never resolved through Get.

### D12 — Keys for the assertable parts

`homeBackground`, `statusCard`, `primaryAction`, `deviceTile-<id>`, `layoutToggle`, `reorderToggle`, `deviceManageSheet`, `settingsSheet` — tests select by key, so a palette tweak cannot silently retarget an assertion.

### Testing strategy

Relationship assertions, not literal hex: a `contrast(a, b)` / `surfaceRatio(a, b)` helper re-implementing the formula above drives the ≥4.5, ≥3.0 and ≥1.15 floors; a forbidden-color list keeps the legacy flat `#F5F9FF` full-page fill and the `#00D4FF` light stop from coming back; disabled state is asserted through `FilledButton.onPressed == null`; hit areas through `tester.getWidgetRect(...)` against the recorded baseline. One parameterized `pumpHomePage(tester, {brightness, devices, isDrinking})` helper covers both modes with `GetMaterialApp`, `SharedPreferences.setMockInitialValues({})`, `Get.reset` teardown and snackbar-queue draining — the same shape as `pumpLoginPage`.

## Risks / Trade-offs

- [The page base becomes `#E4EEF8` while `Scaffold`'s own background stays `#F5F9FF`, so anything exposing the Scaffold (loading branch, overscroll glow, sheet under-fill) can show a second gray] → the page paints `Positioned.fill` over the whole body including the loading branch, and both sheets take the sheet role instead of `scaffoldBackgroundColor`; the final visual pass is the user's on-device check.
- [Deepening the light background is a taste call no test can settle] → automated checks prove the relationships, the user's device run stays the acceptance gate for taste (their recorded preference).
- [Numeric token assertions can harden into hex-locking and break on the next palette tweak] → assert ratios and forbidden legacy values only; token literals appear in one `_HomeTokens` block.
- [Changing the accent water gradient from `#00D4FF/#0099CC` to `#0277BD/#00619E` is a visible brand shift, darker and less "cyan"] → it is the only way to keep white labels at 4.5:1; the brighter cyan survives as the in-progress icon and bubble tint where it carries no text.
- [Touching `HomeController`'s constructor touches a file with passing tests] → the parameter is optional and defaults exactly as today; `drink_failure_prompt_test.dart` only exercises the top-level function; the whole suite must stay green.
- [1156 lines of churn can silently drop an interaction] → the "existing interactions remain reachable" requirement is checked item by item in tasks, and the empty-list, reorder and in-progress branches each get their own case.
- [A transparent `FilledButton` over a gradient can lose its pressed overlay] → explicit overlay color plus matched radius; if the overlay still does not read on a given palette, fall back to a solid two-token brand fill on the wrapper rather than replacing the button widget.
- [Both brightness modes double the assertion surface] → one parameterized pump, run twice per scenario group.

## Migration Plan

No data or API migration: `device_list_layout`, `device_order`, `device_note_<id>` and the token keys are untouched, so upgrade and downgrade are pure visual swaps. Rollback is reverting the implementation commits; no persisted state needs cleaning. Ship as one commit set — the page reads as broken half-migrated.

## Spec Patches applied

- **P1** — "measurable fill step" quantified: adjacent surface roles differ by ≥1.15:1 and are additionally separated by border or shadow.
- **P2** — selected tile scenario relaxed to "at least two of fill, border, elevation and marker", with the measured reason kept in the scenario (a tinted light-mode selection would drop below the P1 floor against the page base).
- **P3** — text over an accent fill or gradient must reach 4.5:1 at the *lightest* point of that gradient, and de-emphasis must come from size or weight rather than from alpha below the floor.
- **P4** — new requirement: the page renders without overflow and with all controls reachable at 320×568 with a 1.3 text scale.

## Open Questions

- Exact band height (login uses 168; the home app bar sits higher) — tuned in Build against a 320px-wide and a tall device; changes no requirement.
- Whether the grid tile aspect ratio stays 2.4 after the border change — resolved by measurement in Build; both layouts already satisfy the same state requirement.

## Build amendments (found while implementing, same scope)

These correct numbers in the tables above or fill gaps they left. None changes a requirement.

| Item | Was | Now | Why |
| --- | --- | --- | --- |
| D3 dark icon chip | `tintDark = #22303E` | `#2A3947` | It was the same literal as `selectedDark`, so a selected tile's icon chip had 1.00:1 against its own row and the icon sank into the fill. |
| D4 brand ink (light) | `#1565A8` | `#0F5C99` | Text sitting in the upper band is measured against `#C5E0F7`, not the page base — `#1565A8` there is **4.45:1**, under the 4.5 floor. `#0F5C99` gives 5.11 on the band and 5.74 on the tint chip. |
| D3 disabled label | light `#5A6B7B` / dark `#7C8894` | `#4A5765` / `#9AA7B4` | 3.60 / 3.96 → 4.85 / 5.84 against the disabled fill. Inactive controls are exempt from 4.5, but an unreadable label is not a design choice. |
| D6 action radius | "24" | 26 (22 compact) | Wrapper and button share one `BorderRadius` variable so they cannot drift; the documented value is corrected to what is built. |
| D6 pressed overlay | inherited from theme | explicit `Colors.white α .24` | The M3 default overlay is `onSurface`-based, i.e. near-black in dark mode — no visible wash on the accent fill. Set through `ButtonStyle.copyWith(overlayColor:)`. |
| D6 disabled fill | `backgroundColor: transparent` only | also `disabledBackgroundColor: transparent` | `ButtonStyleButton` resolves per state: setting only the default state let the disabled state fall through to `_FilledButtonDefaultsM3.backgroundColor` (`onSurface α .12`), which painted a scrim over the neutral token and cut the label to 2.78:1. **A regression against the old `disabledBackgroundColor: Colors.grey[300]`; caught in independent review.** |
| D7 tile padding | `vertical: 10` | `vertical: 11` | The old selected tile carried a 2px border → 60.0px tall; the new 1.6px border made it 59.2, quietly violating "hit area must not shrink". Baselines are pinned at 60.0 (selected) / 57.0 (resting), derived from pre-change geometry (`36 content + 2×10 padding + 2×border`), not copied from the new build. |
| D10 compact branch | paddings only | also status-card padding (16) and action height (56) | A fixed 64px action plus fixed gaps is exactly what overflows at 320×568 with a 1.3 text scale. Outside that branch the action stays 64. |
| `_buildContent` | `Spacer()` kept | `Spacer()` removed | `Expanded(list)` and `Spacer` split the leftover 50/50, leaving the list viewport ~73px on a 600px window and overflowing the empty-state card by 159px. Removing it keeps the action bottom-anchored (the list fills above it) and makes the small-screen requirement reachable. |
| `HomeController.loadDevices` | none | `_loadInFlight` + `_reloadQueued` | Repeated taps of 刷新 fired parallel requests whose results raced. A request arriving while one is in flight is queued and re-run once — dropping it would lose the reload `scanAndAddDevice` relies on to show a newly added device. |
| D9 note dialog field | theme defaults | explicit token fill/border/hint | `inputDecorationTheme` fills pure white / `#1F1F1F`, which is the dialog's own surface role, so the field boundary disappears. Overridden locally; the shared theme stays untouched. |

Harness corrections of the same kind: `contrastOn` flattens a translucent *background* onto a backdrop before measuring (the in-progress icon chip is `white α .18` and read as pure white otherwise); page-level text is measured against the darker of the band stop and the page base; the "second channel" assertion measures the border step and shadow alpha instead of accepting any non-null border; `FilledButton.icon`'s runtime type is a private subclass, so solid-action assertions match `is FilledButton` rather than `byType(FilledButton)`; the bubble assertion pumps a frame before advancing 900ms because `_BubbleAnimation`'s periodic timer is created during that frame.

**TDD history gap, disclosed:** task 3.1 (type-scale levels) entered as a regression guard rather than an observed RED — the group-2 token pass had already applied the sizes. Tasks 1.1, 2.1, 2.4/2.5, 4.1, 4.4 (empty-state overflow), 5.1, 6.1 and the review-driven disabled-state test each recorded a real RED first.

## Verify round 2 (returned by `verify-fail`, same scope)

The independent integration review rejected the first round. Two of its findings were
verified as partly untrue and are recorded here so they are not re-litigated: both sheets *did*
already carry a grabber, and the 320×568 / 1.3 non-empty-list case *was* already covered.

**Correction to this record, found in round 3:** the same paragraph claimed the progress
indicator was already tested. It was not. What the suite covered was the page-level
`CircularProgressIndicator` for a pending request; Requirement 4's clause is about the
`LinearProgressIndicator` inside the status card while a session runs, and nothing asserted it.
The claim is fixed by task 9.4 rather than repeated.

What was actually wrong and how it changed:

| Item | Was | Now | Why |
| --- | --- | --- | --- |
| D3 dark surface stack | page `#0F1417` / band `#15293C` / card `#1A222B` / selected `#22303E` / tint `#2A3947` | `#0A0F14` / `#0D1A28` / `#1E2934` / `#283645` / `#31404F` | The band was *lighter* than the card and the status card sits on the band, so the pair the requirement names measured **1.082** against the 1.15 floor. Ordering is now page < band < card: card/band 1.189, card/page 1.303, selected/card 1.198, tint/selected 1.160, tint/card 1.390. |
| separation assertion | compared with `pageBaseColor()` — the gradient's last stop | compares with `backgroundBehind(key)`, the gradient sampled at the widget's own vertical centre | The page base is only painted at the very bottom of the screen. Measuring a card that sits in the band against the base asserted a surface the card never touches, which is how the 1.082 violation survived a green suite. |
| "second channel" assertion | `border != null \|\| boxShadow.isNotEmpty` | `channelsOf()` measures each channel: fill step ≥ 1.15 against the real backdrop, border *composited over that backdrop* ≥ 1.15, shadow with non-zero alpha **and** blur **and** offset | The old form is true for every card ever built. Measuring the border is what exposed the dark hairline: `α.24 #3A4A5A` over the new card composites to **1.113**, i.e. a line that is drawn but not visible, so it is now `α.35 #4C6076` (1.311 on the card, 1.341 on the page). |
| D3 selection marker | `accentStart` fill + white glyph in both modes | light unchanged; dark uses brand ink fill with page ink glyph | `accentStart` on the dark selected tile is **2.57** (floor 3.0) and a white glyph on it is unreadable. Dark inverts it: fill 5.57 against the tile, glyph 8.69 against the fill. |
| D8 note-edit chip | `color: p.card` | `color: p.tint` | A resting tile *is* `p.card`, so the chip was **1.000** against the surface it sits in — the edit affordance existed only as a 1px hairline. |
| D8 sheet grabber | `p.hairline` | `p.tint` | Found by the assertion written for this round: the hairline on the light sheet face is **1.133**, so the grabber the spec names was effectively invisible. Tint gives 1.214 (light) / 1.390 (dark). |
| reorder hint | bare `Text` on the page gradient | brand-gradient pill with a brand-ink border (`reorderHintKey`) | Requirement 5 says the hint sits "on a surface distinct from normal browsing". A `card`-filled pill was tried first and rejected — that *is* the resting tile, pixel for pixel. The accent pill is 4.4 from the page band, 4.6 from a resting tile, and its white label is 4.80 on its own lightest stop. |
| `HomeController.loadDevices` | expired-session `return` inside `try` | also clears `_reloadQueued` | The early return skips the tail that consumes the flag, so the *next* load fired one whole extra round of requests after a session had expired. |
| note dialog controller | `TextEditingController` built in the `showDialog` builder | `_NoteEditDialog` StatefulWidget disposes it | Nobody released it when the route closed. Save path, validation, autofocus, `maxLength: 20` and the pop-then-snackbar order are unchanged. |

## Verify round 3 (returned by the final integration review, same scope)

| Item | Was | Now | Why |
| --- | --- | --- | --- |
| Dialog action labels | no `foregroundColor`, so the theme's `primary #2196F3` painted them | page brand ink on all four (`取消` x3, `确定`) | **3.12:1** on the white dialog face, under Requirement 3's 4.5 body floor. This was the one place the redesign left a theme default in a home-owned dialog; brand ink gives 6.97 light / 6.67 dark. |
| D3 `hairlineLight` | `0x2E9FB4C9` | `0x4D7E96AE` | Composited against the surfaces it separates: **1.133** on the white card, **1.099** on the page base, **1.079** on the brand band — all below 1.15, so the "second channel" of every light card was really just a 7%-alpha shadow. The new value measures **1.344 / 1.297 / 1.242** in the same order. |
| Note field | one channel (fill 1.174 against the dialog face, border **1.099** against its own fill) | same fill, border lifted with the hairline to 1.293 | Requirement 2 applies to the field too; it was the same drawn-but-invisible defect class round 2 fixed on cards and the grabber. |
| `channelsOf` | fill from the lightest gradient stop; elevation = any shadow with α > 0 | fill from the stop **closest** to the backdrop; elevation needs α ≥ 0.12 *and* blur *and* offset *and* a ≥1.05 mark on the surface behind | Two unfalsifiable paths: taking the lightest stop judged a gradient surface at its best case, and a 6%-alpha shadow certified itself as an elevation channel. Both were load-bearing for the light cards, which is why the stricter harness went red before any token changed. Of the two numeric gates the **α ≥ 0.12** one is the operative bound: a black shadow at α 0.07 already leaves a 1.062 mark, so the 1.05 floor only screens out fully diffuse or zero-offset shadows. |
| `surfaceBehind` | nearest `MaterialType.card` ancestor, matched by a Finder | innermost opaque Material, walked with `visitAncestorElements` | Filtering by type made a solid button's label measure against the white dialog behind it (1.000) instead of against the surface it is painted on, so the predicate is now opacity. The walk replaces the Finder: `_AncestorWidgetFinder` yields innermost-first, so a "keep the last match" loop silently returned the **outermost** opaque Material — the opposite of what the first version of this fix claimed. A M3 `FilledButton` carries its fill on the `ButtonStyle`, not on any ancestor Material, so solid button labels are verified by `_expectSolidActionLegible`, which reads `style.backgroundColor.resolve`; that path is exercised by the note dialog's 保存. |
| Headline dominance assertion | compared the two labels' contrast ratios | compares font size and weight | Both lines clear 4.5, so a ratio comparison passed for a reason unrelated to dominance; dominance lives in size and weight only. |
| Small-screen reachability | `findsOneWidget` | rect centre inside the 320×568 viewport, plus a real tap on the layout toggle | "In the tree" is not "reachable"; a widget positioned off-screen satisfies `findsOneWidget`. |

Record corrections rather than behaviour changes:

- **D4 numbers are stale.** Measured against the round-2 dark stack they are 14.77 (white on dark card, recorded 16.06), 8.01 (secondary, recorded 8.50) and 6.67 (brand glyph on the dark card, recorded 7.25). Every one still clears its floor; the table above D3/D4 keeps the original figures as the round-1 record.
- **D7's derivation was wrong.** A `Container`'s `BoxDecoration.border` is painted inside its box and adds no layout height, so pre-change tiles were 36 + 2x10 = **56**, not the 60 recorded. The 60.0 / 57.0 floors the test asserts are measurements of the new build that happen to sit above that bar, so the guard is stricter than the requirement — not, as first written, derived from the old geometry.
- **Two of the round-3 tests are coverage guards, not observed REDs**: the in-card `LinearProgressIndicator` presence/absence and the idle gradient landing on the `Scaffold` colour both passed the moment they were written, because the behaviour was already correct and only the assertion was missing. They are recorded as guards, and the round-2 claim that the progress indicator was already tested is corrected above.

### Spec patch (round 3)

Requirement 3's scenario *Secondary text is not brighter than primary text* said the secondary line must use "the theme's de-emphasized foreground role". Kept literally, that means `colorScheme.onSurfaceVariant`, which in this app is `Colors.black54` — measured at **4.44:1** on the new page base, below the 4.5 floor the same requirement sets, and `AppTheme` is inside this change's declared "must not touch" boundary. The two clauses contradicted each other and the archive would have carried that into the main spec.

The scenario now constrains what it was always trying to constrain: one named de-emphasized foreground role per surface rather than an opacity sprinkled at each call site, and that role must clear the 4.5 floor. The wording change and the matching proposal line are part of this commit; no requirement, scenario set or numeric floor changed meaning.

## Out-of-scope defects found while verifying (not fixed here)

These were surfaced by the review passes. Each sits outside the boundary the user set (home page body plus its own sheets and dialogs, no global theme edits, no behaviour change), so they are recorded rather than silently passed over.

- `HomeController` prompts: the snackbar bodies are white labels on `Colors.orange` (**2.16:1**), `Colors.red` (**3.68:1**) and `Colors.green` (**2.78:1**) — `home_controller.dart:111`, `:321`, `:454-468`. They predate the redesign and are emitted by the controller rather than the page's own widget tree, but they are the last sub-floor text the home screen puts on screen. A follow-up should move them onto the page's `destructive` / `settle` roles.
- `ScannerPage` overflows horizontally by 12px at 320×568 with a 1.3 text scale (`scanner_page.dart:108`). Reproduced by the home suite when the add-device entry is actually tapped; the small-screen assertion therefore proves the home page's reachability and pops back at a normal size instead of carrying another page's overflow.
- The about dialog still shows a hardcoded `版本: 1.0.4` while `pubspec.yaml` is at 1.0.6.
- `main.dart` forces `statusBarIconBrightness: Brightness.dark`, which puts black status icons over the dark band on a dark-scheme device.

## Verify round 4 (coverage the closing check still owed)

The closing integration check returned "ready to archive" but listed one genuine gap: Requirement 2's elevated-sheet and dialog clauses carry no mode qualifier, yet the separation of a sheet or dialog face from the page was asserted in dark mode only. It was closed with a test that walks all four dialogs and both sheets in **both** modes.

- Elevated surfaces are painted by a `Material`, not a `BoxDecoration`, so `channelsOf` structurally cannot measure them. `expectElevatedSurface()` now measures the three things the scenario actually names: the fill step against the page gradient sampled *at that surface's own position*, a non-zero corner radius, and a non-transparent modal barrier over the page behind.
- Writing it found two of its own bugs before finding any product defect: the radius lives on `Material.shape` for a dialog and on `Material.borderRadius` for a hand-built sheet, so reading only the latter judged an existing 28px radius as 0; and a dialog cancelled from inside the device-management sheet leaves that sheet's barrier over the whole page, so the next app-bar tap is absorbed. Both are test-harness facts, recorded because they change what the assertions mean.
- Numbers are measured, not asserted as literals, so a future re-tune still has to clear the same floors.

### Accepted limits of this suite

Named here rather than left implicit, because each one is a place where "the tests are green" means less than it looks.

1. **Requirement 2's two-channel rule is enforced on the four named surface roles** (page, resting card, selected card, elevated sheet). The leading icon chip and the in-progress status chip are single-channel by fill (1.214 light / 1.390 dark against their row, 1.398 for the in-progress chip) — they are decorative insets inside a surface that already separates, not one of the four roles, so they are compliant. If a future change promotes them to surface roles they need a second channel.
2. **Requirement 3 is verified on enumerated pairs**, not by sweeping every `Text` in the tree. A sweep would have to exempt the controller's out-of-boundary snackbars and any text drawn on the accent gradient, and a blanket gate that silently skips cases is worse than an explicit list. Each new text pair therefore needs its assertion added; the enumeration is the contract.
3. **"Keeps animating" is proven as presence and absence**, not as motion: the in-card `LinearProgressIndicator` is asserted present while a session runs and absent when idle, which catches removal but not a frozen value.
