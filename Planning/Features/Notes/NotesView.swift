import SwiftUI

struct NotesView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var editing: AppNote?
    @State private var newNote = false

    private var filtered: [AppNote] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.data.notes.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        List {
            Section {
                NavigationLink { InboxView() } label: {
                    HStack {
                        Label("Inbox", systemImage: "tray.full.fill").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .premiumGlassRounded(cornerRadius: 22, interactive: true)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section("Notes") {
                if filtered.isEmpty { ContentUnavailableView("No notes", systemImage: "note.text", description: Text("Capture an idea, then turn it into a task when you're ready.")) }
                ForEach(filtered) { note in
                    Button { editing = note } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline).foregroundStyle(.primary)
                            Text(note.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .premiumGlassRounded(cornerRadius: 22, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { offsets in offsets.map { filtered[$0].id }.forEach(store.deleteNote) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Notes").searchable(text: $search)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { newNote = true } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New note") } }
        .sheet(item: $editing) { note in NavigationStack { NoteEditorView(note: note) } }
        .sheet(isPresented: $newNote) { NavigationStack { NoteEditorView(note: AppNote(title: "")) } }
    }
}

struct NoteEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var note: AppNote
    @State private var taskDraft: PlannerTask?
    @State private var confirmDiscard = false
    private let original: AppNote
    init(note: AppNote) {
        self.original = note
        _note = State(initialValue: note)
    }
    private var empty: Bool { note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Title", text: $note.title, axis: .vertical).font(.largeTitle.weight(.semibold))
                TextEditor(text: $note.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 340)
                    .padding(12).premiumGlassRounded(cornerRadius: 24)
                Button {
                    var task = PlanEngine.manualTask(title: note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(note.body.prefix(100)) : note.title, date: store.selectedDate)
                    task.note = note.body
                    task.source = .notes
                    taskDraft = task
                } label: {
                    Label("Plan as a task", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glass).disabled(empty)
                Text("Review the task and choose its time before adding it.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.appCanvas().navigationTitle("Note").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if note != original { confirmDiscard = true } else { dismiss() } } }
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: note.title + "\n\n" + note.body) { Image(systemName: "square.and.arrow.up") }.disabled(empty) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { note.updatedAt = SnapshotClock.stamp(after: note.updatedAt); store.saveNote(note); dismiss() }.disabled(empty)
            }
        }
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(note != original)
        .confirmationDialog("Discard unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .sheet(item: $taskDraft) { task in NavigationStack { TaskEditorView(task: task, isNew: true) } }
    }
}
