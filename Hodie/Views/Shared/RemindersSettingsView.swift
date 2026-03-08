import SwiftUI

struct RemindersSettingsView: View {
    @ObservedObject var provider: RemindersProvider
    @ObservedObject var syncEngine: RemindersSyncEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                listsSection
                if provider.authorization == .granted, syncEngine.selectedListID != nil {
                    Section {
                        Button {
                            _Concurrency.Task { await syncEngine.syncNow() }
                        } label: {
                            if case .syncing = syncEngine.syncState {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                    Text("Syncing…")
                                }
                            } else {
                                Label("Sync now", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                provider.refreshAuthorizationState()
                provider.refreshLists()
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            switch provider.authorization {
            case .needsPermission:
                Button("Request Access") {
                    _Concurrency.Task { await provider.requestAccess() }
                }
                Text("Hodíe needs reminders access to import Siri-captured tasks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .denied:
                Label("Access denied", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                Text("Enable reminders access in Settings > Privacy > Reminders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unknown:
                Text("Status unknown. Try reloading the sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .granted:
                Label("Reminders access granted", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            if let selectedName = syncEngine.selectedListName {
                Text("Connected to \"\(selectedName)\"")
            } else if provider.authorization == .granted {
                Text("Select which Reminders list should feed your inbox.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastSyncedAt = syncEngine.lastSyncedAt {
                Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var listsSection: some View {
        let lists = provider.availableLists
        return Section("Reminder Lists") {
            if provider.authorization != .granted {
                Text("Grant reminders access to view your lists.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if lists.isEmpty {
                Text("No reminder lists available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lists, id: \.id) { list in
                    Button {
                        syncEngine.select(listID: list.id)
                    } label: {
                        HStack {
                            Text(list.name)
                            Spacer()
                            if syncEngine.selectedListID == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                }
                if syncEngine.selectedListID != nil {
                    Button("Stop Importing", role: .destructive) {
                        syncEngine.select(listID: nil)
                    }
                }
            }
        }
    }
}
