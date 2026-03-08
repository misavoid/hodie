import Foundation

@MainActor
final class RemindersSyncEngine: ObservableObject {
    enum SyncState: Equatable {
        case idle
        case syncing
        case error(String)
    }

    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var selectedListID: String?

    var selectedListName: String? {
        guard let selectedListID else { return nil }
        return provider.availableLists.first(where: { $0.id == selectedListID })?.name
    }

    private var isSyncing: Bool {
        if case .syncing = syncState { return true }
        return false
    }

    private let provider: RemindersProvider
    private let taskStore: TaskStore
    private let settings: RemindersSettingsStore

    init(provider: RemindersProvider, taskStore: TaskStore, settings: RemindersSettingsStore = .init()) {
        self.provider = provider
        self.taskStore = taskStore
        self.settings = settings
        self.selectedListID = settings.selectedListID
    }

    func select(listID: String?) {
        guard listID != selectedListID else { return }
        selectedListID = listID
        settings.selectedListID = listID

        if listID == nil {
            syncState = .idle
            lastSyncedAt = nil
        } else {
            Task { await syncNow() }
        }
    }

    func syncIfNeeded(maxAge: TimeInterval = 300) async {
        guard provider.authorization == .granted else { return }
        guard selectedListID != nil else { return }
        guard !isSyncing else { return }
        if let lastSyncedAt, Date().timeIntervalSince(lastSyncedAt) < maxAge {
            return
        }
        await syncNow()
    }

    func syncNow() async {
        guard provider.authorization == .granted else { return }
        guard let listID = selectedListID else { return }
        guard !isSyncing else { return }

        syncState = .syncing
        let reminders = await provider.reminders(for: listID)
        let filtered = reminders.filter { shouldInclude($0) }
        taskStore.importReminders(filtered, calendarID: listID)
        lastSyncedAt = Date()
        syncState = .idle
    }

    private func shouldInclude(_ reminder: RemindersProvider.ReminderItem) -> Bool {
        if reminder.isCompleted {
            return true
        }
        guard let due = reminder.dueDate else {
            return true
        }
        return due >= Date().startOfDay()
    }
}

struct RemindersSettingsStore {
    private let defaults: UserDefaults
    private let selectedKey = "reminders.selected.list_id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedListID: String? {
        get { defaults.string(forKey: selectedKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: selectedKey)
            } else {
                defaults.removeObject(forKey: selectedKey)
            }
        }
    }
}
