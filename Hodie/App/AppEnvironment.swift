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
        seedUITestDataIfNeeded()
    }

    private func seedUITestDataIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("SEED-REMINDER-FIXTURE") else { return }
        guard taskStore.inboxTasks().isEmpty else { return }

        let dueDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let sourceID = Task.reminderSourceID(calendarID: "fixture-calendar", reminderID: UUID().uuidString)
        let reminderTask = Task(
            title: "Fixture Reminder",
            notes: "Seeded for UI tests",
            dueDate: dueDate,
            type: .projectTask,
            source: sourceID,
            sourceListName: "Fixture List",
            recurrence: RecurrenceRule(frequency: .daily, interval: 1)
        )
        context.insert(reminderTask)
        taskStore.saveContext()
    }
}
