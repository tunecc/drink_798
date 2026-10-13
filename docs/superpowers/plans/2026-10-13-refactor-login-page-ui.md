---
change: refactor-login-page-ui
design-doc: docs/openspec/changes/refactor-login-page-ui/design.md
base-ref: e2d0e73b7de394c93b170084ee91ee5e95d3ccd4
archived-with: 2026-10-13-refactor-login-page-ui
---

# Implementation Plan: Login Page Rewrite

<!-- comet-task-authority: docs/openspec/changes/refactor-login-page-ui/tasks.md -->

## Background and constraints

Behavioral contract: `docs/openspec/changes/refactor-login-page-ui/specs/login-page-ui/spec.md` (7 requirements, 16 scenarios). Technical decisions and their rationale: `design.md` (D1-D10). This plan only sequences the work; it does not restate either.

Hard constraints carried over from the design phase:

1. **Never switch `LoginPage.build` to `Get.putIfAbsent`.** Probes showed re-`put` cannot override a registration, and `logout → Get.offAll(LoginPage)` could then reuse a controller still holding `isSmsSent == true`. Tests sidestep the service locator entirely via the buildable panel seam (D9).
2. **A test subclass cannot extend `DrinkApiService`** because its only constructor is private (`DrinkApiService._internal()`). `@visibleForTesting DrinkApiService.forTesting()` is the enabler for D6; without it task 2.2 does not compile.
3. **Every widget test pumps inside `GetMaterialApp`.** `refreshCaptcha`'s failure path calls `Get.snackbar`, which throws a null-check error under a plain `MaterialApp`.
4. **Under `TestWidgetsFlutterBinding` all HTTP returns 400**, so no test may rely on a real request; the fake service is the only source of captcha bytes.
5. `AppTheme` and `home_page.dart` are untouched; the two band colors are local constants in `login_page.dart` (D8).
6. Toolchain is FVM-pinned Flutter 3.38.8 — run checks as `fvm flutter analyze` / `fvm flutter test`.

TDD mode is `tdd`: group 3 establishes RED for each appearance/interaction requirement, group 4 turns them GREEN. A RED is only valid when the failure message is the absence of the behavior under test, not a compile or harness error.

---

## Group 1 — Shared form widgets

<!-- comet-task-ref:1e90585b-68c5-40ca-ab30-5818daf5c8a0 -->
### 1.1 `AppTextField`

Scope: new file `lib/core/widgets/app_form_fields.dart`.
Depends on: nothing.
Constraints: port the behavior of `login_page.dart:473-535` (`_buildTextField`) and fold in `_buildInputLabel` (`:460-471`). Parameters per D4 plus an optional `Key`. Read brightness from `Theme.of(context)`, so callers never pass `context` or `style`.

Verify: `fvm flutter analyze lib/core/widgets/app_form_fields.dart` → zero issues; a standalone test builds the widget with a label and asserts the rendered `TextField` carries the given `keyboardType`, `maxLength`, `inputFormatters` and `Key`.

<!-- comet-task-ref:73c34c83-489e-4171-bd03-156efa33aa42 -->
### 1.2 `AppPrimaryButton`

Scope: same file.
Depends on: 1.1.
Constraints: replaces the three duplicated blocks at `:223-253`, `:314-344`, `:427-455`. Full width, height 56, `loading == true` renders `CircularProgressIndicator` and forces `onPressed` null.

Verify: test renders both states and asserts the spinner appears only while loading and the button is inert when `onPressed == null`.

---

## Group 2 — Test seams

<!-- comet-task-ref:d43827d7-bf75-4670-9672-62d905524b92 -->
### 2.1 Constructor seams

Scope: `DrinkApiService` (add `forTesting()`), `LoginController` (add `{DrinkApiService? apiService}`).
Depends on: nothing.
Constraints: production behavior must stay identical — the default still resolves to `DrinkApiService()`, and `Get.put(LoginController())` at `login_page.dart:12` is not modified. `forTesting()` is annotated `@visibleForTesting`.

Verify: `fvm flutter test` — the existing 6 test files all still pass; `fvm flutter analyze` clean.

<!-- comet-task-ref:f1c27647-8dfe-42c4-9861-64cc70fc8a18 -->
### 2.2 Fake service

Scope: new file `test/features/login/fake_drink_api_service.dart`.
Depends on: 2.1.
Constraints: extends `DrinkApiService` via `forTesting()`, overrides `getCaptcha` (returns the 1×1 transparent-PNG bytes and increments `captchaCalls`), `sendSmsCode`, `login`, `loginWithToken`.

