import SwiftUI

struct TaskRowView: View {
    let task: Task
    var showTime: Bool = false
    var onToggle: (() -> Void)?
    var onFocus: (() -> Void)?
    var onPlan: (() -> Void)?
    var onDelete: (() -> Void)?

    var isDraggable: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onToggle?() }) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .completed ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .completed ? "Mark \(task.title) incomplete" : "Complete \(task.title)")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.status == .completed)
                    Spacer()
                    if let estimated = task.estimatedDurationMinutes {
                        Label("\(estimated)m", systemImage: "clock")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    if task.priority == .high {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if showTime, let start = task.scheduledStart, let end = task.scheduledEnd {
                    Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if task.isReminderImport {
                    ReminderOriginBadge()
                }
            }

            VStack(spacing: 6) {
                if let onFocus {
                    Button(action: onFocus) {
                        Image(systemName: "timer")
                    }
                    .buttonStyle(.borderless)
                    .help("Start focus")
                    .accessibilityLabel("Start focus for \(task.title)")
                }
                if let onPlan {
                    Button(action: onPlan) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Plan \(task.title)")
                }
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete \(task.title)")
                }
            }
        }
        .padding(.vertical, 8)
        .if(isDraggable) { view in
            view.draggable(TaskDragItem(id: task.id)) {
                Text(task.title)
            }
        }
    }
}

private struct ReminderOriginBadge: View {
    var body: some View {
        Label("Reminders", systemImage: "arrow.triangle.turn.up.right.circle.fill")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.secondary)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .accessibilityLabel("Imported from Reminders")
    }
}
