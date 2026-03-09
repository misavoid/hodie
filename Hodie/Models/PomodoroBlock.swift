import Foundation
import SwiftData

@Model
final class PomodoroBlock: Identifiable {
    enum BlockType: String, Codable, CaseIterable, Identifiable {
        case focus
        case shortBreak
        case longBreak

        var id: String { rawValue }
    }

    enum Status: String, Codable, CaseIterable, Identifiable {
        case pending
        case active
        case completed

        var id: String { rawValue }
    }

    @Attribute(.unique) var id: UUID
    var index: Int
    var type: BlockType
    var goal: String?
    var outcome: String?
    var plannedDurationSeconds: Double
    var startedAt: Date?
    var endedAt: Date?
    var remainingOverrideSeconds: Double?
    var status: Status
    var session: PomodoroSession?

    init(
        id: UUID = UUID(),
        index: Int,
        type: BlockType,
        goal: String? = nil,
        plannedDurationSeconds: Double,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        remainingOverrideSeconds: Double? = nil,
        status: Status = .pending,
        session: PomodoroSession? = nil
    ) {
        self.id = id
        self.index = index
        self.type = type
        self.goal = goal
        self.plannedDurationSeconds = plannedDurationSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.remainingOverrideSeconds = remainingOverrideSeconds
        self.status = status
        self.session = session
    }

    var isFocus: Bool { type == .focus }
}
