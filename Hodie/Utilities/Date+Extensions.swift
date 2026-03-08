import Foundation

extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    func adding(minutes: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
}

extension DateInterval {
    static func from(start: Date, durationMinutes: Int) -> DateInterval {
        DateInterval(start: start, duration: TimeInterval(durationMinutes * 60))
    }
}
