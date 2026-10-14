---
comet_change: refactor-home-page-ui
role: technical-design
canonical_spec: openspec
---

# Design

## Context

`lib/features/home/home_page.dart` is 1155 lines holding the page, both bottom sheets, four dialogs and the bubble animation. Four facts shape the approach:

- The idle background is a bug-shaped gradient: `colors` is `[scaffoldBackgroundColor, scaffoldBackgroundColor]` when `isDrinking` is false, so the `AnimatedContainer` paints one flat `#F5F9FF`, and white `cardColor` on it is a surface ratio of **1.057** — measurable, but far below anything a user reads as layering.
- The accent colors already in use fail WCAG against their own text: white on the `#00D4FF → #0099CC` water gradient is **1.77–3.27:1** (worst at the light end), and white on `Colors.orange` (the 结算 state) is **2.16:1**. The page is not just flat, it is low-legibility exactly where it is loudest.
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
- Keep the page's flows, all persisted `SharedPreferences` keys and the set of server calls unchanged. `HomeController`'s *interface* only grew an optional injected service (the test seam). Two loading-side fixes did land in it during Verify, both disclosed in the Build amendments table below: in-flight `loadDevices()` calls are coalesced instead of raced, and the expired-session return clears `_reloadQueued` so the next load does not fire a redundant round. No request was added, removed or reordered for a reason other than suppressing a duplicate that the old code issued by accident.

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
| Page base | `#E4EEF8` | `#0A0F14` | vs card **1.174** light / **1.303** dark |
| Band top | `#C5E0F7` | `#0D1A28` | one step of the background gradient, not a surface pair: **1.163** above the page base in light, **1.095** in dark. What the requirement governs is the card on the band — **1.365** light / **1.189** dark |
| Resting card / sheet | `#FFFFFF` | `#1E2934` | grabber tint one step above its own face (**1.214** light / **1.390** dark), plus shadow and barrier |
| Selected card | `#FFFFFF` + 1.6px border in the brand ink `#0F5C99` + `#DCEBF9` icon chip + solid check chip | `#283645` + 1.6px border in `#64B5F6` | light deliberately keeps the card fill (still **1.174** against the page) and expresses selection through border, marker and elevation; dark steps the fill **1.198** above the resting card. A selection border is a non-text indicator, so it holds the 3.0 floor on its own: **5.94** in light against the page base, **5.57** in dark against the selected fill |
| Accent (in-progress card, enabled primary action) | `#0277BD → #00619E` | same | white label **4.80** at the lightest stop |
| Settle action | `#B45309` — the same constant as `HomePromptColors.warning` | same | white label **5.02** |
| Destructive label | `#C62828` — the same constant as `HomePromptColors.error` | `#FF8A80` | **5.62** on the white card, **6.47** on the dark card |
| Disabled action | `#C6D3DE` + `#4A5765` label | `#232B33` + `#9AA7B4` label | inactive; exempt under WCAG 1.4.3, and the label still clears **4.85** light / **5.84** dark against its own fill |

These are the tokens that ship at HEAD. Round 6 corrected the D4 text table in place but left this one on the round-1 stack, and the whole-change review caught it: the dark page / card / selected values here were the pre-retune `#0F1417` / `#1A222B` / `#22303E`, the light selection border was recorded as the theme's `#2196F3` — which the code's own comment rejects at 2.66 against the page base — and the disabled inks were `#5A6B7B` / `#7C8894` instead of the shipped `#4A5765` / `#9AA7B4`. The two adjacency figures that only ever reproduced on that superseded stack (**1.154**, **1.193**) are gone from the table rather than annotated.

Two corrections this table forced on the Open-stage draft:

1. **Selected tiles do not change fill in light mode.** A tinted selection (`#F5FAFF`) measures only **1.118** against the new page base, i.e. selecting a device would visually glue the tile back into the background — the opposite of the intent. Selection is carried by border + icon-chip tint + solid check chip + elevation; dark mode keeps the fill tint because there it *strengthens* the step (1.198 above the resting card). The spec's selected-state scenario was patched to "at least two of fill, border, elevation, marker" (Spec Patch P2) to match the math.
2. **The page base must not be lighter.** `#F5F9FF` yields 1.057 against white cards; no amount of shadow tuning makes that read as layering. `#E4EEF8` is the minimum change that clears 1.15.

### D4 — Text tokens, and why not `onSurfaceVariant`

| Token | Light | Dark | Measured |
| --- | --- | --- | --- |
| Primary | `Colors.black87` | `Colors.white` | 13.93 on page, 15.91 on card / 14.77 on dark card |
| Secondary (card) | `Colors.black.withValues(alpha: 0.60)` | `Colors.white.withValues(alpha: 0.70)` | 5.74 on card / 7.996 on dark card |
| Secondary (page base) | same α .60 | same α .70 | 5.48 on page / 9.59 on dark page |
| Brand glyph on tint chip | `#1565A8` → `#0F5C99` (D4 amendment) | `#64B5F6` | 5.00 on `#DCEBF9` as first set; the shipped token gives 5.74 on the light tint and 5.11 on the band, and `#64B5F6` gives 4.80 on the dark tint / 6.67 on the dark card |
| Neutral glyph on page base | `#5A6B7B` | `#9AA7B4` | 4.68 on the light page, 7.84 on the dark page (non-text floor 3.0) |

