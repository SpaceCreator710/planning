import SwiftUI

struct InboxView: View {
    @Environment(AppStore.self) private var store
    @State private var title = ""
    @State private var planningItem: InboxTask?

    var body: some View {
        List {
            Section("Quick capture") {
                HStack(spacing: 10) {
                    TextField("Capture something", text: $title)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button { add() } label: {
                        Image(systemName: "plus.circle.fill")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Add to inbox")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if store.data.inbox.isEmpty {
                ContentUnavailableView(
                    "Inbox clear",
                    systemImage: "tray",
                    description: Text("Capture an idea here when you do not want to decide when it belongs yet.")
                )
            } else {
                Section("Unplanned") {
                    ForEach(store.data.inbox) { item in
                        Button { planningItem = item } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let note = item.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Label("Plan", systemImage: "calendar.badge.plus").font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        .draggable("inbox:\(item.id)")
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.data.inbox[$0].id }
                        ids.forEach(store.deleteInbox)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Inbox")
        .sheet(item: $planningItem) { item in NavigationStack { InboxPlacementView(item: item) } }
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, payload.hasPrefix("task:") else { return false }
            store.moveTaskToInbox(String(payload.dropFirst(5)))
            return true
        }
    }

    private func add() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        store.addInbox(value)
        title = ""
    }
}

private struct InboxPlacementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: InboxTask
    @State private var date = Date()
    @State private var start = Date()
    @State private var loaded = false
    var body: some View {
        Form {
            Section {
                Text(item.title).font(.title2.weight(.semibold))
                if let note = item.note, !note.isEmpty { Text(note).foregroundStyle(.secondary) }
            }
            Section("Place in your day") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                DatePicker("Start time", selection: $start, displayedComponents: .hourAndMinute)
                Text("Your other tasks keep their chosen times. You can undo this move from Today or Workspace.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).appCanvas().navigationTitle("Plan from Inbox").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !loaded else { return }; loaded = true
                date = DateKey.date(store.selectedDate) ?? .now
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let current = store.data.inbox.first(where: { $0.id == item.id }) else { dismiss(); return }
                        let time = TimeMath.string(Calendar.current.component(.hour, from: start) * 60 + Calendar.current.component(.minute, from: start))
                        store.performTimelineTransaction(label: "Plan from Inbox") { store.planInbox(current, on: DateKey.string(date), at: time) }
                        dismiss()
                    }.disabled(!store.data.inbox.contains { $0.id == item.id })
                }
            }
    }
}
