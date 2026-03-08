import Foundation

struct ReviewSummary {
    let date: Date
    let completed: [Task]
    let unfinished: [Task]
    let focusSessions: [FocusSession]

    var completionRate: Double {
        guard !unfinished.isEmpty || !completed.isEmpty else { return 1 }
        return Double(completed.count) / Double(completed.count + unfinished.count)
    }

    static func empty(for date: Date) -> ReviewSummary {
        ReviewSummary(date: date, completed: [], unfinished: [], focusSessions: [])
    }
}
