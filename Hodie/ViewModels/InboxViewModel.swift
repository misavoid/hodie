import Foundation
import Combine

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var inboxTasks: [Task] = []
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
        refreshInbox()
    }

    var canSaveQuickTask: Bool {
        !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func addQuickTask() {
        guard canSaveQuickTask else { return }
        _ = taskStore.quickAdd(title: quickTitle.trimmingCharacters(in: .whitespacesAndNewlines), notes: quickNotes, dueDate: quickDueDate, priority: quickPriority)
        refreshInbox()
        resetQuickEntry()
    }

    func delete(_ task: Task) {
        taskStore.delete(task)
        refreshInbox()
    }

    func plan(_ task: Task, for date: Date, start: Date?, durationMinutes: Int?) {
        let interval: DateInterval?
        if let start, let durationMinutes {
            interval = DateInterval.from(start: start, durationMinutes: durationMinutes)
        } else {
            interval = nil
        }
        taskStore.plan(task, for: date, interval: interval)
        refreshInbox()
    }

    func toggleCompletion(_ task: Task) {
        taskStore.toggleCompletion(task)
        refreshInbox()
    }

    func reorder(tasks: [Task]) {
        taskStore.reorder(tasks: tasks)
        refreshInbox()
    }

    func resetQuickEntry() {
        quickTitle = ""
        quickNotes = ""
        quickDueDate = nil
        quickPriority = .normal
    }

    func refreshInbox() {
        inboxTasks = taskStore.inboxTasks()
    }

    var reminderTasks: [Task] {
        inboxTasks.filter { $0.isReminderImport }
    }

    var reminderInboxCount: Int {
        reminderTasks.count
    }
}