Verify: a smoke test builds `LoginController(apiService: FakeDrinkApiService())`, pumps it inside `GetMaterialApp`, and asserts `captchaCalls == 1` after `onInit` with no timer leak at test end.

---

## Group 3 — Failing tests (RED)

All four tasks write into one file, `test/features/login/login_page_ui_test.dart`, against a shared harness: `SharedPreferences.setMockInitialValues({})`, `Get.reset()` in `tearDown`, keys `captchaField`, `captchaImage`, `tokenEntry`, and a size helper that pins the test surface.

<!-- comet-task-ref:701a087c-d4ea-4863-8743-314164dfaa80 -->
### 3.1 Numeric keyboard RED

Scope: test only.
Asserts: `TextField` behind `Key('captchaField')` has `keyboardType == TextInputType.number`; typing `a1b` leaves the value `1`.
Expected RED: currently `_buildTextField` is called without `keyboardType` (`login_page.dart:204-219`), so the assertion fails on `null != number`.

<!-- comet-task-ref:11430e58-6664-4123-935c-f024b25b93fc -->
### 3.2 Inline captcha RED

Scope: test only.
Asserts: `captchaField` and `captchaImage` share the same vertical center and the image box height ≤ the field height.
Expected RED: the image is a standalone full-width 80px block (`:150-193`), so the centers differ.

<!-- comet-task-ref:2d9e4d41-6341-44bc-939f-6b0ae7e415f6 -->
### 3.3 Background RED

Scope: test only.
Asserts: no `BoxDecoration` in the tree paints solid `Color(0xFF0099CC)`, and a `LinearGradient` exists whose last stop has alpha 0.
Expected RED: the full-screen gradient uses `stops: [0.0, 0.4]` into flat `#0099CC` (`:15-26`).

<!-- comet-task-ref:043112cc-7f32-412e-92c7-0859c758edbf -->
### 3.4 Token entry and refresh RED

Scope: test only.
Asserts: a `TextButton` labeled "使用已有 Token 登录" switches the panel and its back control returns; tapping `captchaImage` increments the fake's `captchaCalls`.
Expected RED: today's entry is an icon button labeled "使用 Token 登录" (`:255-261`), so the label lookup fails.

---

## Group 4 — Rewrite (GREEN)

<!-- comet-task-ref:ac9b521c-c0c4-4854-8bdc-8a10a72e6c17 -->
### 4.1 Skeleton

Scope: `LoginPage.build` (`:10-62`).
Constraints: D1 + D7 — `Stack` with a `Positioned` fading band (height 168, brand blue alpha 0.16 → alpha 0) under `SafeArea` + `Column`; delete the full-screen gradient container and the rounded card. Form content sits on the page surface.
Verify: 3.3 GREEN.

<!-- comet-task-ref:20bf2698-a5e1-450c-bcd2-8ee3d53ed908 -->
### 4.2 Header text

Scope: `_buildHeader` (`:64-107`).
Constraints: title and subtitle move from `Colors.white` to theme-adaptive dark foregrounds; the water-drop badge tint follows the band rather than hard-coded white.
Verify: rendering under both brightness values keeps contrast; no hard-coded `Colors.white` foreground remains in the header.

<!-- comet-task-ref:0372a36c-223e-4a3a-afbf-00e567445d13 -->
### 4.3 Phone form on shared widgets

Scope: `_buildPhoneForm` (`:109-264`), `_buildSmsCodeForm`, `_buildTokenForm`.
Constraints: every field becomes `AppTextField`, every primary CTA becomes `AppPrimaryButton`; phone and SMS gain `FilteringTextInputFormatter.digitsOnly`; forms chain with `TextInputAction.next`.
Verify: `_buildTextField`/`_buildInputLabel` no longer referenced; 3.1 partially GREEN (keyboard assertion holds once the captcha field is an `AppTextField`).

<!-- comet-task-ref:d0db6edb-5f54-4c43-92a0-5afdcfc17f8e -->
### 4.4 Inline captcha row

Scope: captcha section of the phone form.
Constraints: D2 + D3 — `Row(Expanded(AppTextField with Key('captchaField'), keyboardType: number, digitsOnly, maxLength: 4), 104×52 image box with Key('captchaImage'))`, `GestureDetector(behavior: HitTestBehavior.opaque)` bound to `refreshCaptcha`, corner refresh glyph, loading indicator inside the same bounds. Delete the "看不清？点击刷新" button (`:194-201`).
Verify: 3.1 and 3.2 GREEN, and the removed label is absent from the tree.

