import XCTest
@testable import Hodie

final class TimelineSegmentBuilderTests: XCTestCase {
    func testSegmentsIncludeAnchorsTasksAndEvents() {
        let builder = TimelineSegmentBuilder()
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: Date())
        let taskStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let taskEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!
        let task = Task(title: "Design block")
        task.scheduledStart = taskStart
        task.scheduledEnd = taskEnd

        let eventStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let eventEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!
        let event = CalendarEvent(
            id: "lunch",
            title: "Lunch",
            startDate: eventStart,
            endDate: eventEnd,
            location: "Cafe",
            calendarTitle: nil,
            isAllDay: false
        )

        var plan = DayPlan(date: date, scheduledTasks: [task], flexibleTasks: [], completedTasks: [], calendarEvents: [event])
        let segments = builder.segments(for: plan)

        XCTAssertEqual(segments.count, 4) // start anchor, task, event, end anchor
        if case .anchor(let label)? = segments.first?.kind {
            XCTAssertEqual(label, "Start of day")
        } else {
            XCTFail("Expected start anchor")
        }
        if case .task(let scheduledTask)? = segments.dropFirst().first?.kind {
            XCTAssertEqual(scheduledTask.id, task.id)
        } else {
            XCTFail("Expected task segment")
        }
        if case .event(let scheduledEvent)? = segments.dropFirst(2).first?.kind {
            XCTAssertEqual(scheduledEvent.id, event.id)
        } else {
            XCTFail("Expected event segment")
        }
        if case .anchor(let label)? = segments.last?.kind {
            XCTAssertEqual(label, "End of day")
        } else {
            XCTFail("Expected end anchor")
        }
    }

    func testDayBoundsClampToFiveAMAndTenPM() {
        let builder = TimelineSegmentBuilder()
        let date = Date()
        let bounds = builder.dayBounds(for: date)

        let calendar = Calendar.current
        let expectedStart = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: date)!
        let expectedEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date)!

        XCTAssertEqual(bounds.start, expectedStart)
        XCTAssertEqual(bounds.end, expectedEnd)
    }
}
