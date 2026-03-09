import SwiftUI
import SwiftData

struct InboxView: View {
    @ObservedObject var viewModel: InboxViewModel
    @ObservedObject var focusController: FocusController
    @ObservedObject var remindersProvider: RemindersProvider
    @ObservedObject var remindersSync: RemindersSyncEngine
    @State private var editingTask: Task?
    @State private var includeDueDate = false
    @State private var showingRemindersSheet = false
    @FocusState private var focusedQuickField: QuickField?

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Capture") {
                    TextField("Task title", text: $viewModel.quickTitle, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.title3)
                        .padding(.vertical, 4)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(handleQuickAdd)
                        .onChange(of: viewModel.quickTitle) { _, newValue in
                            guard newValue.contains(where: \.isNewline) else { return }
                            let sanitized = newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.quickTitle = sanitized
                            handleQuickAdd()
                        }
                        .accessibilityIdentifier("quickCapture.title")
                        .focused($focusedQuickField, equals: .title)
                    TextField("Notes", text: $viewModel.quickNotes, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedQuickField, equals: .notes)
                    Picker("Task Type", selection: $viewModel.quickType) {
                        ForEach(Task.TaskType.allCases) { type in
                            Text(type.displayName).tag(Optional(type))
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Add due date", isOn: $includeDueDate.animation())
                    if includeDueDate {
                        DatePicker("Due", selection: Binding($viewModel.quickDueDate, default: Date()), displayedComponents: [.date])
                    }
                    Picker("Priority", selection: $viewModel.quickPriority) {
                        ForEach(Task.Priority.allCases) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                    Button(action: handleQuickAdd) {
                        Label("Add to Inbox", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSaveQuickTask)
                    .keyboardShortcut(.init("n"), modifiers: [.command])
                }

                Section("Inbox") {
                    Button {
                        showingRemindersSheet = true
                    } label: {
                        RemindersInboxSummaryRow(
                            count: viewModel.reminderInboxCount,
                            authorization: remindersProvider.authorization,
                            selectedListName: remindersSync.selectedListName,
                            syncState: remindersSync.syncState
                        )
                    }
                    .buttonStyle(.plain)

                    if viewModel.scheduledReminderTasks.isEmpty == false {
                        DisclosureGroup(isExpanded: Binding(
                            get: { viewModel.scheduledRemindersExpanded },
                            set: { viewModel.setScheduledSectionExpanded($0) }
                        )) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.scheduledReminderTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        onToggle: { viewModel.toggleCompletion(task) },
                                        onFocus: { focusController.begin(for: task) },
                                        onPlan: { editingTask = task },
                                        onDelete: { viewModel.delete(task) }
                                    )
                                    .swipeActions(edge: .trailing) {
                                        Button("Plan") { editingTask = task }
                                            .tint(.indigo)
                                        Button("Focus") { focusController.begin(for: task) }
                                            .tint(.orange)
                                        Button(role: .destructive) { viewModel.delete(task) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label("Scheduled & Recurring Reminders", systemImage: "calendar.badge.clock")
                                Spacer()
                                CountBadge(count: viewModel.scheduledReminderTasks.count)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Show or hide scheduled reminders")
                    }

                    if viewModel.inboxDisplayTasks.isEmpty {
                        if viewModel.scheduledReminderTasks.isEmpty {
                            ContentUnavailableView("Inbox is clear", systemImage: "sparkles", description: Text("Capture tasks above to start."))
                        }
                    } else {
                        ForEach(viewModel.inboxDisplayTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { viewModel.toggleCompletion(task) },
                                onFocus: { focusController.begin(for: task) },
                                onPlan: { editingTask = task },
                                onDelete: { viewModel.delete(task) }
                            )
                            .swipeActions(edge: .trailing) {
                                Button("Plan") { editingTask = task }
                                    .tint(.indigo)
                                Button("Focus") { focusController.begin(for: task) }
                                    .tint(.orange)
                                Button(role: .destructive) { viewModel.delete(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { indices, newOffset in
                            var updated = viewModel.inboxDisplayTasks
                            updated.move(fromOffsets: indices, toOffset: newOffset)
                            viewModel.reorder(tasks: updated)
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                EditButton()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedQuickField = nil
                    }
                }
            }
            .sheet(item: $editingTask) { task in
                TaskPlanningSheet(task: task, defaultDate: .now) { date, start, duration in
                    viewModel.plan(task, for: date, start: start, durationMinutes: duration)
                }
            }
            .onChange(of: includeDueDate) { _, newValue in
                viewModel.quickDueDate = newValue ? (viewModel.quickDueDate ?? Date()) : nil
            }
            .onAppear {
                includeDueDate = viewModel.quickDueDate != nil
            }
            .task {
                viewModel.refreshInbox()
            }
            .task {
                await remindersSync.syncIfNeeded()
            }
            .sheet(isPresented: $showingRemindersSheet) {
                RemindersSettingsView(provider: remindersProvider, syncEngine: remindersSync)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: remindersSync.lastSyncedAt) { _, _ in
                viewModel.refreshInbox()
            }
        }
    }

    private func handleQuickAdd() {
        viewModel.addQuickTask()
        focusedQuickField = nil
    }

    private enum QuickField: Hashable {
        case title
        case notes
    }
}

private struct RemindersInboxSummaryRow: View {
    let count: Int
    let authorization: RemindersProvider.AuthorizationState
    let selectedListName: String?
    let syncState: RemindersSyncEngine.SyncState

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders inbox")
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
            }
            Spacer()
            if case .syncing = syncState {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                CountBadge(count: count)
                    .accessibilityLabel("\(count) reminders awaiting triage")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reminders inbox, \(count) reminders waiting")
    }

    private var statusText: String {
        switch authorization {
        case .needsPermission:
            return "Connect to Apple Reminders"
        case .denied:
            return "Permission denied"
        case .unknown:
            return "Status unknown"
        case .granted:
            if let selectedListName, !selectedListName.isEmpty {
                return "Syncing \"\(selectedListName)\""
            } else {
                return "Select a list to import"
            }
        }
    }
}

private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.footnote)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}
