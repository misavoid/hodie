import SwiftUI

struct PomodoroSessionPanel: View {
    enum DisplayMode {
        case compact
        case detail
    }

    @ObservedObject var coordinator: PomodoroCoordinator
    @ObservedObject var timer: FocusTimerEngine
    var displayMode: DisplayMode = .detail
    var onPlan: (() -> Void)?

    @State private var currentBlockGoal: String = ""

    var body: some View {
        Group {
            if let state = coordinator.state {
                content(for: state)
            } else {
                emptyState
            }
        }
        .onChange(of: coordinator.state?.currentBlock?.goal) { _, newValue in
            currentBlockGoal = newValue ?? ""
        }
        .onAppear {
            currentBlockGoal = coordinator.state?.currentBlock?.goal ?? ""
        }
    }

    @ViewBuilder
    private func content(for state: PomodoroCoordinator.ViewState) -> some View {
        switch state.status {
        case .completed, .cancelled:
            completionState(for: state)
        case .planned, .active, .paused:
            activeState(for: state)
        }
    }

    private func activeState(for state: PomodoroCoordinator.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(for: state)
            progress(for: state)
            goalEditor(for: state)
            controls(for: state)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func header(for state: PomodoroCoordinator.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(state.goal.isEmpty ? "Pomodoro Session" : state.goal)
                        .font(displayMode == .detail ? .title2.bold() : .headline)
                    Text(subtitle(for: state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerString())
                    .font(.system(.title2, design: .monospaced))
            }
            if let block = state.currentBlock {
                Label(blockLabel(for: block), systemImage: blockIcon(for: block))
                    .font(.subheadline)
                    .foregroundStyle(block.type == .focus ? Color.primary : Color.teal)
            }
        }
    }

    private func subtitle(for state: PomodoroCoordinator.ViewState) -> String {
        "\(state.completedFocusCount)/\(state.totalFocusCount) focus blocks complete"
    }

    private func blockLabel(for block: PomodoroCoordinator.ViewState.Block) -> String {
        switch block.type {
        case .focus:
            if let ordinal = block.focusOrdinal {
                return "Focus block \(ordinal)"
            }
            return "Focus block"
        case .shortBreak:
            return "Short break"
        case .longBreak:
            return "Long break"
        }
    }

    private func blockIcon(for block: PomodoroCoordinator.ViewState.Block) -> String {
        switch block.type {
        case .focus: return "timer"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "bed.double"
        }
    }

    private func progress(for state: PomodoroCoordinator.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(
                value: Double(state.completedFocusCount),
                total: Double(max(state.totalFocusCount, 1))
            )
            .tint(.accentColor)
            if let nextBlock = nextFocusBlock(after: state.currentIndex, in: state) {
                Text("Next focus: \(nextBlock.goal?.isEmpty == false ? nextBlock.goal! : "Set goal")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func goalEditor(for state: PomodoroCoordinator.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Block Goal")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(
                "Describe your focus outcome",
                text: Binding(
                    get: { currentBlockGoal },
                    set: { newValue in
                        currentBlockGoal = newValue
                    }
                ),
                onCommit: {
                    coordinator.updateCurrentBlockGoal(currentBlockGoal)
                }
            )
            .textFieldStyle(.roundedBorder)
            .disabled(state.currentBlock?.type != .focus)
        }
    }

    private func controls(for state: PomodoroCoordinator.ViewState) -> some View {
        let isFocus = state.currentBlock?.type == .focus
        return HStack {
            if state.status == .paused {
                Button {
                    coordinator.resumeSession()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button {
                    coordinator.pauseSession()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            if !isFocus {
                Button {
                    coordinator.skipCurrentBreak()
                } label: {
                    Label("Skip Break", systemImage: "forward.end")
                }
            }
            Spacer()
            Menu {
                Button("Finish Session") { coordinator.completeSession() }
                Button("Cancel Session", role: .destructive) { coordinator.cancelActiveSession() }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
        .labelStyle(.titleAndIcon)
    }

    private func completionState(for state: PomodoroCoordinator.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session complete")
                .font(.headline)
            Text(state.goal.isEmpty ? "Great work!" : state.goal)
                .font(.subheadline)
            Button {
                onPlan?()
            } label: {
                Label("Plan another session", systemImage: "plus.circle")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No Pomodoro planned")
                .font(.headline)
            Text("Plan a session to keep your focus blocks structured with automatic breaks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                onPlan?()
            } label: {
                Label("Start Pomodoro Session", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func nextFocusBlock(after index: Int, in state: PomodoroCoordinator.ViewState) -> PomodoroCoordinator.ViewState.Block? {
        state.blocks
            .filter { $0.type == .focus }
            .first { $0.index > index }
    }

    private func timerString() -> String {
        let seconds: TimeInterval
        if timer.mode == .pomodoro {
            seconds = timer.remaining
        } else {
            seconds = 0
        }
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let secs = Int(clamped) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
