# Tasks

## 1. Test seam and page harness

- [x] 1.1 Write failing widget tests that register `HomeController(apiService: FakeDrinkApiService(...))`, pump `HomePage` under `GetMaterialApp` with `AppTheme.lightTheme`, and prove the page reuses the registered controller instead of constructing its own; verify `fvm flutter test test/features/home` reports the expected RED before any production code changes. <!-- comet-task:6de3585a-4b1c-4214-bbb0-cfcdc335f4f0 -->
- [x] 1.2 Add the optional `DrinkApiService? apiService` constructor parameter to `HomeController` and switch `HomePage.build` to the `Get.isRegistered` guard used by `LoginPage`; verify the task 1.1 tests go GREEN and `fvm flutter analyze` stays clean. <!-- comet-task:82decdf4-b097-40d7-aeef-07918db03a44 -->
- [x] 1.3 Extend the home fake service so it can serve a non-empty device list, an empty list, and start/settle results, reusing the `DrinkApiService.test()` super constructor pattern from `test/features/login/fake_drink_api_service.dart`; verify a test asserts the fake's call counts with no real network request issued. <!-- comet-task:414a9bc5-e68c-45f8-8979-b24703dabc56 -->
- [x] 1.4 Create a parameterized `pumpHomePage(tester, {brightness, devices, isDrinking})` helper mirroring `pumpLoginPage`, including `Get.reset` teardown and snackbar-queue draining; verify it is used by the tests added in later tasks without extra setup code. <!-- comet-task:fed6163d-4838-4238-aa54-c5e9256c3d1f -->

## 2. Surface tokens and background

- [x] 2.1 Write failing tests for the idle background: a brand-gradient band exists behind the app bar, no state renders a single flat fill, and the legacy two-identical-stop gradient is gone; verify RED against the current page. <!-- comet-task:2a2a4a9a-eefb-4e81-ba15-f4839a3ead63 -->
- [x] 2.2 Define the private surface-role tokens (page base, resting card, selected card, elevated sheet) and the named idle/in-progress three-stop gradients from design D2-D4, then replace the `AnimatedContainer` background with `_HomeBackground` using `Positioned.fill`; verify the task 2.1 tests go GREEN in light mode. <!-- comet-task:d1426a9c-e7af-416c-a5e3-b388f7db6e65 -->
- [x] 2.3 Add the dark-mode role values and verify the same background tests pass when pumped with `AppTheme.darkTheme`. <!-- comet-task:7e57c386-3d88-4001-b450-9917afc23482 -->
- [x] 2.4 Write and pass an adjacency test asserting each neighboring surface pair differs by the documented luminance step and is additionally separated by a border or shadow, in both brightness modes; verify the failure message names the pair that regressed. <!-- comet-task:ef6e1e68-8348-4a77-a559-c7abed40f363 -->
- [x] 2.5 Add a contrast test asserting caption and secondary text reach 4.5:1 and headings 3:1 against their own surface, switching caption colors to `colorScheme.onSurfaceVariant` where they fall short; verify it passes in both modes. <!-- comet-task:e6ebb1bf-784c-4e19-9e7e-05951f27925e -->

## 3. Type scale and status card

- [x] 3.1 Write failing tests asserting the page exposes the documented hierarchy levels (screen title, status headline, status caption, section title, item title) with distinct sizes or weights; verify RED. <!-- comet-task:bd63570d-e6ea-4c00-baff-4788432e75a1 -->
- [x] 3.2 Apply the six type-scale constants from design D7 to the app bar, status card, section header and item titles, keeping `GoogleFonts.notoSansSc` as the effective family; verify task 3.1 goes GREEN. <!-- comet-task:7516940c-5b19-4cf1-9a2d-7b8d0d880ce7 -->
- [x] 3.3 Restyle the status card for both states — resting card role when idle, accent gradient with readable white text plus the animated progress bar when in progress; verify a test asserts the headline reads "正在接水中" with the progress indicator present only while `isDrinking` is true. <!-- comet-task:6fcacfe2-e321-490c-884d-c6e2cb14b98b -->

## 4. Device tiles

