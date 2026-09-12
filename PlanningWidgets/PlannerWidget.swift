import AppIntents
import SwiftUI
import WidgetKit

struct PlannerEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedPlannerSnapshot
}

struct PlannerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlannerEntry { PlannerEntry(date: .now, snapshot: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (PlannerEntry) -> Void) { completion(PlannerEntry(date: .now, snapshot: load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlannerEntry>) -> Void) {
        let entry = PlannerEntry(date: .now, snapshot: load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(10 * 60))))
    }

    private func load() -> SharedPlannerSnapshot {
        guard let raw = UserDefaults(suiteName: appGroupID)?.data(forKey: "planner-snapshot"),
              let value = try? JSONDecoder().decode(SharedPlannerSnapshot.self, from: raw) else { return .placeholder }
        return value
    }
}

extension SharedPlannerSnapshot {
    static var placeholder: SharedPlannerSnapshot {
        .init(
            date: "Today", title: "Today", nextTaskTitle: "Build the next step", nextTaskTime: "14:30", nextTaskIcon: "scope",
            completed: 2, total: 5, updatedAt: .now,
            tasks: [
                .init(id: "1", title: "Plan the next step", time: "14:30", icon: "scope", completed: false, subtasks: [
                    .init(id: "1a", title: "Choose the first action", completed: false),
                    .init(id: "1b", title: "Start a 20-minute block", completed: false)
                ]),
                .init(id: "2", title: "Review notes", time: "15:15", icon: "note.text", completed: false)
            ],
            inboxTitles: ["Idea to sort later"],
            accentRGB: [169.0 / 255.0, 104.0 / 255.0, 104.0 / 255.0]
        )
    }
}

struct CompleteSharedTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "Task") var taskID: String

    init() { taskID = "" }
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        _ = SharedPlannerPersistence.completeTask(taskID)
        SharedActionQueue.enqueue(.init(kind: .completeTask, taskID: taskID))
        SharedWidgetMutation.complete(taskID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct CompleteSharedSubtaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Subtask"
    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "Task") var taskID: String
    @Parameter(title: "Subtask") var subtaskID: String

    init() { taskID = ""; subtaskID = "" }
    init(taskID: String, subtaskID: String) { self.taskID = taskID; self.subtaskID = subtaskID }

    func perform() async throws -> some IntentResult {
        _ = SharedPlannerPersistence.completeSubtask(taskID: taskID, subtaskID: subtaskID)
        SharedActionQueue.enqueue(.init(kind: .completeSubtask, taskID: taskID, subtaskID: subtaskID))
        SharedWidgetMutation.completeSubtask(taskID: taskID, subtaskID: subtaskID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipSharedTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Task"
    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "Task") var taskID: String

    init() { taskID = "" }
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        _ = SharedPlannerPersistence.skipTask(taskID)
        SharedActionQueue.enqueue(.init(kind: .skipTask, taskID: taskID))
        SharedWidgetMutation.remove(taskID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

private enum SharedWidgetMutation {
    static func complete(_ id: String) {
        mutate { snapshot in
            guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { return }
            if !snapshot.tasks[index].completed { snapshot.completed = min(snapshot.total, snapshot.completed + 1) }
            snapshot.tasks[index].completed = true
            refreshNext(&snapshot)
        }
    }

    static func completeSubtask(taskID: String, subtaskID: String) {
        mutate { snapshot in
            guard let taskIndex = snapshot.tasks.firstIndex(where: { $0.id == taskID }),
                  let subtaskIndex = snapshot.tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
            snapshot.tasks[taskIndex].subtasks[subtaskIndex].completed = true
        }
    }

    static func remove(_ id: String) {
        mutate { snapshot in
            snapshot.tasks.removeAll { $0.id == id }
            snapshot.total = max(snapshot.completed, snapshot.total - 1)
            refreshNext(&snapshot)
        }
    }

    private static func mutate(_ body: (inout SharedPlannerSnapshot) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let raw = defaults?.data(forKey: "planner-snapshot"), var snapshot = try? JSONDecoder().decode(SharedPlannerSnapshot.self, from: raw) else { return }
        body(&snapshot)
        snapshot.updatedAt = .now
        if let encoded = try? JSONEncoder().encode(snapshot) { defaults?.set(encoded, forKey: "planner-snapshot") }
    }

    private static func refreshNext(_ snapshot: inout SharedPlannerSnapshot) {
        let next = snapshot.tasks.first { !$0.completed }
        snapshot.nextTaskTitle = next?.title
        snapshot.nextTaskTime = next?.time
        snapshot.nextTaskIcon = next?.icon
    }
}

enum PlanningWidgetTheme {
    static var currentAccent: Color {
        guard let raw = UserDefaults(suiteName: appGroupID)?.data(forKey: "planner-snapshot"),
              let snapshot = try? JSONDecoder().decode(SharedPlannerSnapshot.self, from: raw) else {
            return Color(red: 169.0 / 255.0, green: 104.0 / 255.0, blue: 104.0 / 255.0)
        }
        return snapshot.widgetAccent
    }
}

extension SharedPlannerSnapshot {
    var widgetAccent: Color {
        guard let accentRGB, accentRGB.count >= 3 else {
            return Color(red: 169.0 / 255.0, green: 104.0 / 255.0, blue: 104.0 / 255.0)
        }
        return Color(
            red: max(0, min(1, accentRGB[0])),
            green: max(0, min(1, accentRGB[1])),
            blue: max(0, min(1, accentRGB[2]))
        )
    }
}

private struct PlanningWidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    let accent: Color

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.08) : Color(red: 0.985, green: 0.98, blue: 0.97))
            LinearGradient(
                colors: [accent.opacity(scheme == .dark ? 0.26 : 0.18), .clear, accent.opacity(scheme == .dark ? 0.08 : 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.12 : 0.09))
                .frame(width: 150, height: 150)
                .blur(radius: 24)
                .offset(x: 70, y: -65)
        }
    }
}

