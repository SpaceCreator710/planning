// Platform test doubles only. Scheduling, AppStore and AI context use production source.
import Foundation
enum VerificationResult<T: Sendable>: Sendable { case verified(T), unverified }
struct Transaction: Sendable {
    static var updates: AsyncStream<VerificationResult<Transaction>> { AsyncStream { $0.finish() } }
    func finish() async {}
}
let appGroupID = "group.planning.qa"
enum SharedDataFile {
    static let filename = "qa-unused.json"
    static let url: URL? = nil
    static func read() -> Data? { nil }
}
enum SharedStateService { static func publish(_ data: AppData) {} }
actor PersistenceService {
    static let shared = PersistenceService()
    private var snapshot = AppData()
    nonisolated static func fastBootstrapSnapshot() -> AppData? { nil }
    func saveLocalSnapshot(_ data: AppData) throws { snapshot = data }
    func save(_ data: AppData) throws { snapshot = data }
    func load() -> AppData { snapshot }
    func cloudStatus() -> Bool { false }
}
@MainActor final class SubscriptionService {
    static let shared = SubscriptionService()
    let enabled = false
    func currentTier() async -> SubscriptionTier { .free }
    func remainingFreePlanningAIRequests() -> Int { 5 }
    func consumeFreePlanningAIRequest() -> Bool { true }
}
@MainActor final class SupabaseService {
    static let shared = SupabaseService()
    var session: String? = nil
    func saveSnapshot(_ data: AppData) async -> Bool { true }
    func loadSnapshot() async -> AppData? { nil }
}
actor NotificationService {
    static let shared = NotificationService()
    func cancel(taskId: String) {}
    func requestAuthorization() -> Bool { true }
    func scheduleMorningPlanning(enabled: Bool, time: String) {}
    func scheduleOverdueRescue(enabled: Bool, tasks: [PlannerTask]) {}
    func scheduleEveningReview(enabled: Bool, time: String) {}
    func cancelAllTaskNotifications() {}
    func rebuildUpcoming(tasks: [PlannerTask], enabled: Bool, quietHoursStart: String, quietHoursEnd: String, maximumTaskAlerts: Int) {}
}
actor CalendarService {
    static let shared = CalendarService()
    func calendarTasks(from: Date, to: Date) -> [PlannerTask]? { [] }
}
actor LiveActivityService {
    static let shared = LiveActivityService()
    func finish() {}
    func start(task: PlannerTask, minutes: Int?) {}
}
actor HealthService {
    static let shared = HealthService()
    func stopBackgroundDelivery() {}
    func startBackgroundDelivery() {}
    func snapshot() -> HealthSnapshot { HealthSnapshot() }
}