<!-- comet-task-ref:9bbd88fb-e177-48b2-8eaa-c3ef05f3a56c -->
### 4.5 Token entry demotion

Scope: bottom of the phone form + panel seam wiring.
Constraints: D5 + D9 — de-emphasized `TextButton` labeled "使用已有 Token 登录" with `Key('tokenEntry')`; `showTokenLogin`/`showPhoneLogin`/`loginWithToken` behavior untouched.
Verify: 3.4 GREEN.

<!-- comet-task-ref:91375002-6f63-447b-95bc-e1281c767d99 -->
### 4.6 Dead-code sweep

Scope: `login_page.dart` imports and leftovers.
Verify: `fvm flutter analyze` zero issues project-wide.

---

## Group 5 — Integration verification

<!-- comet-task-ref:05bbb318-6a76-4723-a2c0-b1520c10bd0f -->
### 5.1 Full regression

Command pair, each recorded through Runtime: `comet check run refactor-login-page-ui build --local -- fvm flutter analyze` and `... -- fvm flutter test`.
Verify: both exit 0; new login-page cases pass and the original 6 files still pass.

<!-- comet-task-ref:9e2070dd-d674-4a1c-b3a0-f8c5e2381969 -->
### 5.2 Requirement walk (Build-side input)

Scope: the mapping table only, no code.
Verify: for each of the 7 requirements, name the test case or code location and mark machine-undecidable aesthetic items as pending the user's on-device check. Verify consumes this table rather than re-deriving it.

<!-- comet-task-ref:aa520c57-12a5-418c-b163-f012c85c8a90 -->
### 5.3 On-device checklist handoff

Scope: the checklist text Verify puts to the user.
Verify: four items — numeric keyboard raises, captcha no longer dominates, no blue fragmentation at the bottom, Token login still reaches the device list — with an explicit note that visual acceptance is claimed only after the user answers.

---

## Group 6 — Post-review fixes

All five came out of the single independent review round (`review_mode: standard`) and are recorded in `design.md` → "Review log".

<!-- comet-task-ref:4bc9fac3-fd20-45c4-b486-b390ccf15dc1 -->
### 6.1 Token visibility regression

Scope: `_TokenForm` in `login_page.dart`.
Constraints: `obscureText` must be read inside an `Obx` that actually tracks `isTokenVisible`. The panel-level `Obx` does not — it only registers reads made inside its own builder, and GetX restores its tracking proxy before children build.
Verify: the visibility case fails when the wrapper is removed (confirmed by temporarily deleting it) and passes with it.

<!-- comet-task-ref:75313222-b10c-4e99-8a2b-7a6d203f802d -->
### 6.2 Falsifiable background assertions

Scope: the background group in `login_page_ui_test.dart`.
Constraints: scan `Container` decorations only — `Container` renders a `DecoratedBox`, so scanning both double-counts one fill. Match solid `#0099CC` fills *and* opaque `#0099CC` gradient stops, since the original offender was a gradient whose `color` is null. Require exactly one gradient whose last stop has alpha 0.
Verify: green against the new page, red against the pre-rewrite gradient.

<!-- comet-task-ref:33cf7c3f-2a42-4245-ad11-1efddf822462 -->
### 6.3 Flow and dark-mode coverage

Scope: `login_page_ui_test.dart`.
Constraints: cover advance-to-SMS, `autofocus` there, back-refetch, rejected captcha (reason surfaced, no advance, captcha refetched), the submitted SMS payload, and a dark-brightness pass over the background plus a non-white header assertion. Every snackbar assertion must drain GetX's queue before teardown or Flutter fails on a pending timer/ticker.
Verify: `fvm flutter test` passes with the added cases.

<!-- comet-task-ref:9c8c9aac-b457-47a8-b9be-0d18d03be8cc -->
### 6.4 Button color and code-field alignment

Scope: `AppPrimaryButton`, captcha and SMS fields.
Constraints: pin `AppTheme.primaryColor` with a white foreground instead of inheriting `filledButtonTheme`, whose dark variant pairs `primaryLight` with white text at 2.2:1. Restore `TextAlign.center` and hint sizing for the two code fields.
Verify: the component test still asserts height 56 and the UI suite is green.

<!-- comet-task-ref:ec23adc0-1b8d-4d90-ba60-aef7e540e9ad -->
### 6.5 Seam hygiene and lifecycle

