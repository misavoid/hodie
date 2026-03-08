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
- `.placing(taskID)`: triggered when the user taps “Place in timeline” from a flex task or Inbox picker. Timeline reveals an overlay of hour ticks and available slots from 5 AM–10 PM, plus a draggable ghost block representing the pending task.
- `.confirming(startTime)`: optional transient state while the user drags and snaps to allowable start times; once confirmed, schedule the task, then revert to `.idle`.

## UI Behavior
- Hour labels are hidden in `.idle` and only rendered in the planner overlay while `.placing`.
- Empty spans between segments are not rendered as their own rows; instead, each block footer shows the duration of the next gap (e.g., `3h 20m free time`). If the day ends after the current block, use the remaining time until 10:00 PM.
- All-day events render as a condensed inline list (chips under the start anchor) so they remain visible context without consuming full-card height in the timeline.
- Drag/drop should use the overlay’s snapping logic (15-minute increments) rather than per-hour drop targets. After placement, scroll the new block into view and collapse the overlay.

## Implementation Steps
1. Refactor `TodayView` layout and remove the segmented picker. Embed the new `TodayTimelineView` below the flex section and pass `TimelineInteractionState` bindings.
2. Create `TimelineSegmentBuilder` (likely in `DayPlanner`) that merges calendar events and scheduled tasks into contiguous blocks with start/end metadata.
3. Implement `TimelineSegmentView` for task/event rendering plus `TimelinePlannerOverlay` for the expanded hour grid and drop handling.
4. Add “Place in timeline” quick actions in flex rows and Inbox planning flows that toggle `.placing(taskID)`.
5. Update drag/drop + scheduling logic to consume overlay selections and to re-render segments immediately after a placement.

## Testing
- Extend unit tests (`TodayViewModelTests`) to cover segment generation and `TimelineInteractionState` transitions.
- Add UI tests that: enter placing mode, verify hour markers appear, drag a task into the timeline, and confirm the view collapses with the “free time” label displayed.
- Manually verify on both iOS and macOS that timeline scrolling, drag/drop, and focus timer integrations still behave as expected.
