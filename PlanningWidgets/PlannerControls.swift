import AppIntents
import SwiftUI
import WidgetKit

struct StartFocusControl: ControlWidget {
    static let kind = "com.aiplanyourday.start-focus"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartFocusIntent()) { Label("Start Focus", systemImage: "scope") }
        }
        .displayName("Start Focus")
        .description("Start the next action and its Live Activity.")
    }
}

struct StartFocusIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "Start Focus"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "start-focus-requested")
        return .result()
    }
}

struct QuickCaptureControl: ControlWidget {
    static let kind = "com.aiplanyourday.quick-capture"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickCaptureIntent()) { Label("Quick Capture", systemImage: "plus.circle.fill") }
        }
        .displayName("Quick Capture")
        .description("Open the native task editor immediately.")
    }
}

struct QuickCaptureIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "Quick Capture"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "quick-capture-requested")
        return .result()
    }
}

struct CompleteNextControl: ControlWidget {
    static let kind = "com.aiplanyourday.complete-next"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CompleteNextControlIntent()) { Label("Complete Next", systemImage: "checkmark.circle.fill") }
        }
        .displayName("Complete Next")
        .description("Complete the next unfinished task without opening the app.")
    }
}

struct CompleteNextControlIntent: AppIntent {
    static let supportedModes: IntentModes = [.background]
    static let title: LocalizedStringResource = "Complete Next"
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupID)
        if let raw = defaults?.data(forKey: "planner-snapshot"),
           var snapshot = try? JSONDecoder().decode(SharedPlannerSnapshot.self, from: raw),
           let index = snapshot.tasks.firstIndex(where: { !$0.completed }) {
            let taskID = snapshot.tasks[index].id
            _ = SharedPlannerPersistence.completeTask(taskID)
            SharedActionQueue.enqueue(.init(kind: .completeTask, taskID: taskID))
            snapshot.tasks[index].completed = true
            snapshot.completed = min(snapshot.total, snapshot.completed + 1)
            let next = snapshot.tasks.first { !$0.completed }
            snapshot.nextTaskTitle = next?.title
            snapshot.nextTaskTime = next?.time
            snapshot.nextTaskIcon = next?.icon
            snapshot.updatedAt = .now
            if let encoded = try? JSONEncoder().encode(snapshot) { defaults?.set(encoded, forKey: "planner-snapshot") }
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct OpenTodayControl: ControlWidget {
    static let kind = "com.aiplanyourday.open-today"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTodayControlIntent()) { Label("Today", systemImage: "calendar") }
        }
        .displayName("Today")
        .description("Jump directly to today's horizontal day chain.")
    }
}

struct OpenTodayControlIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "Open Today"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "open-today-requested")
        return .result()
    }
}

struct RealityReplanControl: ControlWidget {
    static let kind = "com.aiplanyourday.replan"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: RealityReplanControlIntent()) { Label("Reality Replan", systemImage: "arrow.triangle.2.circlepath") }
        }
        .displayName("Reality Replan")
        .description("Open the fast rescue flow when the day slips.")
    }
}

struct RealityReplanControlIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "Reality Replan"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "replan-requested")
        return .result()
    }
}

struct OpenCoachControl: ControlWidget {
    static let kind = "com.aiplanyourday.open-coach"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenCoachControlIntent()) { Label("AI Coach", systemImage: "brain.head.profile") }
        }
        .displayName("AI Coach")
        .description("Jump straight into your active AI coaching conversation.")
    }
}

struct OpenCoachControlIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "Open AI Coach"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "open-coach-requested")
        return .result()
    }
}

struct NewTaskControl: ControlWidget {
    static let kind = "com.aiplanyourday.new-task"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NewTaskIntent()) {
                Label("New Task", systemImage: "calendar.badge.plus")
            }
        }
        .displayName("New Task")
        .description("Open the task editor for today.")
    }
}

struct NewTaskIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "New Task"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "quick-capture-requested")
        return .result()
    }
}

struct NewRecurringTaskControl: ControlWidget {
    static let kind = "com.aiplanyourday.new-recurring-task"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NewRecurringTaskIntent()) {
                Label("Recurring Task", systemImage: "repeat.circle.fill")
            }
        }
        .displayName("Recurring Task")
        .description("Open the task editor with recurrence ready to configure.")
    }
}

struct NewRecurringTaskIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    static let title: LocalizedStringResource = "New Recurring Task"
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "new-recurring-task-requested")
        return .result()
    }
}
