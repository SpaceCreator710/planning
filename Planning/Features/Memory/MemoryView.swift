import SwiftUI

struct MemoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section("Master memory") {
                Toggle("Memory across Planner & Workspace", isOn: Binding(
                    get: { store.data.settings.globalMemoryEnabled != false },
                    set: { store.setGlobalMemoryEnabled($0) }
                ))
                Text("When off, Planning stops learning new cross-mode preferences and AI long-term memory is excluded from prompts. Your explicit tasks, pages, notes, projects and settings remain saved because they are your content.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label("You stay in control", systemImage: "brain.head.profile")
                    .font(.headline)
                Text(store.data.settings.globalMemoryEnabled == false
                     ? "Long-term AI memory is currently disabled. Existing memories remain stored but are not used until you turn memory back on."
                     : "Planning only uses memories that are enabled here. You can disable or delete any learned preference at any time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if store.data.memories.isEmpty {
                ContentUnavailableView(
                    "No memories yet",
                    systemImage: "sparkles",
                    description: Text("Useful preferences learned from your planning and coach conversations will appear here.")
                )
            } else {
                Section("Learned preferences") {
                    ForEach(store.data.memories) { memory in
                        Toggle(isOn: Binding(
                            get: { store.data.memories.first { $0.id == memory.id }?.enabled ?? false },
                            set: { enabled in
                                guard let index = store.data.memories.firstIndex(where: { $0.id == memory.id }) else { return }
                                store.data.memories[index].enabled = enabled
                                store.persist()
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(memory.fact)
                                Text(memory.category.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.data.settings.globalMemoryEnabled == false)
                    }
                    .onDelete { offsets in
                        store.data.memories.remove(atOffsets: offsets)
                        store.persist()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("AI Memory")
    }
}
