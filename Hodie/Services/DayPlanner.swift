import Foundation
import Combine

@MainActor
final class DayPlanner: ObservableObject {
    @Published private(set) var plan: DayPlan = .empty(for: .now)

    private let taskStore: TaskStore
    private let calendarProvider: CalendarEventSource

    init(taskStore: TaskStore, calendarProvider: CalendarEventSource) {
        self.taskStore = taskStore
        self.calendarProvider = calendarProvider
    }

    func refresh(for date: Date) async {
        var plan = taskStore.dayPlan(for: date)
        let events = await calendarProvider.events(for: date)
        plan.calendarEvents = events
        await MainActor.run {
            self.plan = plan
        }
    }
}
