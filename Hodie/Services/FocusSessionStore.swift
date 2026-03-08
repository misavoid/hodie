import Foundation
import SwiftData

@MainActor
final class FocusSessionStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func startSession(for task: Task?, preset: FocusSession.SessionType, overrideDuration: Int? = nil) -> FocusSession {
        let defaultMinutes = preset == .custom ? 25 : preset.defaultMinutes
        let minutes = overrideDuration ?? defaultMinutes
        let session = FocusSession(task: task, plannedDurationMinutes: minutes, sessionType: preset)
        context.insert(session)
        save()
        return session
    }

    func endSession(_ session: FocusSession, completed: Bool) {
        session.finish(at: .now, completed: completed)
        if completed, let task = session.task {
            task.markCompleted()
        }
        save()
    }

    func cancelSession(_ session: FocusSession) {
        context.delete(session)
        save()
    }

    func history(limit: Int = 20) -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\FocusSession.startedAt, order: .reverse)], fetchLimit: limit)
        return (try? context.fetch(descriptor)) ?? []
    }

    private func save() {
        try? context.save()
    }
}
