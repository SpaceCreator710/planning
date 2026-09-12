import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private var taskAlertRevision = 0

    struct PendingTaskAlert: Sendable {
        let taskId: String
        let offset: Int
        let fireDate: Date
        let title: String
    }

    func requestAuthorization() async -> Bool {
        do { return try await center.requestAuthorization(options: [.alert, .badge, .sound]) } catch { return false }
    }

    /// Schedules a single task. Full-app refreshes should prefer `rebuildUpcoming` so the
    /// pending notification queue stays bounded and chronological.
    func schedule(task: PlannerTask, enabled: Bool = true) async {
        await cancel(taskId: task.id)
        guard enabled else { return }
        for alert in alerts(for: task) where alert.fireDate > .now {
            await add(alert)
        }
    }

    /// Rebuilds task alerts in chronological order and leaves headroom for system/review alerts.
    /// The queue is deliberately bounded because iOS limits pending local notifications per app.
    func rebuildUpcoming(
        tasks: [PlannerTask],
        enabled: Bool,
        quietHoursStart: String,
        quietHoursEnd: String,
        maximumTaskAlerts: Int = 48
    ) async {
        taskAlertRevision += 1
        let revision = taskAlertRevision
        await cancelAllTaskNotifications()
        guard enabled, revision == taskAlertRevision else { return }

        let candidates = tasks
            .flatMap(alerts(for:))
            .filter { $0.fireDate > .now }
            .filter { !isInQuietHours($0.fireDate, start: quietHoursStart, end: quietHoursEnd) }
            .sorted { $0.fireDate < $1.fireDate }

        for alert in candidates.prefix(maximumTaskAlerts) {
            guard revision == taskAlertRevision else { return }
            await add(alert)
        }
    }

    func scheduleMorningPlanning(enabled: Bool, time: String = "08:00") async {
        center.removePendingNotificationRequests(withIdentifiers: ["morning-planning"])
        guard enabled, let minutes = parseMinutes(time) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Shape the day"
        content.body = "Open today’s plan and make the first action obvious."
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let request = UNNotificationRequest(
            identifier: "morning-planning",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    func scheduleOverdueRescue(enabled: Bool, tasks: [PlannerTask], now: Date = .now) async {
        center.removePendingNotificationRequests(withIdentifiers: ["overdue-rescue"])
        guard enabled, hasOverdueRun(tasks: tasks, now: now) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Replan the next move"
        content.body = "Several planned actions have passed. Open the timeline to rescue or reschedule what still matters."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "overdue-rescue",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        try? await center.add(request)
    }

    func scheduleEveningReview(enabled: Bool, time: String = "20:30") async {
        center.removePendingNotificationRequests(withIdentifiers: ["evening-review"])
        guard enabled else { return }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Close the day"
        content.body = "Review what moved, what slipped, and make tomorrow easier."
        content.sound = .default
        var components = DateComponents()
        components.hour = parts[0]
        components.minute = parts[1]
        let request = UNNotificationRequest(
            identifier: "evening-review",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    func cancel(taskId: String) async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests.map(\.identifier).filter { $0.hasPrefix("task-\(taskId)-") || $0 == "task-\(taskId)" }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAllTaskNotifications() async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests.map(\.identifier).filter { $0.hasPrefix("task-") }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func alerts(for task: PlannerTask) -> [PendingTaskAlert] {
        guard task.status == .pending || task.status == .active else { return [] }
        guard let day = DateKey.date(task.planDate) else { return [] }
        let referenceTime = task.allDay == true ? (task.allDayAlertTime ?? "09:00") : task.startTime
        guard let referenceTime else { return [] }
        let parts = referenceTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let date = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) else { return [] }

        var offsets = Set<Int>()
        // Timed tasks always get a start notification when task reminders are enabled.
        // Extra user-selected reminders are layered on top of that.
        if task.allDay != true { offsets.insert(0) }
        if let primary = task.reminderMinutesBefore { offsets.insert(primary) }
        for value in task.additionalReminderMinutesBefore ?? [] { offsets.insert(value) }

        return offsets.compactMap { offset in
            guard let fire = Calendar.current.date(byAdding: .minute, value: -offset, to: date) else { return nil }
            return PendingTaskAlert(taskId: task.id, offset: offset, fireDate: fire, title: task.title)
        }
    }

    private func hasOverdueRun(tasks: [PlannerTask], now: Date) -> Bool {
        let today = DateKey.string(now)
        let elapsed = tasks
            .filter { $0.planDate == today && $0.allDay != true && $0.startTime != nil }
            .compactMap { task -> (PlannerTask, Date)? in
                guard let day = DateKey.date(task.planDate), let start = task.startTime else { return nil }
                let parts = start.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2,
                      let startDate = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) else { return nil }
                let endDate: Date
                if let end = task.endTime {
                    let endParts = end.split(separator: ":").compactMap { Int($0) }
                    endDate = endParts.count == 2
                        ? (Calendar.current.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: day) ?? startDate.addingTimeInterval(Double(task.durationMinutes) * 60))
                        : startDate.addingTimeInterval(Double(task.durationMinutes) * 60)
                } else {
                    endDate = startDate.addingTimeInterval(Double(task.durationMinutes) * 60)
                }
                guard endDate < now else { return nil }
                return (task, endDate)
            }
            .sorted { $0.1 < $1.1 }

        var streak = 0
        for (task, _) in elapsed {
            switch task.status {
            case .pending, .active:
                streak += 1
                if streak >= 4 { return true }
            case .completed, .skipped:
                streak = 0
            }
        }
        return false
    }

    private func add(_ alert: PendingTaskAlert) async {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.offset == 0 ? "Starting now · open your live timeline" : "Starts in \(humanOffset(alert.offset))"
        content.sound = .default
        content.threadIdentifier = "planner-task"
        let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: alert.fireDate)
        let request = UNNotificationRequest(
            identifier: "task-\(alert.taskId)-\(alert.offset)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    private func isInQuietHours(_ date: Date, start: String, end: String) -> Bool {
        guard let startMinutes = parseMinutes(start), let endMinutes = parseMinutes(end) else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinutes == endMinutes { return false }
        if startMinutes < endMinutes { return minutes >= startMinutes && minutes < endMinutes }
        return minutes >= startMinutes || minutes < endMinutes
    }

    private func parseMinutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }

    private func humanOffset(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 { return "\(minutes / 60) hr" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }
}
