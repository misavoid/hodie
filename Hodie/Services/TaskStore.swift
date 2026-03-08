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
        var predicate: Predicate<Task>?
        switch (status, date) {
        case (.none, .none):
            predicate = nil
        case let (.some(status), .none):
            predicate = #Predicate { task in task.status == status }
        case let (.none, .some(date)):
            let start = date.startOfDay()
            let end = start.addingTimeInterval(86_400)
            predicate = #Predicate { task in
                task.plannedFor != nil && task.plannedFor! >= start && task.plannedFor! < end
            }
        case let (.some(status), .some(date)):
            let start = date.startOfDay()
            let end = start.addingTimeInterval(86_400)
            predicate = #Predicate { task in
                task.status == status && task.plannedFor != nil && task.plannedFor! >= start && task.plannedFor! < end
            }
        }
        let descriptor = FetchDescriptor<Task>(predicate: predicate, sortBy: [SortDescriptor(\Task.orderIndex, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func dayPlan(for date: Date) -> DayPlan {
        let start = date.startOfDay()
        let end = start.addingTimeInterval(86_400)
        let plannedPredicate = #Predicate<Task> { task in
            task.plannedFor != nil && task.plannedFor! >= start && task.plannedFor! < end && task.status != .completed
        }
        let plannedDescriptor = FetchDescriptor<Task>(predicate: plannedPredicate, sortBy: [
            SortDescriptor(\Task.scheduledStart, order: .forward),
            SortDescriptor(\Task.orderIndex, order: .forward)
        ])
        let planned = (try? context.fetch(plannedDescriptor)) ?? []
        let scheduled = planned.filter { $0.status == .scheduled }
        let flexible = planned.filter { $0.status != .scheduled }

        let completedPredicate = #Predicate<Task> { task in
            task.completedAt != nil && task.completedAt! >= start && task.completedAt! < end
        }
        let completedDescriptor = FetchDescriptor<Task>(predicate: completedPredicate, sortBy: [SortDescriptor(\Task.completedAt, order: .reverse)])
        let completed = (try? context.fetch(completedDescriptor)) ?? []
        return DayPlan(date: date, scheduledTasks: scheduled, flexibleTasks: flexible, completedTasks: completed, calendarEvents: [])
    }

    func inboxTasks() -> [Task] {
        let descriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.status == Task.Status.inbox }, sortBy: [SortDescriptor(\Task.orderIndex, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
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
