import EventKit
import Foundation
import Combine

@MainActor
final class RemindersProvider: ObservableObject {
    enum AuthorizationState {
        case unknown
        case needsPermission
        case denied
        case granted
    }

    struct ReminderList: Identifiable, Hashable {
        let id: String
        let name: String
    }

    struct ReminderItem: Identifiable, Hashable {
        let id: String
        let calendarIdentifier: String
        let calendarTitle: String
        let title: String
        let notes: String?
        let dueDate: Date?
        let completionDate: Date?
        let recurrence: RecurrenceRule?
        let isCompleted: Bool
        let priority: Int
        let hasDueTimeComponents: Bool
        let noteCharacterCount: Int
        let isFlagged: Bool
    }

    @Published private(set) var authorization: AuthorizationState = .unknown
    @Published private(set) var availableLists: [ReminderList] = []

    private let eventStore = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    init() {
        refreshAuthorizationState()
        refreshLists()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                self.refreshLists()
            }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func refreshAuthorizationState() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            authorization = .needsPermission
        case .restricted, .denied, .writeOnly:
            authorization = .denied
        case .authorized, .fullAccess:
            authorization = .granted
        @unknown default:
            authorization = .needsPermission
        }
    }

    func requestAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17, macOS 14, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
            authorization = granted ? .granted : .denied
            refreshLists()
        } catch {
            authorization = .denied
            availableLists = []
        }
    }

    func refreshLists() {
        guard authorization == .granted else {
            availableLists = []
            return
        }

        let calendars = eventStore.calendars(for: .reminder).filter { calendar in
            guard calendar.allowsContentModifications else { return false }
            switch calendar.type {
            case .local, .calDAV:
                return true
            default:
                return false
            }
        }

        availableLists = calendars
            .map { ReminderList(id: $0.calendarIdentifier, name: $0.title) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func reminders(for calendarID: String) async -> [ReminderItem] {
        guard authorization == .granted else { return [] }
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { return [] }

        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = await fetchReminders(matching: predicate)
        return reminders.compactMap { reminder in
            let recurrence = reminder.recurrenceRules?.compactMap { recurrenceRule(from: $0) }.first
            let dueComponents = reminder.dueDateComponents
            let notes = reminder.notes

            return ReminderItem(
                id: reminder.calendarItemIdentifier,
                calendarIdentifier: calendar.calendarIdentifier,
                calendarTitle: reminder.calendar?.title ?? calendar.title,
                title: reminder.title ?? "(No Title)",
                notes: notes,
                dueDate: date(from: dueComponents),
                completionDate: reminder.completionDate,
                recurrence: recurrence,
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                hasDueTimeComponents: hasTimeComponents(dueComponents),
                noteCharacterCount: notes?.count ?? 0,
                isFlagged: reminder.priority == 1
            )
        }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func date(from components: DateComponents?) -> Date? {
        guard var components else { return nil }
        if components.timeZone == nil {
            components.timeZone = TimeZone.current
        }
        return Calendar.current.date(from: components)
    }

    private func hasTimeComponents(_ components: DateComponents?) -> Bool {
        guard let components else { return false }
        return components.hour != nil || components.minute != nil
    }

    private func recurrenceRule(from rule: EKRecurrenceRule) -> RecurrenceRule? {
        switch rule.frequency {
        case .daily:
            return RecurrenceRule(frequency: .daily, interval: rule.interval)
        case .weekly:
            return RecurrenceRule(frequency: .weekly, interval: rule.interval)
        default:
            return nil
        }
    }
}
