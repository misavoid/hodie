import Foundation
import Combine

@MainActor
final class PomodoroCoordinator: ObservableObject {
    struct ViewState: Equatable, Identifiable {
        struct Block: Equatable, Identifiable {
            var id: UUID
            var index: Int
            var type: PomodoroBlock.BlockType
            var goal: String?
            var outcome: String?
            var plannedDurationSeconds: Double
            var status: PomodoroBlock.Status
            var focusOrdinal: Int?

            var isFocus: Bool { type == .focus }
        }

        var id: UUID
        var goal: String
        var notes: String?
        var createdAt: Date
        var status: PomodoroSession.Status
        var blocks: [Block]
        var currentIndex: Int
        var configuration: PomodoroConfiguration

        var currentBlock: Block? {
            guard blocks.indices.contains(currentIndex) else { return nil }
            return blocks[currentIndex]
        }

        var completedFocusCount: Int {
            blocks.filter { $0.isFocus && $0.status == .completed }.count
        }

        var totalFocusCount: Int {
            blocks.filter { $0.isFocus }.count
        }
    }

    @Published private(set) var state: ViewState?

    var isRunning: Bool { timer.state == .running && timer.mode == .pomodoro }

    private let store: PomodoroSessionStore
    private let timer: FocusTimerEngine
    private var activeSession: PomodoroSession?

    init(store: PomodoroSessionStore, timer: FocusTimerEngine) {
        self.store = store
        self.timer = timer
    }

    func restoreActiveSession() {
        guard activeSession == nil else {
            updateViewState()
            return
        }
        guard let session = store.activeSession() else {
            timer.stop()
            updateViewState()
            return
        }
        activeSession = session
        normalize(session: session)
        attachTimerIfNeeded(for: session)
        updateViewState()
    }

    func startSession(
        goal: String,
        pomodoroCount: Int,
        perPomGoals: [String],
        notes: String? = nil,
        configuration: PomodoroConfiguration? = nil
    ) {
        if let session = activeSession {
            cancel(session: session)
        }
        let resolvedConfiguration = configuration ?? .default
        let session = store.createSession(
            goal: goal.isEmpty ? "Pomodoro Session" : goal,
            notes: notes,
            pomodoroCount: pomodoroCount,
            perPomGoals: perPomGoals,
            configuration: resolvedConfiguration
        )
        activeSession = session
        updateViewState()
        beginBlock(at: 0)
    }

    func pauseSession() {
        guard let session = activeSession,
              let block = currentBlock(in: session),
              timer.mode == .pomodoro else { return }
        timer.pause()
        block.remainingOverrideSeconds = timer.remaining
        block.startedAt = nil
        session.status = .paused
        session.updatedAt = .now
        store.save()
        updateViewState()
    }

    func resumeSession() {
        guard let session = activeSession,
              let block = currentBlock(in: session) else { return }
        beginBlock(at: session.currentIndex, resumeFromPause: true)
    }

    func skipCurrentBreak() {
        guard let session = activeSession,
              let block = currentBlock(in: session),
              block.type != .focus else { return }
        block.status = .completed
        block.endedAt = .now
        block.startedAt = block.startedAt ?? .now
        block.remainingOverrideSeconds = nil
        session.updatedAt = .now
        advanceToNextBlock()
    }

    func completeSession(withNotes notes: String? = nil) {
        guard let session = activeSession else { return }
        session.notes = notes
        finish(session: session, cancelled: false)
    }

    func cancelActiveSession() {
        guard let session = activeSession else { return }
        cancel(session: session)
    }

    func updateCurrentBlockGoal(_ goal: String) {
        guard let session = activeSession,
              let block = currentBlock(in: session),
              block.type == .focus else { return }
        block.goal = goal
        session.updatedAt = .now
        store.save()
        updateViewState()
    }

    // MARK: - Private helpers

    private func beginBlock(at index: Int, resumeFromPause: Bool = false) {
        guard let session = activeSession else { return }
        ensureSortedBlocks(for: session)
        guard session.blocks.indices.contains(index) else {
            finish(session: session, cancelled: false)
            return
        }
        session.currentIndex = index
        let block = session.blocks[index]
        let now = Date()
        block.status = .active
        block.startedAt = now
        block.endedAt = nil
        let remaining: TimeInterval
        if resumeFromPause, let storedRemaining = block.remainingOverrideSeconds {
            remaining = max(1, storedRemaining)
        } else if let override = block.remainingOverrideSeconds {
            remaining = max(1, override)
        } else {
            remaining = block.plannedDurationSeconds
        }
        block.remainingOverrideSeconds = nil
        session.status = .active
        session.updatedAt = now
        timer.pomodoroCompletionHandler = { [weak self] in
            _Concurrency.Task { [weak self] in
                await MainActor.run {
                    self?.completeActiveBlockFromTimer()
                }
            }
        }
        if resumeFromPause {
            timer.attachExisting(
                durationSeconds: block.plannedDurationSeconds,
                remainingSeconds: remaining,
                state: .running,
                mode: .pomodoro
            )
        } else {
            timer.startPomodoroBlock(durationSeconds: block.plannedDurationSeconds)
        }
        store.save()
        updateViewState()
    }

