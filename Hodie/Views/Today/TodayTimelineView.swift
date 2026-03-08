import SwiftUI

struct TodayTimelineView: View {
    let layouts: [TimelineScheduleLayout]
    let allDayEvents: [CalendarEvent]
    let dayBounds: (start: Date, end: Date)
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    private var sortedLayouts: [TimelineScheduleLayout] {
        layouts.sorted { lhs, rhs in
            if lhs.item.start == rhs.item.start {
                return lhs.item.end < rhs.item.end
            }
            return lhs.item.start < rhs.item.start
        }
    }

    private var nextStartLookup: [String: Date] {
        var lookup: [String: Date] = [:]
        let sorted = sortedLayouts
        for (index, layout) in sorted.enumerated() {
            let upcoming = sorted[(index + 1)...].first(where: { $0.item.start >= layout.item.end })
            if let upcoming {
                lookup[layout.id] = upcoming.item.start
            }
        }
        return lookup
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TimelineAnchorHeader(
                    label: "Start of day",
                    time: dayBounds.start,
                    allDayEvents: allDayEvents
                )

                TimelineCanvasView(
                    layouts: sortedLayouts,
                    nextStartLookup: nextStartLookup,
                    dayBounds: dayBounds,
                    onToggleTask: onToggleTask,
                    onFocusTask: onFocusTask,
                    onPlanTask: onPlanTask
                )

                TimelineAnchorFooter(label: "End of day", time: dayBounds.end)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct TimelineCanvasView: View {
    let layouts: [TimelineScheduleLayout]
    let nextStartLookup: [String: Date]
    let dayBounds: (start: Date, end: Date)
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    private let hourHeight: CGFloat = 60
    private var totalMinutes: Double {
        dayBounds.end.timeIntervalSince(dayBounds.start) / 60
    }
    private var totalHeight: CGFloat {
        CGFloat(totalMinutes) * (hourHeight / 60)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TimelineAxisView(bounds: dayBounds, height: totalHeight)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(layouts) { layout in
                        let startOffset = offset(for: layout.item.start)
                        let blockHeight = max(44, height(for: layout.item))
                        let laneWidth = laneWidth(for: layout, totalWidth: width)
                        let xPosition = CGFloat(layout.laneIndex) * (laneWidth + 8)
                        TimelineBlockView(
                            layout: layout,
                            freeTimeText: freeTime(for: layout),
                            onToggleTask: onToggleTask,
                            onFocusTask: onFocusTask,
                            onPlanTask: onPlanTask
                        )
                        .frame(width: laneWidth, height: blockHeight, alignment: .topLeading)
                        .position(
                            x: xPosition + laneWidth / 2,
                            y: startOffset + blockHeight / 2
                        )
                    }
                }
            }
            .frame(height: totalHeight)
        }
        .frame(height: totalHeight)
    }

    private func offset(for date: Date) -> CGFloat {
        let minutes = date.timeIntervalSince(dayBounds.start) / 60
        return CGFloat(minutes) * (hourHeight / 60)
    }

    private func height(for item: TimelineScheduleItem) -> CGFloat {
        CGFloat(item.durationMinutes) * (hourHeight / 60)
    }

    private func laneWidth(for layout: TimelineScheduleLayout, totalWidth: CGFloat) -> CGFloat {
        let spacing = CGFloat(layout.totalLanes - 1) * 8
        return (totalWidth - spacing) / CGFloat(layout.totalLanes)
    }

    private func freeTime(for layout: TimelineScheduleLayout) -> String? {
        guard let nextStart = nextStartLookup[layout.id] else { return nil }
        let gap = nextStart.timeIntervalSince(layout.item.end)
        guard gap >= 60 else { return nil }
        let totalMinutes = Int(gap / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes)m")
        }
        guard !components.isEmpty else { return nil }
        return "\(components.joined(separator: " ")) free time"
    }
}

private struct TimelineAxisView: View {
    let bounds: (start: Date, end: Date)
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bounds.start.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: height - 32)
            Text(bounds.end.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, alignment: .leading)
    }
}

private struct TimelineBlockView: View {
    let layout: TimelineScheduleLayout
    let freeTimeText: String?
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch layout.item.kind {
            case .task(let task):
                TimelineTaskBlock(
                    task: task,
                    freeTimeText: freeTimeText,
                    onToggle: { onToggleTask(task) },
                    onFocus: { onFocusTask(task) },
                    onPlan: { onPlanTask(task) }
                )
            case .event(let event):
                TimelineEventBlock(
                    event: event,
                    start: layout.item.start,
                    end: layout.item.end,
                    freeTimeText: freeTimeText
                )
            }
        }
    }
}

private struct TimelineTaskBlock: View {
    let task: Task
    let freeTimeText: String?
    var onToggle: () -> Void
    var onFocus: () -> Void
    var onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.status == .completed ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(2)
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
            }
            HStack(spacing: 8) {
                Button(action: onFocus) {
                    Label("Focus", systemImage: "timer")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)

                Button(action: onPlan) {
                    Label("Reschedule", systemImage: "calendar.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            if let freeTimeText {
                Text(freeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
    }
}

private struct TimelineEventBlock: View {
    let event: CalendarEvent
    let start: Date
    let end: Date
    let freeTimeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                    Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            if let freeTimeText {
                Text(freeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.indigo.opacity(0.1))
        )
    }
}

private struct TimelineAnchorHeader: View {
    let label: String
    let time: Date
    let allDayEvents: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !allDayEvents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allDayEvents) { event in
                            Label(event.title, systemImage: "sun.max.fill")
                                .lineLimit(1)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct TimelineAnchorFooter: View {
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
        .padding(.horizontal)
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
