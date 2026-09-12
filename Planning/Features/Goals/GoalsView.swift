import SwiftUI

struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingNew = false
    @State private var showArchived = false
    private var activeGoals: [Goal] { store.data.goals.filter { showArchived ? $0.archived : !$0.archived } }
    var body: some View {
        List {
            Toggle("Show archived goals", isOn: $showArchived)
            if activeGoals.isEmpty { ContentUnavailableView("No goals yet", systemImage: "target", description: Text("Create a goal and connect your daily plan to something that matters.")) }
            ForEach(activeGoals) { goal in NavigationLink { GoalDetailView(goalID: goal.id) } label: { VStack(alignment: .leading, spacing: 6) { HStack { Text(goal.title).font(.headline); Spacer(); Text("\(goal.progress)%").font(.subheadline).monospacedDigit() }; ProgressView(value: Double(goal.progress), total: 100); if !goal.why.isEmpty { Text(goal.why).font(.caption).foregroundStyle(.secondary).lineLimit(2) } } } }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Goals").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("New goal") } }.sheet(isPresented: $showingNew) { NavigationStack { NewGoalView() } }
    }
}

private struct NewGoalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var why = ""; @State private var category: TaskCategory = .focus
    var body: some View { Form { TextField("Goal", text: $title); TextField("Why it matters", text: $why, axis: .vertical); Picker("Category", selection: $category) { ForEach(TaskCategory.allCases) { Text($0.rawValue.capitalized).tag($0) } } }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("New Goal").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { store.data.goals.append(Goal(title: title, why: why, category: category)); store.persist(); dismiss() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
}

struct GoalDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let goalID: String
    @State private var milestone = ""
    private var goal: Goal? { store.data.goals.first { $0.id == goalID } }
    var body: some View {
        Group {
            if let goal {
                Form {
                    Section("Your outcome") {
                        TextField("Goal", text: binding(\.title, fallback: goal.title))
                        TextField("Why it matters", text: binding(\.why, fallback: goal.why), axis: .vertical)
                        Slider(value: Binding(get: { Double(self.goal?.progress ?? goal.progress) }, set: { value in update { $0.progress = Int(value) } }), in: 0...100, step: 1)
                        Text("Progress · \(goal.progress)%").monospacedDigit()
                    }
                    Section("Milestones") {
                        ForEach(goal.milestones) { item in
                            Toggle(item.title, isOn: Binding(
                                get: { self.goal?.milestones.first { $0.id == item.id }?.completed ?? item.completed },
                                set: { value in update { current in
                                    guard let index = current.milestones.firstIndex(where: { $0.id == item.id }) else { return }
                                    current.milestones[index].completed = value
                                } }
                            ))
                        }
                        HStack {
                            TextField("Add milestone", text: $milestone)
                            Button {
                                let title = milestone.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !title.isEmpty else { return }
                                update { $0.milestones.append(GoalMilestone(title: title)) }
                                milestone = ""
                            } label: { Image(systemName: "plus.circle.fill").frame(width: 44, height: 44) }
                                .accessibilityLabel("Add milestone")
                                .disabled(milestone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    Section {
                        Button(goal.archived ? "Restore goal" : "Archive goal", systemImage: goal.archived ? "arrow.uturn.backward" : "archivebox") {
                            update { $0.archived.toggle() }; dismiss()
                        }
                        Text("Archived goals stay saved and can be restored from the Goals list.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else { ContentUnavailableView("Goal not found", systemImage: "scope") }
        }.scrollContentBackground(.hidden).appCanvas().navigationTitle("Goal")
    }
    private func binding<Value>(_ path: WritableKeyPath<Goal, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { goal?[keyPath: path] ?? fallback }, set: { value in update { $0[keyPath: path] = value } })
    }
    private func update(_ change: (inout Goal) -> Void) {
        guard let index = store.data.goals.firstIndex(where: { $0.id == goalID }) else { return }
        change(&store.data.goals[index]); store.persist()
    }
}
