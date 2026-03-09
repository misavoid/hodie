import SwiftUI

struct TodayTimelineView: View {
    let layouts: [TimelineScheduleLayout]
    let allDayEvents: [CalendarEvent]
    let dayBounds: (start: Date, end: Date)
    let interactionState: TimelineInteractionState
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    private let anchorSpacing: CGFloat = 24

    private var sortedLayouts: [TimelineScheduleLayout] {
        layouts.sorted { lhs, rhs in
            if lhs.item.start == rhs.item.start {
                return lhs.item.end < rhs.item.end
            }
            return lhs.item.start < rhs.item.start
        }
    }

    private var showsHourMarkers: Bool {
        if case .placing = interactionState {
            return true
        }
        return false
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

    private var timelineBounds: (start: Date, end: Date) {
        guard let first = sortedLayouts.first else { return dayBounds }
        let earliestStart = first.item.start
        let latestEnd = sortedLayouts.reduce(first.item.end) { partialResult, layout in
            max(partialResult, layout.item.end)
        }
        if latestEnd <= earliestStart {
            let fallbackEnd = earliestStart.addingTimeInterval(15 * 60)
            return (start: earliestStart, end: fallbackEnd)
        }
        return (start: earliestStart, end: latestEnd)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TimelineAnchorHeader(
                    label: "Start of day",
                    time: dayBounds.start,
                    allDayEvents: allDayEvents
                )
                .padding(.bottom, anchorSpacing)

                TimelineCanvasView(
                    layouts: sortedLayouts,
                    nextStartLookup: nextStartLookup,
                    dayBounds: dayBounds,
                    timelineBounds: timelineBounds,
                    showsHourMarkers: showsHourMarkers,
                    onToggleTask: onToggleTask,
                    onFocusTask: onFocusTask,
                    onPlanTask: onPlanTask
                )
                .padding(.bottom, anchorSpacing)

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
    let timelineBounds: (start: Date, end: Date)
    let showsHourMarkers: Bool
    var onToggleTask: (Task) -> Void
    var onFocusTask: (Task) -> Void
    var onPlanTask: (Task) -> Void

    private let hourHeight: CGFloat = 60
    private let consecutiveEventSpacing: CGFloat = 10
    private let overlappingLaneSpacing: CGFloat = 8
    private let endOfDayInset: CGFloat = 32
    private let contiguousTolerance: TimeInterval = 1
    private var visibleMinutes: Double {
        max(1, timelineBounds.end.timeIntervalSince(timelineBounds.start) / 60)
    }
    private var basePointsPerMinute: CGFloat { hourHeight / 60 }
    private var scaledHeight: CGFloat {
        CGFloat(visibleMinutes) * basePointsPerMinute
    }
    private var layoutMetrics: LayoutMetrics {
        computeLayoutMetrics()
    }
    private var overlapAtStartLookup: [String: Bool] {
        var lookup: [String: Bool] = [:]
        for layout in layouts {
            let overlapsAnotherLane = layouts.contains { other in
                guard other.id != layout.id else { return false }
                guard other.laneIndex != layout.laneIndex else { return false }
                return other.item.start <= layout.item.start && layout.item.start < other.item.end
            }
            lookup[layout.id] = overlapsAnotherLane
        }
        return lookup
    }

    var body: some View {
        let metrics = layoutMetrics

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TimelineAxisView(
                    bounds: timelineBounds,
                    height: metrics.totalHeight,
                    showsHourMarkers: showsHourMarkers
                )
                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack(alignment: .topLeading) {
                        ForEach(layouts) { layout in
                            let startOffset = metrics.startOffsets[layout.id]
                                ?? rawOffset(for: layout.item.start, pointsPerMinute: metrics.pointsPerMinute)
                            let blockHeight = blockHeight(for: layout.item, pointsPerMinute: metrics.pointsPerMinute)
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
                .frame(height: metrics.totalHeight)
            }
            .frame(height: metrics.totalHeight)

            Color.clear
                .frame(height: endOfDayInset)
        }
    }
    private func laneWidth(for layout: TimelineScheduleLayout, totalWidth: CGFloat) -> CGFloat {
        let spacing = CGFloat(layout.totalLanes - 1) * 8
        return (totalWidth - spacing) / CGFloat(layout.totalLanes)
    }

    private func freeTime(for layout: TimelineScheduleLayout) -> String? {
        let nextStart = nextStartLookup[layout.id]
        let comparisonDate = nextStart ?? dayBounds.end
        let gap = comparisonDate.timeIntervalSince(layout.item.end)
        guard gap > 0 else { return nil }
        let totalMinutes = Int(gap / 60)
        guard let formatted = formattedDuration(minutes: totalMinutes) else { return nil }
        if nextStart == nil {
            return "\(formatted) until end of day"
        }
        return "\(formatted) free time"
    }

    private func formattedDuration(minutes totalMinutes: Int) -> String? {
        guard totalMinutes > 0 else { return nil }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes) min")
        }
        guard !components.isEmpty else { return nil }
        return components.joined(separator: " ")
    }

