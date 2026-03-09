import Testing
@testable import Hodie

@MainActor
struct TaskStoreTests {
    @Test func dayPlanSeparatesScheduledAndFlexible() async throws {
        let (taskStore, _, _) = try TestUtilities.makeStores()
        let today = Date().startOfDay()
        let flexible = taskStore.quickAdd(title: "Plan agenda")
        taskStore.plan(flexible, for: today, interval: nil)
        let scheduled = taskStore.quickAdd(title: "Deep work")
        let interval = DateInterval.from(start: today.adding(minutes: 9 * 60), durationMinutes: 60)
        taskStore.plan(scheduled, for: today, interval: interval)

        let plan = taskStore.dayPlan(for: today)
        #expect(plan.flexibleTasks.count == 1)
        #expect(plan.scheduledTasks.count == 1)
    }

    @Test func rolloverMovesTasksForward() async throws {
        let (taskStore, _, _) = try TestUtilities.makeStores()
        let task = taskStore.quickAdd(title: "Write summary")
        taskStore.plan(task, for: Date().startOfDay(), interval: nil)
        taskStore.rollover(task, destination: .tomorrow)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(task.plannedFor?.isSameDay(as: tomorrow) == true)
        taskStore.rollover(task, destination: .inbox)
        #expect(task.status == .inbox)
    }

    @Test func reminderImportSetsListNameAndType() async throws {
        let (taskStore, _, _) = try TestUtilities.makeStores()
        let reminder = RemindersProvider.ReminderItem(
            id: "abc",
            calendarIdentifier: "list-1",
            calendarTitle: "Workspace",
            title: "Prep slides",
            notes: "Quarterly review",
            dueDate: Date().addingTimeInterval(5400),
            completionDate: nil,
            recurrence: Task.RecurrenceRule(frequency: .weekly, interval: 1),
            isCompleted: false,
            priority: 1,
            hasDueTimeComponents: true,
            noteCharacterCount: 30,
            isFlagged: true
        )

        taskStore.importReminders([reminder], calendarID: "list-1", calendarName: "Workspace")
        let inbox = taskStore.inboxTasks()
        #expect(inbox.count == 1)
        #expect(inbox.first?.sourceListName == "Workspace")
        #expect(inbox.first?.type == .projectTask)
        #expect(inbox.first?.recurrence?.frequency == .weekly)
        #expect(inbox.first?.shouldAppearInScheduledReminderSection == true)
    }
}
