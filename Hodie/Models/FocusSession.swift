import Foundation
import SwiftData

@Model
final class FocusSession: Identifiable {
    enum SessionType: String, Codable, CaseIterable, Identifiable {
        case pomodoro25
        case deep50
        case custom

        var id: String { rawValue }
        var defaultMinutes: Int {
            switch self {
            case .pomodoro25: return 25
            case .deep50: return 50
            case .custom: return 0
            }
        }
        var label: String {
            switch self {
            case .pomodoro25: return "25m Focus"
            case .deep50: return "50m Deep"
            case .custom: return "Custom"
            }
        }
    }

    @Attribute(.unique) var id: UUID
    var task: Task?
    var startedAt: Date
    var endedAt: Date?
    var plannedDurationMinutes: Int
    var actualDurationMinutes: Int?
    var wasCompleted: Bool
    var sessionType: SessionType
    var notes: String?

    init(
        id: UUID = UUID(),
        task: Task?,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        plannedDurationMinutes: Int,
        actualDurationMinutes: Int? = nil,
        wasCompleted: Bool = false,
        sessionType: SessionType,
        notes: String? = nil
    ) {
        self.id = id
        self.task = task
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDurationMinutes = plannedDurationMinutes
        self.actualDurationMinutes = actualDurationMinutes
        self.wasCompleted = wasCompleted
        self.sessionType = sessionType
        self.notes = notes
    }

    func finish(at endDate: Date = .now, completed: Bool) {
        endedAt = endDate
        actualDurationMinutes = Int(endDate.timeIntervalSince(startedAt) / 60)
        wasCompleted = completed
    }
}
