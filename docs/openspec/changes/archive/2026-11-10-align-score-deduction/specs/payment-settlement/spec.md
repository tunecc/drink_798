# Spec Delta: payment-settlement

## ADDED Requirements

### Requirement: Wallet-paid starts sync the score-deduction switch first

The system SHALL enable the account-level score-deduction switch (`acc/upt` with `useScore=1`) before every wallet-paid session start, so the server settlement cascade deducts score first (it applies score only while this switch is on). When the sync fails — network error or server rejection — the system SHALL NOT send that start request and SHALL surface a dedicated failure prompt. The sync SHALL be sent only when a start request is about to be sent; the adopt/takeover path SHALL NOT send it.

#### Scenario: Switch sync precedes every wallet-paid start

- **WHEN** the user starts a session on an available device
- **THEN** the switch-sync request completes before the start request is sent, and the start request still uses the wallet payment type with no other request in between

#### Scenario: Failed switch sync blocks the start

- **WHEN** the switch-sync request fails with a network error or a server rejection
- **THEN** no start request is sent for that attempt, and the user sees a dedicated failure prompt explaining the session was not started

#### Scenario: Adopted session does not re-sync

- **WHEN** the device is already running and the app adopts the session without sending a start request
- **THEN** no switch-sync request is sent for that adoption

### Requirement: Switch-sync request carries no signature or branding

The switch-sync request (`acc/upt`) SHALL NOT carry a `sign` parameter and SHALL NOT carry an `ApplicationType` header, consistent with every other non-login request of the app.

#### Scenario: Sync request shape stays unsigned and unbranded

- **WHEN** the system constructs the switch-sync request
- **THEN** the request carries no `sign` parameter and no `ApplicationType` header
