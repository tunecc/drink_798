# payment-settlement Specification

## Purpose
Defines how a water session is paid for and reported: the payment type used to start a session, what happens when the server rejects the payment, and how the finished session's consumption (including score deductions) is reported to the user. The platform server settles each session with a fixed cascade — score deduction, then wallet gift credit, then wallet balance, then Alipay for any remainder — so the client's job is to request wallet payment and make the server's settlement visible, never to silently switch payment methods.

## Requirements

### Requirement: Session start uses wallet payment without payment-method fallback

The system SHALL start a water session with the wallet payment type (`ptype=91`) and MUST NOT automatically retry the start request with a different payment type when the server rejects it. Before starting, the system SHALL keep its existing device precheck behavior: offline and disabled devices are blocked with a dedicated prompt, and a device already in use is adopted into the settle-able state without re-sending the start request.

#### Scenario: Start succeeds with wallet payment

- **WHEN** the user starts a session on an available device and the server accepts the wallet-payment start request
- **THEN** the session starts, the app enters the in-session state, and no other payment request is sent

#### Scenario: Wallet payment rejected — no automatic Alipay retry

- **WHEN** the server rejects the wallet-payment start request with any non-authentication failure (for example account arrears or a payment requirement)
- **THEN** the system surfaces that rejection to the user and MUST NOT send a second start request with the Alipay password-free payment type

#### Scenario: Login expiry is not retried

- **WHEN** the server rejects the start request because the login session has expired
- **THEN** the system prompts re-login and does not send any further start request

### Requirement: Server payment rejections are surfaced with actionable prompts

The system SHALL translate known server rejection codes — `-52` account arrears, `-82` payment required, `-88` no Alipay withholding agreement signed, `-87` withholding agreement expired — into actionable Chinese prompts, and MUST treat each as terminal for that start attempt. For any other rejection code, the system SHALL show the server-provided message when present, and fall back to a generic failure prompt otherwise. Network-level failures keep their existing technical prompt.

#### Scenario: Account arrears blocks start without method switch

- **WHEN** a start request is rejected with code `-52`
- **THEN** the user sees the arrears prompt telling them to top up, and no Alipay payment request is sent

#### Scenario: Missing withholding agreement

- **WHEN** a start request is rejected with code `-88`
- **THEN** the user sees the prompt explaining that no Alipay withholding agreement is signed

#### Scenario: Unknown rejection passes server message through

- **WHEN** a start request is rejected with a code the system does not map and the server provides a message
- **THEN** the user sees the server's message

### Requirement: Finished session reports consumption with score-discount breakdown

After a water session ends — via manual settle or idle detection — the system SHALL fetch the session's settlement bill and report one summary with the total amount, the score-deducted part and the wallet-paid part. The score part SHALL come from the bill's promotion record (promotion type 4, `discount`), the wallet part from the bill's `payment` field, so a fully score-covered session is reported as such. The report SHALL use the home page's existing prompt styling.

#### Scenario: Consumption paid by score and wallet

- **WHEN** a finished session's bill records a score discount and a wallet payment
- **THEN** the summary shows the total consumption, the score-deducted amount, and the wallet-paid amount

#### Scenario: Session fully covered by score deduction

- **WHEN** a finished session's bill has a score discount and a zero `payment` field
- **THEN** the summary reports the consumption as fully covered by score deduction, with no wallet amount implied

#### Scenario: No charge for the session

- **WHEN** a finished session's bill records no payment and no score discount
- **THEN** the summary reports that the session produced no charge

### Requirement: Settlement bill lookup tolerates reporting latency

The system SHALL briefly re-query for the settlement bill when it is not queryable immediately after the session ends, and SHALL finish quietly without blocking the user when no bill appears within that re-query window.

#### Scenario: Bill is not yet available

- **WHEN** the settlement bill is not queryable immediately after the session ends
- **THEN** the system briefly re-queries for the bill and reports as soon as it appears

#### Scenario: Bill never becomes available

- **WHEN** the settlement bill does not appear within the short re-query window
- **THEN** the system finishes quietly without blocking the user and without reporting a wrong amount
