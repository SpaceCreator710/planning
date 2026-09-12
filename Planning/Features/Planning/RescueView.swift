import SwiftUI

struct RescueView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "distracted"
    @State private var energy = 2
    @State private var minutes = 60
    @State private var working = false
    @State private var draft: ReviewedPlanDraft?
    var body: some View {
        Group {
            if store.hasAccess(.advancedReplan) {
                Form {
                    Section("What changed?") { Picker("Reason", selection: $reason) { Text("Overslept").tag("overslept"); Text("Distracted").tag("distracted"); Text("Low energy").tag("low-energy"); Text("Task too big").tag("task-too-big"); Text("Unexpected event").tag("unexpected") }; Stepper("Energy · \(energy)/5", value: $energy, in: 1...5); Picker("Time left", selection: $minutes) { Text("10 min").tag(10); Text("30 min").tag(30); Text("1 hour").tag(60); Text("2 hours").tag(120) } }
                    Section { Button(working ? "Preparing preview…" : "Preview adjustment", systemImage: "arrow.triangle.2.circlepath", action: preview).buttonStyle(.glassProminent).disabled(working || store.activePlan == nil) }
                }
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView { Label("Reality Replan is Pro", systemImage: "arrow.triangle.2.circlepath") } description: { Text("Rebuild a disrupted day around what is still realistic.") } actions: { NavigationLink("See Pro") { PaywallView() }.buttonStyle(.glassProminent) }
                    .padding()
            }
        }
        .appCanvas()
        .interactiveDismissDisabled(working)
        .sheet(item: $draft) { draft in NavigationStack { PlanDraftReviewView(draft: draft) { self.draft = nil; dismiss() } } }
        .navigationTitle("Reality Replan").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) } }
    }

    private func preview() {
        guard !working, let current = store.activePlan else { return }
        working = true
        let input = PlanBuildInput(brainDump: current.tasks.filter { $0.status != .completed }.map(\.title).joined(separator: "\n"), mustWin: current.intention, fixedCommitments: store.data.profile.fixedCommitments + "\nChange: " + reason, energy: energy, style: .minimum, availableMinutes: minutes, plannerMode: current.mode)
        Task {
            let result = await AIService.shared.buildPlan(input: input, context: store.data, health: store.healthSnapshot, date: current.date, replan: true)
            var plan = PlanEngine.preserveProtected(current: current, replacement: result.0)
            plan.rescuedAt = SnapshotClock.stamp()
            draft = ReviewedPlanDraft(plan: plan, original: current, fallback: result.fallback, replan: true)
            working = false
        }
    }

}
