# Spec Delta: account-balance

## Purpose

Defines how the app makes the user's wallet balance and score balance visible: fetching the two account balances, displaying them on the home page, and keeping them current after settlements, so the user can see the funds the payment cascade draws from before and after each session.

## ADDED Requirements

### Requirement: Home page shows wallet and score balances

When the user is logged in, the home page SHALL display the account's wallet balance (as CNY) and the score balance (as points, using the server's valid-score value). The balances SHALL be fetched with the account's existing credentials from the wallet-owner and account-score endpoints, and the display SHALL follow the home page's existing visual rules for surfaces, hierarchy and contrast. When the user is not logged in, the home page SHALL NOT show balance values.

#### Scenario: Balances shown for a logged-in user

- **WHEN** a logged-in user opens the home page and both balance queries succeed
- **THEN** the home page shows the wallet balance in yuan and the valid score balance in points

#### Scenario: Not logged in

- **WHEN** no valid login exists
- **THEN** the home page shows no balance values and does not send balance requests

#### Scenario: Balance query fails

- **WHEN** a balance query fails or returns an unparseable response while the user is logged in
- **THEN** the balance section degrades gracefully (placeholder instead of a number, with no error dialog interrupting the user), and the rest of the home page keeps working

### Requirement: Balances refresh after settlement

After a session's settlement completes, the system SHALL re-fetch both balances so the displayed values reflect the deduction that settlement caused.

#### Scenario: Balances update after a session ends

- **WHEN** a water session settles (manually or by idle detection) and the bill is reported
- **THEN** the displayed wallet and score balances are refreshed to match the server state

#### Scenario: Refresh failure after settlement

- **WHEN** the post-settlement balance refresh fails
- **THEN** the previously displayed values remain, with no error dialog interrupting the user
