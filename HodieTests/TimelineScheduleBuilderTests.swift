import XCTest
@testable import Hodie

final class TimelineScheduleBuilderTests: XCTestCase {
    @MainActor
    func testLayoutsIncludeTasksAndEventsWithLanes() {
        let builder = TimelineScheduleBuilder()
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: Date())

        let firstTask = Task(title: "Morning Deep Work")
        firstTask.scheduledStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        firstTask.estimatedDurationMinutes = 60

        let overlappingTask = Task(title: "Design Sync")
        overlappingTask.scheduledStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)
        overlappingTask.estimatedDurationMinutes = 45

        let eventStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!
        let eventEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let event = CalendarEvent(
            id: "cal-event",
            title: "Lunch",
            startDate: eventStart,
            endDate: eventEnd,
            location: "Cafe",
            calendarTitle: nil,
            isAllDay: false
        )

        var plan = DayPlan(date: date, scheduledTasks: [firstTask, overlappingTask], flexibleTasks: [], completedTasks: [], calendarEvents: [event])
        let layouts = builder.layouts(for: plan)

        XCTAssertEqual(layouts.count, 3)
        let laneCounts = layouts.filter { Calendar.current.component(.hour, from: $0.item.start) == 9 }.map(\.totalLanes)
        XCTAssertTrue(laneCounts.allSatisfy { $0 == 2 }, "Overlapping tasks should share two lanes")

        let lunchLayout = layouts.first { layout in
            if case .event(let candidate) = layout.item.kind {
                return candidate.id == event.id
            }
            return false
        }
        XCTAssertNotNil(lunchLayout)
    }

    func testDayBoundsClampToFiveToTen() {
        let builder = TimelineScheduleBuilder()
        let date = Date()
        let bounds = builder.dayBounds(for: date)
        let calendar = Calendar.current
        let expectedStart = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: date)
        let expectedEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date)
        XCTAssertEqual(bounds.start, expectedStart)
        XCTAssertEqual(bounds.end, expectedEnd)
    }
}
