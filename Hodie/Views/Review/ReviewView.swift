import SwiftUI
import Charts

struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var showingConfirmation = false

    private let metricColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    datePickerCard
                    completionCard
                    metricsGrid
                    tasksBreakdownCard
                    focusHistoryCard
                    rolloverCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
            .task { viewModel.refresh() }
        }
    }

    private var datePickerCard: some View {
        DashboardCard(title: "Selected Day", icon: "calendar", tint: .mint) {
            DatePicker(
                "Day",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.refresh()
            }
        }
    }

    private var completionCard: some View {
        DashboardCard(title: "Completion", icon: "checkmark.seal.fill", tint: .green) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(completionPercentText)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("of today's plan done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView(value: viewModel.summary.completionRate)
                    .tint(.green)
                    .scaleEffect(y: 1.3)
                    .frame(width: 120)
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: 16) {
            ReviewMetricCard(
                title: "Completed",
                value: "\(viewModel.summary.completed.count)",
                subtitle: "tasks",
                icon: "checkmark.circle.fill",
                tint: .green
            )
            ReviewMetricCard(
                title: "Unfinished",
                value: "\(viewModel.summary.unfinished.count)",
                subtitle: "left",
                icon: "exclamationmark.circle.fill",
                tint: .orange
            )
            ReviewMetricCard(
                title: "Focus time",
                value: focusDurationLabel,
                subtitle: "logged",
                icon: "timer",
                tint: .indigo
            )
            ReviewMetricCard(
                title: "Total tasks",
                value: "\(totalTasks)",
                subtitle: "planned",
                icon: "list.bullet.rectangle.fill",
                tint: .blue
            )
        }
    }

    private var tasksBreakdownCard: some View {
        DashboardCard(title: "Task Breakdown", icon: "chart.pie.fill", tint: .purple) {
            if taskMetrics.isEmpty {
                placeholder("Log tasks to see progress.")
            } else {
                Chart(taskMetrics) { metric in
                    SectorMark(
                        angle: .value("Tasks", metric.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(metric.color.gradient)
                }
                .frame(height: 200)
                .overlay(alignment: .center) {
                    VStack(spacing: 2) {
                        Text("\(totalTasks)")
                            .font(.title2.weight(.bold))
                        Text("tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    ForEach(taskMetrics) { metric in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(metric.color)
                                .frame(width: 10, height: 10)
                            Text("\(metric.id) \(metric.value)")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
    }

    private var focusHistoryCard: some View {
        DashboardCard(title: "Focus History", icon: "chart.bar.fill", tint: .indigo) {
            if focusData.isEmpty {
                placeholder("No focus sessions yet.")
            } else {
                Chart(focusData) { datum in
                    BarMark(
                        x: .value("Minutes", datum.duration),
                        y: .value("Session", datum.title)
                    )
                    .foregroundStyle(datum.color.gradient)
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text("\(Int(datum.duration))m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: CGFloat(focusData.count) * 34 + 40)
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var rolloverCard: some View {
        DashboardCard(title: "Unfinished", icon: "arrow.uturn.forward.circle.fill", tint: .orange) {
            if viewModel.summary.unfinished.isEmpty {
                placeholder("All tasks completed — nice work!")
            } else {
                Text("\(viewModel.summary.unfinished.count) tasks still open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                unfinishedChipRow
                Button {
                    showingConfirmation = true
                } label: {
                    Label("Rollover unfinished", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    private var unfinishedChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(unfinishedPreview) { task in
                    Text(task.title)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2), in: Capsule())
                }
            }
            .padding(.top, 4)
        }
    }

    private var taskMetrics: [TaskStatusDatum] {
        [
            TaskStatusDatum(id: "Completed", value: viewModel.summary.completed.count, color: .green),
            TaskStatusDatum(id: "Unfinished", value: viewModel.summary.unfinished.count, color: .orange)
        ].filter { $0.value > 0 }
    }

    private var focusData: [FocusSessionDatum] {
        viewModel.summary.focusSessions.map { session in
            FocusSessionDatum(
                id: session.id,
                title: session.task?.title ?? session.sessionType.label,
                duration: Double(session.actualDurationMinutes ?? session.plannedDurationMinutes),
                color: session.wasCompleted ? .indigo : .gray
            )
        }
    }

    private var unfinishedPreview: [Task] {
        Array(viewModel.summary.unfinished.prefix(6))
    }

    private var totalTasks: Int {
        viewModel.summary.completed.count + viewModel.summary.unfinished.count
    }

    private var completionPercentText: String {
        let percent = Int((viewModel.summary.completionRate * 100).rounded())
        return "\(percent)%"
    }

    private var totalFocusMinutes: Int {
        focusData.reduce(0) { partial, datum in
            partial + Int(datum.duration)
        }
    }

    private var focusDurationLabel: String {
        let hours = totalFocusMinutes / 60
        let minutes = totalFocusMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    @ViewBuilder
    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct ReviewMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.25), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct TaskStatusDatum: Identifiable {
    let id: String
    let value: Int
    let color: Color
}

private struct FocusSessionDatum: Identifiable {
    let id: UUID
    let title: String
    let duration: Double
    let color: Color
}
