import AppIntents
import SwiftUI

@main
struct PlanningApp: App {
    @State private var store = AppStore()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    // These shortcuts use static parameters; their declarations are indexed
                    // by the system. No dynamic entity catalogue needs a launch-time refresh.
                    try? await Task.sleep(for: .milliseconds(5_000))
                    guard !Task.isCancelled else { return }
                    await store.monitorSubscriptionTransactions()
                }
                .onOpenURL { url in
                    _ = SupabaseService.shared.handle(url: url)
                    if url.host == "focus" { store.showPlannerToday() }
                    if url.host == "coach" { store.selectedTab = .coach }
                    if url.host == "today" { store.showPlannerToday(); store.selectedDate = DateKey.today }
                }
                .task(id: "\(scenePhase)-\(store.data.profile.onboardingCompleted)") {
                    guard scenePhase == .active, store.data.profile.onboardingCompleted else { return }

                    // Quick actions are tiny local UserDefaults reads and should be reflected
                    // immediately. Everything that can touch StoreKit, CloudKit, HealthKit,
                    // EventKit or the notification center waits until the resumed UI is visible.
                    SharedRequestService.consume(into: store)

                    try? await Task.sleep(for: .milliseconds(5_000))
                    guard !Task.isCancelled else { return }
                    await store.performForegroundRefresh()
                }
        }
    }

}

struct SiriAddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Add a task directly to Planning.")
    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "Task") var title: String
    @Parameter(title: "When") var when: Date?
    @Parameter(title: "Duration in minutes", default: 30) var durationMinutes: Int

    func perform() async throws -> some IntentResult {
        var data = await PersistenceService.shared.load()
        let target = when ?? .now
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "Planning", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a task title."])
        }
        let dateKey = DateKey.string(target)
        var task = PlanEngine.manualTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: dateKey)
        task.durationMinutes = max(5, min(480, durationMinutes))
        if when != nil {
            let components = Calendar.current.dateComponents([.hour, .minute], from: target)
            task.startTime = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
            if let start = TimeMath.minutes(task.startTime) { task.endTime = TimeMath.clockString(start + task.durationMinutes) }
        }
        if let index = data.plans.firstIndex(where: { $0.date == dateKey }) { data.plans[index].tasks.append(task) }
        else { data.plans.append(DayPlan(date: dateKey, title: dateKey == DateKey.today ? "Today" : "Plan", mode: .dayChain, tasks: [task])) }
        data.lastModifiedAt = SnapshotClock.stamp(after: data.lastModifiedAt)
        try await PersistenceService.shared.save(data)
        SharedStateService.publish(data)
        return .result()
    }
}

struct SiriAddInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture to Inbox"
    static let description = IntentDescription("Capture something without deciding when to do it.")
    static let supportedModes: IntentModes = [.background]

    @Parameter(title: "Item") var title: String

    func perform() async throws -> some IntentResult {
        var data = await PersistenceService.shared.load()
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "Planning", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter an inbox item."])
        }
        data.inbox.append(InboxTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines)))
        data.lastModifiedAt = SnapshotClock.stamp(after: data.lastModifiedAt)
        try await PersistenceService.shared.save(data)
        SharedStateService.publish(data)
        return .result()
    }
}

struct SiriCompleteNextIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Next Task"
    static let description = IntentDescription("Mark the next unfinished task as complete.")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult {
        var data = await PersistenceService.shared.load()
        guard let planIndex = data.plans.firstIndex(where: { $0.date == DateKey.today }) else { return .result() }
        let sortedIDs = data.plans[planIndex].tasks
            .filter { $0.status == .pending || $0.status == .active }
            .sorted { (TimeMath.minutes($0.startTime) ?? 1440) < (TimeMath.minutes($1.startTime) ?? 1440) }
            .map(\.id)
        guard let id = sortedIDs.first, let taskIndex = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }) else { return .result() }
        data.plans[planIndex].tasks[taskIndex].status = .completed
        data.plans[planIndex].tasks[taskIndex].completedAt = ISO8601DateFormatter().string(from: .now)
        data.lastModifiedAt = SnapshotClock.stamp(after: data.lastModifiedAt)
        try await PersistenceService.shared.save(data)
        SharedStateService.publish(data)
        return .result()
    }
}

