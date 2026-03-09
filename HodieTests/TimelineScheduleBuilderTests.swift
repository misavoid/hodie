import XCTest
import CoreGraphics
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

    func testLanePlacement_preventsOverlapForOutOfOrderLayouts() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.startOfDay(for: Date())
        let baseStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let minuteOffsets = [15, 75, 135]
        let durations = [60, 60, 45]

        var layouts: [TimelineScheduleLayout] = []

        for (index, minuteOffset) in minuteOffsets.enumerated() {
            let start = baseStart.addingTimeInterval(TimeInterval(minuteOffset * 60))
            let end = start.addingTimeInterval(TimeInterval(durations[index] * 60))
            let event = CalendarEvent(
                id: "synthetic-\(index)",
                title: "Synthetic \(index)",
                startDate: start,
                endDate: end,
                location: nil,
                calendarTitle: nil,
                isAllDay: false
            )
            let item = TimelineScheduleItem(
                id: event.id,
                kind: .event(event),
                start: start,
                end: end
            )
            layouts.append(
                TimelineScheduleLayout(
                    id: item.id,
                    item: item,
                    laneIndex: 0,
                    totalLanes: 2
                )
            )
        }

        let reversedLayouts = Array(layouts.reversed())
        let overlappingLaneSpacing: CGFloat = 8
        let overlappingLaneSpacingBoost: CGFloat = 6
        let consecutiveSpacing: CGFloat = 10
        let cardBottomPadding: CGFloat = 10

        let overlapLookup = makeOverlapLookup(for: layouts, parallelStartWindow: 60)

        let compression = TimelineCompressionInfo(
            referenceStart: baseStart,
            totalCompressedMinutes: 12 * 60,
            adjustments: []
        )
        let pointsPerMinute: CGFloat = 1
        let calculator = TimelineLanePlacementCalculator(
            layouts: layouts,
            consecutiveEventSpacing: consecutiveSpacing,
            overlappingLaneSpacing: overlappingLaneSpacing,
            overlappingLaneSpacingBoost: overlappingLaneSpacingBoost,
            contiguousTolerance: 1,
            cardBottomPadding: cardBottomPadding
        )
        let reversedCalculator = TimelineLanePlacementCalculator(
            layouts: reversedLayouts,
            consecutiveEventSpacing: consecutiveSpacing,
            overlappingLaneSpacing: overlappingLaneSpacing,
            overlappingLaneSpacingBoost: overlappingLaneSpacingBoost,
            contiguousTolerance: 1,
            cardBottomPadding: cardBottomPadding
        )

        let orderedPlacement = calculator.placements(
            pointsPerMinute: pointsPerMinute,
            overlapLookup: overlapLookup,
            compression: compression
        )
        let reversedPlacement = reversedCalculator.placements(
            pointsPerMinute: pointsPerMinute,
            overlapLookup: overlapLookup,
            compression: compression
        )

        XCTAssertEqual(orderedPlacement.offsets.count, reversedPlacement.offsets.count)
        XCTAssertEqual(orderedPlacement.offsets, reversedPlacement.offsets, "Lane placement should ignore incoming order")

        let sortedByStart = layouts.sorted { lhs, rhs in lhs.item.start < rhs.item.start }
        for (previous, current) in zip(sortedByStart, sortedByStart.dropFirst()) {
            guard
                let previousOffset = reversedPlacement.offsets[previous.id],
                let currentOffset = reversedPlacement.offsets[current.id]
            else {
                XCTFail("Missing placement offsets for synthetic layouts")
                return
            }

            let previousBlockHeight = max(44, CGFloat(previous.item.durationMinutes) * pointsPerMinute)
            let requiredGap = previousBlockHeight + consecutiveSpacing
            XCTAssertGreaterThanOrEqual(
                currentOffset,
                previousOffset + requiredGap,
                "Same-lane blocks must never overlap even when layouts are shuffled"
            )
        }
    }

    func testLanePlacement_respectsSpacingUnderCompressionAndMinHeights() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.startOfDay(for: Date())
        let baseStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!

        let layouts = [
            makeLayout(id: "compressed-0", start: baseStart, durationMinutes: 15, laneIndex: 0, totalLanes: 1),
            makeLayout(id: "compressed-1", start: baseStart.addingTimeInterval(150 * 60), durationMinutes: 20, laneIndex: 0, totalLanes: 1),
            makeLayout(id: "compressed-2", start: baseStart.addingTimeInterval(300 * 60), durationMinutes: 25, laneIndex: 0, totalLanes: 1)
        ]

        let compression = TimelineCompressionInfo(
            referenceStart: baseStart,
            totalCompressedMinutes: 10 * 60,
            adjustments: [
                (time: layouts[1].item.start, reduction: 90),
                (time: layouts[2].item.start, reduction: 150)
            ]
        )

        let consecutiveSpacing: CGFloat = 10
        let cardBottomPadding: CGFloat = 10
        let overlappingLaneSpacing: CGFloat = 8
        let overlappingLaneSpacingBoost: CGFloat = 6
        let pointsPerMinute: CGFloat = 0.5

        let calculator = TimelineLanePlacementCalculator(
            layouts: layouts.shuffled(),
            consecutiveEventSpacing: consecutiveSpacing,
            overlappingLaneSpacing: overlappingLaneSpacing,
            overlappingLaneSpacingBoost: overlappingLaneSpacingBoost,
            contiguousTolerance: 1,
            cardBottomPadding: cardBottomPadding
        )

        let placement = calculator.placements(
            pointsPerMinute: pointsPerMinute,
            overlapLookup: makeOverlapLookup(for: layouts, parallelStartWindow: 60),
            compression: compression
        )

        let sorted = layouts.sorted { $0.item.start < $1.item.start }
        for (previous, current) in zip(sorted, sorted.dropFirst()) {
            guard
                let previousOffset = placement.offsets[previous.id],
                let currentOffset = placement.offsets[current.id]
            else {
                XCTFail("Missing placement offsets for compressed layouts")
                return
            }

            let previousHeight = max(44, CGFloat(previous.item.durationMinutes) * pointsPerMinute)
            let expectedGap = previousHeight + consecutiveSpacing
            XCTAssertGreaterThanOrEqual(
                currentOffset,
                previousOffset + expectedGap,
                "Spacing must hold even when compression collapses raw offsets"
            )
        }
    }

    func testLanePlacement_appliesOverlapBoostWhenParallelLanesAlign() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.startOfDay(for: Date())
        let baseStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let halfHour: TimeInterval = 30 * 60

        let lane0First = makeLayout(id: "lane0-first", start: baseStart, durationMinutes: 30, laneIndex: 0, totalLanes: 2)
        let lane1First = makeLayout(id: "lane1-first", start: baseStart, durationMinutes: 30, laneIndex: 1, totalLanes: 2)
        let lane0Second = makeLayout(id: "lane0-second", start: baseStart.addingTimeInterval(halfHour), durationMinutes: 30, laneIndex: 0, totalLanes: 2)
        let lane1Second = makeLayout(id: "lane1-second", start: baseStart.addingTimeInterval(halfHour), durationMinutes: 30, laneIndex: 1, totalLanes: 2)

        let layouts = [lane0Second, lane1First, lane0First, lane1Second]
        let consecutiveSpacing: CGFloat = 10
        let cardBottomPadding: CGFloat = 10
        let overlappingLaneSpacing: CGFloat = 8
        let overlappingLaneSpacingBoost: CGFloat = 6
        let pointsPerMinute: CGFloat = 1

        let calculator = TimelineLanePlacementCalculator(
            layouts: layouts,
            consecutiveEventSpacing: consecutiveSpacing,
            overlappingLaneSpacing: overlappingLaneSpacing,
            overlappingLaneSpacingBoost: overlappingLaneSpacingBoost,
            contiguousTolerance: 1,
            cardBottomPadding: cardBottomPadding
        )

        let placement = calculator.placements(
            pointsPerMinute: pointsPerMinute,
            overlapLookup: makeOverlapLookup(for: layouts, parallelStartWindow: 60),
            compression: TimelineCompressionInfo(
                referenceStart: baseStart,
                totalCompressedMinutes: 4 * 60,
                adjustments: []
            )
        )

        guard
            let lane0FirstOffset = placement.offsets[lane0First.id],
            let lane1FirstOffset = placement.offsets[lane1First.id],
            let lane0SecondOffset = placement.offsets[lane0Second.id],
            let lane1SecondOffset = placement.offsets[lane1Second.id]
        else {
            XCTFail("Missing offsets for parallel lane scenario")
            return
        }

        XCTAssertEqual(lane0FirstOffset, lane1FirstOffset, accuracy: 0.0001, "Initial overlapping events must align")

        let baseHeight = max(44, CGFloat(lane0First.item.durationMinutes) * pointsPerMinute)
        let sequentialGap = baseHeight + consecutiveSpacing
        let expectedBoost = overlappingLaneSpacing // no dynamic boost when pointsPerMinute == 1

        XCTAssertEqual(lane0SecondOffset, lane1SecondOffset, accuracy: 0.0001, "Overlap boost should keep parallel lanes aligned")
        XCTAssertEqual(
            lane0SecondOffset,
            lane0FirstOffset + sequentialGap + expectedBoost,
            accuracy: 0.0001,
            "Overlap boost must apply after guaranteeing the base spacing"
        )
    }
}

private func makeLayout(id: String, start: Date, durationMinutes: Int, laneIndex: Int, totalLanes: Int) -> TimelineScheduleLayout {
    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    let event = CalendarEvent(
        id: id,
        title: id,
        startDate: start,
        endDate: end,
        location: nil,
        calendarTitle: nil,
        isAllDay: false
    )
    let item = TimelineScheduleItem(id: id, kind: .event(event), start: start, end: end)
    return TimelineScheduleLayout(id: id, item: item, laneIndex: laneIndex, totalLanes: totalLanes)
}

private func makeOverlapLookup(for layouts: [TimelineScheduleLayout], parallelStartWindow: TimeInterval) -> [String: Bool] {
    var lookup: [String: Bool] = [:]
    for layout in layouts {
        let overlapsAnotherLane = layouts.contains { other in
            guard other.id != layout.id else { return false }
            guard other.laneIndex != layout.laneIndex else { return false }
            let startDifference = abs(layout.item.start.timeIntervalSince(other.item.start))
            guard startDifference <= parallelStartWindow else { return false }
            return layout.item.start < other.item.end
        }
        lookup[layout.id] = overlapsAnotherLane
    }
    return lookup
}
