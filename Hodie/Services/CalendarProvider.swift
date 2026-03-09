import EventKit
import Foundation
import SwiftUI
import Combine

protocol CalendarEventSource: AnyObject {
    func events(for date: Date) async -> [CalendarEvent]
    func invalidateCache(for date: Date)
}

extension CalendarEventSource {
    func invalidateCache(for date: Date) {}
}

@MainActor
final class CalendarProvider: ObservableObject, CalendarEventSource {
    enum AuthorizationState {
        case unknown
        case needsPermission
        case denied
        case granted
    }

    @Published private(set) var authorization: AuthorizationState = .unknown
    private let eventStore = EKEventStore()
    private var changeCancellable: AnyCancellable?

    init() {
        refreshAuthorizationState()
        changeCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: eventStore)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleEventStoreChange()
            }
    }

    func refreshAuthorizationState() {
        switch EKEventStore.authorizationStatus(for: .event) {
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
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
            authorization = granted ? .granted : .denied
        } catch {
            authorization = .denied
        }
    }

    func events(for date: Date) async -> [CalendarEvent] {
        guard authorization == .granted else {
            return []
        }

        let start = date.startOfDay()
        eventStore.refreshSourcesIfNecessary()
        let end = start.addingTimeInterval(86_400)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        let events = ekEvents.map { ekEvent in
            CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title ?? "(No Title)",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                location: ekEvent.location,
                calendarTitle: ekEvent.calendar.title,
                isAllDay: ekEvent.isAllDay
            )
        }
        return events
    }

    func invalidateCache(for date: Date) {
        eventStore.reset()
        eventStore.refreshSourcesIfNecessary()
    }

    private func handleEventStoreChange() {
        eventStore.reset()
    }
}
