---
change: refactor-home-page-ui
design-doc: docs/openspec/changes/refactor-home-page-ui/design.md
base-ref: 88167acde28002cb9bd768d551f2397884638b32
---

# Implementation Plan — refactor-home-page-ui

<!-- comet-task-authority: docs/openspec/changes/refactor-home-page-ui/tasks.md -->

Execution: `autonomous` · TDD: `tdd` (RED recorded per task) · Review: `standard` · Isolation: `current` on `main`.
Behavioral contract: `docs/openspec/changes/refactor-home-page-ui/specs/home-page-ui/spec.md` (9 requirements). Technical decisions, token values and every contrast figure: `design.md` (D1-D12). This plan only sequences work — it restates neither.

## Ground rules for this run

- Test-first: each implementation task starts by writing the test that fails **because the behavior is missing**, records the RED command and its failure reason, then implements to GREEN. `fvm flutter test test/features/home` is the per-task loop; the whole suite runs once at the end.
- Assertion style: computed relationships (`contrast()`, `surfaceRatio()`, `composite()` re-implementing the WCAG formula from the design doc), keys from D12, `FilledButton.onPressed == null`, and `tester.getRect()` against the recorded hit-area baseline. Literal hex is asserted only for the **forbidden** legacy values.
- Files allowed to change: `lib/features/home/home_page.dart`, `lib/features/home/home_controller.dart`, `test/features/home/*`. `lib/core/theme/app_theme.dart` must stay byte-identical (task 7.3 proves it).
- Group order is a dependency chain: the harness feeds the token layer, the token layer feeds every appearance assertion.

## Group 1 — Test seam and page harness

<!-- comet-task-ref:6de3585a-4b1c-4214-bbb0-cfcdc335f4f0 -->
### 1.1 Failing seam test
Depends on: nothing.
Verify: `fvm flutter test test/features/home` shows RED naming the absent `apiService` parameter.

<!-- comet-task-ref:82decdf4-b097-40d7-aeef-07918db03a44 -->
### 1.2 `HomeController` injection + registration guard
Depends on: 1.1. Constraints: default must stay `DrinkApiService()`; `HomePage.build` mirrors `LoginPage`'s `Get.isRegistered` branch.
Verify: 1.1 GREEN, `fvm flutter analyze --no-pub` clean.

<!-- comet-task-ref:414a9bc5-e68c-45f8-8979-b24703dabc56 -->
### 1.3 Fake service for the home flow
Depends on: 1.2. Extends through `DrinkApiService.test()`; serves list/empty/start/stop/toggle.
Verify: a test asserts call counts and parameters with zero real requests.

<!-- comet-task-ref:fed6163d-4838-4238-aa54-c5e9256c3d1f -->
### 1.4 `pumpHomePage` harness
Depends on: 1.3. `GetMaterialApp`, `SharedPreferences.setMockInitialValues`, `tester.binding.setSurfaceSize` (a bare `MediaQuery` does not change the paint size), `Get.reset` teardown, snackbar draining, `pump()` instead of `pumpAndSettle()` because the bubble animation never settles.
Verify: reused by every later test.

## Group 2 — Surface tokens and background

<!-- comet-task-ref:2a2a4a9a-eefb-4e81-ba15-f4839a3ead63 -->
### 2.1 Failing background-anchor tests
Verify: RED against the two-identical-stop gradient and the flat `#F5F9FF` base.

<!-- comet-task-ref:d1426a9c-e7af-416c-a5e3-b388f7db6e65 -->
### 2.2 `_HomeT` tokens and `_HomeBackground`
Depends on: 2.1. Values from design D3/D5, page painted with `Positioned.fill`, `Scaffold.backgroundColor` set to the page role.
Verify: 2.1 GREEN in light mode.

<!-- comet-task-ref:7e57c386-3d88-4001-b450-9917afc23482 -->
### 2.3 Dark column of the token table
Verify: the 2.1/2.2 assertions also pass under `AppTheme.darkTheme`.

<!-- comet-task-ref:ef6e1e68-8348-4a77-a559-c7abed40f363 -->
### 2.4 Adjacency test
Verify: page↔card, page↔band, card↔selected channels, page↔sheet each clear the spec floor in both modes.

<!-- comet-task-ref:e6ebb1bf-784c-4e19-9e7e-05951f27925e -->
### 2.5 Text and glyph contrast test
Verify: secondary ≥4.5 on every surface it sits on, glyphs ≥3.0, accent text ≥4.5 at the lightest stop.

## Group 3 — Type scale and status card

<!-- comet-task-ref:bd63570d-e6ea-4c00-baff-4788432e75a1 -->
### 3.1 Hierarchy assertions
Verify: the five levels are distinct and the headline dominates its card.
*Note:* this test was written after the group-2 token pass had already applied the sizes, so it entered as a regression guard rather than an observed RED. Recorded as a TDD-history gap, not as a passing RED.

