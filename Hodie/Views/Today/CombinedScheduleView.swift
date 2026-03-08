import SwiftUI

struct CombinedScheduleView: View {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [Task]
    var onDropTask: (UUID, Date) -> Void

    @State private var expandedHour: Int?

    private let hours = Array(5...22)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    TimelineRow(
                        date: date,
                        hour: hour,
                        events: eventsForHour(hour),
                        tasks: tasksForHour(hour),
                        expandedHour: $expandedHour,
                        onDropTask: onDropTask
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func eventsForHour(_ hour: Int) -> [CalendarEvent] {
        events.filter { !$0.isAllDay && $0.startDate.hourComponent == hour }
    }

    private func tasksForHour(_ hour: Int) -> [Task] {
        tasks.filter {
            guard let start = $0.scheduledStart else { return false }
            return Calendar.current.component(.hour, from: start) == hour
        }
    }
}

private struct TimelineRow: View {
    let date: Date
    let hour: Int
    let events: [CalendarEvent]
    let tasks: [Task]
    @Binding var expandedHour: Int?
    var onDropTask: (UUID, Date) -> Void

    private let collapsedHeight: CGFloat = 52
    private let expandedHeight: CGFloat = 132

    private var isExpanded: Bool { expandedHour == hour }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: isExpanded ? 6 : 0) {
                Text(timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isExpanded {
                    ForEach(intermediateTimeLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 48, alignment: .trailing)

            TimelineIndicator(
                isActive: hasContent,
                isFirst: hour == 5,
                isLast: hour == 22,
                expanded: isExpanded
            )

            VStack(alignment: .leading, spacing: 8) {
                if hasContent {
                    ForEach(events) { event in
                        TimelineCard(
                            title: event.title,
                            subtitle: "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))",
                            icon: "calendar",
                            tint: .indigo.opacity(0.28)
                        )
                    }
                    ForEach(tasks) { task in
                        TimelineCard(
                            title: task.title,
                            subtitle: task.estimatedDurationMinutes.map { "\($0) min" },
                            icon: "checkmark.circle.fill",
                            tint: Color.accentColor.opacity(0.2)
                        )
                        .draggable(TaskDragItem(id: task.id)) {
                            Text(task.title)
                        }
                    }
                } else {
                    Text("Free")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, isExpanded ? 12 : 4)
        .frame(minHeight: isExpanded ? expandedHeight : collapsedHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isExpanded ? Color(.secondarySystemBackground) : Color.clear)
                .shadow(color: isExpanded ? Color.black.opacity(0.05) : .clear, radius: 6, x: 0, y: 2)
        )
        .dropDestination(
            for: TaskDragItem.self,
            action: { items, location in
                guard
                    let id = items.first?.id,
                    let startDate = startDate(for: location.y)
                else { return false }
                onDropTask(id, startDate)
                expandedHour = nil
                return true
            }
        ) { hovering in
            if hovering {
                expandedHour = hour
            } else if expandedHour == hour {
                expandedHour = nil
            }
        }
        .animation(.easeInOut(duration: 0.18), value: expandedHour)
    }

    private var hasContent: Bool {
        !(events.isEmpty && tasks.isEmpty)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        if let displayDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
            return formatter.string(from: displayDate)
        }
        return "\(hour):00"
    }

    private var intermediateTimeLabels: [String] {
        [15, 30, 45].compactMap {
            Calendar.current.date(bySettingHour: hour, minute: $0, second: 0, of: date)?.formatted(date: .omitted, time: .shortened)
        }
    }

    private func startDate(for verticalLocation: CGFloat) -> Date? {
        let height = isExpanded ? expandedHeight : collapsedHeight
        let clamped = max(0, min(verticalLocation, height))
        let ratio = clamped / height
        let minute = max(0, min(59, Int((ratio * 60).rounded(.down))))
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

}

private struct TimelineIndicator: View {
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool
    let expanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isFirst ? 6 : (expanded ? 18 : 12))
                .opacity(isFirst ? 0 : 1)
            Circle()
                .fill(isActive ? Color.accentColor : Color(.systemGray4))
                .frame(width: expanded ? 16 : 10, height: expanded ? 16 : 10)
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(expanded ? 0.4 : 0), lineWidth: expanded ? 4 : 0)
                )
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isLast ? 6 : (expanded ? 28 : 12))
                .opacity(isLast ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.15), value: expanded)
    }
}

private struct TimelineCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.primary)
                .padding(8)
                .background(tint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

private extension Date {
    var hourComponent: Int {
        Calendar.current.component(.hour, from: self)
    }
}
