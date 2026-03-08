import SwiftUI

struct TodayTimelineView: View {
    let segments: [TimelineSegment]
    let allDayEvents: [CalendarEvent]
    let dayBounds: (start: Date, end: Date)
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    var body: some View {
        CompactTimelineView(
            segments: segments,
            allDayEvents: allDayEvents,
            dayBounds: dayBounds,
            onToggleTask: onToggleTask,
            onFocusTask: onFocusTask,
            onPlanTask: onPlanTask
        )
    }
}

private struct CompactTimelineView: View {
    let segments: [TimelineSegment]
    let allDayEvents: [CalendarEvent]
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
                        allDayEvents: index == 0 ? allDayEvents : [],
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
    let allDayEvents: [CalendarEvent]
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
            TimelineAnchorRow(label: label, time: segment.start, allDayEvents: allDayEvents, freeTimeText: freeTimeText)
        case .task(let task):
            TimelineTaskCard(
                task: task,
                freeTimeText: freeTimeText,
                onToggle: { onToggleTask(task) },
                onFocus: { onFocusTask(task) },
                onPlan: { onPlanTask(task) }
            )
        case .event(let event):
            TimelineEventCard(event: event, start: segment.start, end: segment.end, freeTimeText: freeTimeText)
        }
    }

    private var freeTimeText: String? {
        guard !isLast else { return nil }
        let gap = nextStart.timeIntervalSince(segment.end)
        guard gap >= 60 else { return nil }
        let minutes = Int(gap / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if remainingMinutes > 0 {
            parts.append("\(remainingMinutes)m")
        }
        guard !parts.isEmpty else { return nil }
        return "\(parts.joined(separator: " ")) free time"
    }
}

private struct TimelineAnchorRow: View {
    let label: String
    let time: Date
    let allDayEvents: [CalendarEvent]
    let freeTimeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let freeTimeText {
                Text(freeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !allDayEvents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allDayEvents) { event in
                            Label(event.title, systemImage: "sun.max.fill")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                    .padding(.top, 8)
                }
            }
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

struct TimelineTimePickerSheet: View {
    let task: Task
    let bounds: (start: Date, end: Date)
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    @State private var selectedTime: Date

    init(task: Task, bounds: (start: Date, end: Date), initialTime: Date, onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.task = task
        self.bounds = bounds
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Schedule \"\(task.title)\"")
                    .font(.headline)
                DatePicker(
                    "Start time",
                    selection: $selectedTime,
                    in: bounds.start...bounds.end,
                    displayedComponents: .hourAndMinute
                )
                #if os(macOS)
                .datePickerStyle(.field)
                #else
                .datePickerStyle(.wheel)
                #endif
                .labelsHidden()
                Text("Choose a time between 5 AM and 10 PM.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        onConfirm(selectedTime)
                    }
                }
            }
        }
    }
}