<!-- comet-task-ref:7516940c-5b19-4cf1-9a2d-7b8d0d880ce7 -->
### 3.2 Type scale application
Verify: 3.1 GREEN with `notoSansSc` still winning.

<!-- comet-task-ref:6fcacfe2-e321-490c-884d-c6e2cb14b98b -->
### 3.3 Status card in both states
Verify: `isDrinking` swaps to the accent fill, headline/caption text and the progress bar.

## Group 4 — Device tiles

<!-- comet-task-ref:77d9605e-fde1-4df3-9dea-6b00ec15bf3a -->
### 4.1 Selected vs resting assertions (list and grid)
Verify: ≥2 channels change; the selected tile still clears the page floor; grayscale-readable.

<!-- comet-task-ref:90de78f2-39a3-4286-bf25-778e95ccd1e6 -->
### 4.2 Tile token application
Verify: 4.1 GREEN in both layouts and both modes.

<!-- comet-task-ref:cda30d7b-0c49-4247-aee8-94f36e8701ed -->
### 4.3 Hit-area baseline guard
Constraints: measured from the pre-change page — tile 59.2px tall, note chip 26×26, toolbar icon buttons 40×40, action 64px.
Verify: every box ≥ baseline after the restyle.

<!-- comet-task-ref:e69b2724-46f2-479e-a399-538ad0f6e4ca -->
### 4.4 Empty state and reorder mode
Verify: empty card scrolls instead of overflowing (159px overflow observed first), reorder keeps handles and the selected device.

## Group 5 — Primary action and small-screen behavior

<!-- comet-task-ref:6a59640a-38d5-43d6-a7e1-d6b266820c1e -->
### 5.1 Action assertions
Verify: RED on the missing `primaryAction` key, then on label contrast 3.13 and the inactive appearance.

<!-- comet-task-ref:9a06c5cd-95d9-4178-aeeb-66355c7418cc -->
### 5.2 Gradient behind a transparent `FilledButton`
Constraints: wrapper radius must equal the button radius; disabled keeps `onPressed == null`.
Verify: 5.1 GREEN, analyze clean.

<!-- comet-task-ref:84611d6b-12b8-4eab-af39-57720f7b823a -->
### 5.3 Start/settle wiring
Verify: call counts on the fake, no controller logic changed.

<!-- comet-task-ref:cd77a452-ac8d-4b69-9b90-9433810f8fd2 -->
### 5.4 Compact branch at 320×568 @ textScale 1.3
Verify: no overflow exception; action, layout toggle and add entry reachable.

## Group 6 — Sheets and dialogs

<!-- comet-task-ref:ef23fb9f-79b7-4cf2-b9d5-0fc9e4af7248 -->
### 6.1 Device management sheet assertions
Verify: RED on the missing sheet key and on the 1.06 sheet-vs-page separation.

<!-- comet-task-ref:8ca25930-8a90-47d0-925c-13b841c22c30 -->
### 6.2 Sheet tokens
Verify: 6.1 GREEN; settings sheet still offers 关于 / 退出登录.

<!-- comet-task-ref:5538ed04-7998-4925-8632-13e4fcc50d7e -->
### 6.3 Dialogs onto the same roles
Verify: dialog surface ≥1.15 against the page base; solid actions no longer fall back to the theme's `primaryColor`; destructive labels use the darker destructive ink.

## Group 7 — Integration and regression

<!-- comet-task-ref:9e5e684b-2ea4-4d6f-bce0-95248966a6b9 -->
### 7.1 Interaction sweep
Verify: one test walks refresh, select, note edit, layout toggle, reorder, start, settle, manage sheet, settings sheet, logout confirm cancel.

<!-- comet-task-ref:5b2e5c22-529c-4f41-8551-560fabc3f81f -->
### 7.2 Whole-project checks
Verify: `fvm flutter test --no-pub` and `fvm flutter analyze --no-pub` pass (pub needs network; use `--no-pub` once dependencies are resolved).

<!-- comet-task-ref:12d0b3cd-44ca-4fdc-9f1b-553739e2c4a6 -->
### 7.3 Shared theme untouched
Verify: `git diff --stat lib/core/theme/app_theme.dart lib/features/login lib/core/widgets lib/core/services` is empty and the login tests still pass.

<!-- comet-task-ref:89020659-1c44-4b7b-bb0c-72735473a2ad -->
### 7.4 On-device handoff
Verify: the user gets `fvm flutter run` plus the release-build commands; taste stays their call.

## Riskiest coupling

Everything depends on the `#E4EEF8` page base: it is what separates white cards (1.174) and what breaks `black54` secondary text (4.44). Changing that one value requires re-running 2.4, 2.5 and 4.1 rather than assuming they still hold.
