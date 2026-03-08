import Foundation

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
        Task {
            await refresh()
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
        Task { await refresh() }
    }

    func planToToday(_ task: Task, date: Date, start: Date?, durationMinutes: Int?) {
        let interval: DateInterval?
        if let start, let durationMinutes {
            interval = DateInterval.from(start: start, durationMinutes: durationMinutes)
        } else {
            interval = nil
        }
        taskStore.plan(task, for: date, interval: interval)
        Task { await refresh() }
    }

    func reorder(tasks: [Task]) {
        taskStore.reorder(tasks: tasks)
        Task { await refresh() }
    }

    func requestCalendarAccessIfNeeded() {
        if calendarProvider.authorization == .needsPermission {
            Task {
                await calendarProvider.requestAccess()
                await refresh()
            }
        }
    }
}
