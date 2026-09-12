import SwiftUI

private enum FocusPhase: String {
    case focus = "Focus"
    case breakTime = "Break"
}

struct FocusView: View {
    @Environment(AppStore.self) private var store
    @State private var focusMinutes = 25
    @State private var breakMinutes = 5
    @State private var rounds = 4
    @State private var currentRound = 1
    @State private var phase: FocusPhase = .focus
    @State private var secondsRemaining = 25 * 60
    @State private var running = false
    @State private var phaseEndsAt: Date?
    @State private var taskID: String?

    private var availableTasks: [PlannerTask] {
        TaskTimelineOrder.sorted((store.todayPlan?.tasks ?? []).filter {
            ($0.status == .pending || $0.status == .active) && $0.externalSource == nil
        })
    }

    private var task: PlannerTask? {
        availableTasks.first(where: { $0.id == taskID })
            ?? availableTasks.first(where: { $0.status == .active })
            ?? availableTasks.first(where: {
                guard let end = TaskSchedule.endDate($0) else { return false }
                let start = end.addingTimeInterval(-Double($0.durationMinutes) * 60)
                return start <= .now && end > .now
            })
            ?? availableTasks.first
    }

    private var phaseDurationSeconds: Int {
        (phase == .focus ? focusMinutes : breakMinutes) * 60
    }

    private var progress: Double {
        1 - Double(secondsRemaining) / Double(max(1, phaseDurationSeconds))
    }

    private var phaseTitle: String {
        if phase == .focus {
            return task?.title ?? "Focus session"
        } else {
            return "Reset before the next round"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !availableTasks.isEmpty {
                    Picker("Focus on", selection: Binding(
                        get: { task?.id ?? "" },
                        set: { taskID = $0; resetClockIfIdle() }
                    )) {
                        ForEach(availableTasks) { Text($0.title).tag($0.id) }
                    }
                    .pickerStyle(.menu).disabled(running)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                GlassEffectContainer(spacing: 10) {
                    PlanningAdaptiveRow(spacing: 10) {
                        Label(phase.rawValue, systemImage: phase == .focus ? "scope" : "cup.and.saucer.fill")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .premiumGlassCapsule()
                        Text("Round \(currentRound)/\(rounds)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ZStack {
                    Circle().stroke(.secondary.opacity(0.14), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: min(1, max(0, progress)))
                        .stroke(.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth(duration: 0.35), value: progress)
                    VStack(spacing: 8) {
                        Text(timeText)
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(phaseTitle)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(28)
                }
                .frame(width: 270, height: 270)

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus interval").font(.headline)
                        Picker("Focus minutes", selection: $focusMinutes) {
                            Text("15m").tag(15); Text("25m").tag(25); Text("45m").tag(45); Text("60m").tag(60)
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break").font(.headline)
                        Picker("Break minutes", selection: $breakMinutes) {
                            Text("3m").tag(3); Text("5m").tag(5); Text("10m").tag(10); Text("15m").tag(15)
                        }
                        .pickerStyle(.segmented)
                    }
                    Stepper("Rounds · \(rounds)", value: $rounds, in: 1...8)
                }
                .padding(18)
                .premiumGlassRounded(cornerRadius: 26, tint: .clear, interactive: true)
                .disabled(running)

                GlassEffectContainer(spacing: 12) {
                    PlanningAdaptiveRow(spacing: 12) {
                        Button {
                            toggleRunning()
                        } label: {
                            Label(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)

                        if phase == .breakTime {
                            Button("Skip Break", systemImage: "forward.end.fill") { advancePhase() }
                                .buttonStyle(.glass)
                                .controlSize(.large)
                        }
                    }
                }

                if !running && secondsRemaining != phaseDurationSeconds {
                    Button("Reset this interval", systemImage: "arrow.counterclockwise") { resetClockIfIdle() }
                        .buttonStyle(.glass)
                }

                Text("Focus intervals and breaks stay local and distraction-free. Your current focus block appears as a Live Activity when available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .appCanvas()
        .navigationTitle("Focus")
        .onChange(of: focusMinutes) { _, _ in resetClockIfIdle() }
        .onChange(of: breakMinutes) { _, _ in resetClockIfIdle() }
        .onChange(of: rounds) { _, newValue in currentRound = min(currentRound, newValue) }
        .task(id: running) {
            while running && secondsRemaining > 0 {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard !Task.isCancelled else { return }
                if let phaseEndsAt {
                    secondsRemaining = max(0, Int(ceil(phaseEndsAt.timeIntervalSinceNow)))
                }
            }
            if !Task.isCancelled && running && secondsRemaining <= 0 { advancePhase() }
        }
    }

    private func toggleRunning() {
        if running {
            if let phaseEndsAt { secondsRemaining = max(0, Int(ceil(phaseEndsAt.timeIntervalSinceNow))) }
            phaseEndsAt = nil
            running = false
            Task { await LiveActivityService.shared.finish() }
            return
        }
        phaseEndsAt = Date().addingTimeInterval(TimeInterval(secondsRemaining))
        running = true
        if running, phase == .focus, let task {
            taskID = task.id
            store.startTask(task.id, focusMinutes: max(1, Int(ceil(Double(secondsRemaining) / 60))))
        }
    }

    private func resetClockIfIdle() {
        guard !running else { return }
        secondsRemaining = phaseDurationSeconds
    }

    private func advancePhase() {
        running = false
        phaseEndsAt = nil
        if phase == .focus {
            if currentRound >= rounds {
                currentRound = 1
                phase = .focus
                secondsRemaining = focusMinutes * 60
                Task { await LiveActivityService.shared.finish() }
                return
            }
            phase = .breakTime
            secondsRemaining = breakMinutes * 60
            Task { await LiveActivityService.shared.finish() }
        } else {
            currentRound += 1
            phase = .focus
            secondsRemaining = focusMinutes * 60
        }
    }

    private var timeText: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }
}
