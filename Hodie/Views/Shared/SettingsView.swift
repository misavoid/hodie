import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section("Calendar") {
                switch environment.calendarProvider.authorization {
                case .granted:
                    Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .denied:
                    Label("Calendar access denied", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                    Text("Allow Hodíe to read calendars via System Settings > Privacy > Calendars.")
                case .needsPermission:
                    Button("Request Access") {
                        _Concurrency.Task { await environment.calendarProvider.requestAccess() }
                    }
                case .unknown:
                    Text("Status unknown")
                }
            }
        }
        .padding()
        .frame(minWidth: 320, minHeight: 200)
    }
}
