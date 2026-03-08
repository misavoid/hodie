import Foundation
import SwiftData
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let container: ModelContainer
    let context: ModelContext
    let taskStore: TaskStore
    let focusStore: FocusSessionStore
    let calendarProvider: CalendarProvider
    let dayPlanner: DayPlanner
    let reviewCoordinator: ReviewCoordinator
    let focusTimer: FocusTimerEngine
    let focusController: FocusController
    let remindersProvider: RemindersProvider
    let remindersSync: RemindersSyncEngine

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
        self.taskStore = TaskStore(context: context)
        self.focusStore = FocusSessionStore(context: context)
        self.calendarProvider = CalendarProvider()
        self.dayPlanner = DayPlanner(taskStore: taskStore, calendarProvider: calendarProvider)
        self.reviewCoordinator = ReviewCoordinator(taskStore: taskStore, focusStore: focusStore)
        self.focusTimer = FocusTimerEngine()
        self.focusController = FocusController(focusStore: focusStore, timer: focusTimer)
        self.remindersProvider = RemindersProvider()
        let remindersSettings = RemindersSettingsStore(defaults: .standard)
        self.remindersSync = RemindersSyncEngine(provider: remindersProvider, taskStore: taskStore, settings: remindersSettings)
    }
}
