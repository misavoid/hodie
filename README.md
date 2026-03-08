# Hodíe

Hodíe is a calm, day-first productivity companion for iOS and macOS. It combines rapid task capture, a today-centric planner with calendar context, a built-in focus timer, and a humane daily review so one person can run their entire day without bouncing between apps.

## Feature Overview
- **Inbox capture:** always-on text fields and keyboard shortcuts make it easy to throw tasks into the inbox with notes, priority, and optional due dates.
- **Today view:** hybrid list timeline showing calendar events, scheduled task blocks, flexible “planned for today” work, and completion history. Drag to reorder tasks when editing.
- **Planning flow:** pick any inbox task, choose a date, optionally assign a start time + duration, and it lands in Today immediately.
- **Integrated focus timer:** start a Pomodoro-style session directly from a task (or the floating HUD), pause/resume, and automatically persist the session to the task when it completes.
- **Daily review + rollover:** see completed vs unfinished work, focus history, and one-tap rollover actions to move anything unfinished to tomorrow or back to the inbox.
- **Apple Calendar context:** read-only EventKit integration keeps Today grounded in the user’s real schedule (with graceful empty/permission states).

## Architecture
- **Language + UI:** 100% Swift + SwiftUI targeting iOS 17+/macOS 14+ with a shared codebase and per-platform idioms (TabView on iOS, NavigationSplitView on macOS).
- **Persistence:** SwiftData `Task` and `FocusSession` models power local-first storage. A single `ModelContainer` is shared across scenes, with in-memory storage automatically enabled when the app launches under UI tests.
- **Services:**
  - `TaskStore` centralizes CRUD, planning, reordering, and rollover logic.
  - `FocusSessionStore` + `FocusTimerEngine` run the countdown experience and record history.
  - `CalendarProvider` wraps EventKit for read-only events.
  - `DayPlanner` composes task/query results with calendar events for the Today surface.
  - `ReviewCoordinator` builds the end-of-day summary and applies rollover operations.
- **View models:** `InboxViewModel`, `TodayViewModel`, `ReviewViewModel`, and `FocusController` keep SwiftUI views declarative while maintaining predictable state.
- **Views:** Shared components (`TaskRowView`, `TaskPlanningSheet`, `FocusOverlayView`) support feature screens (Inbox, Today, Review). Platform-specific containers (`TabView` vs `NavigationSplitView`) keep each OS native.

## Running the App
1. Ensure Xcode 16 (or newer) is installed on macOS Sonoma.
2. Clone the repository and open the project:
   ```bash
   git clone https://github.com/misavoid/hodie.git
   cd hodie
   xed .
   ```
3. Choose the `Hodie` scheme.
4. Select your destination:
   - **iOS / iPadOS:** pick an iOS 17+ simulator (e.g., *iPhone 15 Pro*).
   - **macOS:** choose *My Mac (Designed for Mac)*.
5. Build & run (`Cmd+R`). The same SwiftUI code adapts per platform; calendar access prompts appear on first launch.

CLI build examples (useful for CI automation):
```bash
# iOS build + tests
xcodebuild test -scheme Hodie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'

# macOS build
xcodebuild build -scheme Hodie -destination 'platform=macOS,arch=arm64'
```

## Testing
Automated coverage spans SwiftData model logic, planning + rollover flows, the focus timer engine, and UI capture/plan/focus/review journeys.

- **Unit tests:**
  ```bash
  xcodebuild test -scheme Hodie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:HodieTests
  ```
- **UI tests (capture → plan → focus → review, plus rollover):**
  ```bash
  xcodebuild test -scheme Hodie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:HodieUITests
  ```
  UI tests launch the app with the `UI-TESTING` argument so SwiftData runs entirely in-memory, keeping runs deterministic.

## Keyboard + Interaction Notes
- `⌘N` (macOS) creates a new inbox task when the Quick Capture section is focused.
- `Space` (macOS toolbar shortcut) opens the floating focus HUD.
- Reordering tasks in Today or Inbox requires entering edit mode and then dragging rows.
- Calendar permissions are optional; if access is denied, Today still works with manual scheduling.

## Documentation
- `docs/plan/Hodie_PLAN.md` — master product brief and milestones.
- `docs/plan/MVP_IMPLEMENTATION_PLAN.md` — current architecture + testing plan derived from the brief.
- `AGENTS.md` — development guardrails (Apple-first scope, day-first UX priorities, and out-of-scope items).

Stay aligned with the north star question: **Does this help someone plan, see, and run their day in one place?**
