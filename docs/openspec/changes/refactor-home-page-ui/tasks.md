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
- [x] 6.3 Bring the five dialogs (note edit, delete confirm, logout confirm, about, plus the reorder exit path) onto the shared type scale and icon chips; verify tests still reach delete confirmation and about-dialog GitHub link. <!-- comet-task:5538ed04-7998-4925-8632-13e4fcc50d7e -->

## 7. Integration and regression

- [x] 7.1 Run the interaction sweep required by the spec — refresh, settings, layout toggle, reorder, scan-add, select, edit note, start, settle, manage devices, delete, empty state — against the redesigned page and check off each item in this file only when its behavior matches the pre-change app; verify with a widget test per group where a test already exists. <!-- comet-task:9e5e684b-2ea4-4d6f-bce0-95248966a6b9 -->
- [x] 7.2 Run `fvm flutter test` and `fvm flutter analyze` for the whole project and verify every pre-existing test still passes, including `test/features/login/login_page_ui_test.dart` and `test/features/home/drink_failure_prompt_test.dart`. <!-- comet-task:5b2e5c22-529c-4f41-8551-560fabc3f81f -->
- [x] 7.3 Confirm the login and scanner pages are pixel-unchanged by checking that `lib/core/theme/app_theme.dart` global defaults were not modified and their tests still pass; verify with `git diff` on that file. <!-- comet-task:12d0b3cd-44ca-4fdc-9f1b-553739e2c4a6 -->
- [x] 7.4 Hand the on-device visual pass to the user with the exact run command (`fvm flutter run`) and the release-build commands, since automated tests cannot judge taste; the verification report itself is written in the Verify phase. <!-- comet-task:89020659-1c44-4b7b-bb0c-72735473a2ad -->
