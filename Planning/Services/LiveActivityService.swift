@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<FocusActivityAttributes>?

    func start(task: PlannerTask, minutes: Int? = nil) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await finish()
        let start = Date()
        let duration = max(5, minutes ?? task.durationMinutes)
        let end = start.addingTimeInterval(TimeInterval(duration * 60))
        let attributes = FocusActivityAttributes(taskID: task.id, icon: IconEngine.symbol(for: task))
        let state = FocusActivityAttributes.ContentState(taskTitle: task.title, startDate: start, endDate: end)
        do {
            activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: end), pushType: nil)
        } catch { }
    }

    func finish() async {
        self.activity = nil
        for active in Activity<FocusActivityAttributes>.activities {
            let final = FocusActivityAttributes.ContentState(taskTitle: active.content.state.taskTitle, startDate: active.content.state.startDate, endDate: .now)
            await active.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
