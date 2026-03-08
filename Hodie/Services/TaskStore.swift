import Foundation
import SwiftData

@MainActor
final class TaskStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func quickAdd(title: String, notes: String? = nil, dueDate: Date? = nil, priority: Task.Priority = .normal) -> Task {
        let newTask = Task(title: title, notes: notes, dueDate: dueDate, priority: priority)
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

    func saveContext() {
        try? context.save()
    }
}

enum RolloverDestination {
    case tomorrow
    case inbox
}