`Theme.colorScheme.onSurfaceVariant` is `Colors.black54` from the login change. Composited over the new page base it measures **4.44:1**, below the 4.5 floor the spec sets for caption text, so the home page carries its own secondary token at α .60 and uses it on every surface. Non-text elements (icons, borders) are held to 3.0:1, which is why the existing `AppTheme.primaryColor` glyph on the tint chip (**2.57**) is replaced by `_brandOnTint`.

De-emphasis below the floor is expressed through size and weight, never through alpha: the in-progress caption at `white.withValues(alpha: 0.85)` measures **3.92:1** on the accent gradient, so it becomes full white at 13/w400 under a 22/w700 headline.

### D5 — One background per state, never a two-stop no-op

`_HomeBackground` holds two named three-stop gradients — idle (brand tint → band → page base) and in-progress (accent water → page base) — both ending exactly on the page base color, applied to a `Positioned.fill` `AnimatedContainer` that keeps the current 800ms cross-fade. Because each gradient's terminal stop is a literal token rather than `Theme.of(context).scaffoldBackgroundColor`, no state can collapse into a flat field again, and the bubbles overlay stays unchanged above it.

### D6 — Primary action: gradient painted behind a real `FilledButton`

The control stays a `FilledButton` so `onPressed: null` continues to produce the correct disabled semantics, ripple, focus traversal and label/icon layout. Its gradient comes from a wrapping `DecoratedBox` while the button itself sets `backgroundColor: Colors.transparent`, `elevation: 0` and `shadowColor: Colors.transparent`; Flutter paints the `DecoratedBox` before its child, so the ink overlay lands on top of the gradient.

The mandatory detail: the button's `shape` radius must equal the wrapper's, otherwise the ripple is clipped to `AppTheme`'s 16 and the pressed state visibly cuts the corner. Both read one shared `BorderRadius` variable, 26 normally and 22 on the compact branch (the draft said 24; the Build amendments table records the correction). Height 64. When disabled the wrapper paints the flat neutral fill and the label moves to the neutral label token.

*Alternatives considered:* an `InkWell` over a gradient container — rejected, it loses `Semantics(enabled: false)` and needs manual focus; a solid `FilledButton` with only a glow shadow — rejected, the gradient is the visible part of the request; `ShaderMask` over the button — rejected, it also masks the ink and any child icon tint.

### D7 — Device tiles keep their structure, states change only paint

`_buildCompactDeviceItem` and `_buildGridDeviceItem` keep `GestureDetector` + `Container` and every existing child, including the note-edit chip measured today at **26×26** (`EdgeInsets.all(6)` + `Icon(size: 14)`), the row height and the toolbar icon buttons. Those numbers become explicit minimums asserted by test, so "no hit area shrinks" is checked rather than promised. Reorder mode keeps `ReorderableListView` and the drag handle and only gains a distinct surface for the hint row.

*Alternatives considered:* `ListTile`/`Card` — rejected, the border-and-fill control is the point; wrapping tiles in `InkWell` for ripple — deferred, it changes tap feel the user did not ask to change.

### D8 — Type scale as constants

Six named levels: screen title 20/w700, status headline 22/w700, status caption 13/w400 (secondary token), section title 17/w700, item title 15/w600, secondary action 13/w500. Shipped as inline `TextStyle`s on the page's own text (the design's first draft said "through `textTheme` copies where possible" — no `textTheme` lookup exists in the file; the family still comes from the inherited `DefaultTextStyle`, so `GoogleFonts.notoSansSc` keeps winning and only the mechanism claim was wrong). The five sizes are asserted item by item, which is what keeps a palette-only edit from silently flattening the scale.

### D9 — Sheets and dialogs read the same tokens

Both bottom sheets keep `showCupertinoModalBottomSheet` (already gives the drag-to-dismiss feel) and change paint only: the two `Material(color: Theme.of(context).scaffoldBackgroundColor)` sites become the sheet role (`#FFFFFF` / `#1E2934`, the dark value set by the round-2 re-tune and recorded in "Verify round 2"), plus grabber, title and row tokens. `AlertDialog` resolves its background from `colorScheme.surface`, which is `#F5F9FF` today and would now read as a third gray, so each dialog passes `backgroundColor` = sheet role locally.

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
- [1155 lines of churn can silently drop an interaction] → the "existing interactions remain reachable" requirement is checked item by item in tasks, and the empty-list, reorder and in-progress branches each get their own case.
- [A transparent `FilledButton` over a gradient can lose its pressed overlay] → explicit overlay color plus matched radius; if the overlay still does not read on a given palette, fall back to a solid two-token brand fill on the wrapper rather than replacing the button widget.
- [Both brightness modes double the assertion surface] → one parameterized pump, run twice per scenario group.

