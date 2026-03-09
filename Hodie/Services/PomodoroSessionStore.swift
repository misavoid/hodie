import Foundation
import SwiftData

@MainActor
final class PomodoroSessionStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createSession(
        goal: String,
        notes: String?,
        pomodoroCount: Int,
        perPomGoals: [String],
        configuration: PomodoroConfiguration
    ) -> PomodoroSession {
        let session = PomodoroSession(goal: goal, notes: notes, configuration: configuration)
        session.blocks = makeBlocks(
            pomodoroCount: pomodoroCount,
            perPomGoals: perPomGoals,
            configuration: configuration,
            session: session
        )
        context.insert(session)
        save()
        return session
    }

    func activeSession() -> PomodoroSession? {
        var descriptor = FetchDescriptor<PomodoroSession>(
            sortBy: [SortDescriptor(\PomodoroSession.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.first { session in
            session.status != .completed && session.status != .cancelled
        }
    }

    func session(with id: UUID) -> PomodoroSession? {
        var descriptor = FetchDescriptor<PomodoroSession>(
            sortBy: [SortDescriptor(\PomodoroSession.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.first { $0.id == id }
    }

    func save() {
        try? context.save()
    }

    func delete(_ session: PomodoroSession) {
        context.delete(session)
        save()
    }

    private func makeBlocks(
        pomodoroCount: Int,
        perPomGoals: [String],
        configuration: PomodoroConfiguration,
        session: PomodoroSession
    ) -> [PomodoroBlock] {
        var blocks: [PomodoroBlock] = []
        var index = 0
        for focusIndex in 0..<max(1, pomodoroCount) {
            let goal = perPomGoals[safe: focusIndex]
            let focusBlock = PomodoroBlock(
                index: index,
                type: .focus,
                goal: goal,
                plannedDurationSeconds: configuration.focusDuration,
                session: session
            )
            blocks.append(focusBlock)
            index += 1
            let isLast = focusIndex == pomodoroCount - 1
            guard !isLast else { continue }
            let breakType: PomodoroBlock.BlockType = ((focusIndex + 1) % configuration.longBreakInterval == 0) ? .longBreak : .shortBreak
            let breakDuration = breakType == .longBreak ? configuration.longBreakDuration : configuration.shortBreakDuration
            let breakBlock = PomodoroBlock(
                index: index,
                type: breakType,
                plannedDurationSeconds: breakDuration,
                session: session
            )
            blocks.append(breakBlock)
            index += 1
        }
        return blocks
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
