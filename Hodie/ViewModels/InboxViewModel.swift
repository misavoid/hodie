import Foundation
import Combine

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var inboxTasks: [Task] = []
    @Published private(set) var inboxDisplayTasks: [Task] = []
    @Published private(set) var scheduledReminderTasks: [Task] = []
    @Published private(set) var reminderBacklogTasks: [Task] = []
    @Published var quickTitle: String = ""
    @Published var quickNotes: String = ""
    @Published var quickDueDate: Date? = nil
    @Published var quickPriority: Task.Priority = .normal
    @Published var quickType: Task.TaskType?
    @Published var showingDetailForTask: Task?
    @Published var planningTask: Task?
    @Published var showingPlanSheet = false
    @Published var scheduledRemindersExpanded: Bool = false

    private let taskStore: TaskStore
    // Memoized signature prevents redundant SwiftUI diffing when reminder-backed tasks are unchanged.
    private var reminderSignature: Int?
    private var hasInitializedScheduledSection = false

    init(taskStore: TaskStore) {
        self.taskStore = taskStore
        refreshInbox()
    }

    var canSaveQuickTask: Bool {
        !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quickType != nil
    }

    func addQuickTask() {
        guard canSaveQuickTask, let quickType else { return }
        _ = taskStore.quickAdd(
            title: quickTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: quickNotes,
            dueDate: quickDueDate,
            priority: quickPriority,
            type: quickType
        )
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
        quickType = nil
    }

    func refreshInbox() {
#if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
#endif
        let tasks = taskStore.inboxTasks()
        // Pre-split inbox once to keep Today/Inbox scrolling responsive when hundreds of reminders sync in.
        inboxTasks = tasks
        let reminderCandidates = tasks.filter { $0.isReminderImport }
        let scheduled = reminderCandidates.filter { $0.shouldAppearInScheduledReminderSection }
        reminderBacklogTasks = reminderCandidates.filter { !$0.shouldAppearInScheduledReminderSection }
        inboxDisplayTasks = tasks.filter { !$0.shouldAppearInScheduledReminderSection }

        var hasher = Hasher()
        scheduled.forEach { task in
            hasher.combine(task.source)
            hasher.combine(task.updatedAt)
        }
        let signature = hasher.finalize()
        if reminderSignature != signature {
            scheduledReminderTasks = scheduled
            reminderSignature = signature
        }

        if !scheduled.isEmpty && !hasInitializedScheduledSection {
            scheduledRemindersExpanded = false
            hasInitializedScheduledSection = true
        }
#if DEBUG
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed > 0.005 {
            debugPrint(String(format: "[InboxViewModel] refreshInbox fetched %d tasks in %.4f s", tasks.count, elapsed))
        }
#endif
    }

    func setScheduledSectionExpanded(_ expanded: Bool) {
        scheduledRemindersExpanded = expanded
    }

    var reminderInboxCount: Int {
        scheduledReminderTasks.count + reminderBacklogTasks.count
    }
}