## Migration Plan

No data or API migration: `device_list_layout`, `device_order`, `device_note_<id>` and the token keys are untouched, so upgrade and downgrade are pure visual swaps. Rollback is reverting the implementation commits; no persisted state needs cleaning. Ship as one commit set — the page reads as broken half-migrated.

## Spec Patches applied

- **P1** — "measurable fill step" quantified: adjacent surface roles differ by ≥1.15:1 and are additionally separated by border or shadow.
- **P2** — selected tile scenario relaxed to "at least two of fill, border, elevation and marker"; the scenario states the rule only, and the measured reason (a tinted light-mode selection would drop below the P1 floor against the page base) lives in D3 below rather than in the spec.
- **P3** — text over an accent fill or gradient must reach 4.5:1 at the *lightest* point of that gradient, and de-emphasis must come from size or weight rather than from alpha below the floor.
- **P4** — new requirement: the page renders without overflow and with all controls reachable at 320×568 with a 1.3 text scale.
- **P5** — round 3: *Secondary text is not brighter than primary text* stopped naming a global theme token and started naming the property (one de-emphasized role per surface, clearing the 4.5 floor). Recorded in "Spec patch (round 3)".
- **P6** — round 5: Requirement 3 gained the prompt clause ("any prompt the page raises over itself MUST sit on its own opaque surface and clear the same 4.5:1 floor") and the scenario *Prompts the page raises stay legible*, later extended in round 5 to name the plain blocking notice and to require the neutral face carry none of the semantic hues. Recorded in "Build round 5".

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
| D7 tile padding | `vertical: 10` | `vertical: 11` | The row grew a 1.6px border. Baselines are pinned at 60.0 (selected) / 57.0 (resting) so no hit area can shrink. Those two numbers are measurements of the new build, not a derivation from the old geometry — see the D7 correction under "Verify round 3": a `Container` border adds no layout height, so the pre-change rows were 36 + 2×10 = **56**, and the guard is stricter than the requirement rather than derived from it. |
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
| "second channel" assertion | `border != null \|\| boxShadow.isNotEmpty` | `channelsOf()` measures each channel: fill step ≥ 1.15 against the real backdrop, border *composited over that backdrop* ≥ 1.15, shadow with non-zero alpha **and** blur **and** offset | The old form is true for every card ever built. Measuring the border is what exposed the dark hairline: `α.24 #3A4A5A` over the new card composites to **1.115** (channels 37, 49, 61), i.e. a line that is drawn but not visible, so it is now `α.35 #4C6076` (1.311 on the card, 1.341 on the page). The value this row first recorded was 1.113, which only reproduces when the 8-bit rounding the harness applies is skipped — the same error class round 6 retired on the light hairline, caught by the round-7 review. |
| D3 selection marker | `accentStart` fill + white glyph in both modes | light unchanged; dark uses brand ink fill with page ink glyph | `accentStart` on the dark selected tile is **2.57** (floor 3.0) and a white glyph on it is unreadable. Dark inverts it: fill 5.57 against the tile, glyph 8.69 against the fill. |
| D8 note-edit chip | `color: p.card` | `color: p.tint` | A resting tile *is* `p.card`, so the chip was **1.000** against the surface it sits in — the edit affordance existed only as a 1px hairline. |
| D8 sheet grabber | `p.hairline` | `p.tint` | Found by the assertion written for this round: the hairline on the light sheet face is **1.133**, so the grabber the spec names was effectively invisible. Tint gives 1.214 (light) / 1.390 (dark). |
| reorder hint | bare `Text` on the page gradient | brand-gradient pill with a brand-ink border (`reorderHintKey`) | Requirement 5 says the hint sits "on a surface distinct from normal browsing". A `card`-filled pill was tried first and rejected — that *is* the resting tile, pixel for pixel. The accent pill is 3.51 from the page band, 4.09 from the page base and 4.80 from a resting tile, and its white label is 4.80 on its own lightest stop. |
| `HomeController.loadDevices` | expired-session `return` inside `try` | also clears `_reloadQueued` | The early return skips the tail that consumes the flag, so the *next* load fired one whole extra round of requests after a session had expired. |
| note dialog controller | `TextEditingController` built in the `showDialog` builder | `_NoteEditDialog` StatefulWidget disposes it | Nobody released it when the route closed. Save path, validation, autofocus, `maxLength: 20` and the pop-then-snackbar order are unchanged. |

## Verify round 3 (returned by the final integration review, same scope)

