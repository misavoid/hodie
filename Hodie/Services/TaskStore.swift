import Foundation
import SwiftData

@MainActor
final class TaskStore {
    private let context: ModelContext
    private let defaults: UserDefaults
    private let typeMigrationKey = "task.type.migrated.v1"

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        backfillTaskTypesIfNeeded()
    }

    func quickAdd(title: String, notes: String? = nil, dueDate: Date? = nil, priority: Task.Priority = .normal, type: Task.TaskType = .task) -> Task {
        let newTask = Task(title: title, notes: notes, dueDate: dueDate, priority: priority, type: type)
        context.insert(newTask)
        saveContext()
        return newTask
    }

    func update(_ task: Task, configure: (Task) -> Void) {
        configure(task)
        task.updatedAt = .now
        saveContext()
    }

    func delete(_ task: Task) {
        context.delete(task)
        saveContext()
    }

    func tasks(in status: Task.Status? = nil, plannedFor date: Date? = nil) -> [Task] {
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\Task.orderIndex, order: .forward)])
        var results = (try? context.fetch(descriptor)) ?? []
        if let status {
            results = results.filter { $0.status == status }
        }
        if let date {
            let start = date.startOfDay()
            let end = start.addingTimeInterval(86_400)
            results = results.filter { task in
                guard let planned = task.plannedFor else { return false }
                return planned >= start && planned < end
            }
        }
        return results
    }

    func projectTasks(includeCompleted: Bool = false) -> [Task] {
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\Task.updatedAt, order: .reverse)])
        var tasks = (try? context.fetch(descriptor)) ?? []
        tasks = tasks.filter { $0.type == .projectTask }
        if !includeCompleted {
            tasks = tasks.filter { $0.status != .completed }
        }
        return tasks
    }

    func dayPlan(for date: Date) -> DayPlan {
        let start = date.startOfDay()
        let end = start.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<Task>()
        let allTasks = (try? context.fetch(descriptor)) ?? []
        let planned = allTasks.filter { task in
            guard let plannedDate = task.plannedFor else { return false }
            return plannedDate >= start && plannedDate < end && task.status != .completed
        }
        let scheduled = planned
            .filter { $0.status == .scheduled }
            .sorted {
                switch ($0.scheduledStart, $1.scheduledStart) {
                case let (lhs?, rhs?):
                    if lhs == rhs {
                        return $0.orderIndex < $1.orderIndex
                    }
                    return lhs < rhs
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.orderIndex < $1.orderIndex
                }
            }
        let flexible = planned
            .filter { $0.status != .scheduled }
            .sorted { $0.orderIndex < $1.orderIndex }

        let completed = allTasks
            .filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start && completedAt < end
            }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.completedAt else { return false }
                guard let rhsDate = rhs.completedAt else { return true }
                return lhsDate > rhsDate
            }
        return DayPlan(date: date, scheduledTasks: scheduled, flexibleTasks: flexible, completedTasks: completed, calendarEvents: [])
    }

    func inboxTasks() -> [Task] {
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\Task.orderIndex, order: .forward)])
        let tasks = (try? context.fetch(descriptor)) ?? []
        return tasks.filter { $0.status == .inbox }
    }

    func reorder(tasks: [Task]) {
        for (index, task) in tasks.enumerated() {
            task.orderIndex = Double(index)
        }
        saveContext()
    }

    func toggleCompletion(_ task: Task) {
        if task.status == .completed {
            task.status = task.scheduledStart == nil ? .planned : .scheduled
            task.completedAt = nil
        } else {
            task.markCompleted()
        }
        saveContext()
    }

    func plan(_ task: Task, for date: Date, interval: DateInterval?) {
        task.plan(for: date, interval: interval)
        saveContext()
    }

    func rollover(_ task: Task, destination: RolloverDestination) {
        switch destination {
        case .tomorrow:
            if let date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                task.plan(for: date, interval: nil)
            }
        case .inbox:
            task.reopenToInbox()
        }
        saveContext()
    }

    func importReminders(_ reminders: [RemindersProvider.ReminderItem], calendarID: String, calendarName: String?) {
        let descriptor = FetchDescriptor<Task>()
        let tasks = (try? context.fetch(descriptor)) ?? []
        let prefix = Task.reminderSourcePrefix(for: calendarID)

        var existing: [String: Task] = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            guard let source = task.source, source.hasPrefix(prefix) else { return nil }
            return (source, task)
        })

        var seenSources: Set<String> = []

        for reminder in reminders {
            let sourceID = Task.reminderSourceID(calendarID: calendarID, reminderID: reminder.id)
            seenSources.insert(sourceID)

            if let task = existing[sourceID] {
                task.title = reminder.title
                task.notes = reminder.notes
                task.dueDate = reminder.dueDate
                task.source = sourceID
                task.sourceListName = calendarName ?? reminder.calendarTitle
                task.recurrence = reminder.recurrence

                if reminder.isCompleted {
                    task.markCompleted(date: reminder.completionDate ?? task.completedAt ?? Date())
                } else {
                    task.status = .inbox
                    task.completedAt = nil
                }
                task.updatedAt = .now
            } else {
                let inferredType = inferredType(for: reminder)
                let newTask = Task(
                    title: reminder.title,
                    notes: reminder.notes,
                    status: reminder.isCompleted ? .completed : .inbox,
                    dueDate: reminder.dueDate,
                    type: inferredType,
                    source: sourceID
                )
                newTask.sourceListName = calendarName ?? reminder.calendarTitle
                newTask.recurrence = reminder.recurrence
                if reminder.isCompleted {
                    newTask.completedAt = reminder.completionDate ?? Date()
                }
                context.insert(newTask)
                existing[sourceID] = newTask
            }
        }

        for (source, task) in existing where !seenSources.contains(source) {
            context.delete(task)
        }

        saveContext()
    }

    func saveContext() {
        try? context.save()
    }

    private func backfillTaskTypesIfNeeded() {
        guard !defaults.bool(forKey: typeMigrationKey) else { return }
        let descriptor = FetchDescriptor<Task>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            let inferred: Task.TaskType
            if let duration = task.estimatedDurationMinutes {
                if duration <= Task.TaskType.quickTick.defaultDurationMinutes {
                    inferred = .quickTick
                } else if duration >= Task.TaskType.projectTask.defaultDurationMinutes {
                    inferred = .projectTask
                } else {
                    inferred = .task
                }
            } else if task.isReminderImport, let source = task.source, source.contains("reminder:") {
                inferred = .task
            } else {
                inferred = .task
            }
            task.type = inferred
            if task.estimatedDurationMinutes == nil {
                task.estimatedDurationMinutes = inferred.defaultDurationMinutes
            }
        }
        saveContext()
        defaults.set(true, forKey: typeMigrationKey)
    }

    private func inferredType(for reminder: RemindersProvider.ReminderItem) -> Task.TaskType {
        if reminder.isFlagged || reminder.noteCharacterCount >= 140 {
            return .projectTask
        }
        if reminder.hasDueTimeComponents || reminder.dueDate != nil || reminder.recurrence != nil {
            return .task
        }
        return .quickTick
    }
}

enum RolloverDestination {
    case tomorrow
    case inbox
}