- [x] 4.1 Write failing tests for the selected versus resting tile in both list and grid layouts, asserting selection changes fill, border and check marker together and remains distinguishable in grayscale; verify RED. <!-- comet-task:77d9605e-fde1-4df3-9dea-6b00ec15bf3a -->
- [x] 4.2 Apply the tile tokens to `_buildCompactDeviceItem` and `_buildGridDeviceItem`; verify task 4.1 goes GREEN in both layouts and both brightness modes. <!-- comet-task:90de78f2-39a3-4286-bf25-778e95ccd1e6 -->
- [x] 4.3 Capture the current touch-target boxes (note-edit chip 26×26, row height, toolbar icon buttons) as an explicit minimum in a test, then restyle the tiles and verify every measured box is greater than or equal to the recorded baseline. <!-- comet-task:cda30d7b-0c49-4247-aee8-94f36e8701ed -->
- [x] 4.4 Restyle the empty-device card and the reorder-mode surface and hint row, keeping the drag handles, `ReorderableListView` behavior and the current selection after leaving reorder mode; verify tests assert both the empty-state scan action and a completed reorder round-trip. <!-- comet-task:e69b2724-46f2-479e-a399-538ad0f6e4ca -->

## 5. Primary action

- [x] 5.1 Write failing tests asserting the primary action is the visually dominant control, that it renders the brand gradient when a device is selected, and that `FilledButton.onPressed` is null with the flat inactive wrapper when the list is empty or nothing is selected; verify RED. <!-- comet-task:6a59640a-38d5-43d6-a7e1-d6b266820c1e -->
- [x] 5.2 Implement the gradient-painted `FilledButton` wrapper from design D5 (height 64, radius 24, glow shadow when enabled, flat neutral fill when disabled) for both the 开始接水 and 结算 states; verify task 5.1 goes GREEN and `fvm flutter analyze` reports no new issues. <!-- comet-task:9a06c5cd-95d9-4178-aeeb-66355c7418cc -->
- [x] 5.3 Verify with a test that tapping the primary action still calls `startDrinking` when enabled and does nothing when disabled, and that the in-progress label switches to 结算 with the stop icon; confirm no controller logic changed. <!-- comet-task:84611d6b-12b8-4eab-af39-57720f7b823a -->
- [x] 5.4 Implement the compact padding branch from design D10 so the page satisfies "Page stays usable at small sizes and large text scale"; verify with a 320×568 pump at textScale 1.3 asserting `tester.takeException()` is null and that the primary action, layout toggle and add-device entry are all reachable, written RED first. <!-- comet-task:cd77a452-ac8d-4b69-9b90-9433810f8fd2 -->

## 6. Sheets and dialogs

- [x] 6.1 Write a failing test that opens the device management sheet and asserts the grabber, title, per-row delete, add-device action and the same surface roles as the page; verify RED. <!-- comet-task:ef23fb9f-79b7-4cf2-b9d5-0fc9e4af7248 -->
- [x] 6.2 Apply the sheet tokens to the device management and settings sheets from design D8, keeping `showCupertinoModalBottomSheet`; verify task 6.1 goes GREEN and the settings sheet still exposes 关于 and 退出登录 with their icons. <!-- comet-task:8ca25930-8a90-47d0-925c-13b841c22c30 -->
- [x] 6.3 Bring the four dialogs (note edit, delete confirm, logout confirm, about) onto the shared type scale and icon chips; verify tests still reach delete confirmation and about-dialog GitHub link. <!-- comet-task:5538ed04-7998-4925-8632-13e4fcc50d7e -->

## 7. Integration and regression

