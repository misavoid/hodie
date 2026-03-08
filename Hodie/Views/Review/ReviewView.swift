import SwiftUI

struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    DatePicker("Day", selection: $viewModel.selectedDate, displayedComponents: .date)
                        .onChange(of: viewModel.selectedDate) { _ in viewModel.refresh() }
                    ProgressView(value: viewModel.summary.completionRate)
                    Text("Completed: \(viewModel.summary.completed.count)")
                    Text("Unfinished: \(viewModel.summary.unfinished.count)")
                }

                Section("Completed") {
                    if viewModel.summary.completed.isEmpty {
                        Text("No completed tasks yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.summary.completed) { task in
                            Text(task.title)
                        }
                    }
                }

                Section("Unfinished") {
                    if viewModel.summary.unfinished.isEmpty {
                        Text("All tasks done!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.summary.unfinished) { task in
                            Text(task.title)
                        }
                        Button("Rollover unfinished") {
                            showingConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section("Focus Sessions") {
                    if viewModel.summary.focusSessions.isEmpty {
                        Text("No focus history")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.summary.focusSessions) { session in
                            VStack(alignment: .leading) {
                                Text(session.task?.title ?? "Session")
                                    .font(.headline)
                                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt?.formatted(date: .omitted, time: .shortened) ?? "…")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review")
            .confirmationDialog("Rollover unfinished tasks", isPresented: $showingConfirmation) {
                Button("Move to tomorrow") {
                    viewModel.rolloverDestination = .tomorrow
                    viewModel.rolloverUnfinished()
                }
                Button("Send back to inbox") {
                    viewModel.rolloverDestination = .inbox
                    viewModel.rolloverUnfinished()
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                viewModel.refresh()
            }
        }
    }
}
