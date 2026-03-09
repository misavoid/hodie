import Testing
@testable import Hodie

struct TaskModelTests {
    @Test func planningAndCompletionFlow() async throws {
        let task = Task(title: "Deep Work")
        let today = Date().startOfDay()
        task.plan(for: today, interval: nil)
        #expect(task.status == .planned)
        #expect(task.plannedFor?.isSameDay(as: today) == true)

        let interval = DateInterval.from(start: today.adding(minutes: 60), durationMinutes: 90)
        task.plan(for: today, interval: interval)
        #expect(task.status == .scheduled)
        #expect(task.estimatedDurationMinutes == 90)

        task.markCompleted()
        #expect(task.status == .completed)
        #expect(task.completedAt != nil)

        task.reopenToInbox()
        #expect(task.status == .inbox)
        #expect(task.plannedFor == nil)
        #expect(task.scheduledStart == nil)
    }

    @Test func taskTypeDefaultsAndScheduledGrouping() async throws {
        let quick = Task(title: "Tick", type: .quickTick)
        #expect(quick.type == .quickTick)
        #expect(quick.estimatedDurationMinutes == Task.TaskType.quickTick.defaultDurationMinutes)

        let reminder = Task(
            title: "Reminder",
            dueDate: Date().addingTimeInterval(3600),
            type: .task,
            source: Task.reminderSourceID(calendarID: "fixture", reminderID: "1"),
            sourceListName: "Calls",
            recurrence: Task.RecurrenceRule(frequency: .daily)
        )
        #expect(reminder.isReminderImport)
        #expect(reminder.shouldAppearInScheduledReminderSection)
        #expect(reminder.reminderListDisplayLabel == "Calls")
    }
}
