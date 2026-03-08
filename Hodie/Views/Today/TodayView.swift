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
    @State private var showCombinedSchedule = false
    @State private var showAllDayEvents = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }
                Section {
                    Picker("Schedule View", selection: $showCombinedSchedule) {
                        Text("Timeline").tag(true)
                        Text("Separate").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                if showCombinedSchedule {
                    Section("Schedule") {
                        plannedFlexInline(draggable: true)
                            .padding(.bottom, 12)

                        CombinedScheduleView(
                            date: viewModel.selectedDate,
                            events: viewModel.plan.calendarEvents,
                            tasks: viewModel.plan.scheduledTasks
                        ) { id, start in
                            viewModel.rescheduleTask(id: id, to: start)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                } else {
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
                                    onPlan: { editingTask = task },
                                    isDraggable: true
                                )
                            }
                            .onMove { indices, newOffset in
                                var tasks = viewModel.plan.scheduledTasks
                                tasks.move(fromOffsets: indices, toOffset: newOffset)
                                viewModel.reorder(tasks: tasks)
                            }
                        }
                    }
                    plannedFlexSection(draggable: false)
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

    @ViewBuilder
    private func plannedFlexSection(draggable: Bool) -> some View {
        Section("Planned flex") {
            plannedFlexContent(draggable: draggable)
        }
    }

    @ViewBuilder
    private func plannedFlexInline(draggable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned flex")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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
                    onPlan: { editingTask = task },
                    isDraggable: draggable
                )
            }
            .onMove { indices, newOffset in
                var tasks = viewModel.plan.flexibleTasks
                tasks.move(fromOffsets: indices, toOffset: newOffset)
                viewModel.reorder(tasks: tasks)
            }
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
                            HStack(spacing: 8) {
                                Image(systemName: "tray.full")
                                    .font(.body)
                                Text("All-day events (\(allDayEvents.count))")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                        .padding(.vertical, 6)
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