- [x] 7.1 Run the interaction sweep required by the spec — refresh, settings, layout toggle, reorder, scan-add, select, edit note, start, settle, manage devices, delete, empty state — against the redesigned page and check off each item in this file only when its behavior matches the pre-change app; verify with a widget test per group where a test already exists. <!-- comet-task:9e5e684b-2ea4-4d6f-bce0-95248966a6b9 -->
- [x] 7.2 Run `fvm flutter test` and `fvm flutter analyze` for the whole project and verify every pre-existing test still passes, including `test/features/login/login_page_ui_test.dart` and `test/features/home/drink_failure_prompt_test.dart`. <!-- comet-task:5b2e5c22-529c-4f41-8551-560fabc3f81f -->
- [x] 7.3 Confirm the login and scanner pages are pixel-unchanged by checking that `lib/core/theme/app_theme.dart` global defaults were not modified and their tests still pass; verify with `git diff` on that file. <!-- comet-task:12d0b3cd-44ca-4fdc-9f1b-553739e2c4a6 -->
- [x] 7.4 Hand the on-device visual pass to the user with the exact run command (`fvm flutter run`) and the release-build commands, since automated tests cannot judge taste; the verification report itself is written in the Verify phase. <!-- comet-task:89020659-1c44-4b7b-bb0c-72735473a2ad -->

## 8. Round 2 — fixes returned by Verify

- [x] 8.1 Add a `backgroundBehind()` sampler that reads the painted idle gradient at each widget's own position, and re-point the resting-card and selected-card separation assertions at the surface the widget is actually drawn on; verify RED against the current dark palette. <!-- comet-task:7b6f4c97-d8ba-40f5-8c48-94a0945a8937 -->
- [x] 8.2 Re-tune the dark surface tokens (page, band, card, selected, tint, hairline) so every adjacent surface pair clears the 1.15 floor in dark mode; verify task 8.1 goes GREEN. <!-- comet-task:4bd924cf-93af-4e34-bce1-6d30df7aa555 -->
- [x] 8.3 Replace the tautological second-channel assertion (`border != null || boxShadow.isNotEmpty`, always true) with a measured channel count — fill step, resolvable border, real elevation — requiring at least two and never fill alone; verify GREEN. <!-- comet-task:6fb38240-f553-40ac-bf6c-cfbeadfa510b -->
- [x] 8.4 Write RED tests for the selection check marker and the note-edit chip, then make the marker fill mode-aware (dark uses the brand ink with a dark glyph) and move the chip onto the tint fill; verify GREEN. <!-- comet-task:5d89fc04-40de-4490-8c5c-e04e507d11f9 -->
- [x] 8.5 Write a RED test that the 拖动调整顺序 hint sits on a surface distinct from normal browsing with at least two channels, then implement the hint chip; verify GREEN. <!-- comet-task:7106d70b-4cd0-4852-a3a4-9a3ad9cf4680 -->
- [x] 8.6 Clear `_reloadQueued` on the expired-session return so the next load does not fire a spurious extra fetch, and move the note dialog into a stateful widget so its `TextEditingController` is disposed; verify with a fetch-count test. <!-- comet-task:bac227c2-d709-4a37-b9c4-2d2edf9009e8 -->
- [x] 8.7 Add the missing coverage the spec asks for: grid layout at 320×568 with 1.3 text scale, the sheet barrier that covers the page behind it, and a grayscale-rendering selection assertion; run the full suite and `fvm flutter analyze`. <!-- comet-task:7fd463ee-f3a7-47a7-8b02-48fd436951b4 -->

## 9. Round 3 — returned by the final integration review