    private func completeActiveBlockFromTimer() {
        guard let session = activeSession,
              let block = currentBlock(in: session) else { return }
        block.status = .completed
        block.endedAt = Date()
        block.remainingOverrideSeconds = nil
        session.updatedAt = .now
        advanceToNextBlock()
    }

    private func advanceToNextBlock() {
        guard let session = activeSession else { return }
        session.currentIndex += 1
        if session.currentIndex >= session.blocks.count {
            finish(session: session, cancelled: false)
        } else {
            beginBlock(at: session.currentIndex)
        }
    }

    private func attachTimerIfNeeded(for session: PomodoroSession) {
        guard let block = currentBlock(in: session) else {
            finish(session: session, cancelled: false)
            return
        }
        guard session.status == .active || session.status == .paused else { return }
        let remaining = remainingTime(for: block)
        if remaining <= 1 {
            block.status = .completed
            block.endedAt = Date()
            session.currentIndex += 1
            store.save()
            attachTimerIfNeeded(for: session)
            return
        }
        let engineState: FocusTimerEngine.State = session.status == .paused ? .paused : .running
        timer.pomodoroCompletionHandler = { [weak self] in
            _Concurrency.Task { [weak self] in
                await MainActor.run {
                    self?.completeActiveBlockFromTimer()
                }
            }
        }
        timer.attachExisting(
            durationSeconds: block.plannedDurationSeconds,
            remainingSeconds: remaining,
            state: engineState,
            mode: .pomodoro
        )
    }

    private func normalize(session: PomodoroSession) {
        ensureSortedBlocks(for: session)
        while session.currentIndex < session.blocks.count {
            let block = session.blocks[session.currentIndex]
            guard block.status == .completed else { break }
            session.currentIndex += 1
        }
        store.save()
    }

    private func ensureSortedBlocks(for session: PomodoroSession) {
        session.blocks.sort { $0.index < $1.index }
    }

    private func finish(session: PomodoroSession, cancelled: Bool) {
        timer.stop()
        session.status = cancelled ? .cancelled : .completed
        session.completedAt = Date()
        session.updatedAt = Date()
        store.save()
        if cancelled {
            store.delete(session)
            activeSession = nil
            state = nil
        } else {
            activeSession = nil
            state = ViewState(session: session)
        }
    }

    private func cancel(session: PomodoroSession) {
        timer.stop()
        store.delete(session)
        activeSession = nil
        updateViewState()
    }

    private func currentBlock(in session: PomodoroSession) -> PomodoroBlock? {
        ensureSortedBlocks(for: session)
        guard session.blocks.indices.contains(session.currentIndex) else { return nil }
        return session.blocks[session.currentIndex]
    }

    private func remainingTime(for block: PomodoroBlock) -> TimeInterval {
        if let override = block.remainingOverrideSeconds {
            return max(0, override)
        }
        guard let startedAt = block.startedAt else {
            return block.plannedDurationSeconds
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        return max(0, block.plannedDurationSeconds - elapsed)
    }

    private func updateViewState() {
        if let session = activeSession {
            self.state = ViewState(session: session)
        } else {
            self.state = nil
        }
    }
}

private extension PomodoroCoordinator.ViewState {
    init(session: PomodoroSession) {
        self.id = session.id
        self.goal = session.goal
        self.notes = session.notes
        self.createdAt = session.createdAt
        self.status = session.status
        var focusOrdinal = 0
        self.blocks = session.blocks
            .sorted(by: { $0.index < $1.index })
            .map { block in
                if block.type == .focus {
                    focusOrdinal += 1
                }
                return Block(
                    id: block.id,
                    index: block.index,
                    type: block.type,
                    goal: block.goal,
                    outcome: block.outcome,
                    plannedDurationSeconds: block.plannedDurationSeconds,
                    status: block.status,
                    focusOrdinal: block.type == .focus ? focusOrdinal : nil
                )
            }
        self.currentIndex = session.currentIndex
        self.configuration = session.configuration
    }
}
