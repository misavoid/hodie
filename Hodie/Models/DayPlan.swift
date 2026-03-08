import Foundation

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarTitle: String?
    let isAllDay: Bool
}

struct DayPlan {
    var date: Date
    var scheduledTasks: [Task]
    var flexibleTasks: [Task]
    var completedTasks: [Task]
    var calendarEvents: [CalendarEvent]

    var hasFocusHistory: Bool {
        scheduledTasks.contains { !$0.focusSessions.isEmpty } ||
        flexibleTasks.contains { !$0.focusSessions.isEmpty }
    }

    static func empty(for date: Date) -> DayPlan {
        DayPlan(date: date, scheduledTasks: [], flexibleTasks: [], completedTasks: [], calendarEvents: [])
    }
}