- [x] 9.1 Tokenize the four dialog `TextButton` labels (delete 取消, about 确定, logout 取消, note 取消) onto the page's brand ink, and add a test that measures every text button and dialog action label against the surface it actually sits on in both modes; verify RED at 3.12:1. <!-- comet-task:0424bbad-47ff-46c7-ba89-21af6891c810 -->
- [x] 9.2 Deepen the light hairline until the border channel measures at least 1.15 against the white card, the page base and the brand band, so light separation no longer leans entirely on a 7%-alpha shadow; verify RED and that the dark hairline still clears its own floor. <!-- comet-task:b16bf9d6-7943-4aac-a0a9-ff1223c2fb57 -->
- [x] 9.3 Give the note-dialog text field a real second channel — a border resolvable against its own fill — and assert it measured against the dialog face rather than the page gradient; verify RED at 1.099. <!-- comet-task:82faa4f8-31c6-49d0-92dc-d85b84b3608e -->
- [x] 9.4 Cover Requirement 4's in-card progress clause: assert the `LinearProgressIndicator` is present while a session is in progress and absent when idle. This is a coverage guard, not an observed RED, and must be disclosed as such. <!-- comet-task:7578180f-b2f6-41e1-948f-860feae0217b -->
- [x] 9.5 Cover Requirement 1's bottom-region clause: assert the idle gradient's terminal stop equals the `Scaffold` background colour so no hard edge appears above the safe area, in both modes. Coverage guard; disclose. <!-- comet-task:a37b7fd7-d879-4c38-87d9-1840ea47afff -->
- [x] 9.6 Amend the delta spec's secondary-text clause so it constrains the role and the 4.5 floor instead of naming a global theme token, record the measured reason (`onSurfaceVariant` = `black54` = 4.44 on the new base) in the design doc, correct the inaccurate round-2 claim that the in-card progress indicator was already tested, and refresh the design handoff. <!-- comet-task:cf8cffbe-ccdc-42d3-841b-db7d57e008c4 -->
- [x] 9.7 Replace assertions that pass for the wrong reason: headline dominance must be measured by size/weight instead of contrast ratio, small-screen "reachable" must check the rect lies inside the viewport and actually tap the layout toggle and add-device entry, and the reorder pill must be measured in dark mode too. <!-- comet-task:2f7b5c2f-b4b5-4c26-9c7d-2a57864abfce -->
- [x] 9.8 Correct the stale numbers recorded in D4 and D7 and state D7's real assumption about border layout height, so the design record matches what is built. <!-- comet-task:9ee2546f-9f1c-4689-ace0-9e9f6674a10e -->

## 10. Round 4 — coverage the closing check still owed

- [x] 10.1 Assert the elevated surfaces separate from the page in light mode as well as dark — the device-management sheet, the settings sheet and the dialog faces. `channelsOf` only understands `BoxDecoration`, so give Material-painted surfaces their own measurement. Disclose honestly whether this is an observed RED or a guard that passed on first write. <!-- comet-task:6612bd7c-2359-4426-92a3-9adce57fd136 -->
- [x] 10.2 Correct the recorded grabber figure to the measured 1.214 light / 1.390 dark, and write down the two limits the closing check named: the leading icon chip and the in-progress status chip are single-channel elements that are not one of Requirement 2's four named surface roles, and Requirement 3 is verified on enumerated pairs rather than a whole-tree text sweep. <!-- comet-task:cab1ad11-a533-4876-b880-4de2c2c4bf32 -->

## 11. Round 5 — prompts (scope extension authorised by the user)

- [x] 11.1 Write failing tests for the prompts the home screen raises — expired session (warning), a failed operation (error), a successful one (`开始接水`) — asserting each face is fully opaque and its label clears 4.5:1 in **both** colour schemes, that the three kinds keep distinct hues on genuinely coloured faces (chroma floor, so three greys cannot pass a hue-distance check by accident) and that a neutral notice face stays achromatic; verify RED against `Colors.orange` / `Colors.red` / `Colors.green`. <!-- comet-task:768b34b4-b3bc-4ba3-8bd9-68a6e625fb78 -->
- [x] 11.2 Move those prompts onto the page's own amber / red / green roles via a shared holder so `HomePage` and `HomeController` cannot drift, without changing any prompt's text, title, position or duration. Measuring them surfaced four more sites that set no face at all — `toggleReorderMode`, `selectDevice`, the no-selection guard, and the note-save prompt raised from the page's own dialog — each inheriting GetX's `Colors.grey.withOpacity(0.2)` face and a theme-resolved ink, so all four now declare a face and a label from the same holder (neutral for the blocking notices, `success` for the saved note). Verify task 11.1 goes GREEN and the full suite plus `fvm flutter analyze --no-pub` pass. <!-- comet-task:0fd0910f-af23-4d02-a346-18242e42b8f4 -->
- [x] 11.3 Record the extension in `design.md` (the numbers, the shared-holder decision, and why the theme file stays untouched) so the archived spec, design and code agree. <!-- comet-task:fea080e7-1b1c-482c-bb09-7925b0563afc -->

