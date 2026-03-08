import SwiftUI

struct TodayTimelineView: View {
    let date: Date
    let plan: DayPlan
    let segments: [TimelineSegment]
    let dayBounds: (start: Date, end: Date)
    let placingTask: Task?
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void
    var onSelectPlacementTime: (Date) -> Void
    var onCancelPlacement: () -> Void

    var body: some View {
        Group {
            if let placingTask {
                TimelinePlacementView(
                    date: date,
                    plan: plan,
                    placingTask: placingTask,
                    onSelectPlacementTime: onSelectPlacementTime,
                    onCancelPlacement: onCancelPlacement
                )
            } else {
                CompactTimelineView(
                    segments: segments,
                    dayBounds: dayBounds,
                    onToggleTask: onToggleTask,
                    onFocusTask: onFocusTask,
                    onPlanTask: onPlanTask
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: placingTask?.id)
    }
}

private struct CompactTimelineView: View {
    let segments: [TimelineSegment]
    let dayBounds: (start: Date, end: Date)
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let nextStart = nextStartDate(after: index) ?? dayBounds.end
                    TimelineSegmentRow(
                        segment: segment,
                        isFirst: index == 0,
                        isLast: index == segments.count - 1,
                        nextStart: nextStart,
                        onToggleTask: onToggleTask,
                        onFocusTask: onFocusTask,
                        onPlanTask: onPlanTask
                    )
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func nextStartDate(after index: Int) -> Date? {
        guard segments.indices.contains(index + 1) else { return nil }
        return segments[index + 1].start
    }
}

private struct TimelineSegmentRow: View {
    let segment: TimelineSegment
    let isFirst: Bool
    let isLast: Bool
    let nextStart: Date
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TimelineIndicator(isActive: !segment.isAnchor, isFirst: isFirst, isLast: isLast)
            content
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var content: some View {
        switch segment.kind {
        case .anchor(let label):
            TimelineAnchorRow(label: label, time: segment.start)
        case .task(let task):
            TimelineTaskCard(
                task: task,
                freeTimeText: freeTimeText,
                onToggle: { onToggleTask(task) },
                onFocus: { onFocusTask(task) },
                onPlan: { onPlanTask(task) }
            )
        case .event(let event):
            TimelineEventCard(event: event, start: segment.start, end: segment.end, freeTimeText: nil)
        }
    }

    private var freeTimeText: String? {
        let gap = nextStart.timeIntervalSince(segment.end)
        guard gap > 60 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let formatted = formatter.string(from: nextStart)
        return "Free time until \(formatted)"
    }
}

private struct TimelineAnchorRow: View {
    let label: String
    let time: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TimelineTaskCard: View {
    let task: Task
    let freeTimeText: String?
    var onToggle: () -> Void
    var onFocus: () -> Void
    var onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.status == .completed ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                    if let start = task.scheduledStart {
                        let end = task.scheduledEnd ?? start.addingTimeInterval(TimeInterval((task.estimatedDurationMinutes ?? 60) * 60))
                        Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                VStack(spacing: 6) {
                    Button(action: onFocus) {
                        Image(systemName: "timer")
                    }
                    .buttonStyle(.borderless)
                    Button(action: onPlan) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if let freeTimeText {
                Text(freeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
}

private struct TimelineEventCard: View {
    let event: CalendarEvent
    let start: Date
    let end: Date
    let freeTimeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "calendar")
                    .padding(8)
                    .background(Color.indigo.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    if event.isAllDay {
                        Text("All day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let freeTimeText {
                Text(freeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
}

private struct TimelineIndicator: View {
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isFirst ? 0 : 20)
            Circle()
                .fill(isActive ? Color.accentColor : Color(.systemGray4))
                .frame(width: 12, height: 12)
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isLast ? 0 : 20)
        }
    }
}

private struct TimelinePlacementView: View {
    let date: Date
    let plan: DayPlan
    let placingTask: Task
    var onSelectPlacementTime: (Date) -> Void
    var onCancelPlacement: () -> Void

    private let hours = Array(5...22)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Place \"\(placingTask.title)\"")
                        .font(.headline)
                    Text("Select a start time between 5 AM and 10 PM.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancelPlacement)
                    .buttonStyle(.bordered)
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(hours, id: \.self) { hour in
                        TimelinePlacementHourRow(
                            date: date,
                            hour: hour,
                            events: events(for: hour),
                            tasks: tasks(for: hour)
                        ) { selected in
                            onSelectPlacementTime(selected)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func events(for hour: Int) -> [CalendarEvent] {
        plan.calendarEvents.filter { event in
            guard !event.isAllDay else { return false }
            return Calendar.current.component(.hour, from: event.startDate) == hour
        }
    }

    private func tasks(for hour: Int) -> [Task] {
        plan.scheduledTasks.filter { task in
            guard let start = task.scheduledStart else { return false }
            return Calendar.current.component(.hour, from: start) == hour
        }
    }
}

private struct TimelinePlacementHourRow: View {
    let date: Date
    let hour: Int
    let events: [CalendarEvent]
    let tasks: [Task]
    var onSelect: (Date) -> Void

    private var minuteIncrements: [Int] {
        hour == 22 ? [0] : [0, 15, 30, 45]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hourLabel)
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                ForEach(minuteIncrements, id: \.self) { minute in
                    Button {
                        if let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self.date) {
                            onSelect(date)
                        }
                    } label: {
                        Text(timeLabel(for: minute))
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if !(tasks.isEmpty && events.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tasks) { task in
                        Text("• \(task.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(events) { event in
                        Text("• \(event.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 2)
            } else {
                Text("Free hour")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Divider()
        }
    }

    private var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date)
    }

    private func timeLabel(for minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date)
    }
}
