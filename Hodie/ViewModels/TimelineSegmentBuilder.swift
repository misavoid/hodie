import Foundation

struct TimelineSegment: Identifiable {
    enum Kind {
        case anchor(String)
        case task(Task)
        case event(CalendarEvent)
    }

    let id: String
    let kind: Kind
    let start: Date
    let end: Date

    var isAnchor: Bool {
        if case .anchor = kind { return true }
        return false
    }
}

struct TimelineSegmentBuilder {
    let startHour = 5
    let endHour = 22

    private let calendar = Calendar.current

    func segments(for plan: DayPlan) -> [TimelineSegment] {
        let bounds = dayBounds(for: plan.date)
        var segments: [TimelineSegment] = [
            TimelineSegment(
                id: "anchor-start-\(bounds.start.timeIntervalSinceReferenceDate)",
                kind: .anchor("Start of day"),
                start: bounds.start,
                end: bounds.start
            )
        ]

        let scheduledTaskEntries = plan.scheduledTasks.compactMap { task -> (Date, Date, TimelineSegment.Kind)? in
            guard let start = task.scheduledStart else { return nil }
            let duration = task.estimatedDurationMinutes ?? 60
            let end = task.scheduledEnd ?? start.addingTimeInterval(TimeInterval(duration * 60))
            return (start, end, .task(task))
        }

        let eventEntries = plan.calendarEvents.compactMap { event -> (Date, Date, TimelineSegment.Kind)? in
            if event.isAllDay {
                return nil
            }
            let clampedStart = max(bounds.start, event.startDate)
            let clampedEnd = min(bounds.end, event.endDate)
            guard clampedEnd > bounds.start else { return nil }
            return (clampedStart, clampedEnd, .event(event))
        }

        let combined = (scheduledTaskEntries + eventEntries)
            .sorted { lhs, rhs in
                if lhs.0 == rhs.0 {
                    switch (lhs.2, rhs.2) {
                    case (.task, .event):
                        return true
                    case (.event, .task):
                        return false
                    default:
                        return lhs.1 < rhs.1
                    }
                }
                return lhs.0 < rhs.0
            }

        combined.forEach { entry in
            let start = min(bounds.end, max(bounds.start, entry.0))
            let end = max(start, min(bounds.end, entry.1))
            let id: String
            switch entry.2 {
            case .task(let task):
                id = "task-\(task.id.uuidString)"
            case .event(let event):
                id = "event-\(event.id)"
            case .anchor(let label):
                id = "anchor-\(label)-\(start.timeIntervalSinceReferenceDate)"
            }
            segments.append(
                TimelineSegment(
                    id: id,
                    kind: entry.2,
                    start: start,
                    end: end
                )
            )
        }

        segments.append(
            TimelineSegment(
                id: "anchor-end-\(bounds.end.timeIntervalSinceReferenceDate)",
                kind: .anchor("End of day"),
                start: bounds.end,
                end: bounds.end
            )
        )

        return segments
    }

    func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let dayStart = calendar.date(
            bySettingHour: startHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date

        let dayEnd = calendar.date(
            bySettingHour: endHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? dayStart.addingTimeInterval(17 * 3600)

        return (start: dayStart, end: dayEnd)
    }
}
