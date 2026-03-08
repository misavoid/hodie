# AGENTS.md

## Project

**Hodíe** is a day-first personal productivity app focused initially on **iOS and macOS only**.

The app combines:
- task capture
- day planning
- calendar context
- focus timer / pomodoro-style execution
- end-of-day review

The intent is to create one coherent system for running a day instead of scattering workflow across multiple apps.

## Current Development Scope

For now, agent work must focus strictly on:

- **iOS**
- **macOS**
- shared Apple-native architecture
- Swift / SwiftUI implementation

Do **not** optimize current implementation decisions for Android or Windows yet, unless the decision is also clearly beneficial for Apple-platform development.

Cross-platform concerns can be considered later, but should not complicate the current codebase prematurely.

## Product Goals

When contributing to this repository, optimize for the following:

1. **Today-first UX**
   - The app should revolve around helping the user run the current day.

2. **Low-friction capture**
   - Adding tasks should be very fast.

3. **Time awareness**
   - Tasks should relate to real time and planning, not just exist in lists.

4. **Execution support**
   - The user should be able to move smoothly from planning into focused work.

5. **Humane workflow**
   - Rescheduling and unfinished tasks should be handled cleanly and without punitive UX.

## Technical Preferences

### Language and UI
- Use **Swift**.
- Use **SwiftUI** as the default UI framework.
- Prefer shared code between iOS and macOS where practical.

### Architecture
- Keep the architecture modular and readable.
- Favor simple, maintainable patterns over overly abstract frameworks.
- Avoid premature enterprise-style complexity.
- Prefer local-first behavior.
- Keep domain logic separated from UI where it improves clarity.

### Code Style
- Write clear, idiomatic Swift.
- Use descriptive names.
- Keep files focused and reasonably small.
- Avoid cleverness that hurts maintainability.
- Prefer explicitness over magic.

### State and Data
- Keep models lean in the beginning.
- Avoid adding fields or abstractions that are not yet justified by real product needs.
- Favor predictable state flow.
- Persist data in a way that works well offline.

## UX Expectations

When implementing features, prefer:
- calm interfaces
- clear hierarchy
- low visual clutter
- minimal friction
- strong defaults over too many settings

Avoid:
- overdesigned “productivity hustle” aesthetics
- bloated control panels
- unnecessary gamification
- feature creep

## MVP Priorities

Agents should prioritize these features first:

1. Task capture
2. Today view
3. Planning tasks into today
4. Basic calendar context
5. Focus timer linked to tasks
6. Daily review and rollover flow

Anything outside that scope should be treated as secondary unless explicitly requested.

## Calendar Guidance

Calendar support is important, but the goal is not to recreate a full standalone calendar product.

Prioritize:
- showing calendar events as context
- integrating events into the Today view
- helping the user plan around time commitments

Do not overinvest early in:
- advanced event editing
- broad provider complexity
- full parity with Apple Calendar features

## Focus Timer Guidance

The focus timer is part of the execution flow, not a detached utility.

Preferred user flow:
- choose task
- start focus
- complete or stop session
- persist session history
- return naturally to the day workflow

## Platform Guidance

### iOS
Optimize for:
- fast capture
- clear Today view
- smooth task-to-focus transitions
- lightweight daily planning on a smaller screen

### macOS
Optimize for:
- denser information layout where appropriate
- efficient keyboard-friendly interactions
- stronger planning workflows
- comfort for longer sessions

Do not force iPhone UX onto macOS when a more native desktop interaction model would be better.

## Decision Rules

When uncertain, prefer the option that is:
1. simpler
2. more native to Apple platforms
3. easier to maintain
4. closer to the core workflow of planning and running the day

## Out of Scope for Now

Unless explicitly requested, avoid spending time on:
- Android implementation
- Windows implementation
- collaborative/team features
- AI features
- social features
- habit-tracking expansion
- extensive analytics
- plugin systems
- deep theming/customization systems

## Expected Agent Behavior

When asked to implement or propose something:
- stay aligned with the current Apple-first scope
- protect the MVP from bloat
- challenge unnecessary complexity
- favor practical shipping decisions
- keep suggestions grounded in the product vision

If a request risks expanding the project away from the core day-management workflow, call that out clearly and suggest a leaner version.

## North Star

Every meaningful contribution should support this question:

> Does this help the user plan, see, and run their day in one place?
