# Proposal: align-payment-settlement

## Why

The 慧生活798 server settles each water session with a fixed cascade — score deduction first, then wallet gift credit, then wallet balance, and only the remainder via Alipay — whenever the client starts the session with wallet payment (`ptype=91`). drink_798 already sends `ptype=91`, but (1) it shows none of the resulting bill, so users cannot see score deductions that already happen, and (2) when the wallet payment is rejected for any reason, `HomeController.startDrinking` silently retries with Alipay password-free payment (`ptype=21`), which charges the user's Alipay for the full amount and bypasses the score/wallet cascade entirely. The sibling third-party client (life-798 / WaterWidget, same gateway) relies on the cascade and surfaces the bill breakdown; this change brings drink_798 to the same behavior.

## What Changes

- Remove the silent `ptype=91 → ptype=21` fallback in `HomeController.startDrinking`. A wallet-payment rejection now surfaces the server's reason instead of switching payment method.
- Map known server rejection codes to actionable prompts: `-52` account arrears, `-82` payment required, `-88` no Alipay withholding agreement signed, `-87` withholding agreement expired. `-99` (session expired) keeps the existing re-login flow; other codes keep passing the server message through.
- After a session ends (manual settle via `dev/end`, or the status poll detecting idle), fetch the settlement bill (`type=91`, `status=3`, `cata=6`) and show a per-session consumption summary: total, score-discount part (`promo.type=4` → `discount`), and the wallet-paid part. A short poll tolerates settlement latency, matching the reference implementation's approach.
- Add wallet balance (`/acc/wallet/owner`) and score balance (`/acc/score/acc-score`) fetching, and display both on the home page; refresh after a settlement.
- No change to the `dev/start` request shape: `ptype` stays `91`. No score missions/check-in, no recharge/Alipay top-up flow, no signing changes.

## Capabilities

### New Capabilities

- `payment-settlement`: How a water session is paid for and reported — wallet-first payment type, no silent payment-method fallback, server rejection reasons surfaced in Chinese prompts, and per-session consumption reporting with the score-discount breakdown.
- `account-balance`: Wallet and score balance visibility — fetching and parsing the two balance endpoints, displaying them on the home page, and refreshing them after settlement.

### Modified Capabilities

<!-- none: drink-api-signing, home-page-ui and login-page-ui requirements are unchanged.
     New home-page UI for balances must follow home-page-ui rules but does not alter them. -->

## Impact

- `lib/core/services/drink_api_service.dart`: new bill-query, wallet-balance and score-balance methods plus response models/parsers.
- `lib/core/models/`: new models for settlement bill/consumption and account balances.
- `lib/features/home/home_controller.dart`: remove fallback, add error-code mapping, post-settlement bill fetch and balance state.
- `lib/features/home/home_page.dart`: balance display section (must follow `home-page-ui` visual rules).
- Tests: `drink_api_service_request_test.dart` and controller tests extended for the new endpoints and the no-fallback behavior.
- Real-device verification required: whether the token held by this app (sent without an `ApplicationType` header) is accepted by `/acc/wallet/owner` and `/acc/score/acc-score`; the reference client sends those with `ApplicationType: 1,1`. If rejected, the fallback plan is decided in design/build, not by scope expansion here.
- Verified reference behavior: score deduction is recorded in bill details as `promo.type=4` / `discount`, bills are `type=91` / `status=3` / `cata=6`, wallet parts are in `payment`; score stream entries are `type=107` with `spend`.
