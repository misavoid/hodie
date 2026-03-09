import Foundation
import Combine

@MainActor
final class FocusController: ObservableObject {
    @Published var isPresented = false
    @Published var activeTask: Task?
    @Published var activeSession: FocusSession?
    @Published var selectedPreset: FocusSession.SessionType = .pomodoro25
    @Published var customMinutes: Int = 25

    var timer: FocusTimerEngine { focusTimer }
    var remainingSeconds: TimeInterval { focusTimer.remaining }
    var totalSeconds: TimeInterval { max(focusTimer.duration, 1) }
    var state: FocusTimerEngine.State { focusTimer.state }
    var isBlockedByPomodoro: Bool { focusTimer.mode == .pomodoro }

    private let focusStore: FocusSessionStore
    private let focusTimer: FocusTimerEngine
    private var cancellables: Set<AnyCancellable> = []

    init(focusStore: FocusSessionStore, timer: FocusTimerEngine) {
        self.focusStore = focusStore
        self.focusTimer = timer
        focusTimer.completionHandler = { [weak self] in
            _Concurrency.Task { [weak self] in
                await MainActor.run {
                    self?.completeFromTimer()
                }
            }
        }
        focusTimer.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func begin(for task: Task?) {
        guard customMinutes > 0 else { return }
        guard !isBlockedByPomodoro else { return }
        let override = selectedPreset == .custom ? customMinutes : nil
        let session = focusStore.startSession(for: task, preset: selectedPreset, overrideDuration: override)
        activeTask = task
        activeSession = session
        isPresented = true
        focusTimer.start(durationMinutes: override ?? selectedPreset.defaultMinutes)
    }

    func pause() { focusTimer.pause() }
    func resume() { focusTimer.resume() }

    func cancel() {
        guard let session = activeSession else { return }
        focusStore.cancelSession(session)
        reset()
    }

    func completeManually() {
        guard let session = activeSession else { return }
        focusStore.endSession(session, completed: true)
        reset()
    }

    private func completeFromTimer() {
        guard let session = activeSession else { return }
        focusStore.endSession(session, completed: true)
        reset()
    }

    private func reset() {
        focusTimer.stop()
        activeSession = nil
        activeTask = nil
        isPresented = false
    }

    func recentSessions(limit: Int = 10) -> [FocusSession] {
        focusStore.history(limit: limit)
    }
}
