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
    @State private var editingTask: Task?
    @State private var showingInboxPicker = false
    @State private var showAllDayEvents = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }
                Section("Calendar") {
                    calendarContent
                }
                Section("Scheduled") {
                    if viewModel.plan.scheduledTasks.isEmpty {
                        Text("No scheduled blocks yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.plan.scheduledTasks) { task in
                            TaskRowView(
                                task: task,
                                showTime: true,
                                onToggle: { viewModel.toggleCompletion(task) },
                                onFocus: { focusController.begin(for: task) },
                                onPlan: { editingTask = task }
                            )
                        }
                        .onMove { indices, newOffset in
                            var tasks = viewModel.plan.scheduledTasks
                            tasks.move(fromOffsets: indices, toOffset: newOffset)
                            viewModel.reorder(tasks: tasks)
                        }
                    }
                }
                Section("Planned flex") {
                    if viewModel.plan.flexibleTasks.isEmpty {
                        Text("Select from inbox to plan your day.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.plan.flexibleTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { viewModel.toggleCompletion(task) },
                                onFocus: { focusController.begin(for: task) },
                                onPlan: { editingTask = task }
                            )
                        }
                        .onMove { indices, newOffset in
                            var tasks = viewModel.plan.flexibleTasks
                            tasks.move(fromOffsets: indices, toOffset: newOffset)
                            viewModel.reorder(tasks: tasks)
                        }
                    }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInboxPicker = true
                    } label: {
                        Label("Plan from Inbox", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .sheet(item: $editingTask) { task in
                TaskPlanningSheet(task: task, defaultDate: viewModel.selectedDate) { date, start, duration in
                    viewModel.planToToday(task, date: date, start: start, durationMinutes: duration)
                }
            }
            .sheet(isPresented: $showingInboxPicker) {
                InboxPlanningPicker(tasks: environment.taskStore.inboxTasks()) { task in
                    editingTask = task
                }
            }
            .task { viewModel.load() }
            .refreshable { await viewModel.refresh() }
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
            .padding(.top, 4)
        case .granted:
            Label("Calendar connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
                .padding(.top, 4)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Calendar access denied", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("Open Settings") {
                    openCalendarSettings()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(.top, 4)
        case .unknown:
            ProgressView("Checking calendar access…")
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch viewModel.calendarAuthorization {
        case .granted:
            let allDayEvents = viewModel.plan.calendarEvents.filter { $0.isAllDay }
            let timedEvents = viewModel.plan.calendarEvents.filter { !$0.isAllDay }
            if allDayEvents.isEmpty && timedEvents.isEmpty {
                Text("No events scheduled for today.")
                    .foregroundStyle(.secondary)
            } else {
                if !allDayEvents.isEmpty {
                    DisclosureGroup(isExpanded: $showAllDayEvents) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allDayEvents) { event in
                                calendarEventRow(event, showTime: false)
                                    .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Label("All-day events (\(allDayEvents.count))", systemImage: "tray.full")
                            .font(.subheadline)
                            .bold()
                    }
                    .padding(.bottom, 8)
                }
                if !timedEvents.isEmpty {
                    ForEach(timedEvents) { event in
                        calendarEventRow(event, showTime: true)
                            .padding(.vertical, 4)
                    }
                }
            }
        case .needsPermission:
            Text("Connect your calendar above to see today’s events.")
                .foregroundStyle(.secondary)
        case .denied:
            Text("Calendar access is disabled. Enable it in Settings to show events here.")
                .foregroundStyle(.secondary)
        case .unknown:
            ProgressView("Loading calendar…")
        }
    }

    private func calendarEventRow(_ event: CalendarEvent, showTime: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).bold()
            if showTime {
                Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
}
