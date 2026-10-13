# Tasks

## 1. Shared form widgets

- [x] 1.1 Create `lib/core/widgets/app_form_fields.dart` with `AppTextField` (label, keyboardType, maxLength, inputFormatters, prefixIcon, suffixIcon, obscureText, textInputAction, autofocus; light/dark adaptation read from the theme) and verify `fvm flutter analyze lib/core/widgets/app_form_fields.dart` reports zero issues and the widget renders standalone in a new widget test <!-- comet-task:1e90585b-68c5-40ca-ab30-5818daf5c8a0 -->
- [x] 1.2 Add `AppPrimaryButton` in the same file (full width, height 56, shows a progress indicator and disables taps while loading) and verify a widget test renders both states, asserting `CircularProgressIndicator` appears and the button is inert when `onPressed == null` <!-- comet-task:73c34c83-489e-4171-bd03-156efa33aa42 -->

## 2. Test seam

- [x] 2.1 Give `LoginController` an optional constructor parameter to inject `DrinkApiService`, defaulting to `DrinkApiService()`, and verify the existing 6 test files still pass under `fvm flutter test` while the production call site `Get.put(LoginController())` stays unchanged <!-- comet-task:d43827d7-bf75-4670-9672-62d905524b92 -->
- [x] 2.2 Add `test/features/login/fake_drink_api_service.dart` overriding `getCaptcha` to return fixed PNG bytes and recording `sendSmsCode`/`login` calls and refresh counts, and verify it drives the group-3 widget tests with zero real network requests <!-- comet-task:f1c27647-8dfe-42c4-9861-64cc70fc8a18 -->

## 3. Failing tests first

- [x] 3.1 In `test/features/login/login_page_ui_test.dart` write the numeric-keyboard case: after focusing the captcha field `keyboardType == TextInputType.number`, and typing letters leaves the value empty, and verify `fvm flutter test test/features/login/login_page_ui_test.dart` fails RED because the current implementation passes no keyboardType <!-- comet-task:701a087c-d4ea-4863-8743-314164dfaa80 -->
- [x] 3.2 Add the case "captcha image shares a row with its field and is no taller than it", and verify the same file fails RED because the current image is a standalone full-width 80-high block <!-- comet-task:11430e58-6664-4123-935c-f024b25b93fc -->
- [x] 3.3 Add the cases "no `#0099CC` solid band at the bottom" and "a smooth fading gradient band remains at the top", and verify the same file fails RED because of the current `stops: [0.0, 0.4]` gradient <!-- comet-task:2d9e4d41-6341-44bc-939f-6b0ae7e415f6 -->
- [x] 3.4 Add the cases "Token entry is reachable and returns" and "tapping the image refreshes the captcha", and verify the refresh case asserts the fake service's counter while the Token case fails RED because today's entry is an icon button with different wording <!-- comet-task:043112cc-7f32-412e-92c7-0859c758edbf -->

## 4. Login page rewrite

- [x] 4.1 Rewrite the page skeleton to a light surface plus a fixed-height top fading band, deleting the full-screen gradient container and the rounded card layer, and verify task 3.3 turns GREEN and the rendered tree contains no solid `Color(0xFF0099CC)` fill <!-- comet-task:ac9b521c-c0c4-4854-8bdc-8a10a72e6c17 -->
- [x] 4.2 Switch the header title and subtitle from white to theme-adaptive dark text, and verify rendering under both brightness values keeps readable contrast with colors taken from the theme rather than hard-coded white <!-- comet-task:20bf2698-a5e1-450c-bcd2-8ee3d53ed908 -->
- [x] 4.3 Convert the phone form to `AppTextField`/`AppPrimaryButton`, and verify the phone and SMS fields both carry `digitsOnly` filtering and that `_buildTextField`/`_buildInputLabel` are no longer referenced in `login_page.dart` <!-- comet-task:0372a36c-223e-4a3a-afbf-00e567445d13 -->
- [x] 4.4 Move the captcha into a `Row` (field on the left, 104×52 image box on the right, tap to refresh) and delete the "看不清？点击刷新" button, and verify tasks 3.1 and 3.2 turn GREEN and the removed label is absent from the rendered tree <!-- comet-task:d0db6edb-5f54-4c43-92a0-5afdcfc17f8e -->
- [x] 4.5 Demote the Token entry to a de-emphasized bottom text link "使用已有 Token 登录" while leaving `showTokenLogin`/`showPhoneLogin`/`loginWithToken` behavior untouched, and verify task 3.4 turns GREEN with the token form's back button and verification flow unchanged <!-- comet-task:9bbd88fb-e177-48b2-8eaa-c3ef05f3a56c -->
- [x] 4.6 Remove dead code, unused imports and leftover helpers, and verify `fvm flutter analyze` reports zero issues for the whole project <!-- comet-task:91375002-6f63-447b-95bc-e1281c767d99 -->

## 5. Integration verification