struct SiriShowTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Schedule"
    static let description = IntentDescription("Preview today's unfinished tasks without opening Planning.")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = await PersistenceService.shared.load()
        let tasks = data.plans.first(where: { $0.date == DateKey.today })?.tasks
            .filter { $0.status == .pending || $0.status == .active }
            .sorted { (TimeMath.minutes($0.startTime) ?? 1440) < (TimeMath.minutes($1.startTime) ?? 1440) } ?? []
        let summary: String
        if tasks.isEmpty {
            summary = "Your day chain is clear."
        } else {
            summary = tasks.prefix(6).map { task in
                if let time = task.startTime { return "\(time) — \(task.title)" }
                return task.title
            }.joined(separator: ". ")
        }
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

struct SiriShowInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Inbox"
    static let description = IntentDescription("Preview captured Inbox items without opening the app.")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = await PersistenceService.shared.load()
        let items = data.inbox.prefix(6).map(\.title)
        let summary = items.isEmpty ? "Your Inbox is empty." : items.joined(separator: ". ")
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

struct SiriRealityReplanIntent: AppIntent {
    static let title: LocalizedStringResource = "Reality Replan"
    static let description = IntentDescription("Open Reality Replan when the day no longer matches the plan.")
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "replan-requested")
        return .result()
    }
}

struct SiriOpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today"
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "open-today-requested")
        return .result()
    }
}

struct SiriStartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "start-focus-requested")
        return .result()
    }
}

struct SiriOpenCoachIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AI Coach"
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "open-coach-requested")
        return .result()
    }
}

struct PlannerAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SiriAddTaskIntent(), phrases: ["Add a task in \(.applicationName)", "Plan something in \(.applicationName)"], shortTitle: "Add Task", systemImageName: "plus.circle")
        AppShortcut(intent: SiriAddInboxIntent(), phrases: ["Capture this in \(.applicationName)", "Add to my \(.applicationName) inbox"], shortTitle: "Capture", systemImageName: "tray.and.arrow.down")
        AppShortcut(intent: SiriCompleteNextIntent(), phrases: ["Complete my next task in \(.applicationName)", "I finished my next \(.applicationName) task"], shortTitle: "Complete Next", systemImageName: "checkmark.circle")
        AppShortcut(intent: SiriShowTodayIntent(), phrases: ["What's my day in \(.applicationName)", "Show my schedule in \(.applicationName)"], shortTitle: "Today's Schedule", systemImageName: "list.bullet.rectangle")
        AppShortcut(intent: SiriShowInboxIntent(), phrases: ["Show my inbox in \(.applicationName)", "What's in my \(.applicationName) inbox"], shortTitle: "Show Inbox", systemImageName: "tray.full")
        AppShortcut(intent: SiriRealityReplanIntent(), phrases: ["Replan my day in \(.applicationName)", "My plan changed in \(.applicationName)"], shortTitle: "Reality Replan", systemImageName: "arrow.triangle.2.circlepath")
        AppShortcut(intent: SiriOpenTodayIntent(), phrases: ["Show today in \(.applicationName)", "Open my day in \(.applicationName)"], shortTitle: "Today", systemImageName: "calendar")
        AppShortcut(intent: SiriStartFocusIntent(), phrases: ["Start focus in \(.applicationName)", "Focus now with \(.applicationName)"], shortTitle: "Start Focus", systemImageName: "scope")
        AppShortcut(intent: SiriOpenCoachIntent(), phrases: ["Open coach in \(.applicationName)", "Talk to my \(.applicationName) coach"], shortTitle: "AI Coach", systemImageName: "brain.head.profile")
    }

    static var shortcutTileColor: ShortcutTileColor { .pink }
}
