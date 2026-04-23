# Memory Toast Tool Design

- Date: 2026-04-23
- Platform: macOS
- Status: Approved for planning

## 1. Overview

Memory Toast Tool is a native macOS menu bar application that monitors system memory usage on a configurable interval and prompts the user to close high-memory applications when configured thresholds are exceeded.

The product goal for V1 is to provide a trustworthy, lightweight, bilingual memory monitoring tool that helps the user take action safely. The tool focuses on detection, guided app shutdown, and controlled escalation to force quit when normal quit fails. It does not claim to perform unreliable "memory cleaning" actions.

## 2. Product Goals

- Monitor macOS memory usage continuously from a menu bar app.
- Evaluate configurable alert rules against physical memory usage, available memory, swap usage, and memory pressure.
- Show a dense status panel with current system metrics and quick actions.
- Present a single alert panel with a live-updating process list when thresholds are exceeded.
- Let the user request normal app quit first, wait with a visible countdown, then expose force quit only for remaining selected apps.
- Optionally relaunch successfully quit apps after a configurable delay.
- Ship with Simplified Chinese and English localization by default.

## 3. Non-Goals

- No "clean memory junk" or cache purge feature.
- No silent background force quit.
- No automatic force quit without explicit user action.
- No privileged or kernel-level memory operations.
- No cross-platform support in V1.
- No historical analytics dashboard in V1.
- No account system, sync, or cloud configuration.

## 4. User Experience

### 4.1 Menu Bar App

- The app runs as a persistent macOS menu bar app.
- The status icon reflects three states: normal, warning, and critical.
- The menu bar panel uses an information-dense layout.
- The panel shows:
  - current system memory summary
  - triggered rule summary
  - current top process memory usage
  - shortcuts for running a manual check, opening settings, and opening the alert panel

### 4.2 Detection Interval

- The user can enter a custom detection interval in seconds.
- Default detection interval is `30` seconds.
- The value is stored persistently.

### 4.3 Alert Rules

The user can configure one or more rules using these conditions:

- physical memory usage ratio
- available physical memory
- swap usage
- macOS memory pressure

The product must support a rule model that can be extended later, but V1 only needs local evaluation.

### 4.4 Alert Panel

When any active rule is triggered, the app shows one unified alert panel. This panel replaces the earlier two-dialog idea.

The panel shows:

- current system metrics
- matched rule reasons
- all detected applications and their current memory usage
- default selection of the top `N` memory-consuming apps
- per-app option to relaunch after successful quit

Default selected app count is configurable. Initial default is `3`.

### 4.5 Quit Flow

When the user clicks `Quit Selected`:

1. The app sends a normal quit request to all selected apps.
2. The alert panel enters a handling state with a `10` second countdown.
3. During the countdown:
   - process liveness and memory usage continue to refresh in real time
   - selected apps that exit successfully are removed from the panel immediately
   - the selection list and checkboxes are disabled and shown in a greyed-out state
4. When the countdown finishes:
   - if there are still selected apps alive, the panel reveals `Force Quit Selected`
   - this button only applies to the apps that were originally selected and are still alive

### 4.6 Alert Panel Close Conditions

The alert panel closes only when one of these conditions is met:

- all selected target processes have exited
- the user closes the panel manually with the system close button

### 4.7 Relaunch After Quit

Each app row can opt into relaunch-after-quit.

Rules:

- relaunch delay is configurable
- default relaunch delay is `5` seconds
- relaunch is only attempted for apps that quit successfully through the normal quit path
- apps that required force quit are not automatically relaunched

### 4.8 Additional Controls

The alert flow also supports:

- `Ignore Once`
- `Snooze`
- ignore list entries that prevent apps from being selected by default while still allowing them to appear in the list

### 4.9 Localization

The app ships with:

- Simplified Chinese
- English

Behavior:

- default language follows the macOS system language when possible
- the user can manually override language in settings
- all user-facing strings must come from localization resources

## 5. Technical Approach