private struct AccentBadge: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(accent)
            .background(accent.opacity(0.14), in: Capsule())
    }
}

private struct InteractiveTaskRow: View {
    let task: SharedTaskSummary
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: CompleteSharedTaskIntent(taskID: task.id)) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: task.icon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(task.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .strikethrough(task.completed)
                }
                if let time = task.time {
                    Text(time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct InteractiveSubtaskRow: View {
    let taskID: String
    let subtask: SharedSubtaskSummary
    let accent: Color

    var body: some View {
        HStack(spacing: 7) {
            Button(intent: CompleteSharedSubtaskIntent(taskID: taskID, subtaskID: subtask.id)) {
                Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Text(subtask.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .strikethrough(subtask.completed)
            Spacer(minLength: 0)
        }
    }
}

struct PlannerWidgetView: View {
    let entry: PlannerEntry

    var body: some View {
        let accent = entry.snapshot.widgetAccent
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(entry.snapshot.title, systemImage: "circle.grid.cross.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Spacer()
                AccentBadge(text: "\(entry.snapshot.completed)/\(entry.snapshot.total)", accent: accent)
            }
            if let task = entry.snapshot.tasks.first(where: { !$0.completed }) {
                InteractiveTaskRow(task: task, accent: accent)
            } else {
                Label("Your chain is clear.", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Text("Add the next task when you're ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ProgressView(value: Double(entry.snapshot.completed), total: Double(max(1, entry.snapshot.total)))
                .tint(accent)
        }
        .containerBackground(for: .widget) { PlanningWidgetBackground(accent: accent) }
    }
}

struct TimelineOverviewWidgetView: View {
    let entry: PlannerEntry

    var body: some View {
        let accent = entry.snapshot.widgetAccent
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Day Chain", systemImage: "timeline.selection")
                    .font(.headline)
                    .foregroundStyle(accent)
                Spacer()
                AccentBadge(text: "\(entry.snapshot.completed)/\(entry.snapshot.total)", accent: accent)
            }
            Capsule()
                .fill(accent.opacity(0.18))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let progress = entry.snapshot.total > 0 ? Double(entry.snapshot.completed) / Double(entry.snapshot.total) : 0
                        Capsule()
                            .fill(accent)
                            .frame(width: max(6, proxy.size.width * CGFloat(progress)))
                    }
                }
            ForEach(entry.snapshot.tasks.prefix(5)) { task in
                InteractiveTaskRow(task: task, accent: accent)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { PlanningWidgetBackground(accent: accent) }
    }
}

struct InboxOverviewWidgetView: View {
    let entry: PlannerEntry

    var body: some View {
        let accent = entry.snapshot.widgetAccent
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Inbox", systemImage: "tray.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Spacer()
                AccentBadge(text: "\(entry.snapshot.inboxTitles.count)", accent: accent)
            }
            ForEach(Array(entry.snapshot.inboxTitles.prefix(4).enumerated()), id: \.offset) { _, title in
                HStack(spacing: 7) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text(title).font(.caption).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(intent: QuickCaptureIntent()) {
                Label("Capture", systemImage: "plus")
                    .foregroundStyle(accent)
            }
            .font(.caption.weight(.semibold))
        }
        .containerBackground(for: .widget) { PlanningWidgetBackground(accent: accent) }
    }
}

struct CurrentTaskWidgetView: View {
    let entry: PlannerEntry

    var body: some View {
        let accent = entry.snapshot.widgetAccent
        VStack(alignment: .leading, spacing: 8) {
            if let task = entry.snapshot.tasks.first(where: { !$0.completed }) {
                HStack {
                    Label(task.title, systemImage: task.icon)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(accent)
                    Spacer()
                    Button(intent: CompleteSharedTaskIntent(taskID: task.id)) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                if let time = task.time {
                    Text(time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if task.subtasks.isEmpty {
                    Text("No subtasks yet").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(task.subtasks.prefix(4)) { subtask in
                        InteractiveSubtaskRow(taskID: task.id, subtask: subtask, accent: accent)
                    }
                }
            } else {
                Label("Day complete", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Text("Nothing unfinished right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { PlanningWidgetBackground(accent: accent) }
    }
}

struct PlannerWidget: Widget {
    let kind = "AIPlanYourDay.NextAction"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlannerProvider()) { PlannerWidgetView(entry: $0) }
            .configurationDisplayName("Next Action")
            .description("See and complete the next task in your day chain.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct TimelineOverviewWidget: Widget {
    let kind = "AIPlanYourDay.Timeline"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlannerProvider()) { TimelineOverviewWidgetView(entry: $0) }
            .configurationDisplayName("Day Chain")
            .description("Complete tasks directly from your live day chain.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct InboxOverviewWidget: Widget {
    let kind = "AIPlanYourDay.Inbox"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlannerProvider()) { InboxOverviewWidgetView(entry: $0) }
            .configurationDisplayName("Inbox")
            .description("See captured items and jump into quick capture.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CurrentTaskWidget: Widget {
    let kind = "AIPlanYourDay.CurrentTask"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlannerProvider()) { CurrentTaskWidgetView(entry: $0) }
            .configurationDisplayName("Current Task + Subtasks")
            .description("See the current task and complete its subtasks without opening the app.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
