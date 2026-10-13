# Spec Delta

## Purpose

Defines the visual contract of the water-fetching home page — background anchoring, surface role separation, type scale, primary action affordance, device item states and dark-mode parity — so the page reads as a layered screen while every existing interaction stays reachable.

## ADDED Requirements

### Requirement: Idle page keeps a brand anchor in the background

When no water session is in progress, the home page background SHALL present a brand-derived gradient region that anchors the top of the screen and fades smoothly into the page body, and MUST NOT resolve to a single flat fill.

#### Scenario: Idle page top region

- **WHEN** the user is on the home page and no session is in progress
- **THEN** the top region carries a brand-colored gradient behind the app bar and status card
- **AND** the gradient end color equals the page body color, leaving no visible dividing line

#### Scenario: Idle page bottom region

- **WHEN** the user looks at the lower part of the idle home page, including the bottom safe area
- **THEN** that area shows the page body color rather than an uncovered under-layer
- **AND** no abrupt color boundary appears between the body and the safe area

#### Scenario: Session in progress keeps its own accent state

- **WHEN** the user starts a session and `isDrinking` becomes true
- **THEN** the page switches to its accent-colored in-progress treatment with the bubbles still animating
- **AND** the in-progress state remains distinguishable from the idle state at a glance

### Requirement: Adjacent surfaces stay separable

The home page SHALL use distinct surface roles for the page background, a resting card, a selected card and an elevated sheet. Any two surface roles that can appear adjacent on screen MUST be separable through at least two channels, where a fill step of at least 1.15:1 relative-luminance ratio, a distinct border and an elevation difference each count as one channel — a fill step alone never satisfies this requirement.

#### Scenario: Resting card on the page background

- **WHEN** the status card or a device item is drawn on the page background in light mode
- **THEN** the card fill differs from the page background by at least 1.15:1 and its edge is additionally marked by a border or an elevation shadow
- **AND** the card boundary is resolvable without reading its content

#### Scenario: Selected card differs from resting card

- **WHEN** the user selects a device while another device stays unselected on screen
- **THEN** at least two of the item's fill, border, elevation and check marker change together
- **AND** the selected item still meets the surface floor above against the page background, so selecting it does not merge it into the page
- **AND** the difference is still readable in a grayscale rendering

#### Scenario: Elevated sheet separates from the page

- **WHEN** a bottom sheet opens over the home page
- **THEN** the sheet surface is a distinct role from the page background and carries a grabber and a rounded top edge
- **AND** the page behind it is visibly dimmed or covered

### Requirement: Text keeps a legible hierarchy

The home page SHALL render text at no fewer than three distinct hierarchy levels; body and caption text MUST reach at least 4.5:1 contrast against the surface they sit on, headings MUST reach at least 3:1, and text drawn on an accent fill or gradient MUST reach 4.5:1 against the lightest point of that fill. Any prompt the page raises over itself MUST sit on its own opaque surface and clear the same 4.5:1 floor against it. De-emphasized text MUST express its lower rank through size or weight rather than through an opacity that falls below these floors.

#### Scenario: Hierarchy levels are distinguishable

- **WHEN** the user reads the idle home page
- **THEN** the screen title, the status headline, the status caption and a device item title differ in size or weight by an intentional step
- **AND** the status headline is the dominant line inside the status card

#### Scenario: Secondary text is not brighter than primary text

- **WHEN** a caption or hint is displayed next to a headline on the same card
- **THEN** the secondary line resolves through one named de-emphasized foreground role for the surface it sits on, rather than an opacity applied ad hoc at each call site
- **AND** it still clears the 4.5:1 floor above against that surface, so the role is chosen for legibility and not for rank alone
- **AND** its visual weight stays below the headline it belongs to

#### Scenario: Prompts the page raises stay legible

- **WHEN** the home page raises a prompt over itself — a success, a warning, an error, or a plain blocking notice
- **THEN** the prompt sits on its own opaque surface and its label clears 4.5:1 against that surface in both colour schemes
- **AND** the three semantic kinds keep visually distinct hues, so the colour itself still says which kind of prompt it is
- **AND** a blocking notice carries none of those hues, so it cannot be mistaken for one of them

