# Hodíe — Initial Project Plan

## Vision

Hodíe is a personal day management system for people who are tired of splitting their day across separate apps for reminders, calendar planning, and focus timers.

The goal is not to build a generic productivity app. The goal is to build a **day-first operating system** that helps a user:

- capture what they need to do
- plan it into a real day
- execute with focus
- review what happened
- adapt without friction

Hodíe should feel calm, opinionated, elegant, and practical.

## Product Positioning

Hodíe combines four layers that are usually fragmented:

1. **Tasks** — things the user wants or needs to do
2. **Calendar** — time-based commitments and schedule context
3. **Focus** — a built-in timer for deep work and execution
4. **Daily planning** — the bridge that turns tasks into an actual day

The core promise is:

> One place to plan, schedule, and actually run the day.

## Phase 1 Scope

Phase 1 is focused only on:

- **iOS**
- **macOS**

Android and Windows are intentionally out of scope for now.

The product should be built in a way that allows future expansion, but current architecture and UX decisions should optimize for native Apple platforms first.

## Core Product Principles

### 1. Day-first, not list-first
The app should center around **Today** as the primary experience.

### 2. Fast capture
Users should be able to brain-dump tasks quickly with minimal friction.

### 3. Time-aware planning
Tasks should not exist in a vacuum. They should connect to available time.

### 4. Execution matters
The app should not stop at planning. Starting work should feel natural and immediate.

### 5. Humane productivity
Missed tasks should not feel punitive. Rescheduling should be easy and calm.

### 6. Opinionated before customizable
The first versions should prioritize a strong workflow over excessive settings.

## Target User

Initial target user:

- individuals, not teams
- people who actively manage their own day
- users who dislike jumping between multiple productivity apps
- users who want structure without a bloated system
- users who value elegant UX and native-feeling design

## MVP Goal

The MVP should answer one key question:

> Can a user realistically manage their whole day in Hodíe without needing separate apps for reminders, calendar context, and pomodoro-style focus sessions?

If yes, the MVP is successful.

## MVP Features

### 1. Inbox Capture
A place for quick task entry.

Requirements:
- create task quickly
- title is required
- optional notes
- optional due date
- optional estimated duration
- optional priority

### 2. Today View
The main screen of the app.

Requirements:
- show today’s calendar events
- show today’s scheduled tasks
- show unscheduled tasks selected for today
- support clear visual separation between fixed events and flexible work
- support drag/reorder interactions where appropriate per platform

### 3. Task Management
Requirements:
- create, edit, complete, delete tasks
- support task states such as inbox, planned, scheduled, completed
- support recurring tasks later if simple enough, but do not block MVP on advanced recurrence

### 4. Planning Flow
Requirements:
- move tasks from inbox into today
- optionally assign estimated duration
- optionally schedule tasks into a time slot
- allow a task to exist as “planned for today” without requiring exact scheduling

### 5. Focus Timer
Requirements:
- start focus mode directly from a task
- support a basic timer
- support pomodoro-style durations, but keep implementation simple
- record completed focus sessions
- tie focus sessions back to the active task when possible

### 6. Daily Review
Requirements:
- show completed tasks
- show unfinished tasks
- allow easy rollover to tomorrow or back to inbox
- surface a lightweight sense of closure for the day

## Not in MVP

These may be explored later, but should not be built first:

- team collaboration
- shared workspaces
- Android support
- Windows support
- AI planning suggestions
- advanced natural language parsing
- habit tracker features
- note-taking system beyond simple task notes
- heavy analytics dashboards
- complex calendar provider support beyond what is necessary for initial integration
- highly customizable themes and workflow engines

## Initial Information Architecture

Proposed top-level app areas:

- **Today**
- **Inbox**
- **Tasks**
- **Focus**
- **Review**

Alternative: combine some sections if the structure feels too heavy.

Likely first navigation priority:
1. Today
2. Inbox
3. Tasks
4. Review

Focus can also exist as a state entered from a task rather than as a full standalone tab.

## Initial Task Data Model

Suggested first-pass task properties:

- `id`
- `title`
- `notes`
- `status`
- `createdAt`
- `updatedAt`
- `dueDate`
- `scheduledStart`
- `scheduledEnd`
- `estimatedDurationMinutes`
- `completedAt`
- `priority`
- `isToday`
- `source`
- `recurrenceRule` (optional, can be deferred)

Keep the first model lean. Avoid premature complexity.

## Initial Focus Session Data Model

Suggested properties:

- `id`
- `taskId`
- `startedAt`
- `endedAt`
- `plannedDurationMinutes`
- `actualDurationMinutes`
- `wasCompleted`
- `sessionType`

## Calendar Strategy

The calendar is critical context, but this should not become a full calendar app clone.

Phase 1 approach:
- integrate calendar events as visible schedule context
- keep events readable in Today view
- do not attempt to outbuild Apple Calendar
- prioritize awareness and planning over exhaustive calendar editing features

## UX Priorities

### Today view should feel excellent
This is the heart of the product. It should be the strongest and most polished screen.

### Capture should be frictionless
Adding a task should be almost thoughtless.

### Focus mode should feel like momentum
A task should move naturally into execution.

### Review should reduce guilt
Unfinished work should be easy to reschedule instead of becoming clutter.

## Technical Direction

Recommended initial stack:
- **Swift**
- **SwiftUI**
- shared Apple-platform codebase where possible
- native architecture, not cross-platform for v1

Recommended technical priorities:
- local-first data model
- excellent offline behavior
- sync can come after local workflow is solid
- architecture should be modular enough to support future platform expansion

## Suggested Milestones

### Milestone 1 — Product Skeleton
- app shell
- navigation structure
- placeholder views
- local data persistence chosen and wired
- create/edit/delete task flow working

### Milestone 2 — Today Core
- today view layout
- show tasks relevant to today
- show calendar context
- support planning tasks into today

### Milestone 3 — Focus Integration
- start focus session from task
- basic timer
- persist completed focus sessions

### Milestone 4 — Daily Review
- end-of-day summary
- rollover flow
- complete vs unfinished state handling

### Milestone 5 — Polish Pass
- reduce friction in capture
- improve transitions and UX consistency
- refine information density on iPhone and macOS

## Design Tone

Hodíe should feel:

- calm
- clear
- elegant
- intentional
- low-friction
- premium but not cold

Avoid:
- corporate project management vibes
- cluttered dashboards
- gamification overload
- excessive motivational fluff

## Open Questions

These should be revisited early during implementation:

1. Should Today be timeline-first, list-first, or hybrid?
2. How much calendar editing should be supported in phase 1?
3. Should focus mode be a dedicated screen or a task state overlay?
4. What is the minimum viable recurrence model?
5. How should inbox vs today vs scheduled states be represented to keep the model understandable?

## Future Personalization

Long-term, the app should feel custom to each user. On the very first startup, show a short questionnaire that helps identify which productivity systems best fit that user. Only those systems and related workflows should surface in the UI and onboarding. This personalization layer should be implemented last, after the core day-management workflow is solid.

## Definition of Early Success

An early successful build should allow this workflow:

1. User captures a few tasks
2. User sees calendar context for the day
3. User selects what matters today
4. User starts a focus session on a chosen task
5. User completes or reschedules work at the end of the day

If that flow feels natural, Hodíe is on the right path.
