import SwiftUI
import SwiftData
import Foundation

@main
struct HodieApp: App {
    @StateObject private var environment: AppEnvironment

    init() {
        let container = Self.makeContainer()
        _environment = StateObject(wrappedValue: AppEnvironment(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .environmentObject(environment)
        }
        .modelContainer(environment.container)
#if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(environment)
        }
#endif
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Task.self,
            FocusSession.self
        ])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-TESTING")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
}
