import SwiftUI
import SwiftData

struct InboxView: View {
    @ObservedObject var viewModel: InboxViewModel
    @ObservedObject var focusController: FocusController
    @Query(filter: #Predicate<Task> { $0.status == .inbox }, sort: [SortDescriptor(\Task.orderIndex, order: .forward)]) private var tasks: [Task]
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
                    if tasks.isEmpty {
                        ContentUnavailableView("Inbox is clear", systemImage: "sparkles", description: Text("Capture tasks above to start."))
                    } else {
                        ForEach(tasks) { task in
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
                            var updated = tasks
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
            .onChange(of: includeDueDate) { newValue in
                if newValue {
                    viewModel.quickDueDate = viewModel.quickDueDate ?? Date()
                } else {
                    viewModel.quickDueDate = nil
                }
            }
            .onAppear {
                includeDueDate = viewModel.quickDueDate != nil
            }
        }
    }
}
