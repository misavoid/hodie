import SwiftUI

struct FocusScreen: View {
    @ObservedObject var controller: FocusController
    @ObservedObject var pomodoroCoordinator: PomodoroCoordinator
    @State private var showingPomodoroPlanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PomodoroSessionPanel(
                    coordinator: pomodoroCoordinator,
                    timer: controller.timer,
                    displayMode: .detail,
                    onPlan: { showingPomodoroPlanner = true }
                )
                Divider()
                if controller.isPresented, let session = controller.activeSession {
                    activeSessionView(session)
                } else {
                    setupView
                }
                historySection
            }
            .padding()
        }
        .navigationTitle("Focus")
        .sheet(isPresented: $showingPomodoroPlanner) {
            PomodoroPlannerView(coordinator: pomodoroCoordinator)
        }
    }

    private func activeSessionView(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.task?.title ?? "Focus Session")
                .font(.title2)
                .bold()
            ProgressView(value: controller.totalSeconds - controller.remainingSeconds, total: controller.totalSeconds)
            HStack {
                Text(timeString(controller.remainingSeconds))
                    .font(.system(.largeTitle, design: .monospaced))
                Spacer()
                Button(controller.state == .running ? "Pause" : "Resume") {
                    controller.state == .running ? controller.pause() : controller.resume()
                }
                Button("Done") { controller.completeManually() }
                Button("Cancel", role: .destructive) { controller.cancel() }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready to focus?")
                .font(.title2)
            if isPomodoroBlockingTimer {
                Label("Pomodoro session is using the focus timer", systemImage: "lock.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Picker("Preset", selection: $controller.selectedPreset) {
                ForEach(FocusSession.SessionType.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            if controller.selectedPreset == .custom {
                Stepper(value: $controller.customMinutes, in: 5...180, step: 5) {
                    Text("Custom duration: \(controller.customMinutes) min")
                }
            }
            Button {
                controller.begin(for: controller.activeTask)
            } label: {
                Label("Start Focus", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPomodoroBlockingTimer)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.headline)
            let sessions = controller.recentSessions()
            if sessions.isEmpty {
                Text("Sessions will appear after you finish focus work.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading) {
                        Text(session.task?.title ?? "Session")
                            .font(.subheadline)
                        Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) • \(session.sessionType.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func timeString(_ remaining: TimeInterval) -> String {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var isPomodoroBlockingTimer: Bool {
        guard let status = pomodoroCoordinator.state?.status else { return false }
        return status == .active || status == .paused
    }
}
