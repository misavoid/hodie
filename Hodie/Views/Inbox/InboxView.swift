import SwiftUI
import SwiftData

struct InboxView: View {
    @ObservedObject var viewModel: InboxViewModel
    @ObservedObject var focusController: FocusController
    @State private var editingTask: Task?
    @State private var includeDueDate = false

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Capture") {
                    TextField("Task title", text: $viewModel.quickTitle)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(viewModel.addQuickTask)
                    TextField("Notes", text: $viewModel.quickNotes, axis: .vertical)
                        .lineLimit(1...3)
                    Toggle("Add due date", isOn: $includeDueDate.animation())
                    if includeDueDate {
                        DatePicker("Due", selection: Binding($viewModel.quickDueDate, default: Date()), displayedComponents: [.date])
                    }
                    Picker("Priority", selection: $viewModel.quickPriority) {
                        ForEach(Task.Priority.allCases) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                    Button(action: viewModel.addQuickTask) {
                        Label("Add to Inbox", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSaveQuickTask)
                    .keyboardShortcut(.init("n"), modifiers: [.command])
                }

                Section("Inbox") {
                    RemindersInboxSummaryRow(count: viewModel.reminderInboxCount)
                    if viewModel.inboxTasks.isEmpty {
                        ContentUnavailableView("Inbox is clear", systemImage: "sparkles", description: Text("Capture tasks above to start."))
                    } else {
                        ForEach(viewModel.inboxTasks) { task in
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
                            var updated = viewModel.inboxTasks
                            updated.move(fromOffsets: indices, toOffset: newOffset)
                            viewModel.reorder(tasks: updated)
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar { EditButton() }
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
        }
    }
}

private struct RemindersInboxSummaryRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders inbox")
                        .font(.headline)
                    Text("Imported reminders waiting to plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
            }
            Spacer()
            Text(count, format: .number)
                .font(.footnote)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .accessibilityLabel("\(count) reminders awaiting triage")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reminders inbox, \(count) reminders waiting")
    }
}
