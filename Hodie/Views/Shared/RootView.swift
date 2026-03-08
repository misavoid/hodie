import SwiftUI

struct RootView: View {
    @ObservedObject var environment: AppEnvironment
    @StateObject private var todayViewModel: TodayViewModel
    @StateObject private var inboxViewModel: InboxViewModel
    @StateObject private var reviewViewModel: ReviewViewModel
    @State private var macSelection: SidebarItem? = .today

    init(environment: AppEnvironment) {
        self.environment = environment
        _todayViewModel = StateObject(wrappedValue: TodayViewModel(planner: environment.dayPlanner, taskStore: environment.taskStore, calendarProvider: environment.calendarProvider))
        _inboxViewModel = StateObject(wrappedValue: InboxViewModel(taskStore: environment.taskStore))
        _reviewViewModel = StateObject(wrappedValue: ReviewViewModel(coordinator: environment.reviewCoordinator))
    }

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(selection: $macSelection) {
                Label("Today", systemImage: "sun.max").tag(SidebarItem.today)
                Label("Inbox", systemImage: "tray").tag(SidebarItem.inbox)
                Label("Review", systemImage: "checklist").tag(SidebarItem.review)
            }
            .frame(minWidth: 180)
        } detail: {
            macContent
        }
        .toolbar { focusToolbar }
        .overlay(alignment: .bottomTrailing) {
            FocusOverlayView(controller: environment.focusController)
                .padding()
        }
#else
        TabView {
            TodayView(viewModel: todayViewModel, focusController: environment.focusController)
                .tabItem { Label("Today", systemImage: "sun.max") }
            InboxView(viewModel: inboxViewModel, focusController: environment.focusController)
                .tabItem { Label("Inbox", systemImage: "tray") }
            ReviewView(viewModel: reviewViewModel)
                .tabItem { Label("Review", systemImage: "clock.arrow.circlepath") }
        }
        .overlay(alignment: .bottom) {
            FocusOverlayView(controller: environment.focusController)
                .padding()
        }
#endif
    }

    @ToolbarContentBuilder
    private var focusToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                environment.focusController.begin(for: nil)
            } label: {
                Label("Start Focus", systemImage: "timer")
            }
            .keyboardShortcut(.init(.space), modifiers: [.command])
        }
    }

    @ViewBuilder
    private var macContent: some View {
        switch macSelection {
        case .today, .none:
            TodayView(viewModel: todayViewModel, focusController: environment.focusController)
        case .inbox:
            InboxView(viewModel: inboxViewModel, focusController: environment.focusController)
        case .review:
            ReviewView(viewModel: reviewViewModel)
        }
    }

    enum SidebarItem: Hashable {
        case today
        case inbox
        case review
    }
}
