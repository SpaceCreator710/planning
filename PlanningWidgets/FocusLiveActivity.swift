import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct CompleteFocusTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Focus Task"

    @Parameter(title: "Task") var taskID: String

    init() { taskID = "" }
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        _ = SharedPlannerPersistence.completeTask(taskID)
        SharedActionQueue.enqueue(.init(kind: .completeTask, taskID: taskID))
        return .result()
    }
}

struct SkipFocusTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Focus Task"

    @Parameter(title: "Task") var taskID: String

    init() { taskID = "" }
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        _ = SharedPlannerPersistence.skipTask(taskID)
        SharedActionQueue.enqueue(.init(kind: .skipTask, taskID: taskID))
        return .result()
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            let accent = PlanningWidgetTheme.currentAccent
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: context.attributes.icon).font(.title2).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.taskTitle).font(.headline).lineLimit(1)
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true).font(.title3.monospacedDigit())
                        ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false)
                            .tint(accent)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button(intent: CompleteFocusTaskIntent(taskID: context.attributes.taskID)) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    Button(intent: SkipFocusTaskIntent(taskID: context.attributes.taskID)) {
                        Label("Skip", systemImage: "forward.end")
                    }
                }
                .font(.caption.weight(.semibold))
                .tint(accent)
            }
            .padding()
            .activityBackgroundTint(accent.opacity(0.10))
            .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            let accent = PlanningWidgetTheme.currentAccent
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: context.attributes.icon).font(.title2).foregroundStyle(accent) }
                DynamicIslandExpandedRegion(.center) { Text(context.state.taskTitle).font(.headline).lineLimit(1) }
                DynamicIslandExpandedRegion(.trailing) { Text(timerInterval: Date()...context.state.endDate, countsDown: true).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false)
                        HStack(spacing: 12) {
                            Button(intent: CompleteFocusTaskIntent(taskID: context.attributes.taskID)) {
                                Label("Done", systemImage: "checkmark.circle.fill")
                            }
                            Button(intent: SkipFocusTaskIntent(taskID: context.attributes.taskID)) {
                                Label("Skip", systemImage: "forward.end")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .tint(accent)
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: context.attributes.icon)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true).monospacedDigit()
            } minimal: {
                Image(systemName: "scope")
            }
            .widgetURL(URL(string: "planning://focus"))
            .keylineTint(accent)
        }
    }
}
