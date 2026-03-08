import Foundation

struct TimelineScheduleItem: Identifiable {
    enum Kind {
        case task(Task)
        case event(CalendarEvent)
    }

    let id: String
    let kind: Kind
    let start: Date
    let end: Date

    var durationMinutes: Int {
        max(1, Int(end.timeIntervalSince(start) / 60))
    }
}

struct TimelineScheduleLayout: Identifiable {
    let id: String
    let item: TimelineScheduleItem
    let laneIndex: Int
    let totalLanes: Int
}

struct TimelineScheduleBuilder {
    let startHour = 5
    let endHour = 22

    private let calendar = Calendar.current

    func layouts(for plan: DayPlan) -> [TimelineScheduleLayout] {
        let items = scheduleItems(for: plan)
        return layout(items: items)
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

    private func scheduleItems(for plan: DayPlan) -> [TimelineScheduleItem] {
        let bounds = dayBounds(for: plan.date)
        var items: [TimelineScheduleItem] = []

        for task in plan.scheduledTasks {
            guard let start = task.scheduledStart else { continue }
            let duration = task.estimatedDurationMinutes ?? 60
            let end = task.scheduledEnd ?? start.addingTimeInterval(TimeInterval(duration * 60))
            let clampedStart = max(bounds.start, start)
            let clampedEnd = min(bounds.end, end)
            guard clampedEnd > clampedStart else { continue }
            items.append(
                TimelineScheduleItem(
                    id: "task-\(task.id.uuidString)",
                    kind: .task(task),
                    start: clampedStart,
                    end: clampedEnd
                )
            )
        }

        for event in plan.calendarEvents where !event.isAllDay {
            let clampedStart = max(bounds.start, event.startDate)
            let clampedEnd = min(bounds.end, event.endDate)
            guard clampedEnd > clampedStart else { continue }
            items.append(
                TimelineScheduleItem(
                    id: "event-\(event.id)",
                    kind: .event(event),
                    start: clampedStart,
                    end: clampedEnd
                )
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }
    }

    private func layout(items: [TimelineScheduleItem]) -> [TimelineScheduleLayout] {
        guard !items.isEmpty else { return [] }
        var clusters: [[TimelineScheduleItem]] = []
        var currentCluster: [TimelineScheduleItem] = []
        var currentEnd = Date.distantPast

        for item in items {
            if currentCluster.isEmpty {
                currentCluster = [item]
                currentEnd = item.end
            } else if item.start < currentEnd {
                currentCluster.append(item)
                currentEnd = max(currentEnd, item.end)
            } else {
                clusters.append(currentCluster)
                currentCluster = [item]
                currentEnd = item.end
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        var layouts: [TimelineScheduleLayout] = []

        for cluster in clusters {
            var laneEndTimes: [Date] = []
            var clusterLayouts: [(TimelineScheduleItem, Int)] = []

            for item in cluster {
                var laneIndex = 0
                while laneIndex < laneEndTimes.count && item.start < laneEndTimes[laneIndex] {
                    laneIndex += 1
                }
                if laneIndex == laneEndTimes.count {
                    laneEndTimes.append(item.end)
                } else {
                    laneEndTimes[laneIndex] = item.end
                }
                clusterLayouts.append((item, laneIndex))
            }

            let totalLanes = max(1, laneEndTimes.count)
            layouts.append(contentsOf: clusterLayouts.map { entry in
                TimelineScheduleLayout(
                    id: entry.0.id,
                    item: entry.0,
                    laneIndex: entry.1,
                    totalLanes: totalLanes
                )
            })
        }

        return layouts
    }
}
