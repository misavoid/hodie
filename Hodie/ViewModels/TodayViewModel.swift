import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published private(set) var plan: DayPlan
    @Published var showingPlanningSheet = false
    @Published var taskBeingPlanned: Task?

    var calendarAuthorization: CalendarProvider.AuthorizationState {
        calendarProvider.authorization
    }

    private let planner: DayPlanner
    private let taskStore: TaskStore
    private let calendarProvider: CalendarProvider

    init(planner: DayPlanner, taskStore: TaskStore, calendarProvider: CalendarProvider) {
        self.planner = planner
        self.taskStore = taskStore
        self.calendarProvider = calendarProvider
        self.selectedDate = .now.startOfDay()
        self.plan = .empty(for: .now)
    }

    func load() {
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func refresh() async {
        await planner.refresh(for: selectedDate)
        await MainActor.run {
            self.plan = planner.plan
        }
    }

    func toggleCompletion(_ task: Task) {
        taskStore.toggleCompletion(task)
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func planToToday(_ task: Task, date: Date, start: Date?, durationMinutes: Int?) {
        let interval: DateInterval?
        if let start, let durationMinutes {
            interval = DateInterval.from(start: start, durationMinutes: durationMinutes)
        } else {
            interval = nil
        }
        taskStore.plan(task, for: date, interval: interval)
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func reorder(tasks: [Task]) {
        taskStore.reorder(tasks: tasks)
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func requestCalendarAccessIfNeeded() {
        if calendarProvider.authorization == .needsPermission {
            _Concurrency.Task { [weak self] in
                guard let self else { return }
                await self.calendarProvider.requestAccess()
                await self.refresh()
            }
        }
    }

    func task(with id: UUID) -> Task? {
        plan.scheduledTasks.first { $0.id == id }
            ?? plan.flexibleTasks.first { $0.id == id }
    }

    func rescheduleTask(id: UUID, to start: Date) {
        guard let task = task(with: id) else { return }
        let duration = task.estimatedDurationMinutes ?? 60
        let interval = DateInterval.from(start: start, durationMinutes: duration)
        taskStore.plan(task, for: selectedDate, interval: interval)
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }
}
