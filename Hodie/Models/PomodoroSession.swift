import Foundation
import SwiftData

struct PomodoroConfiguration: Codable, Equatable {
    var focusDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var longBreakInterval: Int

    static let `default` = PomodoroConfiguration(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 30 * 60,
        longBreakInterval: 4
    )
}

@Model
final class PomodoroSession: Identifiable {
    enum Status: String, Codable, CaseIterable, Identifiable {
        case planned
        case active
        case paused
        case completed
        case cancelled

        var id: String { rawValue }
    }

    @Attribute(.unique) var id: UUID
    var goal: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var status: Status
    var currentIndex: Int
    var focusDurationSeconds: Double
    var shortBreakDurationSeconds: Double
    var longBreakDurationSeconds: Double
    var longBreakInterval: Int
    @Relationship(deleteRule: .cascade, inverse: \PomodoroBlock.session) var blocks: [PomodoroBlock]

    init(
        id: UUID = UUID(),
        goal: String,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: Status = .planned,
        currentIndex: Int = 0,
        configuration: PomodoroConfiguration = .default,
        blocks: [PomodoroBlock] = []
    ) {
        self.id = id
        self.goal = goal
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = nil
        self.status = status
        self.currentIndex = currentIndex
        self.focusDurationSeconds = configuration.focusDuration
        self.shortBreakDurationSeconds = configuration.shortBreakDuration
        self.longBreakDurationSeconds = configuration.longBreakDuration
        self.longBreakInterval = configuration.longBreakInterval
        self.blocks = blocks
    }

    var configuration: PomodoroConfiguration {
        PomodoroConfiguration(
            focusDuration: focusDurationSeconds,
            shortBreakDuration: shortBreakDurationSeconds,
            longBreakDuration: longBreakDurationSeconds,
            longBreakInterval: longBreakInterval
        )
    }
}
