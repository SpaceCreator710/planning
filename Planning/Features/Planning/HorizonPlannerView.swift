import SwiftUI

struct HorizonPlannerView: View {
    @Environment(AppStore.self) private var store
    @State private var horizon: PlanningHorizon = .week
    @State private var objective = ""
    @State private var building = false
    var body: some View {
        Group {
            if store.hasAccess(.horizonPlanner) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        PlanningEmptyState(title: "Make room for the bigger picture", message: "Choose one outcome. Build a roadmap, then bring its next actions into your day.", symbol: "map")
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Horizon", selection: $horizon) {
                                ForEach(PlanningHorizon.allCases) { Text($0.rawValue.capitalized).tag($0) }
                            }.pickerStyle(.segmented)
                            TextField("What outcome do you want?", text: $objective, axis: .vertical).lineLimit(3...6)
                            Button(action: build) {
                                HStack {
                                    if building { ProgressView() }
                                    Label(building ? "Building your roadmap…" : "Build roadmap", systemImage: "sparkles")
                                }.frame(maxWidth: .infinity, minHeight: 32)
                            }.buttonStyle(.glassProminent).disabled(objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || building)
                        }.padding(18).premiumGlassRounded(cornerRadius: 26).disabled(building)
                        SectionLabel("Your roadmaps")
                        if store.data.horizonPlans.isEmpty {
                            Text("Your first roadmap will appear here.").foregroundStyle(.secondary)
                        }
                        ForEach(store.data.horizonPlans.sorted { $0.createdAt > $1.createdAt }) { plan in
                            NavigationLink { HorizonRoadmapView(plan: plan) } label: {
                                PlanningDestinationRow(title: plan.title, subtitle: plan.summary, symbol: "map", detail: "\(plan.checkpoints.count) checkpoints")
                            }.buttonStyle(.plain)
                        }
                    }.padding(18)
                }
            } else {
                ContentUnavailableView { Label("Horizon Planner is Pro", systemImage: "map.fill") } description: { Text("Turn a week, month or year objective into an AI roadmap with checkpoints.") } actions: { NavigationLink("See Pro") { PaywallView() }.buttonStyle(.glassProminent) }
                    .padding()
            }
        }.appCanvas().navigationTitle("Horizon Planner")
    }
    private func build() {
        guard !building, store.hasAccess(.horizonPlanner), !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        building = true
        let requestedObjective = objective
        let requestedHorizon = horizon
        Task {
            let aiPlan = await AIService.shared.buildHorizon(
                objective: requestedObjective,
                horizon: requestedHorizon,
                context: store.data,
                health: store.healthSnapshot
            )
            let fallbackCheckpoints = [
                HorizonCheckpoint(label: "Start", outcome: "Make the first measurable move", actions: ["Define the next action", "Reserve time for it"]),
                HorizonCheckpoint(label: "Middle", outcome: "Check progress and remove friction", actions: ["Review what changed", "Adjust the plan"]),
                HorizonCheckpoint(label: "Finish", outcome: "Close the loop", actions: ["Complete the outcome", "Review what worked"])
            ]
            await MainActor.run {
                let plan = aiPlan ?? HorizonPlan(
                    horizon: requestedHorizon,
                    objective: requestedObjective,
                    title: requestedObjective,
                    summary: "A focused \(requestedHorizon.rawValue) roadmap built around one clear outcome.",
                    checkpoints: fallbackCheckpoints
                )
                store.data.horizonPlans.insert(plan, at: 0)
                store.persist()
                objective = ""
                building = false
            }
        }
    }
}

private struct HorizonRoadmapView: View {
    @Environment(AppStore.self) private var store
    let plan: HorizonPlan
    @State private var taskDraft: PlannerTask?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                PlanningEmptyState(title: plan.title, message: plan.summary, symbol: "map")
                Text("Tap an action to choose a day and time before adding it to your plan.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(plan.checkpoints) { checkpoint in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(checkpoint.label).font(.title3.weight(.semibold))
                        Text(checkpoint.outcome).foregroundStyle(.secondary)
                        ForEach(Array(checkpoint.actions.enumerated()), id: \.offset) { _, action in
                            Button {
                                taskDraft = PlannerTask(title: action, planDate: store.selectedDate, source: .ai)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(action).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "plus.circle").foregroundStyle(.tint)
                                }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(18).premiumGlassRounded(cornerRadius: 26)
                }
            }.padding(18)
        }.appCanvas().navigationTitle("Roadmap").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $taskDraft) { task in NavigationStack { TaskEditorView(task: task, isNew: true) } }
    }
}
