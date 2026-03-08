# Hodíe MVP Implementation Plan

_Date: March 8, 2026_

This plan translates `AGENTS.md` and `docs/plan/Hodie_PLAN.md` into a concrete architecture for the first Hodíe iOS + macOS release. It balances Today-first UX, low-friction capture, and local-first persistence while keeping the codebase modular and maintainable.

## 1. High-Level Architecture

- **App Shell**
  - Shared SwiftUI entry with `HodieApp` creating a `ModelContainer` (SwiftData) containing `Task` and `FocusSession` models.
  - iOS root: `TabView` with Today (default), Inbox, Focus, Review so the timer is a first-class destination instead of a transient overlay.
  - macOS root: `NavigationSplitView` with sidebar sections (Today, Inbox, Focus, Review) so desktop users can keep a focus screen pinned next to planning/work views.
- **Pattern**: MVVM with lightweight services. Views stay declarative; view models own state mutations and talk to repositories.
- **Modules (directories)**
  - `Models/` (SwiftData entities + enums)
  - `Services/` (TaskStore, FocusSessionStore, DayPlanner, ReviewCoordinator, CalendarProvider, FocusTimerEngine)
  - `ViewModels/` per feature area
  - `Views/` subdivided into Today, Inbox, Focus, Review, Shared components.
  - `Support/` for helpers (formatters, date utilities, shortcuts, accessibility, sample data)
  - Tests mirrored under `HodieTests` & `HodieUITests` for clarity.

## 2. Data & Persistence

### Task model
```
@Model final class Task {
    enum Status: String, Codable { case inbox, planned, scheduled, completed }
    enum Priority: String, Codable { case low, normal, high }
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var status: Status
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var plannedFor: Date?        // midnight of the target day
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var estimatedDurationMinutes: Int?
    var completedAt: Date?
    var priority: Priority
    var orderIndex: Double       // for drag/sort in inbox/today
    @Relationship(deleteRule: .cascade) var focusSessions: [FocusSession]
    var recurrenceStub: Recurrence?
}
```
`Recurrence` is a simple struct (frequency + interval) stored only when explicitly set; no auto-generation yet.

### FocusSession model
```
@Model final class FocusSession {
    enum SessionType: String, Codable { case pomodoro25, shortBreak5, custom }
    @Attribute(.unique) var id: UUID
    var task: Task?
    var startedAt: Date
    var endedAt: Date?
    var plannedDurationMinutes: Int
    var actualDurationMinutes: Int?
    var wasCompleted: Bool
    var notes: String?
}
```

### Support structs
- `CalendarEvent`: lightweight struct mirrored from EventKit for Today view timeline.
- `DayPlan`: computed struct bundling tasks/events for a date.

### Persistence Strategy
- SwiftData `ModelContainer` stored locally; on macOS uses app group container matching iOS for future sync.
- `TaskStore` and `FocusSessionStore` provide typed CRUD + fetch helpers, wrapping `ModelContext` to centralize persistence and ensure thread safety.
- `DayPlanner` composes repositories to produce filtered task sequences (inbox, planned, scheduled, completed) and handles ordering logic.

## 3. Services
- **TaskStore**: create/update/delete, query tasks by status/date, reorder operations, rollover helpers.
- **FocusSessionStore**: start/end sessions, attach to tasks, fetch history.
- **FocusTimerEngine**: Observable object using `Timer.publish` + `TimelineView` to drive countdown, supports presets (25/50 mins, custom), pause/resume, haptics (iOS) + subtle animations.
- **CalendarProvider**: EventKit wrapper (read-only). Requests permission on first launch, caches daily fetches, exposes `fetchEvents(for:)` returning `[CalendarEvent]`.
- **ReviewCoordinator**: builds daily summary, suggests rollover destinations (tomorrow vs inbox), executes chosen transitions.
- **ShortcutCenter**: macOS-only command handler for capture/hotkeys (⌘N for new inbox task, space to start focus, etc.).

## 4. Feature Surfaces & Navigation

### Inbox Capture
- Component: `QuickCaptureBar` (text field + keyboard accessory) + `InboxListView`.
- iOS: pinned input at top with auto-focus, plus swipe actions for schedule/priority.
- macOS: toolbar button + `⌘N` and inline row editing.
- ViewModel: `InboxViewModel` exposing quick-add action, editing sheet, reorder.

### Today View
- Layout: hybrid timeline (events + scheduled tasks) plus a "Planned Flex" shelf that surfaces immediately above the timeline in combined mode for drag-and-drop scheduling.
- `TimelineColumnView` renders events/time blocks with 30-min grid; a toggle switches between separate Calendar/Scheduled sections and a combined interactive timeline that lets users drag tasks to new time slots.
- Drag targets to allow promoting from inbox via `PlanTaskSheet` (sheet/popover) or context menu, plus drag-and-drop within the timeline to reschedule tasks.
- Calendar permission state handled gracefully (empty state w/ CTA) with all-day events collapsed into a single disclosure group so timelines stay compact.

### Planning Flow
- Dedicated sheet accessible from Inbox row actions or Today header.
- Allows selecting planned date (defaults to today), estimated duration, optional start time. Reuses `DurationPicker` component.
- Updating a task triggers `TaskStore.plan(task, for: date, schedule: DateInterval?)`.

### Focus Timer
- Access: dedicated Focus tab/screen plus contextual task actions; screen shows countdown, presets, and recent history so Focus is part of the main navigation on both platforms.
- Timer starts via `FocusViewModel` which coordinates `FocusTimerEngine` + `FocusSessionStore` to persist session once completed/stopped.
- History list visible inside the Focus screen and Review tab.

### Daily Review
- `ReviewView` surfaces the current/previous day summary: completed tasks, unfinished planned tasks, focus stats.
- Actions: mark done, roll forward (set planned date to next day), send back to inbox.
- End-of-day CTA triggers `ReviewCoordinator.rollover(date:)` to batch updates.

## 5. Testing Strategy
- **Unit Tests (Swift Testing)**
  - `TaskTests`: verify state transitions, ordering, estimated duration handling, recurrence stub validation.
  - `PlannerTests`: ensure DayPlanner filters tasks/events correctly, handles timezone boundaries.
  - `FocusTimerTests`: countdown accuracy, pause/resume, persistence results.
  - `ReviewCoordinatorTests`: rollover outcomes (to tomorrow vs inbox) preserving metadata.
  - `PersistenceTests`: confirm SwiftData fetch helpers behave offline (in-memory container).
- **UI Tests (XCTest)**
  - `CaptureFlowUITests`: add tasks from inbox quick entry and verify presence in Today after planning.
  - `FocusFlowUITests`: start timer from Today view, simulate completion, verify session history.
  - `ReviewFlowUITests`: mark tasks complete, run review, ensure rollover toggles.
  - Provide sample data harness for deterministic seeding.

## 6. Assumptions & Notes
1. Calendar access: read-only EventKit; if permission denied we show placeholder and allow manual scheduling only.
2. Notifications/haptics limited to focus timer completion (local notification when timer running in background).
3. Recurrence stub recorded but UI exposes only "repeat daily" toggle for now.
4. Mac + iOS share SwiftUI views except where layout diverges; platform conditionals keep experiences native.
5. No sync yet; all data local. Backup/export is deferred.
6. Accessibility: VoiceOver support via descriptive labels on timeline blocks and focus controls; dynamic type supported on iOS.
7. Animations kept subtle (spring for drag reorder, fade for state transitions) to maintain calm tone.

This plan will guide the upcoming implementation phases: skeleton, Today core, focus, review, and polish/testing.