Scope: `DrinkApiService`, `app_form_fields.dart`, `login_page.dart`, `app_controller.dart`, `pubspec.yaml`.
Constraints: `@visibleForTesting` requires `meta` as a direct dependency (a transitive import trips `depend_on_referenced_packages`). The form panel takes the controller by argument instead of `Get.find`. `logout()` must `Get.delete<LoginController>()`, since `Get.put` never replaces an existing registration and a returning user would otherwise land on a stale step.
Verify: `fvm flutter analyze` zero issues, full suite passing.

---

## Group 7 — Verify-round fixes

Raised by the single final integration review; all seven were resolved in one return to Build.

<!-- comet-task-ref:37225350-65ff-4fb8-9958-c29b64aeb492 -->
### 7.1 Remove the `meta` dependency

Constraints: `package:flutter/foundation.dart` already re-exports `visibleForTesting`; adding `meta` as a runtime dependency contradicted the proposal. Also drops the now-redundant `dart:typed_data` import.
Verify: `git diff pubspec.yaml pubspec.lock` shows no dependency change and `fvm flutter analyze` is clean.

<!-- comet-task-ref:d36e1c6e-afa9-4973-bb65-346c2c6aa370 -->
### 7.2 Make the test constructor inert

Constraints: instance methods cannot be called from an initializer list, so `_initToken()` moves into the constructor body.
Verify: misuse now yields a normal not-logged-in service rather than an empty `Authorization` that clears the stored token; full suite passes.

<!-- comet-task-ref:df711283-9c23-4cd1-9563-8d526956f75e -->
### 7.3 Cover the second route into the login page

Scope: `home_controller.loadDevices()` session-expired branch.
Verify: both `AppController.logout()` and this path delete `LoginController` before `Get.offAll(LoginPage)`.

<!-- comet-task-ref:9b9f149d-d4c7-4a8e-9a2f-13fe01886682 -->
### 7.4 Close the background assertion's blind spot

Constraints: scan `Container` **and** `DecoratedBox` through a `Set` so double-counting is harmless, and assert `Scaffold.backgroundColor == null`.
Verify: reintroducing `backgroundColor: Color(0xFF0099CC)` on the Scaffold makes the case fail (confirmed by temporary edit), and it passes once removed.

<!-- comet-task-ref:809cc5e5-00c4-4534-aabd-e5cf6463fdd2 -->
### 7.5 Add the missing testable scenarios

Scope: `login_page_ui_test.dart`, `fake_drink_api_service.dart`.
Constraints: the loading-slot case needs a `getCaptcha` that never completes and must avoid `pumpAndSettle` (indeterminate spinner); use finite `pump` only.
Verify: three new cases pass — success lands on `HomePage`, the loading slot stays 104×52 with no `Image`, and the removed `看不清？点击刷新` label is asserted absent.

<!-- comet-task-ref:beaea5d6-723e-41ee-b83d-78ee4bcd0833 -->
### 7.6 Test against the real themes

Constraints: use `AppTheme.lightTheme`/`darkTheme` in the harness; give both `ColorScheme`s an explicit `onSurfaceVariant`, since the default falls back to `onSurface` (pure black/white).
Verify: a case asserts `onSurfaceVariant != onSurface` and that header colors equal the theme's values.

<!-- comet-task-ref:d5154b19-7cc5-48d6-ae58-99ed288aea65 -->
### 7.7 Fix hint spacing and row alignment

Constraints: `TextStyle.copyWith` ignores null arguments, so hint spacing must be set to `0` explicitly; the captcha row aligns on `center` so the vertical-center assertion no longer depends on font metrics.
Verify: `fvm flutter analyze` clean and `fvm flutter test` passes (74 tests).

---

## Group 8 — Device-feedback fix

<!-- comet-task-ref:c75632fc-1096-4dec-95cc-7b76d721127d -->
### 8.1 Undo the captcha length narrowing

Scope: `_CaptchaRow` in `login_page.dart`, the numeric-keyboard case in `login_page_ui_test.dart`, `design.md` D3, `proposal.md`.
Constraints: the 4-character cap was an unverified inference; the user's device check reported the official captcha is mostly five numeric characters, so 4 would silently truncate real codes and lock the user out of SMS login. Return to the baseline cap of 6 and keep `digitsOnly`, since a five-digit code is numeric by definition.
Verify: the case enters `12345` and asserts `12345` survives, while `a1b2c` still yields `12`; `fvm flutter analyze` clean and the full suite passes.