| Item | Was | Now | Why |
| --- | --- | --- | --- |
| Dialog action labels | no `foregroundColor`, so the theme's `primary #2196F3` painted them | page brand ink on all four (`取消` x3, `确定`) | **3.12:1** on the white dialog face, under Requirement 3's 4.5 body floor. This was the one place the redesign left a theme default in a home-owned dialog; brand ink gives 6.97 light / 6.67 dark. |
| D3 `hairlineLight` | `0x2E9FB4C9` | `0x4D7E96AE` | Composited against the surfaces it separates: **1.133** on the white card, **1.099** on the page base, **1.079** on the brand band — all below 1.15, so the "second channel" of every light card was really just a 7%-alpha shadow. The new value measures **1.344 / 1.297 / 1.242** in the same order. |
| Note field | one channel (fill 1.174 against the dialog face, border **1.099** against its own fill) | same fill, border lifted with the hairline to 1.297 | Requirement 2 applies to the field too; it was the same drawn-but-invisible defect class round 2 fixed on cards and the grabber. |
| `channelsOf` | fill from the lightest gradient stop; elevation = any shadow with α > 0 | fill from the stop **closest** to the backdrop; elevation needs α ≥ 0.12 *and* blur *and* offset *and* a ≥1.05 mark on the surface behind | Two unfalsifiable paths: taking the lightest stop judged a gradient surface at its best case, and a 6%-alpha shadow certified itself as an elevation channel. Both were load-bearing for the light cards, which is why the stricter harness went red before any token changed. Of the two numeric gates the **α ≥ 0.12** one is the operative bound: a black shadow at α 0.07 already leaves a 1.171 mark against white, so the 1.05 floor only screens out fully diffuse or zero-offset shadows. |
| `surfaceBehind` | nearest `MaterialType.card` ancestor, matched by a Finder | innermost opaque Material, walked with `visitAncestorElements` | Filtering by type made a solid button's label measure against the white dialog behind it (1.000) instead of against the surface it is painted on, so the predicate is now opacity. The walk replaces the Finder: `_AncestorWidgetFinder` yields innermost-first, so a "keep the last match" loop silently returned the **outermost** opaque Material — the opposite of what the first version of this fix claimed. A M3 `FilledButton` carries its fill on the `ButtonStyle`, not on any ancestor Material, so solid button labels are verified by `_expectSolidActionLegible`, which reads `style.backgroundColor.resolve`; that path is exercised by the note dialog's 保存. |
| Headline dominance assertion | compared the two labels' contrast ratios | compares font size and weight | Both lines clear 4.5, so a ratio comparison passed for a reason unrelated to dominance; dominance lives in size and weight only. |
| Small-screen reachability | `findsOneWidget` | rect centre inside the 320×568 viewport, plus a real tap on the layout toggle | "In the tree" is not "reachable"; a widget positioned off-screen satisfies `findsOneWidget`. |

Record corrections rather than behaviour changes:

- **D4 numbers were stale.** Measured against the round-2 dark stack with the harness's own rounding they are 14.77 (white on dark card, recorded 16.06), 7.996 (secondary on the dark card, recorded 8.50) and 6.67 (brand glyph on the dark card, recorded 7.25), and the light side is 13.93 (recorded 13.71), 5.483 and 9.59 (recorded 5.48 and 9.33). Round 6 corrected the D4 table itself rather than leaving the wrong figures as a "round-1 record", because every one of them is a claim a reader can re-derive and would not.
- **D7's derivation was wrong.** A `Container`'s `BoxDecoration.border` is painted inside its box and adds no layout height, so pre-change tiles were 36 + 2x10 = **56**, not the 60 recorded. The 60.0 / 57.0 floors the test asserts are measurements of the new build that happen to sit above that bar, so the guard is stricter than the requirement — not, as first written, derived from the old geometry.
- **Two of the round-3 tests are coverage guards, not observed REDs**: the in-card `LinearProgressIndicator` presence/absence and the idle gradient landing on the `Scaffold` colour both passed the moment they were written, because the behaviour was already correct and only the assertion was missing. They are recorded as guards, and the round-2 claim that the progress indicator was already tested is corrected above.

### Spec patch (round 3)

Requirement 3's scenario *Secondary text is not brighter than primary text* said the secondary line must use "the theme's de-emphasized foreground role". Kept literally, that means `colorScheme.onSurfaceVariant`, which in this app is `Colors.black54` — measured at **4.44:1** on the new page base, below the 4.5 floor the same requirement sets, and `AppTheme` is inside this change's declared "must not touch" boundary. The two clauses contradicted each other and the archive would have carried that into the main spec.

The scenario now constrains what it was always trying to constrain: one named de-emphasized foreground role per surface rather than an opacity sprinkled at each call site, and that role must clear the 4.5 floor. The wording change and the matching proposal line are part of this commit; no requirement, scenario set or numeric floor changed meaning.

## Out-of-scope defects found while verifying (not fixed here)

These were surfaced by the review passes. Each sits outside the boundary the user set (home page body plus its own sheets and dialogs, no global theme edits, no behaviour change), so they are recorded rather than silently passed over.

