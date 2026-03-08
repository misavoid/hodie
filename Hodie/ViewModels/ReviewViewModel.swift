import Foundation
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var summary: ReviewSummary = .empty(for: .now)
    @Published var selectedDate: Date = .now.startOfDay()
    @Published var rolloverDestination: RolloverDestination = .tomorrow

    private let coordinator: ReviewCoordinator

    init(coordinator: ReviewCoordinator) {
        self.coordinator = coordinator
        refresh()
    }

    func refresh() {
        summary = coordinator.summary(for: selectedDate)
    }

    func rolloverUnfinished() {
        coordinator.rolloverAll(summary.unfinished, destination: rolloverDestination)
        refresh()
    }
}
