# AGENT.md

## Project Snapshot

- Project: `MemoryToastTool`
- Platform: macOS only
- App type: native menu bar app
- Primary goal: monitor system memory usage and guide the user to close memory-heavy processes safely
- Default languages: Simplified Chinese + English
- Trust model: explicit user action first, no fake cleanup claims, no automatic force quit

This file is the working contract for future contributors and coding agents. When behavior is unclear, prefer the rules here over inventing new product behavior.

## Product Contract

### Core Value Proposition

Memory Toast Tool is not a "memory cleaner." It is a lightweight macOS utility that:

- samples current system memory state
- evaluates local alert thresholds
- lists running processes by memory usage
- helps the user quit the right apps in a controlled way

### Hard Non-Goals

Do not add or imply any of the following in V1 unless explicitly requested by the user:

- "clean memory junk"
- "release cache"
- "free RAM" through unreliable tricks
- automatic force quit
- hidden background killing
- cross-platform support
- cloud sync, account system, analytics backend

### Safety Rules

- Force quit is never automatic.
- Force quit must require an explicit user click.
- Force quit must not be shown until the countdown ends.
- Force quit only targets processes that were originally selected and are still alive.
- Auto relaunch applies only to apps that quit normally.
- Force-quit apps must never be auto relaunched.
- System-root owners such as `launchd` and `kernel_task` must not be shown as closable targets.

## Locked UX Requirements

### Monitoring

- The app runs from the macOS menu bar.
- It supports both periodic monitoring and manual checks.
- Detection interval must support manual numeric input in seconds.
- The monitoring loop should refresh continuously while the app is running.

### Alert Triggers

Current trigger dimensions:

- available physical memory
- swap used
- memory pressure

The rules are local only. Do not add network-dependent rule logic.

### Alert Panel

- There is only one alert panel.
- The panel shows current memory metrics.
- The panel shows matched trigger reasons.
- The panel shows a collapsible process tree with current memory usage.
- The panel shows both app processes and background processes.
- Root nodes show aggregate memory; child nodes show their own memory.
- The panel shows all listed nodes, not just the selected ones.
- Default selection is the top `N` memory-consuming root processes.
- `N` is configurable in Settings.

### Quit Flow

Required flow:

1. User clicks `Quit Selected`.
2. App sends normal quit requests first.
3. Same panel enters countdown mode.
4. During countdown:
   - process liveness must keep refreshing
   - memory usage must keep refreshing
   - exited processes must disappear immediately from the tree
   - checkboxes and selection controls must be disabled / greyed out
5. After countdown ends:
   - show `Force Quit Selected` only if relevant selected processes are still alive

Selection semantics:

- selecting a parent selects all descendants
- deselecting a parent deselects all descendants
- users may still change an individual child afterward
- partially selected ancestors must show a half-selected state

### Alert Panel Close Conditions

The alert panel closes only when:

- all selected target processes have exited, or
- the user manually closes the window

### Auto Relaunch

- Auto relaunch is configurable per selected app row.
- Auto relaunch delay is configurable.
- Default relaunch delay is `5` seconds.
- Only successful normal quit can schedule relaunch.

### Settings Intro

- `Settings` is the only main window.
- The top of `Settings` contains a short product introduction and basic usage guidance.
- Do not reintroduce a separate safety guide window.

### Main Window

- `Settings` is the app's main window.
- Opening settings from the menu bar opens that main window.
- The main window contains a top-level button that can open the alert panel manually.
- Closing the main window must leave the app resident in the menu bar.
- Closing the main window must remove persistent Dock presence.

### Localization

- Ship with Simplified Chinese and English by default.
- Language follows system by default.
- User may override language in Settings.
- All user-facing strings must come from localization resources.

## Current Defaults

These defaults are sourced from `Sources/MemoryToastCore/AppSettings.swift` and should stay aligned with tests unless intentionally changed:

- detection interval: `30` seconds
- default selected app count: `3`
- relaunch delay: `5` seconds
- force quit reveal delay: `10` seconds
- available memory threshold: `2 GB` (`2_000_000_000` bytes)
- swap used threshold: `4 GB` (`4_000_000_000` bytes)
- ignored bundle identifiers: empty
- snooze: none
- language override: `nil` (`Follow System`)

## Implementation Notes

### Current Architecture

- `Sources/MemoryToastCore/`
  - core models, monitoring, rules, app actions, relaunch service, settings persistence, alert session logic
- `MemoryToastToolApp/`
  - SwiftUI app entry, menu bar UI, alert panel UI, settings UI, localization helper
- `Tests/MemoryToastCoreTests/`
  - unit tests for settings, rules, monitor ordering, app actions, alert policy, alert session state
- `MemoryToastTool.xcodeproj/`
  - Xcode app project used for native macOS build/run

### Important Files

- App entry: `MemoryToastToolApp/MemoryToastToolApp.swift`
- Monitoring loop + alert presentation bridge: `MemoryToastToolApp/MenuBarContainerView.swift`
- Menu UI: `MemoryToastToolApp/MenuBarView.swift`
- Alert UI: `MemoryToastToolApp/AlertPanelView.swift`
- Settings UI: `MemoryToastToolApp/SettingsView.swift`
- Localization helper: `MemoryToastToolApp/LocalizationSupport.swift`
- Persisted settings: `Sources/MemoryToastCore/AppSettings.swift`
- Alert session state machine: `Sources/MemoryToastCore/AlertSessionController.swift`

### State / Behavior Expectations

- `MenuBarContainerView` owns the monitoring loop and decides when to present the alert window.
- If an alert is already active, fresh process samples should update the existing alert session instead of opening duplicate flows.
- The ignored-app list affects default selection, but ignored apps may still appear in the process list.
- The menu bar panel shows current memory summary only.
- Matched rules and detailed process information belong in the alert panel header/body, not the menu bar.
- `Ignore Once` suppresses the current incident until trigger reasons clear.
- `Snooze` suppresses alerts until the stored `snoozeUntil` time expires.

## Development Rules

### Before Changing Product Behavior

- Preserve the product contract above unless the user explicitly changes it.
- Do not reintroduce the earlier "two popups" model.
- Do not add any feature that markets itself as cache cleanup or memory garbage cleanup.
- Do not silently change default values without updating tests and docs.
- Do not regress from tree-based presentation back to a flat GUI-only list.

### Verification Expectations

For meaningful code changes, verify with:

```bash
HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.cache/clang swift test --scratch-path .swiftpm-cache
xcodebuild -project MemoryToastTool.xcodeproj -scheme MemoryToastTool -derivedDataPath .derived-data -destination 'platform=macOS,arch=arm64' build
```

Notes:

- `swift test` is the package-level test gate.
- `xcodebuild build` is the native app build gate.
- `xcodebuild test` is not relied on in this environment.

### Git Workflow

- The user prefers major milestones to be committed separately.
- Keep commits scoped to one coherent step.
- Do not amend commits unless explicitly asked.
- Do not revert unrelated user changes.

## Documentation Sync Rules

If product behavior changes, update the relevant docs in the same step when appropriate:

- `README.md` for user-facing behavior and usage
- `AGENT.md` for locked requirements and contributor guidance
- `docs/superpowers/specs/2026-04-23-memory-toast-tool-design.md` only if the design baseline itself changed materially

## Open Scope Boundaries

Reasonable future extensions if explicitly requested:

- more alert rule types
- better process filtering / grouping
- stronger release packaging
- app icon / polish / onboarding improvements
- historical views or reporting

Do not treat these as already approved roadmap items. They require explicit user direction.