- ~~`HomeController` prompts~~ — recorded here in round 3, then **brought into scope by the user** ("修复 snackbar 的对比度问题") and fixed in [Build round 5](#build-round-5--the-prompts-the-page-raises-over-itself-authorised-scope-extension).
- `LoginController` prompts carry the same pattern this round fixed on home: nine sites pass
  `backgroundColor: Colors.red` / `Colors.green` with `colorText: Colors.white`, i.e. the measured
  3.68:1 and 2.78:1 pair (`login_controller.dart:66`, `:97`, `:106`, `:116`, `:147`, `:159`, `:169`,
  `:192`, `:201`). Found while grepping for other prompt sites, not fixed here: the login page is
  inside the boundary the user drew as untouchable, and its own change (`refactor-login-page-ui`) is
  already archived. Recorded so the next pass at login can pick it up rather than rediscover it.
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

1. **Requirement 2's two-channel rule is enforced on the four named surface roles** (page, resting card, selected card, elevated sheet). The leading icon chip and the in-progress status chip are single-channel by fill — 1.214 light / 1.390 dark against the resting card, and 1.348 against the lightest stop of the in-progress gradient (1.457 at the darkest). Those three pairs are computed from the tokens, not asserted: the suite gates the *glyph on the chip* against its composited face, never the chip against what it sits in. Both chips are decorative insets inside a surface that already separates, not one of the four roles, so they are compliant. If a future change promotes them to surface roles they need a second channel and a test.
2. **Requirement 3 is verified on enumerated pairs**, not by sweeping every `Text` in the tree. A sweep would have to exempt any text drawn on the accent gradient and every prompt face, and a blanket gate that silently skips cases is worse than an explicit list. Each new text pair therefore needs its assertion added; the enumeration is the contract. The prompt faces joined that enumeration in round 5 (below) rather than staying exempt.
3. **"Keeps animating" is proven as presence and absence**, not as motion: the in-card `LinearProgressIndicator` is asserted present while a session runs and absent when idle, which catches removal but not a frozen value.

## Build round 5 — the prompts the page raises over itself (authorised scope extension)

The user named the remaining item ("修复 snackbar 的对比度问题"), which moves it from the out-of-scope
list into this change. The boundary still holds: nothing in `core/theme/` changes, so the login and
scanner pages look exactly as before. What changes is that home now owns the faces of the prompts it
puts on screen.

**Decision: one holder, four faces.** `lib/features/home/home_prompt_colors.dart` declares
`warning #B45309`, `error #C62828`, `success #2E7D32` and `notice #303030`, all read with
`Colors.white` at **5.022 / 5.622 / 5.127 / 13.198**. It lives in `features/home/` and not in
`core/theme/` because these roles are home's own: the page already had an amber settle face and a
red destructive face, and a prompt meaning the same thing must be the same colour. `_HomeT.settle`
and `_HomeT.destructiveLight` now *point at* `HomePromptColors.warning` / `.error` instead of
re-declaring the hexes, so the button and the prompt of the same meaning cannot drift apart.

**Eleven call sites.** Seven prompts already carried an explicit face — two `Colors.orange`
(session expired, in `loadDevices` and in `_fail`), four `Colors.red` (`_fail`, add-device ×2,
`_err`) and one `Colors.green` (`_ok`) — and now read the holder. Four more carried no face at all:
`toggleReorderMode`, `selectDevice` and `startDrinking`'s no-selection guard in the controller, plus
the note-save prompt the page's own dialog raises (`home_page.dart`, title `成功`). Text, title,
`SnackPosition.BOTTOM` and duration are untouched at every one of the eleven; only colour changed.

**Why the four unstyled prompts had to be pinned, stated accurately.** They inherit `Get.snackbar`'s
fallback face, `Colors.grey.withOpacity(0.2)` — not the opaque `#303030` the `GetSnackBar`
constructor default suggests, because the extension resolves a null background to that 20 %-alpha
wash before building the snack. Their label was never white either: `Get.snackbar` builds it from
`colorText ?? iconColor ?? Colors.black`, and `iconColor` is `theme.iconTheme.color`, which this app
sets only inside `AppBarTheme`. So neither end of the pairing was ours — the face was translucent and
the ink came from whichever theme role happened to resolve. A *white* label on that wash would
composite to 1.359:1 over the light page base and about 14.1:1 over the dark one; the pre-fix label
was whatever the theme handed back, which is precisely the thing Requirement 3's new clause says the
page must not leave to chance. All four now declare a face and an ink from the holder: the three
blocking notices take `notice #303030` (13.20:1 with `label`), the note-save prompt takes
`success #2E7D32`, the same face the controller's `_ok` uses, so "saved" cannot look like one thing
in the page and another in the controller. `notice` is deliberately achromatic — a blocking notice is
not a failure, and amber would collide with the session-expired warning — so it sits outside the hue
rule, which applies to the three semantic kinds. Because a distance in *hue* is meaningless without
chroma (three greys all report hue 0 and would pass a distance check by accident), the suite floors
each semantic face at chroma ≥ 0.3 and requires the neutral face to stay below 0.15.

**TDD record.** RED, observed: `fvm flutter test --no-pub test/features/home/home_page_ui_test.dart`
→ 45 passed, 2 failed, and the failures are exactly the behaviour 11.1 asks for —
`the three prompt kinds are legible and keep distinct hues` reported **2.1553** on the warning face
and `prompts stay legible over the dark page too` reported **3.6824** on the error face. Because the
kinds loop aborts at its first failure, the success face's **2.780** (`Colors.green`) is a figure
computed from the same formula before the run, not a second observed RED; it is covered by the
assertion that now passes. Two further REDs were observed later, each on its own run: the neutral
face failed on the opacity clause with `Actual: <0.2>`, and after the independent review named the
note-save prompt the new test failed the same clause with `Actual: <0.2>` in `Brightness.light`
before `home_page.dart` was changed. GREEN: the full suite **122 passed**,
`fvm flutter analyze --no-pub` reports **No issues found** (it also dropped `home_controller.dart`'s
now-unused `package:flutter/material.dart` import).

**What the review changed after it reported.** The first pass over the prompts measured one scheme
only, so the kinds test and the neutral-face test now walk `Brightness.light` and
`Brightness.dark`, which is what "in both colour schemes" in Requirement 3 says; the
`testWidgets('prompts stay legible over the dark page too')` case folded into that loop rather than
surviving as a fourth copy.

### Accepted limits added in round 5

1. **Warning-to-error hue distance is 25.96° against a 20° floor, so the slack is 5.96°**
   (`#B45309` reports hue 25.96°, `#C62828` reports 0°). It passes, but barely: re-tuning either the
   amber or the red by a few degrees toward each other would fail the assertion, and that is a
   deliberate tripwire rather than a comfortable margin. Earlier copies of this record called the
   distance "25.9° of slack", which conflated the two; the test prints the distance rounded to 26°.
2. **The neutral face separates weakly in dark mode.** `#303030` over `pageDark` is a 1.458 fill step
   but only 1.119 over `cardDark`, and a prompt carries no border or shadow. Requirement 3's prompt
   clause asks for an opaque face and a 4.5:1 label, not for a surface step, so this is compliant —
   it is worth knowing before anyone promotes a prompt to one of Requirement 2's surface roles.
3. **Six of the eleven sites are covered by face, not by flow.** `_err`, `_fail`'s two branches,
   add-device ×2 and the reorder guard all resolve to a constant this suite measures on another site
   with the same title and position; only the measured sites' own routes are exercised. A prompt
   added later that reuses one of the four constants inherits the guarantee; one that introduces a
   new colour needs a new assertion.

**Limits of the prompt assertions.** They read `GetSnackBar.backgroundColor` and the rendered label
`TextStyle`, not composited pixels. For these four faces that is exact — every face is opaque and
the app sets no `backgroundGradient` or `boxShadows` on a prompt — but a future prompt that uses a
gradient or a translucent face would need the pixel-sampling treatment the page surfaces get.

## Verify round 6 (final integration review: records and assertions)

The integration review over the whole change (`88167ac..137dc3a`) reported no CRITICAL and four
IMPORTANT items, all of them about what the records *claim* rather than what the page does: the
boundary held, behaviour stayed neutral, and every floor it recomputed passed. It also re-derived the
prompt maths and the GetX fallback face independently, and confirmed all eleven sites.

| Item | Was | Now | Kind |
| --- | --- | --- | --- |
| Requirement 3's "one named de-emphasized role per surface, not an opacity at each call site" | no assertion at all | the six de-emphasized labels that share the card face — status caption, sheet row subtitle, empty-state hint, note-field hint and counter, and the about dialog's second line — must resolve to one identical value in both schemes; the caption is checked against the card and the hint against the note field's own fill, which is the face it actually paints on | coverage guard: passed on first write, because the code already routes every one of them through `p.inkSecondary`. Honest scope: this proves *one value* across the enumerated labels, not that the value was reached through a named identifier (a literal `0x99000000` compares equal), and it only covers the labels it enumerates — which is why the about dialog's line had to be added when the review pointed out it was a live sixth site. |
| Requirement 6's sheet clauses ("rows with name and note or id", "关于 and 退出登录, each with its icon") | a title, a trash count and a surface colour | a note seeded through the preferences mock proves both subtitle branches (`茶水间 · ID: 101` and `ID: 102`), and each settings row must carry its own leading icon inside its `ListTile` | coverage guard, same disclosure. The first draft failed for a reason worth recording: it expected `1栋101`, but `DeviceModel.formattedName` rewrites 栋 to `-`, so the sheet renders `1-101`. The test was wrong, not the page. |
| Dark-side floors | the secondary ink and the tint-chip glyph were measured in light only, while the goals line promises both modes | both now measured in dark too: secondary 8.00 on the dark card, glyph 4.80 on the dark tint | coverage guard; it passed immediately, so the claim is that the suite now proves what the record said, not that a defect was found. |
| "controller business logic / every server call unchanged" | asserted in the goals line and in the proposal's Impact line | rewritten to say what actually happened: the interface gained only the injected service, and rounds 2–3 added the in-flight coalescing plus the expired-session flag clear, both already disclosed in the Build amendments table | wording fix. The code is correct and tested; the summary was the false part. |
| Numbers inside permanent artefacts | `Colors.red` on white annotated 3.72 (a code comment, a test reason string); the theme primary on a white dialog face written as 3.13 in five places (two code comments, three test strings); the replaced light hairline annotated α.24 with steps 1.130 / 1.104; the grabber annotated 1.24 in two places; a stale settle-fill guard aiming at `#FFA000` | 3.68, 3.12, α.18 with 1.133 / 1.099 / 1.079, 1.214, and `#FF9800` — the colour the pre-change page really used | corrections. The hairline's 1.130 / 1.104 came from compositing without the 8-bit rounding the harness applies; the 1.133 / 1.099 pair in the round-3 table was the reproducible one all along. |
| D4's measurement table | kept round-1 figures "as the round-1 record" (13.71, 16.06, 8.50, 9.33, 7.25) while a later bullet admitted they were stale | corrected in place: 13.93 / 15.91 / 14.77, 5.74 / 7.996, 5.48 / 9.59, brand ink 5.74 light and 4.80 on the dark tint, neutral glyph 4.68 / 7.84; the pre-change water gradient reads 1.77–3.27, the reorder pill's steps 3.51 / 4.09 / 4.80, the note field's border 1.297 | corrections. Every one of these is a claim a reader can re-derive and could not, which is worse in an archived document than in a working note. The first round-6 pass then wrote 14.06 / 16.10 for the primary ink by taking `Colors.black87` as α .87; the follow-up review caught it — `black87` is `Color(0xDD000000)`, i.e. α .8667, and the harness gives 13.93 / 15.91. That slip is recorded here rather than quietly re-edited, because it is the same class of error this round exists to eliminate. |
| Dialog count | "five dialogs" in the proposal, task 6.3 and the design's opening description, counting a reorder-exit dialog that has never existed | four, in all three places; the round-5 spec patch also registered as **P6** in the Spec Patches ledger | corrections |

### What round 6 did not change

Round 5's accepted limits stand unchanged (5.96° of hue slack over the 20° floor, the neutral face's
1.119 step over the dark card, six of eleven sites covered by sharing a measured constant rather than
by their own route),
and Requirement 3 is still verified on enumerated pairs: the new single-role test enumerates the
de-emphasized labels rather than sweeping every `Text`, because a sweep would have to exempt the
accent-gradient labels and would fail for reasons unrelated to legibility.

