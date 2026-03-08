# Apple Reminders Integration Plan

## Goals & Scope
- Allow Hodíe users to sync tasks from Apple Reminders so capture done via Siri/Shortcuts lands in Today planning.
- Support iOS + macOS (Sonoma) using the existing local-first architecture; no cloud services required.
- Respect user choice by letting them decide which Reminders list(s) feed into Hodíe. Initial scope: single selectable list; stretch goal: multi-select.
- Keep the integration one-way (Reminders ➜ Hodíe) for MVP, with clear indicators on synced items.

## Architecture Overview
1. **RemindersProvider**: new service wrapping `EKEventStore` reminder APIs. Responsibilities:
   - Request `.reminder` access (distinct from calendar perm).
   - Fetch available `EKCalendar`s where `allowsContentModifications == true` and `type == .local` or `.calDAV`.
   - Fetch reminders for selected calendars, filtering incomplete items with due dates on/after today (configurable).
2. **RemindersSyncEngine**:
   - Persists user’s selected calendar IDs (e.g., `UserDefaults` via `AppEnvironment` or SwiftData settings).
   - On refresh, pulls reminders, maps them into lightweight DTOs, then hands them to `TaskStore`.
   - Uses `Task.source = "reminder:<calendarID>:<reminderID>"` to prevent duplicates and to update statuses.
3. **TaskStore additions**:
   - Import/update helpers to upsert reminders into SwiftData (`status = .planned`, `plannedFor = dueDate.startOfDay()`).
   - Optional flags to mark tasks as read-only if we don’t push completions back yet.

## UX & List Selection
1. **Settings Sheet** (`RemindersSettingsView`):
   - Shows permission state (Connect / Connected / Denied).
   - Lists available reminder lists with radio buttons (single select). Store selected calendar ID.
   - Provide “Sync now” button and description of one-way behavior.
2. **Today Inbox Surface**:
   - Add “Reminders inbox” row at top of flex section listing the count of unscheduled imported reminders.
   - Mark reminder-derived tasks with a small badge (“Reminders”) so users know origin.
3. **Permission Flow**:
   - When user taps “Connect Reminders”, prompt for access; surface fallback states (denied, not available).

## Sync Behavior
- Refresh reminders during app launch, manual pull-to-refresh, and when user changes the selected list.
- For each reminder:
  - Existing Hodíe task with matching `source` → update title, notes, due date, and completion state.
  - New reminder → insert as inbox/flex item planned for its due date (or today if none).
  - Completed reminders → mark corresponding Hodíe task complete.
- Do not delete reminders automatically; removal occurs if the source reminder disappears.
- Consider storing `lastSyncedAt` to throttle background refresh.

## Permissions & Storage
- Add `NSRemindersUsageDescription` to `Info.plist`.
- Persist selected reminder list ID and sync metadata via `AppSettings` (either SwiftData singleton or `UserDefaults`).
- Update onboarding checklist to mention Reminders connection as optional.

## Testing Strategy
- Unit tests for `RemindersProvider` using `EKEventStore` test doubles (wrap protocols) to cover permission transitions and list filtering.
- TaskStore import tests verifying upsert idempotence and `source` handling.
- UI tests: connect to mock provider, select list, ensure reminder badge appears, verify manual sync updates Today view.
- Manual verification on both platforms covering permission denial, multi-list accounts (iCloud + shared), and offline retries.
