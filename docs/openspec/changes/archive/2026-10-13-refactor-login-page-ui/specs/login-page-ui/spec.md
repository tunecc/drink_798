# Spec Delta

## Purpose

Defines the visual structure and input-interaction contract of the login page: captcha placement and size ceiling, captcha keyboard type, page background coloring, and reachability of the Token login entry, so the page stays consistent and verifiable in information hierarchy and input efficiency.

## ADDED Requirements

### Requirement: Captcha image and input field stay adjacent on one row

The system SHALL place the captcha image and its input field in adjacent positions on the same row, and the displayed captcha image height MUST NOT exceed the height of the input field on that row.

#### Scenario: First screen shows phone number and captcha

- **WHEN** the user opens the login page and no SMS code has been requested yet
- **THEN** the captcha image and the captcha input field appear on the same row, the image on one side of the field
- **AND** the displayed image height does not exceed the height of the input field beside it

#### Scenario: Tapping the image refreshes the captcha

- **WHEN** the user taps the captcha image
- **THEN** the system requests a new captcha from the server and replaces the image in place
- **AND** no separate "看不清？点击刷新" text button remains outside the image

#### Scenario: Capt image not yet returned

- **WHEN** the captcha request is still in flight and no image is available
- **THEN** the image slot shows a loading indicator inside its own bounds instead of expanding into a full-width blank block

### Requirement: Captcha input uses a numeric keyboard

The system SHALL present a numeric input keyboard when the captcha input field gains focus, and SHALL accept digit characters only.

#### Scenario: Capt field gains focus

- **WHEN** the user taps the captcha input field
- **THEN** the raised keyboard type is a numeric keyboard rather than the default full keyboard

#### Scenario: Non-digit characters are entered

- **WHEN** the user tries to put a non-digit character into the captcha input field
- **THEN** the non-digit character does not become part of the field value

### Requirement: No dark band at the bottom of the page

The login page SHALL use a light color as its main background, and the coloring of the bottom region — including the bottom safe area occupied by the gesture bar — MUST match the main body so no abrupt color boundary appears.

#### Scenario: Inspecting the bottom of the page

- **WHEN** the user views any screen of the login page in light mode
- **THEN** no dark blue-teal flat region that clearly differs from the body background appears at the bottom of the screen
- **AND** the bottom safe area is colored the same as the page body

#### Scenario: Content shorter than one screen

- **WHEN** the login form is shorter than the visible viewport
- **THEN** the uncovered area below the form still shows the light body background and exposes no dark under-layer

### Requirement: Brand gradient survives as a smooth top tint

The login page SHALL keep a brand-colored gradient at the top as a visual anchor, and that gradient MUST fade smoothly into the light body background without a hard edge.

#### Scenario: Inspecting the top of the page

- **WHEN** the user opens the login page in light mode
- **THEN** the header area carries a brand-colored gradient with the title and subtitle clearly readable on it
- **AND** the color at the end of the gradient equals the light body background, leaving no visible dividing line

### Requirement: Token login entry stays reachable

The login page SHALL keep a Token login entry with lower visual weight than the primary form, and Token login behavior MUST remain as it is today.

#### Scenario: Opening Token login from the primary form

- **WHEN** the user taps the Token login entry at the bottom of the page
- **THEN** the page switches to the token input form and offers a way back to phone-number login

#### Scenario: Token login still works

- **WHEN** the user pastes a token the server accepts and completes login
- **THEN** the user reaches the home page and can see the device list as before

#### Scenario: Token is rejected

- **WHEN** the pasted token is not accepted by the server
- **THEN** the system reports the failure and does not persist that token

### Requirement: Three-step login flow is unchanged

The system SHALL preserve the existing "phone number and captcha → SMS code → login" flow and its states; the visual rewrite must not remove any operation the user could complete before.

#### Scenario: Completing an SMS login

- **WHEN** the user enters a phone number and correct captcha, receives an SMS code, and submits the correct code
- **THEN** login succeeds and the user lands on the home page

#### Scenario: Returning from the SMS code step

- **WHEN** the user taps back while on the SMS code step
- **THEN** the page returns to the phone number and captcha step and the system fetches a fresh captcha image

#### Scenario: Capt is rejected

- **WHEN** the submitted captcha is rejected by the server
- **THEN** the system surfaces the server's failure reason and automatically replaces the captcha image

### Requirement: Form controls look consistent

The login page SHALL give every input control on the page the same corner radius, height rhythm, and focus feedback, and they must stay readable in both light and dark mode.

#### Scenario: Several fields on one page

- **WHEN** the login page renders its labels and input fields (phone number, captcha, SMS code, token)
- **THEN** they share the same corner radius, content padding, and focused-border behavior

#### Scenario: Dark mode

- **WHEN** the device is in dark mode
- **THEN** the login page's text, input fields, and buttons keep a readable contrast and expose no dark block that would only suit light mode
