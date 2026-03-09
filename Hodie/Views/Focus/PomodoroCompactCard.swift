import SwiftUI

struct PomodoroCompactCard: View {
    @ObservedObject var coordinator: PomodoroCoordinator
    @ObservedObject var timer: FocusTimerEngine
    var onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pomodoro")
                    .font(.headline)
                Spacer()
                if isRunning {
                    Text(timerString)
                        .font(.system(.body, design: .monospaced))
                }
            }
            if let state = coordinator.state {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary(for: state))
                        .font(.subheadline)
                    if let block = state.currentBlock {
                        Label(blockDescription(for: block), systemImage: block.type == .focus ? "timer" : "cup.and.saucer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    actionButtons(for: state)
                }
            } else {
                Text("Plan a Pomodoro session to structure your focus time today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    onPlan()
                } label: {
                    Label("Start Session", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var isRunning: Bool {
        coordinator.state?.status == .active && timer.mode == .pomodoro
    }

    private var timerString: String {
        let seconds = max(0, Int(timer.remaining))
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func summary(for state: PomodoroCoordinator.ViewState) -> String {
        "\(state.completedFocusCount)/\(state.totalFocusCount) focus blocks"
    }

    private func blockDescription(for block: PomodoroCoordinator.ViewState.Block) -> String {
        switch block.type {
        case .focus:
            return block.goal?.isEmpty == false ? block.goal! : "Focusing now"
        case .shortBreak:
            return "Short break"
        case .longBreak:
            return "Long break"
        }
    }

    @ViewBuilder
    private func actionButtons(for state: PomodoroCoordinator.ViewState) -> some View {
        HStack {
            if state.status == .paused {
                Button("Resume") { coordinator.resumeSession() }
                    .buttonStyle(.bordered)
            } else if state.status == .active {
                if state.currentBlock?.type == .focus {
                    Button("Pause") { coordinator.pauseSession() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Skip Break") { coordinator.skipCurrentBreak() }
                        .buttonStyle(.bordered)
                }
            } else {
                Button("Plan Again") { onPlan() }
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
    }
}
