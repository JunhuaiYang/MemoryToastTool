# Memory Toast Tool Process Tree and Main Window Design

- Date: 2026-04-27
- Platform: macOS
- Status: Approved in conversation, pending written spec review

## 1. Overview

This spec updates the V1 design in three areas:

- process memory accounting must include child processes and background processes
- the alert panel must present a collapsible process tree instead of a flat GUI-only list
- the app settings experience must become the app's main window, with menu bar residency preserved when the window closes
- memory-summary ownership must shift so that rich incident details live in the alert panel instead of the menu bar

The goal is to make memory reporting materially more accurate, allow the user to inspect and act on process hierarchies directly, and make configuration reachable through a normal app window.

## 2. Problem Statement

The current implementation has three confirmed product issues:

1. process memory reporting is incomplete because child-process memory is not aggregated into the parent hierarchy
2. only GUI applications are sampled, which excludes relevant background processes
3. the settings UI exists but is not reachable from the menu bar app as a normal configurable window

These problems reduce trust in the monitoring result and make the app harder to use as a real tool.

## 3. Product Decisions

### 3.1 Process Sampling Scope

The app must sample both:

- GUI applications
- background processes

Sampling may no longer rely only on `NSWorkspace.shared.runningApplications`. The process model must include enough metadata to build process hierarchies and perform per-node actions.

Required per-process inputs:

- process identifier (`pid`)
- parent process identifier (`ppid`)
- process display name
- bundle identifier when available
- resident memory
- running state

### 3.2 Process Hierarchy Aggregation

Child-process memory must be aggregated upward until the traversal reaches a system-root boundary.

Traversal rule:

- start from each sampled process
- walk upward through parent processes
- stop when the parent is absent or is a system-root process such as `launchd`, `kernel_task`, or equivalent root-level system owner

Outcome:

- if a process belongs under a visible parent hierarchy, its memory contributes to that root hierarchy
- if a background process has no eligible parent hierarchy, it must appear as its own root node

### 3.3 Alert Panel Tree UI

The alert panel must switch from a flat process list to a collapsible tree.

Required behavior:

- top level shows root processes
- each root row shows aggregated memory for the entire subtree
- rows can be expanded to reveal child processes with indentation
- child rows show their own memory, not duplicated aggregate totals
- the user can inspect the full hierarchy inside the same panel

This tree replaces the earlier root-only flattened display. The flat GUI-only list is no longer acceptable.

### 3.4 Selection Rules

Selection behavior must follow tree semantics.

Required rules:

- selecting a parent selects all descendants
- deselecting a parent deselects all descendants
- the user may still modify the selection of an individual child afterward
- if only some descendants are selected, the parent must show a partial-selection state

The selection model therefore needs three visual states for parent rows:

- selected
- unselected
- partially selected

### 3.5 Quit / Force Quit Scope

Any selected node may be acted on, including:

- root app processes
- child helper processes
- standalone background processes

Normal quit phase:

- bundle-backed app nodes continue to use app-level quit behavior
- non-bundle background processes must use process-level termination

Countdown phase:

- process liveness must keep updating
- memory values must keep updating
- exited nodes must disappear immediately
- parent aggregate totals must be recomputed from remaining live descendants
- selection controls must remain disabled / greyed out during countdown

Force quit phase:

- appears only after countdown completes
- applies only to nodes that were originally selected and are still alive

### 3.6 Auto Relaunch Boundary

Auto relaunch remains intentionally narrow.

Rules:

- only bundle-backed app nodes that exited successfully via the normal quit path may be relaunched
- pure background processes are not automatically relaunched
- force-quit targets are never automatically relaunched

### 3.7 Alert Panel Close Conditions

The close conditions remain unchanged:

- all selected targets have exited, or
- the user manually closes the alert window

### 3.8 Main Window / Settings Behavior

The app settings UI becomes the app's main window.

Required behavior:

- the main window content is the settings panel
- opening settings from the menu bar opens this main window
- clicking the Dock icon opens this same main window
- when the main window closes, the app remains in the menu bar
- when the main window closes, the app must not continue to occupy a persistent Dock presence

Product interpretation:

- the app's steady-state presence is menu bar only
- the main window is an on-demand configuration surface

### 3.9 Settings Window Action

The settings main window must include a top-level button that opens the alert panel directly.

Behavior:

- the button is always available
- it may open the alert panel even when no alert rule is currently matched
- in that case, the alert panel still shows the current memory snapshot and current process tree

This makes the alert panel usable as a manual inspection surface, not only as an automatic incident response surface.

### 3.10 Information Placement

The menu bar panel and alert panel now have distinct responsibilities.

Menu bar panel:

- show current memory information only
- do not show matched rules
- do not show the top high-memory app list

Alert panel:

- must show current memory information at the top
- must show currently matched rule reasons at the top
- must show the process tree below

This change centralizes incident context inside the alert panel and keeps the menu bar panel lighter.

## 4. UX Details

### 4.1 Alert Tree Presentation

Each process row should support:

