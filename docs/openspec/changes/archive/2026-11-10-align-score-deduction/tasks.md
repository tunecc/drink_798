# Tasks

## 1. Score-deduction switch API

- [x] 1.1 Add `setUseScore` to `DrinkApiService`: `POST acc/upt` with JSON body `{"useScore":1}`, `Content-Type: application/json`, `Authorization` header only; no `sign` parameter, no `ApplicationType` header. Verify: request-shape test in `test/core/services/drink_api_service_request_test.dart` asserting method, path, body and headers, including the absence of `sign` and `ApplicationType`. <!-- comet-task:1411c31a-2aa0-4260-8742-49faf38509af -->

## 2. Controller wiring

- [x] 2.1 In `HomeController.startDrinking`, call the switch sync after the device precheck and before the single start request; on any sync failure show the dedicated prompt and abort without sending `dev/start`; leave the adopt/takeover path and the settlement flow untouched. Verify: controller tests with the fake service covering success ordering (sync completes, then start), failure abort on a network error and on a server rejection (no start request sent), and no sync on the adoption path. <!-- comet-task:a38616c5-636f-4b58-82f8-76e507e6c890 -->

## 3. Regression and device verification

- [x] 3.1 Run the full test suite and confirm no regressions. Verify: `fvm flutter test` exits 0 with the new tests included. <!-- comet-task:78732593-6827-432d-b4e7-bb044be0a094 -->
- [x] 3.2 Real-device verification of the deduction chain. Verify: with score > 0, a started session ends with a bill carrying `promo.type=4`/`discount`, the score balance decreases, the wallet/Alipay part covers only the remainder, and the account name/avatar are unchanged after the sync (upt body safety). <!-- comet-task:7abe0898-474d-49a8-99ac-b81d0c25149a -->
