import SwiftUI

struct PlanBuilderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var brainDump = ""
    @State private var mustWin = ""
    @State private var fixed = ""
    @State private var energy = 3
    @State private var style: PlanStyle = .realistic
    @State private var isBuilding = false
    @State private var draft: ReviewedPlanDraft?

    var body: some View {
        Form {
            Section {
                Text("What would make this day worthwhile?").font(.title2.weight(.semibold))
                Text("Add what is on your mind. You will review the schedule before anything changes.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Your day") {
                TextField("Tasks, ideas, obligations…", text: $brainDump, axis: .vertical).lineLimit(3...8)
                TextField("One important outcome", text: $mustWin)
            }
            Section("Work around") {
                TextField("Fixed commitments", text: $fixed, axis: .vertical).lineLimit(2...5)
                Stepper("Energy · \(energy)/5", value: $energy, in: 1...5)
                Picker("Plan style", selection: $style) {
                    Text("Full").tag(PlanStyle.full)
                    Text("Realistic").tag(PlanStyle.realistic)
                    Text("Minimum").tag(PlanStyle.minimum)
                }.pickerStyle(.menu)
            }
            Section {
                Button(action: build) {
                    HStack {
                        if isBuilding { ProgressView() }
                        Label(isBuilding ? "Preparing your draft…" : "Preview my day", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }.buttonStyle(.glassProminent)
                    .disabled(isBuilding || (brainDump.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mustWin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Plan with AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isBuilding) } }
        .interactiveDismissDisabled(isBuilding)
        .onAppear { fixed = store.data.profile.fixedCommitments }
        .sheet(item: $draft) { draft in
            NavigationStack { PlanDraftReviewView(draft: draft) { self.draft = nil; dismiss() } }
        }
    }
    private func build() {
        guard !isBuilding else { return }
        isBuilding = true
        let date = store.selectedDate
        let original = store.data.plans.first { $0.date == date }
        let input = PlanBuildInput(brainDump: brainDump, mustWin: mustWin, fixedCommitments: fixed, energy: energy, style: style, plannerMode: .dayChain)
        Task {
            let result = await AIService.shared.buildPlan(input: input, context: store.data, health: store.healthSnapshot, date: date, replan: false)
            let preview = original.map { PlanEngine.preserveProtected(current: $0, replacement: result.0) } ?? result.0
            draft = ReviewedPlanDraft(plan: preview, original: original, fallback: result.fallback)
            isBuilding = false
        }
    }
}

struct PlanDraftReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let draft: ReviewedPlanDraft
    let onApplied: () -> Void
    @State private var stale = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PlanningEmptyState(title: "Your day, before you commit", message: draft.fallback ? "An on-device draft is ready. Check the tasks and times below." : "Review the proposed tasks and times. Your current schedule is still unchanged.", symbol: "calendar.badge.clock")
                Text((DateKey.date(draft.plan.date) ?? .now).formatted(date: .complete, time: .omitted)).font(.headline)
                ForEach(TaskTimelineOrder.sorted(draft.plan.tasks)) { task in
                    HStack(spacing: 12) {
                        Image(systemName: IconEngine.symbol(for: task)).foregroundStyle(TaskTint.resolve(task)).frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title).font(.headline)
                            Text(task.allDay == true ? "All day" : "\(task.startTime ?? "Anytime") · \(task.durationMinutes) min").font(.subheadline).foregroundStyle(.secondary)
                            if task.timelineLocked == true || task.externalSource != nil {
                                Label("Protected", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }.padding(16).premiumGlassRounded()
                }
                if stale {
                    Text("Your schedule changed while this draft was open. Go back and generate a fresh preview; your latest edits have been kept.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(20)
        }.appCanvas().navigationTitle("Review plan").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    if store.applyReviewedPlan(draft) { onApplied() }
                    else { stale = true }
                }.disabled(stale || draft.plan.tasks.isEmpty)
            }
        }
    }
}
