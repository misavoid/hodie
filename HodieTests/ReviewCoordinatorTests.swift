import Testing
@testable import Hodie

@MainActor
struct ReviewCoordinatorTests {
    @Test func summaryShowsCompletedAndUnfinished() async throws {
        let (taskStore, focusStore, _) = try TestUtilities.makeStores()
        let coordinator = ReviewCoordinator(taskStore: taskStore, focusStore: focusStore)
        let today = Date().startOfDay()
        let completed = taskStore.quickAdd(title: "Ship build")
        taskStore.plan(completed, for: today, interval: nil)
        taskStore.toggleCompletion(completed)

        let unfinished = taskStore.quickAdd(title: "Prep meeting")
        taskStore.plan(unfinished, for: today, interval: nil)

        let session = focusStore.startSession(for: completed, preset: .pomodoro25, overrideDuration: 1)
        focusStore.endSession(session, completed: true)

        let summary = coordinator.summary(for: today)
        #expect(summary.completed.contains(where: { $0.id == completed.id }))
        #expect(summary.unfinished.contains(where: { $0.id == unfinished.id }))
        #expect(!summary.focusSessions.isEmpty)
    }
}
