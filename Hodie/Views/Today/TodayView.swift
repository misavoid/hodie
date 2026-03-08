import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var focusController: FocusController
    @State private var editingTask: Task?
    @State private var showingInboxPicker = false

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
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedDate, style: .date)
                .font(.title2)
                .bold()
            HStack {
                statBlock(label: "Planned", value: viewModel.plan.flexibleTasks.count + viewModel.plan.scheduledTasks.count)
                statBlock(label: "Done", value: viewModel.plan.completedTasks.count)
                statBlock(label: "Focus", value: viewModel.plan.hasFocusHistory ? "Active" : "—")
            }
            if viewModel.calendarAuthorization == .needsPermission {
                Button("Connect Calendar") {
                    viewModel.requestCalendarAccessIfNeeded()
                }
            }
        }
        .padding(.vertical)
    }

    private func statBlock(label: String, value: some CustomStringConvertible) -> some View {
        VStack(alignment: .leading) {
            Text("\(value)").font(.title)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var calendarContent: some View {
        if viewModel.plan.calendarEvents.isEmpty {
            Text("No events connected.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(viewModel.plan.calendarEvents) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).bold()
                    Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let location = event.location {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
