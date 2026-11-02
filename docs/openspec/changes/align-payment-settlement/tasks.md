# Tasks: align-payment-settlement

## 1. API service: bill query and balances

- [x] 1.1 Capture the wallet-owner / acc-score / bill-list / bill-detail response envelopes from the reference client (life-798 `IlifeApi`, endpoints confirmed in design D3: `/acc/wallet/owner`, `/acc/score/acc-score`, `/bill/lst-owner`, `/bill/view-full`) as test fixtures. Verify: fixtures recorded in the change's build context and reflected in 1.2/1.3 tests. <!-- comet-task:eaf980c2-df03-4f00-98fb-49791d52ad44 -->
- [x] 1.2 Add `AccountBalance` model plus wallet-balance (`/acc/wallet/owner`) and score-balance (`/acc/score/acc-score`) methods to `DrinkApiService`; parse the endpoint-matching (else single) wallet entry and `data.validScore`; unexpected shapes parse to null. Verify: request-shape and parser unit tests pass via `flutter test`. <!-- comet-task:e81d3cb2-2717-4dc2-b039-cd568387461f -->
- [x] 1.3 Add the settlement bill query and parser: filter to `type=91`/`status=3`/`cata=6` records for the current device newer than session start, take the latest, extract total (`payment` + promo discount), score part (`promo.type=4` → `discount`) and wallet part; ignore other promo types; tolerate `payment=0`. Verify: parser unit tests cover full-score-covered, no-promo, other-promo-ignored and no-bill cases. <!-- comet-task:4be1b4f8-6ed1-4e56-b9fd-a53c5d8d326d -->

## 2. Controller: no-fallback start and error mapping

- [x] 2.1 Extend `drinkFailurePrompt` with `-52`/`-82`/`-88`/`-87` Chinese prompts; keep `-99` re-login and the server-message pass-through for unmapped codes. Verify: prompt unit tests for all mapped codes plus pass-through. <!-- comet-task:560143cb-e198-4e45-89f9-ad81a9259ed9 -->
- [x] 2.2 Remove the `ptype=21` retry in `HomeController.startDrinking`; a wallet-payment rejection surfaces its prompt and sends no further start request; session-expired flow unchanged. Verify: controller tests assert exactly one start request on rejection (updated former fallback tests). <!-- comet-task:a810f378-8192-471e-9e8d-6d85cf551342 -->
- [x] 2.3 Add nullable `walletBalance`/`scoreBalance` observables fetched on device load when logged in; failures and not-logged-in degrade to hidden values with no dialogs and no requests when logged out. Verify: controller tests with a fake API service cover success, failure and logged-out. <!-- comet-task:315cde1b-3574-443b-9c5e-ef07d0cb7f53 -->

## 3. Settlement reporting and balance refresh

- [x] 3.1 After manual settle (`dev/end` success) and after idle-detection completion, run a bounded bill poll (few attempts, seconds apart) and show the consumption summary prompt: total, score-deducted and wallet-paid parts; full-score-covered and no-charge variants; silent expiry when no bill appears. Verify: controller tests with scripted bill availability timing. <!-- comet-task:7e9bfb2c-8b41-47ca-8398-761a4e195bd7 -->
- [x] 3.2 Re-fetch both balances once the settlement report completes; keep previously displayed values if the refresh fails. Verify: controller test asserts refresh call and failure tolerance. <!-- comet-task:0c4fde85-ee27-4415-87fc-177a13bdeb94 -->

## 4. Home page UI

- [x] 4.1 Render a balance section (wallet yuan + score points) visible only when logged in, placeholder while unknown, following `home-page-ui` surface/hierarchy/contrast rules in light and dark modes. Verify: widget tests for logged-in, not-logged-in and load-failure states; `flutter analyze` clean. <!-- comet-task:d8a2c4fc-f96c-471f-88ac-c3e5ed944e8f -->
- [x] 4.2 Ensure the consumption summary uses the existing prompt styling (no new dialog surface). Verify: covered by 3.1 tests plus a manual visual check on a real device in 5.2. <!-- comet-task:e8b052f7-aef3-41ff-86e6-7c28e46f810f -->

## 5. Verification

- [x] 5.1 `flutter analyze` and `flutter test` fully green. Verify: commands exit 0 with all new and existing tests passing. <!-- comet-task:4d857319-4247-4aad-88c1-bbe34f7d1c22 -->
- [x] 5.2 Real-device integration check with the user's account: start a session (wallet payment), force a rejection path to confirm no Alipay retry, confirm the bill report shows the score-discount breakdown, and confirm balances load and refresh. Verify: observed behavior recorded in the change's build context; deviations from D4/D3 contingencies noted before proceeding. <!-- comet-task:56a733a5-1464-4911-a9c7-abff83c8329c -->

## Workflow follow-up

- Build phase final review (per `review_mode: standard`) and the Verify phase integration review happen in their own phases; no tracked task here.
- Real-device checks in 5.2 need the user's device/account available during build or verify.