### 5.1 Stack

- Native macOS app
- SwiftUI for primary UI
- AppKit bridging where menu bar or window behavior requires it

This approach is preferred over Electron or a split daemon architecture because the tool itself monitors memory and should remain lightweight and well-integrated with macOS.

### 5.2 Proposed Module Structure

- `MemoryToastApp.swift`
- `App/MenuBarController.swift`
- `Monitoring/MemorySnapshot.swift`
- `Monitoring/MemoryMonitor.swift`
- `Monitoring/ProcessSample.swift`
- `Rules/AlertRule.swift`
- `Rules/RuleEvaluator.swift`
- `ProcessControl/AppActionService.swift`
- `ProcessControl/AppRelaunchService.swift`
- `AlertSession/AlertSessionState.swift`
- `AlertSession/AlertSessionController.swift`
- `UI/MenuBar/MenuBarView.swift`
- `UI/Alert/AlertPanelView.swift`
- `UI/Settings/SettingsView.swift`
- `Persistence/SettingsStore.swift`
- `Resources/Localizable.xcstrings`

### 5.3 Responsibility Boundaries

`Monitoring`

- samples system-level memory metrics
- samples per-process memory usage
- emits immutable snapshots for rule evaluation and UI consumption

`Rules`

- stores the alert condition model
- evaluates snapshots and returns matched reasons

`ProcessControl`

- requests normal app quit
- performs explicit force quit when requested
- relaunches apps after a configured delay

`AlertSession`

- owns the alert panel state machine
- manages selected apps, countdown timing, disabled UI state, live refresh, and close conditions

`Persistence`

- saves settings and user preferences locally

`Localization`

- stores all localized strings and language selection behavior

## 6. Alert Session State Model

The alert panel should behave like a single state machine instead of multiple disjoint dialogs.

Primary states:

- `idle`
- `presenting`
- `quitRequested(countdownRemaining)`
- `forceQuitAvailable`
- `completed`
- `dismissed`

Expected behavior:

- `presenting` shows the live list and editable selections
- `quitRequested` disables selection edits, refreshes process data, and counts down from `10`
- `forceQuitAvailable` exposes force quit controls only for the still-alive originally selected apps
- `completed` closes the panel automatically once all selected apps are gone
- `dismissed` is reached when the user manually closes the panel

## 7. Data Model Notes

V1 configuration needs at least these persisted values:

- detection interval seconds
- default selected app count
- alert rules
- snooze state
- ignored app identifiers
- relaunch delay seconds
- preferred language override

Each process row shown in the alert panel should have:

- process identifier
- app name
- bundle identifier if available
- current memory usage
- current running state
- initially selected flag
- relaunch-after-quit flag

## 8. Safety Constraints

- Force quit is never automatic.
- Force quit is not visible until countdown completes and only if relevant apps remain alive.
- Selection cannot be changed after quit has been requested.
- Relaunch is restricted to successfully quit apps.
- The app must avoid presenting low-value or misleading "memory cleanup" actions.

## 9. V1 Delivery Scope

Included in V1:

- menu bar app shell
- monitoring loop
- rule evaluation
- dense status panel
- unified live-updating alert panel
- normal quit flow
- delayed force quit flow
- optional relaunch-after-quit
- settings persistence
- Chinese and English localization

Explicitly deferred:

- charts and historical trends
- export/import settings
- onboarding flow
- advanced automation policies
- cloud features

## 10. Recommended Implementation Order

1. Build the monitoring snapshot and rule evaluation layer.
2. Build menu bar status display using sampled data.
3. Build the alert session state machine and live-updating alert panel.
4. Integrate normal quit, force quit, and relaunch control.
5. Add persistent settings and bilingual localization.

## 11. Open Notes for Planning

- V1 should prefer stable macOS-native APIs wherever possible.
- Process sampling and app control may require different strategies for GUI apps versus background processes; planning should focus V1 on user-facing apps.
- The implementation plan should include explicit build and test checkpoints for each major milestone.
