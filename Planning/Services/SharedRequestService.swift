import Foundation

@MainActor
enum SharedRequestService {
    static func consume(into store: AppStore) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let queued = SharedActionQueue.drain()
        for action in queued {
            switch action.kind {
            case .completeTask:
                if let id = action.taskID { store.markTaskCompleted(id) }
            case .completeSubtask:
                if let taskID = action.taskID, let subtaskID = action.subtaskID {
                    store.markSubtaskCompleted(taskID: taskID, subtaskID: subtaskID)
                }
            case .skipTask:
                if let id = action.taskID { store.skipTask(id, reason: "Skipped from widget") }
            case .addInbox:
                if let text = action.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { store.addInbox(text) }
            }
        }
        if let shared = defaults?.stringArray(forKey: "shared-inbox"), !shared.isEmpty {
            shared.forEach { value in
                let title = value.split(separator: "\n").first.map(String.init) ?? value
                store.data.inbox.append(InboxTask(title: title, note: value == title ? nil : value))
            }
            defaults?.removeObject(forKey: "shared-inbox")
            store.record("inbox-added", "Imported \(shared.count) shared items")
            store.persist()
        }
        if defaults?.bool(forKey: "open-today-requested") == true {
            defaults?.set(false, forKey: "open-today-requested")
            store.showPlannerToday()
            store.selectedDate = DateKey.today
        }
        if defaults?.bool(forKey: "open-coach-requested") == true {
            defaults?.set(false, forKey: "open-coach-requested")
            store.selectedTab = .coach
        }
        if defaults?.bool(forKey: "quick-capture-requested") == true {
            defaults?.set(false, forKey: "quick-capture-requested")
            store.showPlannerToday()
            store.quickAddRequested = true
        }
        if defaults?.bool(forKey: "new-recurring-task-requested") == true {
            defaults?.set(false, forKey: "new-recurring-task-requested")
            store.showPlannerToday()
            var task = PlanEngine.manualTask(title: "", date: DateKey.today)
            task.recurrence = .weekly
            store.presentedTask = task
        }
        if defaults?.bool(forKey: "replan-requested") == true {
            defaults?.set(false, forKey: "replan-requested")
            store.showPlannerToday()
            store.replanRequested = true
        }
        if defaults?.bool(forKey: "start-focus-requested") == true {
            defaults?.set(false, forKey: "start-focus-requested")
            store.showPlannerToday()
            if let task = store.todayPlan?.tasks.first(where: { $0.status == .pending }) { store.startTask(task.id) }
        }
    }
}
