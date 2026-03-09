import Testing
@testable import Hodie

@MainActor
struct InboxViewModelTests {
    @Test func scheduledRemindersDefaultCollapsedAndRefresh() async throws {
        let (taskStore, _, _) = try TestUtilities.makeStores()
        let reminderTask = taskStore.quickAdd(title: "Seeded reminder", type: .task)
        reminderTask.source = Task.reminderSourceID(calendarID: "seed", reminderID: "1")
        reminderTask.dueDate = Date().addingTimeInterval(600)
        reminderTask.recurrence = Task.RecurrenceRule(frequency: .daily)
        taskStore.saveContext()

        let viewModel = InboxViewModel(taskStore: taskStore)
        #expect(viewModel.scheduledReminderTasks.count == 1)
        #expect(viewModel.scheduledRemindersExpanded == false)

        viewModel.setScheduledSectionExpanded(true)
        #expect(viewModel.scheduledRemindersExpanded == true)

        reminderTask.dueDate = nil
        reminderTask.recurrence = nil
        taskStore.saveContext()
        viewModel.refreshInbox()
        #expect(viewModel.scheduledReminderTasks.isEmpty)
    }
}
