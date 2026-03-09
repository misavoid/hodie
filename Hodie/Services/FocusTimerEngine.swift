import Foundation
import Combine

@MainActor
final class FocusTimerEngine: ObservableObject {
    enum State {
        case idle
        case running
        case paused
        case completed
    }
    enum Mode {
        case none
        case single
        case pomodoro
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var mode: Mode = .none

    private var timer: Timer?
    private var lastFireDate: Date?
    var completionHandler: (() -> Void)?
    var pomodoroCompletionHandler: (() -> Void)?

    func start(durationMinutes: Int) {
        start(durationSeconds: TimeInterval(durationMinutes * 60), mode: .single)
    }

    func startPomodoroBlock(durationSeconds: TimeInterval) {
        start(durationSeconds: durationSeconds, mode: .pomodoro)
    }

    private func start(durationSeconds: TimeInterval, mode: Mode) {
        duration = max(1, durationSeconds)
        remaining = duration
        state = .running
        self.mode = mode
        scheduleTimer()
    }

    func attachExisting(durationSeconds: TimeInterval, remainingSeconds: TimeInterval, state: State, mode: Mode = .single) {
        duration = max(1, durationSeconds)
        remaining = min(duration, max(0, remainingSeconds))
        self.state = state
        self.mode = mode
        if state == .running {
            scheduleTimer()
        }
    }

    func pause() {
        guard state == .running else { return }
        invalidateTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        scheduleTimer()
    }

    func stop() {
        invalidateTimer()
        remaining = 0
        duration = 0
        state = .idle
        mode = .none
        completionHandler = nil
        pomodoroCompletionHandler = nil
    }

    private func scheduleTimer() {
        invalidateTimer()
        lastFireDate = .now
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                self.tick()
            }
        }
    }

    private func tick() {
        guard state == .running else { return }
        let now = Date()
        if let lastFireDate {
            remaining -= now.timeIntervalSince(lastFireDate)
        } else {
            remaining -= 1
        }
        lastFireDate = now
        if remaining <= 0 {
            remaining = 0
            state = .completed
            invalidateTimer()
            switch mode {
            case .single:
                completionHandler?()
            case .pomodoro:
                pomodoroCompletionHandler?()
            case .none:
                break
            }
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
        lastFireDate = nil
    }

#if DEBUG
    func advance(by seconds: TimeInterval) {
        guard state == .running else { return }
        remaining -= seconds
        if remaining <= 0 {
            remaining = 0
            state = .completed
            invalidateTimer()
            switch mode {
            case .single:
                completionHandler?()
            case .pomodoro:
                pomodoroCompletionHandler?()
            case .none:
                break
            }
        }
    }
#endif
}
