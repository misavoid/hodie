import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TodayView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var focusController: FocusController
    @State private var showingInboxPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }
                plannedFlexSection(draggable: false)
                Section("Timeline") {
                    TodayTimelineView(
                        layouts: viewModel.timelineLayouts,
                        allDayEvents: viewModel.plan.calendarEvents.filter { $0.isAllDay },
                        dayBounds: viewModel.dayBounds,
                        onToggleTask: { task in viewModel.toggleCompletion(task) },
                        onFocusTask: { task in focusController.begin(for: task) },
                        onPlanTask: { task in viewModel.beginTimelinePlacement(for: task) }
                    )
                    .listRowInsets(EdgeInsets())
                }
                Section("Completed") {
                    if viewModel.plan.completedTasks.isEmpty {
                        Text("No completed tasks yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.plan.completedTasks) { task in
                            TaskRowView(task: task, onToggle: { viewModel.toggleCompletion(task) })
                                .opacity(0.75)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .sheet(isPresented: $showingInboxPicker) {
                InboxPlanningPicker(tasks: environment.taskStore.inboxTasks()) { task in
                    viewModel.beginTimelinePlacement(for: task)
                }
            }
            .sheet(item: timelinePlacementBinding) { task in
                TimelineTimePickerSheet(
                    task: task,
                    bounds: viewModel.dayBounds,
                    initialTime: viewModel.timelinePlacementTime ?? viewModel.dayBounds.start,
                    onConfirm: { start in viewModel.confirmTimelinePlacement(at: start) },
                    onCancel: { viewModel.cancelTimelinePlacement() }
                )
            }
            .task { viewModel.load() }
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func plannedFlexSection(draggable: Bool) -> some View {
        Section {
            plannedFlexContent(draggable: draggable)
        }
    }

    @ViewBuilder
    private func plannedFlexContent(draggable: Bool) -> some View {
        if viewModel.plan.flexibleTasks.isEmpty {
            Button {
                showingInboxPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Select from inbox to plan your day")
                    Spacer()
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        } else {
            ForEach(viewModel.plan.flexibleTasks) { task in
                TaskRowView(
                    task: task,
                    onToggle: { viewModel.toggleCompletion(task) },
                    onFocus: { focusController.begin(for: task) },
                    onPlan: { viewModel.beginTimelinePlacement(for: task) },
                    isDraggable: draggable
                )
            }
            .onMove { indices, newOffset in
                var tasks = viewModel.plan.flexibleTasks
                tasks.move(fromOffsets: indices, toOffset: newOffset)
                viewModel.reorder(tasks: tasks)
            }
            Button {
                showingInboxPicker = true
            } label: {
                Label("Plan more from inbox", systemImage: "calendar.badge.plus")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .padding(.top, 6)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.selectedDate, style: .date)
                .font(.title2)
                .bold()
            HStack {
                statBlock(label: "Planned", value: viewModel.plan.flexibleTasks.count + viewModel.plan.scheduledTasks.count)
                statBlock(label: "Done", value: viewModel.plan.completedTasks.count)
                statBlock(label: "Focus", value: viewModel.plan.hasFocusHistory ? "Active" : "—")
            }
            calendarStatusView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    private func statBlock(label: String, value: some CustomStringConvertible) -> some View {
        VStack(alignment: .leading) {
            Text("\(value)").font(.title)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var calendarStatusView: some View {
        switch viewModel.calendarAuthorization {
        case .needsPermission:
            Button {
                viewModel.requestCalendarAccessIfNeeded()
            } label: {
                Label("Connect Calendar", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        case .granted:
            Label("Calendar connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Calendar access denied", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("Open Settings") {
                    openCalendarSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        case .unknown:
            ProgressView("Checking calendar access…")
                .padding(.top, 8)
        }
    }

    private func openCalendarSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
#endif
    }

    private var timelinePlacementBinding: Binding<Task?> {
        Binding(
            get: { viewModel.timelinePlacementTask },
            set: { newValue in
                if newValue == nil {
                    viewModel.cancelTimelinePlacement()
                }
            }
        )
    }
}
