import Foundation
import SwiftData
@testable import Hodie

@MainActor
enum TestUtilities {
    static func inMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Task.self,
            FocusSession.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeStores() throws -> (TaskStore, FocusSessionStore, ModelContainer) {
        let container = try inMemoryContainer()
        let context = container.mainContext
        return (TaskStore(context: context), FocusSessionStore(context: context), container)
    }
}
