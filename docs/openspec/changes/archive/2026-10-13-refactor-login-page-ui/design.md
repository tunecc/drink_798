---
comet_change: refactor-login-page-ui
role: technical-design
canonical_spec: openspec
archived-with: 2026-10-13-refactor-login-page-ui
status: final
---

# Design

This is the confirmed technical design for the login page rewrite. It supersedes the Open-phase draft (D1-D6): the draft's numbering is preserved where the decision survived, D6 was corrected after probing, and D7-D10 are new. Motivation and acceptance requirements live in `proposal.md` and `specs/login-page-ui/spec.md`; this file only covers how.

## Context

`lib/features/login/login_page.dart` (536 lines) is a stateless widget that calls `Get.put(LoginController())` inside `build`. It stacks three layers: Scaffold → a full-screen gradient `Container` (`#00D4FF → #0099CC`, `stops: [0.0, 0.4]`) → `SafeArea` + `Column` (a white header block, then an `Expanded` card with 30px top corner radii filled with the theme's `scaffoldBackgroundColor`). Inside the card, a `SingleChildScrollView` wraps an `Obx` that switches between three forms on `isTokenLogin`/`isSmsSent`.

Constraints that shape the approach:

- `AppTheme.gradientStart/gradientEnd/primaryGradient/waterGradient` are referenced only inside `app_theme.dart`; the home page hard-codes its own gradient colors. The theme file is effectively decoupled from the login page.
- `DrinkApiService` hides its constructor behind a singleton factory (`DrinkApiService._internal()`), and `LoginController` holds it directly.
- Two separate sources expose dark color at the bottom: the gradient reaches flat `#0099CC` at 40% while the card covers only two top corners, and the region vacated by `SafeArea`'s bottom padding always shows the gradient's own solid color.
- The captcha field calls the page-private `_buildTextField` without `keyboardType` (`:204-219`), so it raises the default keyboard; the SMS field in the same file already passes `TextInputType.number` (`:385-405`).
- The project has 6 Dart test files, all pure-logic. No widget test exists yet; `flutter_test` and `flutter_lints` are already in `dev_dependencies`.

### Probe findings (throwaway test, removed after the run)

These were verified empirically before any of the seams below were chosen, and each invalidated an obvious-looking alternative:

| Probe | Observed | Consequence |
| --- | --- | --- |
| Re-`put` an already-registered controller | `same-instance=true` — `GetInstance._insert` ignores a non-dirty existing key | A test cannot override the controller that `LoginPage.build` registers, and `putIfAbsent` would be **unsafe**: after `logout → Get.offAll(LoginPage)`, a surviving controller could still carry `isSmsSent == true` |
| `Get.put` lifecycle | `initCalls=1` — `onInit()` runs synchronously inside `put` | Constructing the page in a test immediately triggers `refreshCaptcha()` |
| `DrinkApiService()` in a test | `runtimeType=DrinkApiService` — the factory ignores `extends` from another library because the only constructor is private | Open-phase task 2.2 ("subclass `DrinkApiService`") would not have compiled; see D6 |
| Pumping the real page | `Null check operator used on a null value` at `SnackbarController._configureOverlay` via `LoginController.refreshCaptcha:59` | Under `TestWidgetsFlutterBinding` all HTTP returns 400, so the captcha request fails and the error path calls `Get.snackbar`, which requires a `GetMaterialApp` |

## Goals / Non-Goals

**Goals:**

- Remove "captcha too large" and "the eye scans up and down" with one layout change rather than two parameter tweaks.
- Define page coloring in exactly one place, so a bottom band disagreeing with the body becomes structurally impossible.
- Give every requirement in `specs/login-page-ui/spec.md` a test that can fail for the right reason.
- Keep the login flow, controller state machine, and API layer behaviorally identical before and after.

**Non-Goals:**

- No change to `AppTheme`: those gradient constants have no external references, so touching them buys nothing and only widens blast radius. *(Amended during Verify: both `ColorScheme`s gained an explicit `onSurfaceVariant`, because leaving it unset silently falls back to `onSurface` and flattens the text hierarchy on the very page being redesigned — see the Verify review log. Gradient constants and the home page remain untouched.)*
- No change to `DrinkApiService` request behavior, the signing logic, or pub dependencies.
- No reordering of the three-step flow, no new login method, no removal of Token login.
- No screenshot or pixel-level visual regression — the environment cannot reliably boot a simulator, so UI verification is structural widget tests plus `flutter analyze`, with aesthetics explicitly deferred to the user's device.

## Decisions

### Visual layering

#### D1: Replace "full-screen gradient + rounded card" with "light surface + fading top band"

The Scaffold sets no background (it inherits the theme's light surface) and the body becomes a `Stack`: a fixed-height fading band pinned to the top with `Positioned` — brand blue transitioning smoothly to transparent, covering only the header — with `SafeArea` + `Column` above it, so form content sits directly on the page's light background. No card container, no 30px rounded boundary. The header title and subtitle change from white to theme-adaptive dark text.

*Alternatives:* keeping the card and using `stops: [0.0, 1.0]` leaves the bottom safe area dark blue, so the reported fragmentation is untouched; giving the card all four corners plus a white margin adds a container and a border where the complaint was clutter. The fragmentation comes from the boundary between two fills, so deleting the card removes the boundary line and the corner exposure at once.

#### D7: The top band is a fixed-height `Positioned` layer (new)

Band height starts at 168 with brand blue at alpha 0.16 fading to alpha 0, declared as two local constants.

*Alternative considered:* an integral full-bleed gradient behind a transparent status bar, which reads better on notched devices but requires manual `MediaQuery` padding bookkeeping, and its failure mode — content overlapping the band — cannot be caught by any test available here.

#### D8: Band colors stay local to the login page (new)

The two constants live in `login_page.dart` rather than `AppTheme`, because the theme's gradient constants have no consumers outside that file and the home page is out of scope. Adding login-only colors to `AppTheme` would create the misleading impression that they are shared.

### Components and interaction

#### D2: Captcha inline on the same row, sized to the field

The captcha row becomes a `Row`: `Expanded(AppTextField)` on the left, a fixed captcha box on the right (height 52, width 104, same corner radius as the field, `BoxFit.contain` inside a `ClipRRect`). The box is wrapped in `GestureDetector(behavior: HitTestBehavior.opaque)` bound to `refreshCaptcha`, with a small refresh glyph overlaid in the corner to signal tappability; the loading state renders a centered indicator inside the same 104×52 bounds.

*Alternative:* shrinking the image to 56 on its own row — still two rows, the eye still jumps, and the extra "看不清？点击刷新" control cannot be dropped. Once inline, the image height is bounded by the field height by construction, and the layout loses one control. 104×52 approximates a typical captcha aspect ratio so `contain` leaves little letterboxing; if the real ratio differs, only these two constants change.

#### D3: Numeric keyboard plus digit filtering, length cap kept at 6

The captcha field passes `keyboardType: TextInputType.number` and `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`. The phone field gains `digitsOnly`; the SMS field keeps `TextInputType.number` and gains `digitsOnly`. Forms chain focus with `TextInputAction.next`, and the SMS step keeps `autofocus`.

*Amended after the user's device check:* this first shipped as `maxLength: 4`, narrowing the previous 6 on the unverified premise that the captcha is four digits. The user reported the official captcha is mostly **five** numeric characters, so 4 would truncate real codes and make SMS login impossible. The cap returns to 6 — the original headroom — while `digitsOnly` stays, since a five-digit code is numeric by definition.

If the server ever switches to an alphanumeric captcha, `digitsOnly` would block input, so both length and filtering are parameters of the shared widget and the fallback is a call-site change. The controller submits the field text as-is and carries no length assumption.

#### D4: New `lib/core/widgets/app_form_fields.dart` with two widgets

- `AppTextField`: converts the page-private `_buildTextField` (58 lines, 13 named parameters) into a widget keeping `label`, `keyboardType`, `maxLength`, `inputFormatters`, `prefixIcon`, `suffixIcon`, `obscureText`, `textInputAction`, `autofocus`, plus an optional `Key`. Light/dark adaptation reads `Theme.of(context).brightness` internally, so callers stop passing `context` and `style`.
- `AppPrimaryButton`: collapses the three near-identical `SizedBox(height:56) + Obx + FilledButton + CircularProgressIndicator` blocks (`:223-253`, `:314-344`, `:427-455`) into one widget taking `onPressed`, `loading`, and `child`.

*Alternative:* keeping them as private methods — smallest diff, but the user asked for extraction, and a page-private builder cannot be constructed in isolation by a test. Four fields and three primary buttons on this page repeat one rule set, so the duplication is of rules, not coincidence. Only the login page consumes these widgets for now.

#### D5: Demote the Token entry to a de-emphasized text link

A `TextButton` at the bottom of the phone form — no icon, small font, grey foreground — labeled "使用已有 Token 登录", calling the existing `showTokenLogin`. The back button inside the token form and the whole `loginWithToken` flow stay untouched. An archived change recorded "token login still shows the device list" as an acceptance scenario, so the entry may become quieter but must not disappear; a plain text link is also located in tests by its label string, which is more stable than an icon button.

### Test seams

#### D9: A buildable form panel, not a service-locator trick (new)

The header block and the form section become widgets that receive a `LoginController` argument. Tests construct those widgets directly with a controller built on a fake service, so no test depends on `Get` registration order and the "who creates the controller" question never enters the picture. `LoginPage` keeps `Get.put(LoginController())` and simply passes the controller down, leaving production behavior byte-identical.

*Alternative rejected:* switching the page to `Get.putIfAbsent` so a pre-registered test controller would win. Beyond being unnecessary for the panel seam, it is a real behavioral hazard — the probe showed registrations are not overridden anyway, and `AppController.logout` navigates back to `LoginPage`, where a surviving controller could still report `isSmsSent == true` and open on the wrong step.

#### D6 (corrected twice): `DrinkApiService.test()` plus the optional controller parameter

`LoginController({DrinkApiService? apiService})` with the field defaulting to `DrinkApiService()` stays as drafted. The fake is built on a new generative `DrinkApiService.test()` constructor annotated `@visibleForTesting`, which skips the SharedPreferences read so a subclass can extend it and override `getCaptcha` (fixed PNG bytes, refresh counter), `sendSmsCode`, `login`, and `loginWithToken`.

*Why the Open-phase draft fails:* `DrinkApiService` declares only `DrinkApiService._internal()`, so `class FakeDrinkApiService extends DrinkApiService` from another library has no accessible super constructor and does not compile.
*Why the first Build fix was also wrong:* `@visibleForTesting DrinkApiService.forTesting()` did not work either. A redirecting factory cannot be the super constructor, so the subclass needs `super.test()` pointing at a **generative** constructor; and `meta` had to become an explicit `dependencies` entry, because importing `package:meta` transitively trips `depend_on_referenced_packages`.
*Alternative rejected:* stubbing at Dio's `httpClientAdapter`, which leaves production code untouched but makes "tap refreshed the captcha" unfalsifiable — every request fails identically, so the test cannot distinguish a refresh call from a no-op.

#### D10: Assertion vocabulary for appearance requirements (new)

Appearance requirements must become decidable, so tests assert structure rather than taste:

| Requirement | Decidable assertion |
| --- | --- |
| Captcha image and field share one row | The field's and image box's vertical centers match (same `Row`), and the image box height ≤ the field height |
| No dark band at the bottom | No `BoxDecoration` in the rendered tree paints solid `Color(0xFF0099CC)` |
| Smooth top tint | A `LinearGradient` exists and its last stop color has alpha 0 |
| Captcha numeric keyboard | The captcha field's `TextField.keyboardType == TextInputType.number`, and typing letters leaves the value empty |
| Token entry reachable | A `TextButton` with label "使用已有 Token 登录" is findable and switches the panel; the back control then restores the phone panel |
| Three-step flow unchanged | Submitting phone + captcha switches to the SMS panel; back returns to the first panel and increments the fake's refresh counter |

Two harness rules follow from the probe: every test pumps inside `GetMaterialApp` (the `refreshCaptcha` error path calls `Get.snackbar`, which crashes under a plain `MaterialApp`), and each test sets `SharedPreferences.setMockInitialValues({})` and calls `Get.reset()` in `tearDown`. Captcha field, image box, and Token link carry `Key`s, since a widget test cannot reason about "the field next to the picture" from hint text alone. Geometry assertions rely on a test surface set explicitly (`MediaQueryData(size: Size(400, 900))`), which also zeroes `SafeArea` padding — so the safe-area clause of the background requirement is asserted through the fill rule rather than by measuring a bottom inset.

One further rule came from Build: GetX queues snackbars, and each one schedules an auto-dismiss timer plus an `AnimationController` owned by the `Overlay`. Asserting snackbar text does work, but a test must drain the queue before teardown (`pump(6s)` then `pumpAndSettle`, twice when the flow raises two), otherwise Flutter fails with "A Timer is still pending" or "disposed with an active Ticker". Where the second snackbar is not the point of the case, the test asserts the submitted payload and the retained step instead.

## Review log (Build, `review_mode: standard`)

One independent review round was used. Findings and their resolution:

- **CRITICAL — Token show/hide was a no-op.** `obscureText` was read in the token form's own `build`, outside the panel `Obx`'s tracking window, so GetX never registered the dependency. Fixed by wrapping the token field in its own `Obx`. Verified as a real regression guard: deleting that wrapper makes the new "visibility toggle really unmasks" case fail.
- **IMPORTANT — the background assertion could never have gone RED.** It inspected `BoxDecoration.color` for `#0099CC`, but the original fill was a *gradient*, whose `color` is null. Rewritten to scan `Container` decorations for either a solid `#0099CC` or an opaque `#0099CC` gradient stop, and to require exactly one gradient whose last stop has alpha 0. `Container` is scanned rather than both `Container` and `DecoratedBox`, because the former renders the latter and the pair double-counted a single fill.
- **IMPORTANT — flow requirements had no coverage.** Added cases for phone + captcha advancing to the SMS step, `autofocus` on the SMS field, back-from-SMS refetching the captcha, a rejected captcha surfacing the server reason without advancing, and the SMS payload actually submitted.
- **IMPORTANT — dark mode was never rendered.** Added a dark-brightness pass over the background rule and a case asserting the header title is not hard-coded white. The primary button no longer inherits `filledButtonTheme` (whose dark variant pairs `primaryLight` with white text at 2.2:1); it pins `AppTheme.primaryColor` with a white foreground, matching the page as it was.
- **IMPORTANT — the test constructor shipped unguarded.** `@visibleForTesting` is now applied, which required declaring `meta` as a direct dependency; the doc comment states the concrete blast radius (empty `Authorization` → the device list treats the session as logged out → the saved token is cleared).
- **IMPORTANT — the refresh affordance disappeared.** A corner refresh glyph and a stronger box border were added. *Accepted deviation:* the `Tooltip` that first shipped alongside the glyph was removed — it left an active ticker in the `Overlay` at teardown, and the visible glyph already carries the discoverability D2 asked for.
- **IMPORTANT — the shipped seam was not the documented one.** The form panel now receives the `LoginController` as a constructor argument instead of calling `Get.find`, so no test depends on `GetInstance._insert` keeping a non-dirty registration.
- **SUGGESTIONs applied:** the page reuses the registered controller instead of allocating a `LoginController` plus four `TextEditingController`s per rebuild; `logout()` now `Get.delete`s it so a returning user cannot land on a stale step; the unused `onSubmitted` parameter was dropped; the duplicated label recipe became a shared `AppFieldLabel`; back buttons carry `Key`s rather than being reached through `find.byType(IconButton).first`; the captcha and SMS fields regained center alignment and hint-text sizing.

## Coverage mapping

| Requirement (specs/login-page-ui) | Design anchor | Verification |
| --- | --- | --- |
| Captcha image and field adjacent on one row | D2, D10 | widget: shared `Row`, matching vertical centers, image height ≤ field height; tap increments the fake's refresh counter |
| Captcha input uses numeric keyboard | D3, D10 | widget: `keyboardType == TextInputType.number`, `maxLength == 6`, a 5-digit code survives, typing letters keeps only digits |
| No dark band at the bottom | D1, D10 | widget: no solid `#0099CC` fill and no opaque `#0099CC` gradient stop, in both brightnesses |
| Brand gradient as smooth top tint | D1, D7, D10 | widget: exactly one gradient, last stop at alpha 0, first stop visible |
| Token login entry stays reachable | D5, D10 | widget: link found by label; tapping shows the token panel with a working back control |
| Three-step flow unchanged | D9, unchanged controller flow | widget: panel switches forward and back, captcha refetched on return |
| Form controls consistent | D4, D8 | widget: all fields are `AppTextField` instances sharing the same radius/height constants |

## Risks / Trade-offs

- **[Removing the card layer may be rejected by eye]** → confined to the skeleton section of `login_page.dart`; if the user dislikes it on device, reverting D1/D7 alone leaves D2/D3/D4/D9 intact.
- **[D3's original 4-character cap]** → realized during the user's device check: the official captcha is mostly five digits, so the narrowed cap would have truncated real codes. Reverted to the baseline 6 and pinned in a test that enters a five-digit value.
- **[Unknown captcha aspect ratio; `contain` may letterbox]** → dimensions are two named constants (52/104); visible letterboxing means adjusting only those.
- **[Widget tests cannot prove the page looks better]** → stated in the acceptance criteria: structure and interaction come from tests, aesthetics come from the user on device. A passing suite is never reported as visual acceptance.
- **[`@visibleForTesting` constructor ships in production code]** → it is inert unless called and documented as such; the alternative (a Dio-level stub) was rejected for weakening the refresh assertion.
- **[`lib/core/widgets/` starts with a single consumer]** → accepted: the confirmed scope is "login page plus reusable input widgets", and the home page is deliberately not force-migrated.

## Review log (Verify final integration review)

The single final integration review covered the whole change, including the Build fixes. Verdict: approve with concerns; five IMPORTANT items were resolved in a return to Build (tasks 7.1-7.7) and two were accepted:

- **I-1 dependency creep** — `meta` was added to `dependencies` purely for `@visibleForTesting`, contradicting the proposal's "no new pub dependencies". `package:flutter/foundation.dart` re-exports the annotation; the dependency is gone.
- **I-2 destructive misuse path** — the test constructor pre-completed `_tokenInitialized`, so an accidental production call would send an empty `Authorization`, let `getDeviceList()` conclude the session expired, and delete the stored token. It now runs `_initToken()` like the real constructor, so misuse is inert. (Instance methods cannot be called in an initializer list, hence the constructor body.)
- **I-3 half-fixed lifecycle** — `logout()` deleted the controller but the session-expired route in `home_controller.loadDevices()` did not, leaving the same stale-step window on that path. Both routes now delete.
- **I-4 blind background assertion** — scanning `Container` only (the Build round's fix for double-counting) could not see a `Scaffold(backgroundColor:)` regression. The scan now covers `Container` and `DecoratedBox` through a deduplicated set and asserts the Scaffold sets no own background. Verified falsifiable: reintroducing `backgroundColor: Color(0xFF0099CC)` on the Scaffold makes the case fail.
- **I-5 untested success path** — "a successful login lands on the home page" is now a real case, alongside the previously missing loading-slot scenario and an explicit assertion that the old "看不清？点击刷新" label is gone.
- **WARNING theme fidelity** — the tests pumped a hand-built `ThemeData`, so they never exercised the app's real colors. `AppTheme`'s `ColorScheme.light/dark` never set `onSurfaceVariant`, which silently falls back to `onSurface` (pure black/white): subtitle, hint text and the deliberately de-emphasized Token link were as strong as body text. Both schemes now set it explicitly, and the tests use `AppTheme.lightTheme`/`darkTheme`.
- **WARNING no-op copyWith** — `letterSpacing: null` is ignored by `TextStyle.copyWith`, so hint text inherited the code-entry spacing; it now sets `0`. The captcha row also switched from `CrossAxisAlignment.end` to `center`, because the "vertical centers match" assertion was only passing thanks to the test font's metrics.

Accepted, not fixed:

- **Button contrast** — white on `AppTheme.primaryColor` computes to 3.12:1, below the 4.5:1 WCAG target for 16px semibold text. This is identical to the pre-rewrite page, so it is not a regression introduced here, and darkening it to `AppTheme.primaryDark` (4.60:1) is a visible brand-color change the user has not asked for. Flagged for the on-device round.
- **Captcha length premise** — `maxLength: 4` plus `digitsOnly` rests on an observation of the server's captcha that no artifact in this repo pins down. If the server ever returns alphanumeric codes, digit filtering blocks input entirely; the fallback is a call-site parameter change. This is the pending on-device entry, not a code defect.
- **Coverage tally** — the Build handoff claimed 13 of 16 scenarios covered. After the 7.x additions the honest count is 13 fully asserted, 2 covered by structural proxies whose remaining clauses are device-only (real IME, rendered appearance), and 1 device-only (token login against the live API). The original claim conflated "has some assertion" with "asserts the requirement".

## Migration Plan

No data migration, no interface change, no persistence-format change; the rewrite ships with the app build. Rollback is reverting this change's commits (rewritten `login_page.dart`, new `app_form_fields.dart`, one `forTesting()` constructor, one controller parameter, new test files) with no state cleanup required.

## Open Questions

None that affect scope, approach, or task breakdown. Band height (168) and alpha (0.16) are starting values the user reviews on device after Build; neither changes any decision branch here.