    private func computeLayoutMetrics() -> LayoutMetrics {
        guard !layouts.isEmpty else {
            return LayoutMetrics(
                pointsPerMinute: basePointsPerMinute,
                totalHeight: scaledHeight,
                startOffsets: [:]
            )
        }

        var height = max(scaledHeight, 44)
        var placement: LayoutPlacement = ([:], height)
        let maxIterations = 6
        let overlapLookup = overlapAtStartLookup

        for _ in 0..<maxIterations {
            let ppm = pointsPerMinute(forHeight: height)
            placement = placements(pointsPerMinute: ppm, overlapLookup: overlapLookup)
            let newHeight = max(scaledHeight, placement.maxBottom)
            if abs(newHeight - height) < 0.5 {
                return LayoutMetrics(pointsPerMinute: ppm, totalHeight: newHeight, startOffsets: placement.offsets)
            }
            height = newHeight
        }

        let finalPPM = pointsPerMinute(forHeight: height)
        let finalPlacement = placements(pointsPerMinute: finalPPM, overlapLookup: overlapLookup)
        let finalHeight = max(scaledHeight, finalPlacement.maxBottom)
        return LayoutMetrics(pointsPerMinute: finalPPM, totalHeight: finalHeight, startOffsets: finalPlacement.offsets)
    }

    private func pointsPerMinute(forHeight height: CGFloat) -> CGFloat {
        guard visibleMinutes > 0 else { return basePointsPerMinute }
        return height / CGFloat(visibleMinutes)
    }

    private func placements(pointsPerMinute: CGFloat, overlapLookup: [String: Bool]) -> LayoutPlacement {
        var offsets: [String: CGFloat] = [:]
        var laneBottoms: [Int: CGFloat] = [:]
        var laneLastEndTimes: [Int: Date] = [:]
        var maxBottom: CGFloat = 0

        for layout in layouts {
            let baseStart = rawOffset(for: layout.item.start, pointsPerMinute: pointsPerMinute)
            let laneBottom = laneBottoms[layout.laneIndex] ?? .leastNormalMagnitude
            let lastEnd = laneLastEndTimes[layout.laneIndex]
            let isContiguous = lastEnd.map { abs(layout.item.start.timeIntervalSince($0)) <= contiguousTolerance } ?? false
            let startOverlapsAnotherLane = overlapLookup[layout.id] ?? false

            let adjustedStart: CGFloat
            if laneBottom.isFinite {
                let spacing: CGFloat
                if isContiguous {
                    spacing = startOverlapsAnotherLane ? overlappingLaneSpacing : consecutiveEventSpacing
                } else {
                    spacing = 0
                }
                adjustedStart = max(baseStart, laneBottom + spacing)
            } else {
                adjustedStart = baseStart
            }
            offsets[layout.id] = adjustedStart

            let blockHeight = blockHeight(for: layout.item, pointsPerMinute: pointsPerMinute)
            let bottom = adjustedStart + blockHeight
            laneBottoms[layout.laneIndex] = bottom
            laneLastEndTimes[layout.laneIndex] = layout.item.end
            maxBottom = max(maxBottom, bottom)
        }

        return (offsets, maxBottom)
    }

    private func rawOffset(for date: Date, pointsPerMinute: CGFloat) -> CGFloat {
        let minutes = date.timeIntervalSince(timelineBounds.start) / 60
        return CGFloat(minutes) * pointsPerMinute
    }

    private func blockHeight(for item: TimelineScheduleItem, pointsPerMinute: CGFloat) -> CGFloat {
        max(44, CGFloat(item.durationMinutes) * pointsPerMinute)
    }

    private typealias LayoutPlacement = (offsets: [String: CGFloat], maxBottom: CGFloat)

    private struct LayoutMetrics {
        let pointsPerMinute: CGFloat
        let totalHeight: CGFloat
        let startOffsets: [String: CGFloat]
    }
}

private struct TimelineAxisView: View {
    let bounds: (start: Date, end: Date)
    let height: CGFloat
    let showsHourMarkers: Bool

    private let calendar = Calendar.current

    private var totalMinutes: Double {
        bounds.end.timeIntervalSince(bounds.start) / 60
    }

    private var hourMarkers: [Date] {
        guard showsHourMarkers else { return [] }
        var markers: [Date] = []
        var current = bounds.start
        while current <= bounds.end {
            markers.append(current)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
            if next == current { break }
            current = next
        }
        return markers
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Capsule()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: height)

            if showsHourMarkers {
                ForEach(hourMarkers, id: \.self) { marker in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(marker.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 1)
                            .opacity(0.7)
                    }
                    .offset(y: markerOffset(for: marker))
                }
            }
        }
        .frame(width: showsHourMarkers ? 84 : 24, height: height, alignment: .topTrailing)
    }

    private func markerOffset(for date: Date) -> CGFloat {
        let minutes = date.timeIntervalSince(bounds.start) / 60
        guard totalMinutes > 0 else { return 0 }
        let pointsPerMinute = height / CGFloat(totalMinutes)
        let offset = CGFloat(minutes) * pointsPerMinute
        let clamped = min(max(offset - 10, 0), height - 24)
        return clamped
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
