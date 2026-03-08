import Foundation

@MainActor
final class ReviewCoordinator {
    private let taskStore: TaskStore
    private let focusStore: FocusSessionStore

    init(taskStore: TaskStore, focusStore: FocusSessionStore) {
        self.taskStore = taskStore
        self.focusStore = focusStore
    }

    func summary(for date: Date) -> ReviewSummary {
        let dayPlan = taskStore.dayPlan(for: date)
        let unfinished = dayPlan.scheduledTasks.filter { $0.status != .completed } + dayPlan.flexibleTasks.filter { $0.status != .completed }
        let completed = dayPlan.completedTasks
        let sessions = focusStore.history(limit: 100).filter { session in
            guard let end = session.endedAt else { return false }
            return end.isSameDay(as: date)
        }
        return ReviewSummary(date: date, completed: completed, unfinished: unfinished, focusSessions: sessions)
    }

    func rolloverAll(_ tasks: [Task], destination: RolloverDestination) {
        tasks.forEach { taskStore.rollover($0, destination: destination) }
    }
}