- expand / collapse affordance when children exist
- checkbox with tri-state support where applicable
- process name
- PID
- memory value
- existing controls where valid, such as ignore-by-default or relaunch-after-quit

Recommended presentation behavior:

- root rows start collapsed by default to keep the panel compact
- the tree should preserve readability under dense process hierarchies
- a child process should remain individually selectable even after inheriting selection from a parent

Above the tree, the alert panel header area must show:

- current memory summary
- matched rule reasons
- countdown / force-quit status when applicable

### 4.2 Dynamic Updates During Countdown

The existing live countdown behavior must extend to the tree model:

- dead child processes disappear from their subtree
- if a root loses all children, it remains only if the root process itself is still alive
- if a selected subtree fully exits, it no longer appears
- memory totals for visible ancestors are recalculated each refresh

### 4.3 Settings Window UX

The settings main window should:

- reuse the current settings form instead of inventing a separate home screen
- include a top-level action for opening the alert panel manually
- open as the primary app window
- be reachable from menu bar actions and Dock activation

No extra dashboard or landing page is required.

### 4.4 Menu Bar Panel UX

The menu bar panel should become simpler than the alert panel.

It should show:

- current system memory metrics
- manual refresh action
- open alert action
- open settings action
- open guide action if retained

It should not show:

- matched rule reason details
- top high-memory process summaries

## 5. Architecture Changes

### 5.1 Raw Process Sampling Layer

Introduce a raw-process sampling model that is broader than the current GUI-app sampler.

Responsibilities:

- enumerate system processes
- capture parent / child relationship metadata
- capture memory for each process
- resolve bundle identifiers when possible

This layer should be separate from the UI-facing tree model.

### 5.2 Process Tree Builder

Add a focused tree-construction component responsible for:

- building parent-child relationships
- identifying root nodes
- stopping upward aggregation at system-root boundaries
- computing aggregate memory for roots and intermediate parents
- producing a deterministic tree structure for UI and selection logic

This logic should be testable independent of SwiftUI.

### 5.3 Alert Session State Expansion

The current alert session state is based on a flat visible process list and a flat PID selection set. It must evolve to support:

- hierarchical visible nodes
- expand / collapse state
- parent-child selection propagation
- partial-selection derivation
- refresh-time removal of exited nodes while preserving valid selection state

The selection logic should remain centralized in the controller / state layer rather than being recreated ad hoc in the view.

### 5.4 Action Execution Layer

The action layer must distinguish between:

- app-level quit / force quit for bundle-backed GUI apps
- process-level terminate / kill for non-bundle background processes

This separation is required so that background processes can participate in the same workflow without pretending they are normal apps.

### 5.5 Main Window Wiring

Replace the current settings-only scene approach with a normal window scene that serves as the app's main window.

Responsibilities:

- open from menu bar action
- open from Dock activation
- close back to menu-bar-only presence

The implementation should preserve the existing settings form as content rather than reworking the whole settings UI.

### 5.6 Presentation Responsibility Split

The view-model and presentation code should be adjusted so that:

- menu bar view models focus on current memory summary and status only
- alert panel state carries both current memory snapshot data and matched rule reasons for display
- manual alert-panel opening from Settings can present the current tree even when there is no active alert incident

## 6. Testing Strategy

The change must be protected with targeted tests.

Minimum required coverage:

- child memory aggregates into the topmost eligible root
- multi-level helper chains aggregate all the way upward
- aggregation stops at `launchd`, `kernel_task`, or equivalent configured system-root boundaries
- orphaned background processes appear as standalone roots
- parent selection selects descendants
- parent deselection clears descendants
- child-only selection produces partial-selection parent state
- refresh removes exited nodes and recomputes aggregate memory correctly
- force quit targets only originally selected still-alive nodes
- settings window is reachable from the menu bar entry path
- settings window can open the alert panel without an active rule match
- alert panel displays current memory summary and matched rule reasons in its header area
- menu bar panel no longer renders rule reasons or top-process summaries

If a specific Dock activation behavior cannot be unit-tested cleanly, the implementation should still isolate that wiring enough to keep the logic reviewable.

## 7. Risks and Constraints

- Full process enumeration may surface many low-value or short-lived processes; the tree builder should preserve correctness first, then presentation clarity.
- Process ancestry on macOS is more nuanced than simple GUI app ownership; boundary rules must be explicit and test-covered.
- Background process termination is inherently riskier than GUI app quitting, so the existing explicit user-confirmed flow must remain strict.
- The feature must not regress the countdown, live-refresh, or auto-close behavior already implemented.

## 8. Out of Scope

This spec does not approve:

- automatic memory cleanup features
- automatic process killing
- auto relaunch for generic background processes
- historical analytics or charts
- expanded dashboard UI beyond the settings main window

## 9. Implementation Summary

The next implementation plan should cover:

1. raw process enumeration and memory sampling
2. tree building and aggregate memory calculation
3. hierarchical selection state and tri-state parent logic
4. background-process action support
5. alert panel tree UI conversion
6. settings main-window wiring and menu access
7. alert-header and menu-bar information split
8. regression and new test coverage
