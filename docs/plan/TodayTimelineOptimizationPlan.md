# Today Timeline Optimization Plan

## Goals
- Collapse the Today view into a single timeline-focused surface while retaining the summary, flex list, and completed sections.
- Reduce visual noise by only showing the day anchors (5 AM and 10 PM) plus existing task/event blocks in the idle state.
- Dynamically reveal full hour markers only while a user is actively placing a task, then snap back to the compact view once placement is confirmed.
- Communicate available downtime via inline “Xh Ym free time” labels instead of rendering empty slots.

## Structural Changes
1. Remove the schedule picker from `TodayView.swift` so the timeline becomes the default (and only) schedule representation. Keep `plannedFlexInline` above the timeline.
2. Replace `CombinedScheduleView` with a new `TodayTimelineView` that renders:
   - Start anchor (5 AM)
   - Interleaved timeline segments derived from scheduled tasks and calendar events
   - End anchor (10 PM)
   - A compact all-day bucket (single row of labels/pills) rather than individual cards
3. Build a lightweight `TimelineSegment` model (start, end, content type, labels) to simplify view rendering and accessibility across iOS/macOS.

## Interaction States
Introduce `TimelineInteractionState` inside `TodayViewModel`:
- `.idle`: default mode, shows anchors + scheduled segments only, no intermediate hour labels.
- `.placing(taskID)`: triggered when the user taps “Place in timeline.” Instead of showing the hour grid, present a clock-style picker (native time picker wheel on iOS / macOS) constrained to 5 AM–10 PM so the user can dial a start time quickly.
- `.confirming(startTime)`: optional transient state while the picker animates; once the user confirms the time, schedule the task and return to `.idle`.

## UI Behavior
- Hour labels are hidden in `.idle`; during placement, only the clock picker is shown so the timeline stays uncluttered.
- Empty spans between segments are not rendered as their own rows; instead, each block footer shows the duration of the next gap (e.g., `3h 20m free time`). If the day ends after the current block, use the remaining time until 10:00 PM.
- All-day events render as a condensed inline list (chips under the start anchor) so they remain visible context without consuming full-card height in the timeline.
- Overlapping timed blocks (tasks or events) share horizontal lanes so items starting at the same or partially overlapping times appear beside each other, sized vertically according to their duration.
- Placement relies entirely on the clock selector (wheel on iOS, combo/time field on macOS). After the user confirms, scroll the new block into view and collapse the picker sheet.

## Implementation Steps
1. Refactor `TodayView` layout and remove the segmented picker. Embed the new `TodayTimelineView` below the flex section and pass `TimelineInteractionState` bindings.
2. Create `TimelineSegmentBuilder` (likely in `DayPlanner`) that merges calendar events and scheduled tasks into contiguous blocks with start/end metadata.
3. Implement `TimelineSegmentView` for task/event rendering plus a `TimelineTimePickerSheet` that wraps the system clock selector (DatePicker in `.hourAndMinute` mode) bounded to 5 AM–10 PM.
4. Add “Place in timeline” quick actions in flex rows and Inbox planning flows that toggle `.placing(taskID)`.
5. Update scheduling logic to consume the picker’s selected time (rounded to 15-minute increments) and re-render segments immediately after placement.

## Testing
- Extend unit tests (`TodayViewModelTests`) to cover segment generation and `TimelineInteractionState` transitions.
- Add UI tests that: enter placing mode, verify hour markers appear, drag a task into the timeline, and confirm the view collapses with the “free time” label displayed.
- Manually verify on both iOS and macOS that timeline scrolling, drag/drop, and focus timer integrations still behave as expected.

## Progress — 2026-03-08
- Added `TimelineInteractionState`-aware axis logic in `TodayTimelineView` so the idle state now shows only the start/end anchors while `.placing` reveals hourly tick labels along the rail (matches the “anchors-only vs. hour markers” goal in this plan).
- Narrowed the idle axis footprint (24 pt) while expanding to 84 pt when markers are visible, which gives timeline cards more breathing room without sacrificing readability when choosing a start time.
- Timeline canvas now trims its vertical span to the first/last scheduled blocks so there’s no empty gutter before breakfast or after the final task; the axis reuses those compressed bounds while free-time summaries communicate any gaps.
- Free-time footer generation now covers every scheduled block (including the last one, which now reports `Xm until end of day`), eliminating the missing labels seen in QA screenshots.
- Added a symmetric 24 pt buffer around the compressed timeline so the “Start of day” and “End of day” anchors now sit the same distance from the first/last cards, resolving the lingering asymmetry call-out while keeping the canvas length tied to actual scheduled blocks.
- Follow-ups: cover the axis toggle in a snapshot/UI test, and consider adding the optional `.confirming` interaction state once the time picker animation work resumes.
- New follow-ups: add regression coverage for the compressed timeline bounds (e.g., ensure all-day-empty states still render a reasonable placeholder) and verify localized strings for “until end of day.”

## Progress — 2026-03-09
- Added a lane-aware spacing pass in `TimelineCanvasView` so back-to-back items (same lane, matching end/start times) receive an automatic 8 pt offset, which keeps the cards from visually touching on both compact and regular timelines.
- Appended a dedicated 32 pt inset after the canvas stack so the “End of day” marker clears the final block consistently; the footer now stays visually detached even when the last card is tall or ends near 10 PM.
- Follow-up: reworked the placement math to iterate on lane bottoms using the real `pointsPerMinute`, so contiguous cards now reserve a fixed 10 pt gap even after the timeline stretches for minimum block heights or dynamic type; confirmed via a quick script mirroring the placement helper (two one-hour blocks starting at 9:15/10:15 now report a 10 pt separation).