## 12. Round 6 — make the claims the suite actually makes (final integration review)

No product behaviour change; this round is assertions, comments and records.

- [x] 12.1 Assert the two Requirement 3 / Requirement 6 clauses that had no test behind them: that de-emphasized text resolves through **one** named role per surface rather than an opacity chosen at each call site, and that the device-management sheet's rows carry name plus note-or-id while the settings sheet's 关于 and 退出登录 each carry their icon. <!-- comet-task:0ff55bee-b690-4af9-bb16-073bf4514215 -->
- [x] 12.2 Measure the idle secondary-label and the tint-chip-glyph floors in the dark scheme as well, so the "verified in both brightness modes" claim in the design record matches what the suite runs. State honestly whether this is an observed RED or a coverage guard that passed on first write. <!-- comet-task:1521f488-5eb5-41f9-abbb-2ac8c81c172f -->
- [x] 12.3 Correct the numbers that live in permanent artefacts: `Colors.red` on the white card is 3.68 not 3.72 (one code comment, one test reason string), the replaced light hairline is α.18 not α.24 with measured steps 1.133 / 1.099 / 1.079, and the grabber sits 1.214 above the sheet face, not 1.24, in both copies of that comment. Aim the stale settle-fill guard at the colour the pre-change page actually used. <!-- comet-task:f9efece3-8659-4d03-b450-480be649aff3 -->
- [x] 12.4 Make the records agree with the code: replace the "no state or request change" claim in proposal.md and design.md with the load-coalescing that was in fact added (already disclosed in the Build amendments table), correct the dialog count from five to four, register the round-5 spec patch in the Spec Patches ledger, and repair the figures the integration review could not reproduce (ink pairs, the note-field border, the reorder pill's fill steps, the pre-fix caption range and the touch-target baseline). <!-- comet-task:89def7b0-d821-4e88-817d-f5794baaa82b -->

## 13. Round 7 — the whole-change review's fix-list (same scope, records and assertions)

Prompted by the final integration review over `88167ac..590d08b`, which found no behaviour, boundary or contrast defect but six records/assertion items. Each figure below was re-derived with the suite's own math before being changed.

- [x] 13.1 Correct the D3 surface-role table to the tokens that actually ship: the dark page / card / selected values are the round-2 re-tune (`#0A0F14` / `#1E2934` / `#283645`), the selected border is the brand ink rather than `#2196F3` (which the code comments themselves reject at 2.66), and the adjacency figures become the shipped 1.303 / 1.198 rather than the 1.154 / 1.193 that only reproduce on the superseded stack. Round 6 applied exactly this rule to D4 and left D3 alone. <!-- comet-task:995883e6-8f0e-4e95-9a24-76fb8e2fb3bf -->
- [x] 13.2 Fix the wrong figures at their remaining sites: the sheet's separation from the old global background is **1.111** (`#F5F9FF` against `#E4EEF8`), not 1.06 — in the sheet comment, the test reason string and the plan line that cites it; the reorder pill's own comment must carry the measured 3.51 / 4.09 / 4.80 instead of 4.4 / 4.6; and a black shadow at α 0.07 leaves a **1.171** mark, not 1.062, which is why the α ≥ 0.12 gate is the operative one. <!-- comet-task:53cbb97e-e1a6-4e68-9632-de45f0c891b1 -->
- [x] 13.3 Close the two assertion gaps: Requirement 4's *Device selected* scenario names the play icon and nothing asserts it, and `sizes.length >= 4` cannot fail because the five font sizes are pinned item by item three lines above it. Add the icon assertion; drop the redundant one. <!-- comet-task:f75c9ca3-9a17-4027-8f6d-45a26948fca9 -->
- [x] 13.4 Record the points where changing the code would cost more than the risk it removes: the in-progress chip's fill step (now the corrected 1.348, computed from the tokens and asserted by no test) and the P2 ledger wording, the `版本: 1.0.4` anchor two tests share with a recorded out-of-scope defect, and the `dialogMaterial.last` lookup's failure mode. <!-- comet-task:39f70d2a-1178-47cd-8b44-896abb50b329 -->
