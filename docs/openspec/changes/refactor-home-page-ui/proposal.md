# Proposal

## Why

The home page is the screen users live on, yet in its idle state it renders as one flat gray field: the background `AnimatedContainer` builds a `LinearGradient` whose two colors are both `Theme.of(context).scaffoldBackgroundColor` (`#F5F9FF`) when `isDrinking` is false, so the advertised gradient collapses to a single swatch, and the white `cardColor` sitting on it differs by about 2% luminance. Cards therefore never separate from the page, the 64px "开始接水" button reads as a flat rectangle, and the whole screen looks unfinished next to the login page, which now carries a light body plus a brand-gradient header anchor.

## What Changes

- The idle background gains a real visual anchor: a brand-gradient header band that fades smoothly into the light body, reusing the pattern the login page settled on instead of a two-stop no-op gradient.
- Surface roles are separated into measurable steps — page background, resting card, selected card, elevated sheet — so elevation no longer depends on a 2% color difference. Each step is also separated by border or shadow, never by fill alone.
- Type scale gains distinct levels: screen title, status headline, status caption, section title, item title, secondary action. Secondary text resolves through one named de-emphasized foreground role for its surface instead of an opacity applied at each call site, and still clears the 4.5:1 floor — which is why that role is a page-local step rather than `onSurfaceVariant`, measured at 4.44 on the new page base.
- The primary action becomes a proper focal button with an explicit disabled state, replacing the current `Colors.grey[300]` fallback that looks like an enabled control.
- Device items express selected / resting / dragging / editing through fill, border and check mark together, while tap and long-press targets do not shrink.
- The home page's own bottom sheets (device management, settings) and dialogs are brought onto the same surface and type scale as the body.
- Dark mode is adapted to the same hierarchy rules — it must stay usable because `themeMode: ThemeMode.system` makes it the default for dark-scheme devices.
- To make the above checkable from the widget tree, `HomeController` gains an optional injected `DrinkApiService` constructor parameter, matching the seam `LoginController` already has. `HomePage` registers `Get.put(HomeController())` with no argument, so production behavior and the singleton stay unchanged.
- No flow is removed or reordered: the app bar entries, the status card, the list/grid toggle, the reorder mode, device selection and long-press note editing, the start/settle button, the two bottom entries, both sheets and all five dialogs keep their current behavior.

## Capabilities

### New Capabilities

- `home-page-ui`: the visual contract of the water-fetching home page — idle background anchoring, surface role separation and minimum contrast, type scale levels, primary action affordance including its disabled state, device item state expression, and the requirement that every existing interaction stays reachable.

### Modified Capabilities

None. `login-page-ui` covers the login page only and no requirement in it changes; `drink-api-signing` covers request signing and is untouched.

## Impact

- Code: `lib/features/home/home_page.dart` (layout, coloring and type scale rewritten; the widget keeps its name and route position), `lib/features/home/home_controller.dart` (optional constructor injection only, no state or request change), and page-private color/radius/spacing constants.
- Shared theme: `lib/core/theme/app_theme.dart` gains named constants for the new surface roles if needed; the global `scaffoldBackgroundColor`, `cardColor` and button defaults are **not** changed, so the login and scanner pages keep their current appearance.
- Untouched: `DrinkApiService`, the Dio layer, `login_page.dart`, `scanner_page.dart`, and every server interaction.
- Tests: new home page widget tests driving the redesigned surface through a fake service and asserting each spec scenario. Existing tests must keep passing, including `test/features/home/drink_failure_prompt_test.dart` and the login UI tests.
- Verification: `fvm flutter test` plus `fvm flutter analyze`; on-device visual confirmation stays with the user, who runs the app locally.
