# Pomodoro Timer Implementation Plan

## Objectives
- Let users configure a Pomodoro session by selecting total session length (number of pomodoros) and an overarching goal statement.
- Capture per-pomodoro intent so each cycle has a mini-goal and optional notes.
- Enforce canonical cadence: 25-minute focus blocks by default, 5-minute short breaks, 30-minute long break after four pomodoros, while still allowing future flexibility.
- Surface progress, remaining effort, and upcoming break context across iOS and macOS.
- Keep planner/timer state unified so Focus HUD, Today view, and notifications stay in sync.

## Key User Stories
1. **Plan Session**: From Today or Focus view, I can tap “Start Pomodoro Session,” set the number of pomodoros (derived from desired total time), write a session goal, and optionally pre-fill per-pom goals. The task type "Project" is to be associated with the session goal of a pomodoro session.
2. **Track Per-Pom Goal**: Before or during each focus block, I can define what I aim to finish in that block and see it while the timer runs.
3. **Auto Break Cadence**: When a pom ends, a 5-minute break starts automatically; after every fourth pom, I’m prompted for or placed into a 30-minute break.
4. **Completion + Reflection**: After the total session, I can mark the overall goal as met, carry unfinished per-pom goals forward, or log notes.
5. **Persistence & Resume**: If the app closes or switches devices, the active session resumes seamlessly with accurate timers and break state.

## Architecture & Data Model
- Extend `FocusTimerEngine` with a `PomodoroSession` struct containing:
  - `id`, `goal`, `createdAt`, `status` (planned/active/paused/completed/cancelled).
  - `pomodoros: [PomodoroBlock]` each with planned goal, actual outcome, start/end timestamps, type (focus/shortBreak/longBreak).
  - `currentIndex`, `nextBreakType`, `configuration` (block duration, short/long breaks, long-break interval = 4).
- Store `PomodoroSession` via SwiftData so TodayViewModel and FocusHUD share the same source of truth. Consider a lightweight SwiftData schema migration.
- Update `FocusTimerEngine` state machine to understand the Pomodoro cadence: `idle → focus → shortBreak → focus ... → longBreak → focus` repeating, emitting Combine publishers consumed by UI.
- Add `PomodoroCoordinator` helper to translate user inputs into session structs and to advance blocks when timers complete.

## UX Flow
1. **Entry Point**
   - Add CTA in Today Focus card (“Pomodoro”) and Focus HUD (“⋯” menu).
   - Present a sheet `PomodoroPlannerView` with controls:
     - Number stepper (1–12 poms, default 4).
     - Calculated total duration preview and slider override.
     - Session goal text field.
     - Optional list of per-pom quick goals (text fields or tasks selection).
2. **Active Session**
   - Focus HUD shows current pom number/total, remaining time, and the per-pom goal.
   - Provide quick-edit for the current block goal.
   - Break screens show countdown, next focus goal, and CTA to skip/extend (bounded by configuration).
3. **Notifications / Widgets**
   - Use existing `FocusTimerEngine` notification hooks to alert on focus end and break start; include goal snippets.
4. **Completion Sheet**
   - Summarize goals achieved, collect reflection, offer to schedule another session or log outcomes (e.g., in Review tab).

## Integration Points
- **TodayViewModel**: Track active session for display in Today timeline; show upcoming break markers.
- **Task Linking**: Allow selecting tasks from TaskStore to populate per-pom goals (non-blocking for v1 if data binding is complex; fallback to free text).
- **Calendar Provider**: Optionally block focus time on calendar; schedule event for total session when user opts in.
- **FocusTimerEngine**: Central timer logic with Combine publishers consumed by SwiftUI views.

## Implementation Steps
1. **Data Layer**
   - Define SwiftData models `PomodoroSessionEntity` and `PomodoroBlockEntity` with relationships and mapping helpers to domain structs.
   - Add persistence helpers (create, fetch active, update block progress).
2. **Engine Updates**
   - Introduce `PomodoroMode` in `FocusTimerEngine` with configuration constants.
   - Implement state transitions and timer scheduling for focus vs. break blocks; ensure long-break insertion every 4th focus completion.
   - Expose publishers for current block info, remaining time, and session progress.
3. **View Models**
   - Extend `TodayViewModel` / `FocusViewModel` with session lifecycle intents (start, pause, resume, skip break, finish).
   - Bind per-pom goal strings and propagate edits to persistence.
4. **UI Components**
   - Build `PomodoroPlannerView` sheet and supporting components (goal list, duration preview badge).
   - Update Focus HUD and Today timeline cards to show Pomodoro-specific chrome (progress ring, upcoming break banner).
   - Add completion summary sheet.
5. **Notifications & Background**
   - Update local notification payloads for focus/break transitions.
   - Ensure background task assertions keep timers accurate when app is inactive.
6. **Testing**
   - Unit tests: session creation, state machine transitions, persistence round-trips.
   - UI tests: start session, auto-break flow, long-break trigger after four poms.

## Risks & Mitigations
- **Timer Drift**: Use `Timer.publish` tied to `FocusTimerEngine` and compare against stored timestamps to correct drift.
- **Persistence Complexity**: Keep models minimal; derive analytics later to avoid blocking shipping.
- **User Overwhelm**: Default to 4 poms (2h) with ability to edit; keep planner simple.

## Metrics & Follow-Up
- Track number of sessions started/completed, average poms per session, break skips.
- Future enhancements: custom durations per user, collaborative sessions, Siri shortcuts.
