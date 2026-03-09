import Foundation
import SwiftData
@testable import Hodie

@MainActor
enum TestUtilities {
    static func inMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Task.self,
            FocusSession.self,
            PomodoroSession.self,
            PomodoroBlock.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeStores() throws -> (TaskStore, FocusSessionStore, ModelContainer) {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let suiteName = "com.hodie.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite for tests")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (TaskStore(context: context, defaults: defaults), FocusSessionStore(context: context), container)
    }
}
