# Proposal: align-score-deduction

## Why

drink_798 already starts every session with the wallet payment type (`ptype=91`), but users report that score deduction never happens: sessions are paid entirely from the wallet (or Alipay) while the score balance stays untouched. Investigation across three independent sources — the official iOS 3.1.9 binary (reverse-engineered from `慧生活798_3.1.9.ipa`), the ilife798 KMP reference client, and the life-798 (WaterWidget) reference client — shows the server cascade (score → wallet gift → wallet balance → Alipay) is **not** triggered by `ptype=91` alone: it also requires the account-level score-deduction switch `useScore` to be on, which the client must sync via `POST acc/upt {"useScore":1}`. The official app exposes this as the 「开启自动抵扣」 toggle on its device payment page; ilife798 re-syncs the switch before every device start and documents that the cascade fires from `useScore=1` + `ptype=91` together; life-798 never syncs it and only works because its account flag was already set elsewhere. drink_798 has never sent `acc/upt`, so whenever the account flag is off the server skips score deduction entirely — which is exactly the reported behavior.

## What Changes

- Add a `setUseScore` API method: `POST acc/upt` with JSON body `{"useScore":1}`, Authorization header only — no signature (matching the unsigned treatment of every non-login request) and no `ApplicationType` header (the official iOS binary does not contain that string, and the existing spec forbids sending it).
- Sync the switch automatically before every wallet-paid session start in `HomeController.startDrinking` (`useScore=1`, per the user-confirmed scope: always-on, no in-app toggle UI). The adopt/takeover path that does not send a start request stays unchanged.
- On the server-rejection side nothing changes: `ptype=91` remains the only start type, no fallback is introduced, and existing rejection prompts (-52/-82/-87/-88/-99) are untouched.
- No changes to `dev/start` request shape, signing rules, or balance/bill endpoints.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `payment-settlement`: add the requirement that a wallet-paid session start is preceded by syncing the server-side score-deduction switch (`acc/upt` with `useScore=1`), and make explicit that the settlement cascade applies score deduction only when that switch is on. Existing requirements (wallet-payment only, no fallback, rejection prompts, bill reporting) are unchanged.

## Impact

- `lib/core/services/drink_api_service.dart`: new `setUseScore` method (POST with JSON body — the service already uses this shape for `acc/login` and `acc/login/code`).
- `lib/features/home/home_controller.dart`: one sync call inserted before the single start request.
- Tests: request-shape tests for the new endpoint and controller tests for the sync-before-start ordering and failure handling.
- Real-device verification: after the change, a session's settlement bill carries `promo.type=4` / `discount` and the score balance decreases — the pre-existing bill-parsing and balance-display code then reports the deduction without modification.
- Design decisions deferred to `design.md`: behavior when the switch sync fails (abort vs warn-and-continue), and rate-limit (-98) handling for `acc/upt`.