## Build round 7 (final integration review over `88167ac..590d08b`)

The review found no behaviour, boundary or contrast defect — the page, the prompt faces and the
eleven call sites all re-derived clean, and the untouched-boundary check on `lib/core/theme/`,
`lib/features/login/` and `lib/features/scanner/` was still empty. What it did find was six records
and assertion items, every one of them the same class round 6 was meant to retire: a number written
down once and never re-measured after the palette moved.

| Item | Was | Now | Kind |
| --- | --- | --- | --- |
| D3 surface-role table | the round-1 dark stack (`#0F1417` page / `#1A222B` card / `#22303E` selected), a `#2196F3` 1.6px light selected border, and adjacency figures 1.154 / 1.193 | the shipped tokens: dark page `#0A0F14`, card `#1E2934`, selected `#283645` with the `#64B5F6` border, light selected border `#0F5C99`; card→page 1.303 dark, card→selected 1.198, and the band-vs-page pair labelled as a gradient step (1.163 light / 1.095 dark) rather than a surface-role adjacency | correction. Round 6 applied exactly this rule to D4 and left D3 alone, which is the inconsistency the review named: the two tables described the same palette at two different depths of history. |
| Sheet role named in D9 | `#1A222B`, the pre-retune dark card | `#1E2934`, with a pointer to the round-2 record | correction — same class as D3: a decision section kept naming a token the palette had already moved past |
| Sheet separation from the old global background | "只差 1.06" in the sheet comment, the same number in a test reason string, and 1.06 in this plan | 1.111 (`#F5F9FF` against `#E4EEF8`) in all three | correction |
| Reorder pill comment | "离本体色 4.4、离白条目 4.6" | the measured 3.51 against the band top, 4.09 against the page base, 4.80 against a white item | correction — the old pair was never computed; it was prose written to justify a decision the 4.5 floor already justified |
| Shadow mark on a white card | "a black shadow at α 0.07 leaves a 1.062 mark" | 1.171, which is why the suite gates on α ≥ 0.12 rather than on the mark | correction |
| Requirement 4's *Device selected* scenario | names the play icon; nothing asserted it | the enabled-action test now requires `Ionicons.play_circle`, and the settle test requires `stop_circle` with play absent | coverage guard, passed on first write |
| `sizes.length >= 4` | a five-value set check that cannot fail, because the five sizes (22 / 20 / 17 / 15 / 13) are pinned item by item three lines above it | deleted; the item-by-item pins stay | assertion that proved nothing |
| Context line "1156 lines" and the matching risk line | 1156 | 1155, the count at `88167ac` | correction |
| P2 ledger entry | claimed the selected-tile scenario "keeps the measured reason" | the scenario carries the rule (at least two of fill, border, elevation, marker); the measured reason lives in D3 | wording fix — the scenario has no number in it |

