# Repository Guidelines

## Project Structure & Module Organization
The app lives in `Hodie/`, with `App/` bootstrapping SwiftUI scenes, `Models/` for SwiftData entities, `Services/` (e.g., `TaskStore`, `CalendarProvider`, `FocusTimerEngine`), `ViewModels/`, `Views/`, and `Utilities/` for shared helpers. UI tests and unit tests reside in `HodieUITests/` and `HodieTests/`, while reference docs sit in `docs/plan/`. Keep new source alongside the closest feature folder so iOS and macOS continue sharing code paths first.

## Build, Test, and Development Commands
- `xed .` — open the workspace in Xcode 16+ (required before running simulators).  
- `xcodebuild build -scheme Hodie -destination 'platform=macOS,arch=arm64'` — macOS build sanity check.  
- `xcodebuild test -scheme Hodie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'` — primary CI-style run that builds, runs unit tests, and exercises SwiftData migrations.  
- `xcodebuild test -scheme Hodie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:HodieUITests` — UI regression sweep for capture → plan → focus → review flows.

## Coding Style & Naming Conventions
Use Swift 5.9+ with the default Xcode 4-space indentation and keep SwiftUI bodies declarative. Favor descriptive nouns for models (`FocusSession`, `DayPlanner`), `ViewModel` suffixes for state containers, and `View` suffixes for UI. Match Apple platform idioms (TabView on iOS, NavigationSplitView on macOS) and gate platform-specific branches with `#if os(...)`. Keep files lean and prefer focused extensions over sprawling types, adding brief comments only when clarity demands it.

## Testing Guidelines
Unit coverage uses XCTest inside `HodieTests/`; mirror production namespaces and name tests `test<Action>_<Expectation>()` (e.g., `testRollover_skipsCompletedTasks`). UI coverage lives in `HodieUITests/` and boots the app with the `UI-TESTING` argument, so avoid persistence assumptions. Every PR should run the full simulator test command above; stretch goals like new stores should add targeted unit tests plus a lightweight UI test if they touch the planning or focus loops.

## Commit & Pull Request Guidelines
Follow the existing short imperative style (`Adjust drop hover handler`, `Fix timeline drop handling`). Each PR description should outline the change, link any issue or doc reference, and include screenshots or screen recordings when UI shifts occur (Today, Inbox, Focus HUD, Review). Note simulator + macOS destinations tested, call out migrations or entitlement changes, and keep commits scoped so reviewers can reason about planner, timer, and calendar flows independently.

## Agent Workflow Priorities
Bias toward today-first UX, low-friction capture, predictable SwiftData/ViewModel state, and resist platform sprawl—every change should help someone plan, see, and run their day today.
