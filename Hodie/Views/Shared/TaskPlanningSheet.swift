import SwiftUI

struct TaskPlanningSheet: View {
    let task: Task
    let defaultDate: Date
    let onSave: (Date, Date?, Int?) -> Void
    let onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var plannedDate: Date
    @State private var assignExactTime: Bool
    @State private var startTime: Date
    @State private var durationMinutes: Int

    init(task: Task, defaultDate: Date, onSave: @escaping (Date, Date?, Int?) -> Void, onCancel: (() -> Void)? = nil) {
        self.task = task
        self.defaultDate = defaultDate
        self.onSave = onSave
        self.onCancel = onCancel
        let initialDate = task.plannedFor ?? defaultDate
        _plannedDate = State(initialValue: initialDate)
        _assignExactTime = State(initialValue: task.scheduledStart != nil)
        _startTime = State(initialValue: task.scheduledStart ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate)
        _durationMinutes = State(initialValue: task.estimatedDurationMinutes ?? 30)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan for") {
                    DatePicker("Day", selection: $plannedDate, displayedComponents: .date)
                    Toggle("Schedule a time", isOn: $assignExactTime.animation())
                    if assignExactTime {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        Stepper(value: $durationMinutes, in: 15...240, step: 15) {
                            Text("Duration: \(durationMinutes) min")
                        }
                    }
                }
                Section("Task Details") {
                    Text(task.title)
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Plan Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(plannedDate, assignExactTime ? startTime : nil, assignExactTime ? durationMinutes : nil)
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
