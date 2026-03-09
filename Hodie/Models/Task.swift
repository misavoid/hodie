import Foundation
import SwiftData

@Model
final class Task: Identifiable {
    enum Status: String, Codable, CaseIterable, Identifiable {
        case inbox
        case planned
        case scheduled
        case completed

        var id: String { rawValue }
    }

    enum Priority: String, Codable, CaseIterable, Identifiable {
        case low
        case normal
        case high

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .low: return "arrow.down"
            case .normal: return "equal"
            case .high: return "arrow.up"
            }
        }
    }

    enum TaskType: String, Codable, CaseIterable, Identifiable {
        case quickTick
        case task
        case projectTask

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .quickTick: return "Quick Tick"
            case .task: return "Task"
            case .projectTask: return "Project Task"
            }
        }

        var badgeIcon: String {
            switch self {
            case .quickTick: return "bolt.circle"
            case .task: return "checkmark.circle"
            case .projectTask: return "hammer.fill"
            }
        }

        var defaultDurationMinutes: Int {
            switch self {
            case .quickTick: return 5
            case .task: return 30
            case .projectTask: return 60
            }
        }
    }

    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var status: Status
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var plannedFor: Date?
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var estimatedDurationMinutes: Int?
    var completedAt: Date?
    var priority: Priority
    var orderIndex: Double
    var type: TaskType
    var source: String?
    var sourceListName: String?
    var recurrence: RecurrenceRule?
    @Relationship(deleteRule: .cascade, inverse: \FocusSession.task) var focusSessions: [FocusSession]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: Status = .inbox,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        dueDate: Date? = nil,
        plannedFor: Date? = nil,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        estimatedDurationMinutes: Int? = nil,
        completedAt: Date? = nil,
        priority: Priority = .normal,
        orderIndex: Double = Date.now.timeIntervalSinceReferenceDate,
        type: TaskType = .task,
        source: String? = nil,
        sourceListName: String? = nil,
        recurrence: RecurrenceRule? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.plannedFor = plannedFor?.startOfDay()
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.estimatedDurationMinutes = estimatedDurationMinutes ?? type.defaultDurationMinutes
        self.completedAt = completedAt
        self.priority = priority
        self.orderIndex = orderIndex
        self.type = type
        self.source = source
        self.sourceListName = sourceListName
        self.recurrence = recurrence
        self.focusSessions = []
    }

    func markCompleted(date: Date = .now) {
        status = .completed
        completedAt = date
        updatedAt = date
    }

    func reopenToInbox() {
        status = .inbox
        plannedFor = nil
        scheduledStart = nil
        scheduledEnd = nil
        completedAt = nil
        updatedAt = .now
    }

    func plan(for date: Date, interval: DateInterval?) {
        plannedFor = date.startOfDay()
        status = interval == nil ? .planned : .scheduled
        scheduledStart = interval?.start
        scheduledEnd = interval?.end
        updatedAt = .now
        if let interval {
            estimatedDurationMinutes = Int(interval.duration / 60)
        }
    }

    func reschedule(to interval: DateInterval?) {
        scheduledStart = interval?.start
        scheduledEnd = interval?.end
        status = interval == nil ? .planned : .scheduled
        updatedAt = .now
    }
}

struct RecurrenceRule: Codable, Hashable {
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case daily
        case weekly

        var id: String { rawValue }
    }

    var frequency: Frequency
    var interval: Int

    init(frequency: Frequency, interval: Int = 1) {
        self.frequency = frequency
        self.interval = max(1, interval)
    }
}

extension Task {
    var isReminderImport: Bool {
        guard let source else { return false }
        return source.hasPrefix("reminder:")
    }

    static func reminderSourcePrefix(for calendarID: String) -> String {
        "reminder:\(calendarID):"
    }

    static func reminderSourceID(calendarID: String, reminderID: String) -> String {
        reminderSourcePrefix(for: calendarID) + reminderID
    }

    var reminderListDisplayLabel: String? {
        guard isReminderImport else { return nil }
        return sourceListName
    }

    var shouldAppearInScheduledReminderSection: Bool {
        guard isReminderImport else { return false }
        if recurrence != nil { return true }
        return dueDate != nil
    }
}
