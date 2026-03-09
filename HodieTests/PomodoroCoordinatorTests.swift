import Testing
import SwiftData
@testable import Hodie

@MainActor
struct PomodoroCoordinatorTests {
    @Test func startSessionCreatesBlocks() async throws {
        let container = try TestUtilities.inMemoryContainer()
        let store = PomodoroSessionStore(context: container.mainContext)
        let timer = FocusTimerEngine()
        let coordinator = PomodoroCoordinator(store: store, timer: timer)

        coordinator.startSession(goal: "Deep work", pomodoroCount: 2, perPomGoals: ["Outline", "Draft"])

        #expect(coordinator.state != nil)
        #expect(coordinator.state?.totalFocusCount == 2)
        #expect(coordinator.state?.currentBlock?.type == .focus)
        #expect(coordinator.state?.currentBlock?.goal == "Outline")
    }

    @Test func advancingTimerMovesThroughBlocks() async throws {
        let container = try TestUtilities.inMemoryContainer()
        let store = PomodoroSessionStore(context: container.mainContext)
        let timer = FocusTimerEngine()
        let coordinator = PomodoroCoordinator(store: store, timer: timer)

        coordinator.startSession(goal: "Cycle", pomodoroCount: 1, perPomGoals: ["Task"])
        #expect(coordinator.state?.currentBlock?.type == .focus)

        timer.advance(by: 25 * 60)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(coordinator.state?.currentBlock == nil)
        #expect(coordinator.state?.status == .completed)
    }

    @Test func pauseAndResumePersistsRemainingTime() async throws {
        let container = try TestUtilities.inMemoryContainer()
        let store = PomodoroSessionStore(context: container.mainContext)
        let timer = FocusTimerEngine()
        let coordinator = PomodoroCoordinator(store: store, timer: timer)

        coordinator.startSession(goal: "Pause Flow", pomodoroCount: 1, perPomGoals: [])
        timer.advance(by: 60)
        coordinator.pauseSession()

        let remainingAfterPause = timer.remaining
        #expect(coordinator.state?.status == .paused)

        coordinator.resumeSession()
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(timer.state == .running)
        #expect(timer.remaining <= remainingAfterPause)
    }
}
