import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var quickTitle: String = ""
    @Published var quickNotes: String = ""
    @Published var quickDueDate: Date? = nil
    @Published var quickPriority: Task.Priority = .normal
    @Published var showingDetailForTask: Task?
    @Published var planningTask: Task?
    @Published var showingPlanSheet = false

    private let taskStore: TaskStore

    init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    var canSaveQuickTask: Bool {
        !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func addQuickTask() {
        guard canSaveQuickTask else { return }
        taskStore.quickAdd(title: quickTitle.trimmingCharacters(in: .whitespacesAndNewlines), notes: quickNotes, dueDate: quickDueDate, priority: quickPriority)
        resetQuickEntry()
    }

    func delete(_ task: Task) {
        taskStore.delete(task)
    }

    func plan(_ task: Task, for date: Date, start: Date?, durationMinutes: Int?) {
        let interval: DateInterval?
        if let start, let durationMinutes {
            interval = DateInterval.from(start: start, durationMinutes: durationMinutes)
        } else {
            interval = nil
        }
        taskStore.plan(task, for: date, interval: interval)
    }

    func toggleCompletion(_ task: Task) {
        taskStore.toggleCompletion(task)
    }

    func reorder(tasks: [Task]) {
        taskStore.reorder(tasks: tasks)
    }

    func resetQuickEntry() {
        quickTitle = ""
        quickNotes = ""
        quickDueDate = nil
        quickPriority = .normal
    }
}
