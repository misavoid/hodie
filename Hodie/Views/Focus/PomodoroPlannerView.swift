import SwiftUI

struct PomodoroPlannerView: View {
    @ObservedObject var coordinator: PomodoroCoordinator
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var pomodoroCount: Int = 4
    @State private var sessionGoal: String = ""
    @State private var sessionNotes: String = ""
    @State private var perPomGoals: [String] = Array(repeating: "", count: 4)
    @State private var projectTasks: [Task] = []
    @State private var selectedProjectTaskID: UUID?

    private let configuration: PomodoroConfiguration = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Goal") {
                    if !projectTasks.isEmpty {
                        Picker("Project Task", selection: $selectedProjectTaskID) {
                            Text("None").tag(UUID?.none)
                            ForEach(projectTasks) { task in
                                Text(task.title).tag(Optional(task.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField("What do you want to accomplish?", text: $sessionGoal)
                    TextField("Optional notes", text: $sessionNotes)
                }
                Section("Pomodoros") {
                    Stepper(value: $pomodoroCount, in: 1...12) {
                        VStack(alignment: .leading) {
                            Text("\(pomodoroCount) focus blocks")
                            Text(totalDurationLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Per-Pom Goals") {
                    ForEach(0..<pomodoroCount, id: \.self) { index in
                        TextField("Pom \(index + 1) goal", text: Binding(
                            get: { goal(at: index) },
                            set: { updateGoal(at: index, value: $0) }
                        ))
                    }
                }
            }
            .navigationTitle("Plan Pomodoro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startSession()
                    }
                    .disabled(pomodoroCount == 0)
                }
            }
        }
        .onAppear {
            loadProjectTasks()
        }
        .onChange(of: pomodoroCount) { _, newValue in
            adjustGoals(for: newValue)
        }
        .onChange(of: selectedProjectTaskID) { _, newValue in
            guard let id = newValue,
                  let task = projectTasks.first(where: { $0.id == id }) else { return }
            sessionGoal = task.title
        }
    }

    private var totalDurationLabel: String {
        let minutes = Int(estimatedTotalDuration() / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "~\(hours)h \(mins)m incl. breaks"
        }
        return "~\(mins)m incl. breaks"
    }

    private func estimatedTotalDuration() -> TimeInterval {
        let focus = Double(pomodoroCount) * configuration.focusDuration
        let shortBreaks = Double(max(pomodoroCount - 1, 0)) * configuration.shortBreakDuration
        let longBreakCount = max((pomodoroCount - 1) / configuration.longBreakInterval, 0)
        let additionalLongBreak = Double(longBreakCount) * (configuration.longBreakDuration - configuration.shortBreakDuration)
        return focus + shortBreaks + additionalLongBreak
    }

    private func adjustGoals(for count: Int) {
        if perPomGoals.count < count {
            perPomGoals.append(contentsOf: Array(repeating: "", count: count - perPomGoals.count))
        } else if perPomGoals.count > count {
            perPomGoals = Array(perPomGoals.prefix(count))
        }
    }

    private func goal(at index: Int) -> String {
        guard perPomGoals.indices.contains(index) else { return "" }
        return perPomGoals[index]
    }

    private func updateGoal(at index: Int, value: String) {
        adjustGoals(for: max(pomodoroCount, index + 1))
        perPomGoals[index] = value
    }

    private func loadProjectTasks() {
        projectTasks = environment.taskStore.projectTasks()
    }

    private func startSession() {
        coordinator.startSession(
            goal: sessionGoal,
            pomodoroCount: pomodoroCount,
            perPomGoals: perPomGoals,
            notes: sessionNotes.isEmpty ? nil : sessionNotes
        )
        dismiss()
    }
}
