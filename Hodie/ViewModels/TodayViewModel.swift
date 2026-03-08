import Foundation
import Combine

enum TimelineInteractionState: Equatable {
    case idle
    case placing(taskID: UUID)
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published private(set) var plan: DayPlan
    @Published private(set) var timelineInteractionState: TimelineInteractionState = .idle
    @Published private(set) var timelinePlacementTask: Task?
    @Published private(set) var timelinePlacementTime: Date?

    var calendarAuthorization: CalendarProvider.AuthorizationState {
        calendarProvider.authorization
    }

    private let planner: DayPlanner
    private let taskStore: TaskStore
    private let calendarProvider: CalendarProvider
    private let timelineBuilder = TimelineScheduleBuilder()

    init(planner: DayPlanner, taskStore: TaskStore, calendarProvider: CalendarProvider) {
        self.planner = planner
        self.taskStore = taskStore
        self.calendarProvider = calendarProvider
        self.selectedDate = .now.startOfDay()
        self.plan = .empty(for: .now)
    }

    var timelineLayouts: [TimelineScheduleLayout] {
        timelineBuilder.layouts(for: plan)
    }

    var dayBounds: (start: Date, end: Date) {
        timelineBuilder.dayBounds(for: selectedDate)
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
            ?? (timelinePlacementTask?.id == id ? timelinePlacementTask : nil)
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

    func beginTimelinePlacement(for task: Task) {
        timelinePlacementTask = task
        timelinePlacementTime = defaultPlacementTime()
        timelineInteractionState = .placing(taskID: task.id)
    }

    func cancelTimelinePlacement() {
        timelinePlacementTask = nil
        timelinePlacementTime = nil
        timelineInteractionState = .idle
    }

    func confirmTimelinePlacement(at start: Date) {
        guard let task = timelinePlacementTask else { return }
        let normalizedStart = normalizedPlacementDate(start)
        let duration = task.estimatedDurationMinutes ?? 60
        let interval = DateInterval.from(start: normalizedStart, durationMinutes: duration)
        taskStore.plan(task, for: selectedDate, interval: interval)
        timelinePlacementTask = nil
        timelinePlacementTime = nil
        timelineInteractionState = .idle
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    private func defaultPlacementTime() -> Date {
        let now = Date()
        let bounds = dayBounds
        if now >= bounds.start && now <= bounds.end {
            return normalizedPlacementDate(now)
        }
        return bounds.start
    }

    private func normalizedPlacementDate(_ date: Date) -> Date {
        let bounds = dayBounds
        let clamped = min(max(date, bounds.start), bounds.end)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: clamped)
        let minute = components.minute ?? 0
        let rounded = (minute / 15) * 15
        components.minute = rounded
        return calendar.date(from: components) ?? bounds.start
    }
}
