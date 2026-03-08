import SwiftUI

struct FocusOverlayView: View {
    @ObservedObject var controller: FocusController
    @State private var showingSetup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if controller.isPresented, let session = controller.activeSession {
                Text(session.task?.title ?? "Focus Session")
                    .font(.headline)
                ProgressView(value: controller.totalSeconds - controller.remainingSeconds, total: controller.totalSeconds)
                HStack {
                    Text(timeString(controller.remainingSeconds))
                        .monospacedDigit()
                        .font(.title2)
                    Spacer()
                    Button(controller.state == .running ? "Pause" : "Resume") {
                        controller.state == .running ? controller.pause() : controller.resume()
                    }
                    Button("Done") {
                        controller.completeManually()
                    }
                    Button("Cancel", role: .destructive) {
                        controller.cancel()
                    }
                }
            } else if showingSetup {
                Text("Ready to focus?")
                    .font(.headline)
                Picker("Preset", selection: $controller.selectedPreset) {
                    ForEach(FocusSession.SessionType.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                if controller.selectedPreset == .custom {
                    Stepper(value: $controller.customMinutes, in: 5...180, step: 5) {
                        Text("Custom duration: \(controller.customMinutes) min")
                    }
                }
                Button {
                    controller.begin(for: controller.activeTask)
                    showingSetup = false
                } label: {
                    Label("Start Focus", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Hide") {
                    showingSetup = false
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingSetup = true
                } label: {
                    Label("Start Focus", systemImage: "timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10)
    }

    private func timeString(_ remaining: TimeInterval) -> String {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