### Recorded rather than fixed

Four points where changing the code costs more than the risk it removes, so they are stated with
their failure mode instead of patched:

- **The two decorative chips' fill steps are computed, not asserted.** The leading icon chip is 1.214
  light / 1.390 dark against the resting card; the in-progress chip is 1.348 against the lightest stop
  of the accent gradient and 1.457 at the darkest (round 7 replaced the 1.398 this record had carried,
  which reproduces on neither stop). No test measures either pair: the suite gates the *glyph on the
  chip*, so a palette tweak that merged a chip into its surface would stay green. Both chips are
  decorative insets inside a surface that already separates, which is why they sit outside
  Requirement 2's two-channel rule — the acceptance is that the rule covers the four named roles only.
- **The about dialog's `版本:` anchor.** Two tests locate that dialog by its version line, and the
  literal `版本: 1.0.4` in `home_page.dart` is a recorded out-of-scope defect (`pubspec.yaml` says
  1.0.6+6). `expectElevatedSurface` and the dismissal check now match on `版本:` with
  `textContaining`, so the assertions survive the day the version string is fixed and do not become a
  false failure caused by a defect this change already declared out of bounds.
- **`dialogMaterial.last`** in the about-dialog surface check takes the last `Material` inside the
  `Dialog` subtree. If a future dialog nests a second opaque Material with its own distinct colour
  (an ink-well, a button face), `.last` reads *that* face and the 1.15 gate can pass while the dialog
  surface itself regresses; if the nested Material has no colour, the `?? base` fallback makes the
  same check fail for a reason unrelated to the surface being measured. Accepted because today's four
  dialogs each have exactly one Material with a non-null colour, and the failure mode is a loud false
  alarm in the likelier branch.

