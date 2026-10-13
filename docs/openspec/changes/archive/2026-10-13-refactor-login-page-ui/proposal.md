# Proposal

## Why

The login page is the app's only entry screen, yet three defects make it look unfinished: the captcha image stretches across the whole row at a fixed 80px height and draws more attention than the input field itself, forcing the eye to scan up and down; the captcha input field never sets `keyboardType`, so tapping it raises the full QWERTY keyboard even though the code is digits-only; and the background gradient uses `stops: [0.0, 0.4]`, which turns everything below 40% of the screen into flat `#0099CC`, exposing a dark blue band through the card's top rounded corners and the bottom safe area that clashes with the card's light `#F5F9FF` fill.

## What Changes

- The captcha image moves from a full-width block to an inline slot on the same row as its input field, sized to match the field height. Tapping the image refreshes it, which removes the need for the separate "看不清？点击刷新" text button.
- The captcha input field switches to a numeric keyboard and accepts digits only.
- The page background becomes a clean light surface: no dark blue band at the bottom, with a smooth brand-gradient tint retained only as a header anchor at the top.
- The page-private `_buildTextField` and `_buildInputLabel` helpers are extracted into reusable widgets under `lib/core/widgets/`.
- The Token login entry is demoted from a button inside the phone form to a de-emphasized text link at the bottom of the page. **Token login behavior itself is unchanged** — pasting a valid token still logs in and still shows the device list.
- No login flow is removed: phone number + captcha → SMS code → login stays exactly as it is.

## Capabilities

### New Capabilities

- `login-page-ui`: the visual structure and input-interaction contract of the login page — captcha inline placement and size ceiling, captcha keyboard type, page background coloring rules, and reachability of the Token login entry.

### Modified Capabilities

None. The existing `drink-api-signing` capability covers device-endpoint signing only, and no requirement in it changes.

## Impact

- Code: `lib/features/login/login_page.dart` (layout and coloring rewritten), new reusable input widgets under `lib/core/widgets/`, and login-local color constants.
- Untouched: the login/captcha flow in `lib/features/login/login_controller.dart`, `lib/core/services/drink_api_service.dart`, the Dio layer, and `lib/features/home/home_page.dart`.
- Tests: new login page widget tests covering keyboard type, captcha inline layout, absence of the dark blue bottom band, and Token entry reachability. The existing 6 Dart test files must keep passing.
- Dependencies and build: no new pub dependencies.
