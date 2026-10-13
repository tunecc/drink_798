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
