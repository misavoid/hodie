import SwiftUI

struct CombinedScheduleView: View {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [Task]
    var onDropTask: (UUID, Date) -> Void

    private let hours = Array(6...22)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    TimelineRow(
                        date: date,
                        hour: hour,
                        events: eventsForHour(hour),
                        tasks: tasksForHour(hour),
                        onDropTask: onDropTask
                    )
                }
            }
            .padding(.vertical, 12)
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
    var onDropTask: (UUID, Date) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 12)

            TimelineIndicator(isActive: hasContent, isFirst: hour == 6, isLast: hour == 22)

            VStack(alignment: .leading, spacing: 8) {
                if hasContent {
                    ForEach(events) { event in
                        TimelineCard(
                            title: event.title,
                            subtitle: "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))",
                            icon: "calendar",
                            tint: .indigo.opacity(0.3)
                        )
                    }
                    ForEach(tasks) { task in
                        TimelineCard(
                            title: task.title,
                            subtitle: task.estimatedDurationMinutes.map { "\($0) min" },
                            icon: "checkmark.circle.fill",
                            tint: Color.accentColor.opacity(0.25)
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
            .padding(.vertical, 8)
            .dropDestination(for: TaskDragItem.self) { items, _ in
                guard
                    let id = items.first?.id,
                    let startDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)
                else { return false }
                onDropTask(id, startDate)
                return true
            }
        }
        .padding(.horizontal)
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
}

private struct TimelineIndicator: View {
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isFirst ? 12 : 24)
                .opacity(isFirst ? 0 : 1)
            Circle()
                .fill(isActive ? Color.accentColor : Color(.systemGray4))
                .frame(width: 12, height: 12)
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 2, height: isLast ? 12 : 24)
                .opacity(isLast ? 0 : 1)
        }
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