## Build rounds 8 and 9 (the round-7 review's fix-list, then its own re-check)

Round 7's review of `88167ac..3ddb1f0` reported 0 CRITICAL / 2 IMPORTANT / 6 MINOR and cleared
behaviour, boundary, security and every shipped contrast figure. All eight findings were recomputed
before being accepted — all eight reproduced — and the dispositions are:

| Item | Severity | Disposition |
| --- | --- | --- |
| Requirement 5's scenario clause "tapping an item still selects it and long-pressing still opens the note editor" was walked only in the single-column layout, so the two-column builders' handlers had no test | IMPORTANT | asserted in `grid layout expresses the same selection language`: tap a second grid tile, check the controller's `currentDevice` moved and the `checkmark_circle` marker followed, then long-press and check that device's note editor opens. Falsifiable on both halves — `checkmark_circle` exists only in `_buildGridDeviceItem` (the list uses `Ionicons.checkmark`), and the dialog title is device-specific. |
| The verification report's own scenario count | IMPORTANT | 20, not 16 (`grep -c '^#### Scenario'` = 3+3+4+3+2+2+1+1+1); the report's coverage table already listed 20 rows, so the summary contradicted it. |
| Requirement 3's 3.0 heading floor had no heading in the enumerated pair list | MINOR | `准备就绪` on the card face and `智能饮水` against both the page base and the band (the stricter `min` of the two) added in light; round 9's re-check then required the dark pair too, since Requirement 7 carries no mode qualifier. |
| A test still named and commented for the translucent default face round 5 replaced | MINOR | renamed to *the plain blocking notice stays legible and carries no hue*, its reason strings rewritten to name the notice role, and it now asserts that face by ARGB identity in both schemes rather than only opacity + chroma + label contrast. |
| Dark hairline recorded as compositing to 1.113 | MINOR | 1.115 (channels 37, 49, 61). 1.113 is exactly what the math gives **without** the harness's 8-bit rounding — the same error class round 6 retired on the light hairline, and it also appears in the `home_page.dart` token comment (1.11 → 1.115). |
| D6 and the report saying the button radius is 24 | MINOR | one shared `BorderRadius` variable at `home_page.dart:910`, 26 normally / 22 compact. Round 9's re-check then caught that `tasks.md` 5.2 still said 24 while the amendment table claimed the correction had been made — corrected, and noted here because a ledger line asserting a fix that never happened is worse than the original wrong number. |
| "25.9° of hue slack" | MINOR | amber `#B45309` reports HSL hue 25.96° and red `#C62828` 0°, so 25.96° is the *distance* and the slack over the 20° floor is 5.96°; the test prints the distance rounded to 26°. |
| D8 claiming the type scale is "applied through `Theme.of(context).textTheme` copies where possible" | MINOR | no `textTheme` lookup exists in the file (`grep -c textTheme` = 0). The scale ships as inline `TextStyle`s and the family is inherited through `DefaultTextStyle`, so `GoogleFonts.notoSansSc` still wins and only the mechanism claim was wrong. |

**TDD disclosure for both rounds (recorded here, not only in the gitignored checkpoint files):** every
assertion added in rounds 8 and 9 is a coverage guard written against behaviour and colours that
already ship, and each passed on first write. None of them is an observed RED, and none is described
anywhere as one. The one thing rounds 8–9 proved about the product was negative: the grid handlers and
the dark heading floors held, so no source change was needed for them — the only `lib/` edit across
both rounds is a comment character (1.11 → 1.115 at `home_page.dart:69`).