- [x] 5.1 Run the full regression `fvm flutter analyze` and `fvm flutter test`, recording each with `comet check run refactor-login-page-ui verify --local --`, and verify both exit codes are 0 with the new login page cases and the original 6 test files all passing <!-- comet-task:05bbb318-6a76-4723-a2c0-b1520c10bd0f -->
- [x] 5.2 Produce the requirement→evidence table the Verify report will consume: for each of the 7 requirements in `specs/login-page-ui/spec.md`, name the concrete test case or code location, and mark any machine-undecidable aesthetic item as pending the user's on-device check <!-- comet-task:9e2070dd-d674-4a1c-b3a0-f8c5e2381969 -->
- [x] 5.3 Hand Verify the exact on-device checklist the user must confirm — numeric keyboard raises, captcha no longer dominates, no blue fragmentation at the bottom, Token login still reaches the device list — recording that visual acceptance is asserted only after the user answers <!-- comet-task:aa520c57-12a5-418c-b163-f012c85c8a90 -->

## 6. Post-review fixes

- [x] 6.1 Restore the Token show/hide toggle, which the rewrite had turned into a no-op because `obscureText` was read outside any tracked `Obx`, and verify the new "visibility toggle really unmasks the field" case fails when the wrapper is removed and passes with it <!-- comet-task:4bc9fac3-fd20-45c4-b486-b390ccf15dc1 -->
- [x] 6.2 Rewrite the background assertions so they can actually fail — scan `Container` decorations for both solid `#0099CC` fills and opaque `#0099CC` gradient stops across both brightnesses, and require exactly one gradient whose last stop is transparent — and verify the case is green against the new page and red against the pre-rewrite gradient <!-- comet-task:75313222-b10c-4e99-8a2b-7a6d203f802d -->
- [x] 6.3 Cover the previously untested flow requirements (advance to the SMS step, `autofocus` there, back-refetches the captcha, rejected captcha surfaces the reason without advancing, SMS payload submitted) and the dark-mode rendering of header and background, and verify `fvm flutter test` reports the added cases passing <!-- comet-task:33cf7c3f-2a42-4245-ad11-1efddf822462 -->
- [x] 6.4 Re-pin the primary button to `AppTheme.primaryColor` with white foreground and restore center alignment on the code fields, and verify the component test still asserts height 56 and the UI suite is green <!-- comet-task:9c8c9aac-b457-47a8-b9be-0d18d03be8cc -->
- [x] 6.5 Annotate the test constructor `@visibleForTesting` (adding `meta` to `dependencies` so the import is legal), document its misuse blast radius, pass the controller into the form panel instead of `Get.find`, and delete the login controller on logout, and verify `fvm flutter analyze` reports zero issues and the whole suite passes <!-- comet-task:ec23adc0-1b8d-4d90-ba60-aef7e540e9ad -->

## 7. Verify-round fixes

- [x] 7.1 Drop the `meta` pub dependency and take `visibleForTesting` from `package:flutter/foundation.dart` instead, and verify `pubspec.yaml`/`pubspec.lock` show no new dependency while `fvm flutter analyze` stays clean <!-- comet-task:37225350-65ff-4fb8-9958-c29b64aeb492 -->
- [x] 7.2 Make `DrinkApiService.test()` run `_initToken()` instead of pre-completing the Future, and verify a production misuse can no longer send an empty `Authorization` and wipe a saved token, with the whole suite still passing <!-- comet-task:d36e1c6e-afa9-4973-bb65-346c2c6aa370 -->
- [x] 7.3 Delete the login controller on the session-expired navigation path in `home_controller.dart` as well as on logout, and verify both routes into the login page start on the phone-and-captcha step <!-- comet-task:df711283-9c23-4cd1-9563-8d526956f75e -->
- [x] 7.4 Widen the background assertions to scan `Container` and `DecoratedBox` through a deduplicated set and assert the `Scaffold` sets no own background, and verify the case now fails when a `Scaffold(backgroundColor: Color(0xFF0099CC))` is reintroduced <!-- comet-task:9b9f149d-d4c7-4a8e-9a2f-13fe01886682 -->
- [x] 7.5 Add the missing testable scenarios — successful login landing on the home page, and the bounded loading slot before the captcha image arrives — plus an assertion that the removed "看不清？点击刷新" label is gone, and verify all three cases pass <!-- comet-task:809cc5e5-00c4-4534-aabd-e5cf6463fdd2 -->
- [x] 7.6 Drive the widget tests with the real `AppTheme.lightTheme`/`darkTheme` and give both color schemes an explicit `onSurfaceVariant`, and verify the de-emphasized text is no longer identical to `onSurface` and the suite passes <!-- comet-task:beaea5d6-723e-41ee-b83d-78ee4bcd0833 -->
- [x] 7.7 Fix the `copyWith(letterSpacing: null)` no-op so hint text does not inherit the code-entry letter spacing, and align the captcha row on center rather than on font metrics, and verify the vertical-center assertion holds with a zero tolerance-free margin being required <!-- comet-task:d5154b19-7cc5-48d6-ae58-99ed288aea65 -->

## 8. Device-feedback fix

- [x] 8.1 Restore the captcha length cap from 4 back to 6 after the user reported the official captcha is mostly five numeric characters, so real codes are never truncated, and verify a widget test enters `12345` and gets `12345` back while letters are still filtered <!-- comet-task:c75632fc-1096-4dec-95cc-7b76d721127d -->