#### Scenario: Text on the accent state stays readable at its weakest point

- **WHEN** a session is in progress and the status card or the primary action shows the accent gradient
- **THEN** the white headline and caption measured against the lightest stop of that gradient both reach 4.5:1
- **AND** the caption keeps its lower rank through size or weight instead of reduced opacity

### Requirement: Primary action is the focal control and states its availability

The start-water / settle action SHALL be the visually dominant control on the page, MUST show one appearance when it can be used and a different, clearly inactive appearance when no device is selected, and MUST NOT be activatable while no device is selected.

#### Scenario: Device selected

- **WHEN** a device is selected and no session is in progress
- **THEN** the action shows its enabled brand treatment, the play icon and the "开始接水" label
- **AND** it is visibly more prominent than any other control on the screen

#### Scenario: No device selected

- **WHEN** the device list is empty or nothing is selected
- **THEN** the action renders as inactive with a fill, label contrast and shape that read as unavailable
- **AND** tapping it does not start a session

#### Scenario: Session in progress

- **WHEN** a session is in progress
- **THEN** the same control switches to the settle state with its own color and the "结算" label
- **AND** the progress indicator inside the status card keeps animating

### Requirement: Device item states stay readable without shrinking interaction targets

The home page SHALL express the resting, selected, editing and dragging states of a device item through visual attributes only, and the hit area of every existing control in an item MUST NOT become smaller than it is today.

#### Scenario: Grid and list layouts keep item states

- **WHEN** the user switches between the single-column and two-column layouts
- **THEN** both layouts express the selected item with the same state language
- **AND** tapping an item still selects it and long-pressing still opens the note editor

#### Scenario: Reorder mode reads as a mode

- **WHEN** the user enters reorder mode
- **THEN** the list shows its drag handles and the "拖动调整顺序" hint on a surface distinct from normal browsing
- **AND** leaving reorder mode restores the previous layout without losing the selected device

### Requirement: Home-owned sheets and dialogs follow the page language

Bottom sheets and dialogs opened from the home page SHALL use the same surface roles, radii and type scale as the page, while keeping every entry they already provide.

#### Scenario: Device management sheet

- **WHEN** the user opens device management
- **THEN** the sheet shows its title, device rows with name and note or id, a per-row delete action and the add-device action
- **AND** deleting still asks for confirmation before the device is removed

#### Scenario: Settings sheet

- **WHEN** the user opens settings from the app bar
- **THEN** the sheet still offers "关于" and "退出登录", each with its icon
- **AND** choosing "关于" opens the version dialog and "退出登录" still asks for confirmation

### Requirement: Dark mode follows the same hierarchy

The home page SHALL apply the same surface role and hierarchy rules in dark mode, and MUST NOT rely on colors that only work in light mode.

#### Scenario: Dark scheme device

- **WHEN** a device using the dark color scheme opens the home page
- **THEN** cards, selected items and sheets stay separable from the page background
- **AND** no text pair falls below the contrast floor above

### Requirement: Page stays usable at small sizes and large text scale

The home page SHALL lay out without overflow on a small screen with enlarged system text, and MUST keep the primary action and every control reachable at that size.

#### Scenario: Small screen with enlarged text

- **WHEN** the page is rendered at 320x568 logical pixels with a 1.3 text scale and a non-empty device list
- **THEN** no render overflow is reported
- **AND** the primary action, the layout toggle and the add-device entry are all visible and tappable

### Requirement: Existing interactions remain reachable

The redesign SHALL preserve every interaction available on the home page today and MUST NOT remove or hide any of them.

#### Scenario: Full interaction sweep

- **WHEN** the user opens the redesigned home page with a non-empty device list
- **THEN** refresh, settings, layout toggle, reorder toggle, add device by scanning, select device, edit note, start session, settle session, manage devices and delete device are all still reachable with the same effect as before
- **AND** the empty-device state still offers scanning to add a device
