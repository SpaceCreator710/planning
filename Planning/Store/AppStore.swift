import Foundation
import Observation
import StoreKit
import SwiftUI

@MainActor @Observable
final class AppStore {
    var data = AppData()
    var selectedDate = DateKey.today
    var selectedTab = AppTab.today
    var presentedTask: PlannerTask?
    var healthSnapshot = HealthSnapshot()
    var isHydrated = false
    var syncMessage: String?
    var activeConversationId = "default"
    var quickAddRequested = false
    var replanRequested = false
    private(set) var pendingCoachActions: [CoachAction] = []
    private(set) var pendingCoachActionSummary: String?
    private(set) var timelineUndoLabel: String?
    private struct UndoCheckpoint {
        let label: String
        let before: AppData
        var after: AppData
    }
    private var timelineUndoHistory: [UndoCheckpoint] = []
    private var timelineUndoTransactionDepth = 0
    private var lastCloudRefreshAt: Date?
    private var lastForegroundRefreshAt: Date?
    private var lastForegroundSubscriptionRefreshAt: Date?
    private var lastForegroundNotificationRefreshAt: Date?
    private var lastForegroundHealthRefreshAt: Date?
    private var lastForegroundExternalSourcesRefreshAt: Date?
    private var didRunDeferredLocalMaintenance = false
    private var runningCustomAgentIDs: Set<String> = []
    private var healthRefreshInProgress = false
    private var pendingPersistenceSnapshot: AppData?
    private var persistenceTask: Task<Void, Never>?
    private static let iconRepairCatalogVersion = 1
    private static let iconRepairCatalogVersionKey = "planning.icon-repair-catalog-version"
    private static let localPersistenceFormatVersion = 2
    private static let localPersistenceFormatVersionKey = "planning.local-persistence-format-version"

    enum AppTab: String, CaseIterable, Identifiable, Hashable { case today, calendar, coach, notes, workspace, profile; var id: String { rawValue } }

    init() {
        // Seed the first frame synchronously from the tiny on-device JSON snapshot.
        // This avoids showing a temporary loading screen while the normal async
        // hydration/repair pass runs immediately afterward. No cloud/network work
        // happens here.
        var snapshot = Self.bootstrapLocalSnapshot()
        snapshot.settings.soundEffectsEnabled = false
        snapshot.settings.autoCalendarReplan = false
        snapshot.settings.timelineFlowShiftEnabled = false
        if snapshot.settings.timelineLayout == .orbit { snapshot.settings.timelineLayout = .horizontal }
        if snapshot.settings.weekTimelineLayout == .orbit { snapshot.settings.weekTimelineLayout = .horizontal }
        snapshot.subscription = .free
        if snapshot.settings.experienceMode == .hybrid { snapshot.settings.experienceMode = .workspace }
        data = snapshot
        selectedDate = DateKey.today
        isHydrated = true

        // The first frame already has the complete local snapshot. Do not decode the same JSON
        // a second time at launch; only non-urgent normalization/migration work remains.
        Task { await hydrate() }
    }

    private static func bootstrapLocalSnapshot() -> AppData {
        if let fast = PersistenceService.fastBootstrapSnapshot() { return fast }

        let decoder = JSONDecoder()
        if let raw = SharedDataFile.read(),
           let decoded = try? decoder.decode(AppData.self, from: raw) {
            return decoded
        }

        // One-time fallback for installs that still have the prerelease local path.
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIPlanYourDay", isDirectory: true)
        let legacy = root.appendingPathComponent(SharedDataFile.filename)
        if let raw = try? Data(contentsOf: legacy, options: .mappedIfSafe),
           let decoded = try? decoder.decode(AppData.self, from: raw) {
            return decoded
        }

        return AppData()
    }

    var activePlan: DayPlan? { data.plans.first(where: { $0.date == selectedDate }) }
    var todayPlan: DayPlan? { data.plans.first(where: { $0.date == DateKey.today }) }

    func hasAccess(_ feature: PremiumFeature) -> Bool {
        if !SubscriptionService.shared.enabled { return true }
        #if DEBUG
        return true
        #else
        return data.subscription.rank >= feature.requiredTier.rank
        #endif
    }

    var freePlanningAIRemaining: Int {
        hasAccess(.fullAI) ? Int.max : SubscriptionService.shared.remainingFreePlanningAIRequests()
    }

    func canUseAIMode(_ mode: AIAssistantMode) -> Bool {
        if hasAccess(.fullAI) { return true }
        return mode == .planning && SubscriptionService.shared.remainingFreePlanningAIRequests() > 0
    }

    func adoptSnapshot(_ snapshot: AppData) {
        let verifiedTier = data.subscription
        var normalized = snapshot
        normalized.settings.soundEffectsEnabled = false
        normalized.settings.autoCalendarReplan = false
        normalized.settings.timelineFlowShiftEnabled = false
        if normalized.settings.timelineLayout == .orbit { normalized.settings.timelineLayout = .horizontal }
        if normalized.settings.weekTimelineLayout == .orbit { normalized.settings.weekTimelineLayout = .horizontal }
        normalized.subscription = verifiedTier
        if normalized.settings.experienceMode == .hybrid { normalized.settings.experienceMode = .workspace }
        data = normalized
        enforceSettingsEntitlements()
        persist()
    }

    private func sanitizedForEntitlements(_ incoming: PlannerTask) -> PlannerTask {
        var task = incoming
        if !hasAccess(.recurrence) {
            task.recurrence = TaskRecurrence.none
            task.recurrenceDays = nil
            task.recurrenceInterval = nil
            task.recurrenceUnit = nil
            task.recurrenceUntil = nil
            task.recurrenceSeriesId = nil
            task.recurrenceGenerated = false
        }
        if !hasAccess(.customAlerts) {
            let first = ([task.reminderMinutesBefore].compactMap { $0 } + (task.additionalReminderMinutesBefore ?? [])).sorted().first
            task.reminderMinutesBefore = first
            task.additionalReminderMinutesBefore = nil
        }
        if !hasAccess(.premiumAppearance) {
            task.customTintHue = nil
            task.customTintSaturation = nil
            task.customTintLightness = nil
        }
        return task
    }

    func hydrate() async {
        // `init` already decoded the complete local snapshot synchronously so the correct
        // onboarding/theme/today UI can be drawn on frame one. A second disk read/decode here
        // was pure duplicate work. Keep launch hydration memory-only and postpone maintenance.
        data.settings.soundEffectsEnabled = false
        data.settings.autoCalendarReplan = false
        data.settings.timelineFlowShiftEnabled = false
        if data.settings.timelineLayout == .orbit { data.settings.timelineLayout = .horizontal }
        if data.settings.weekTimelineLayout == .orbit { data.settings.weekTimelineLayout = .horizontal }
        data.subscription = .free // serialized snapshots never grant StoreKit entitlement
        if data.settings.experienceMode == .hybrid { data.settings.experienceMode = .workspace }
        selectedDate = DateKey.today
        isHydrated = true

        try? await Task.sleep(for: .milliseconds(3_000))
        guard !Task.isCancelled else { return }
        runDeferredLocalMaintenanceIfNeeded()
    }

    private func runDeferredLocalMaintenanceIfNeeded() {
        guard !didRunDeferredLocalMaintenance else { return }
        didRunDeferredLocalMaintenance = true

        removeLegacySilentOnboardingPlanIfSafe()

        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let needsIconRepair = defaults.integer(forKey: Self.iconRepairCatalogVersionKey) < Self.iconRepairCatalogVersion
        let needsCompactRewrite = defaults.integer(forKey: Self.localPersistenceFormatVersionKey) < Self.localPersistenceFormatVersion
        if needsIconRepair { _ = repairLegacyAutomaticIcons() }

        if needsIconRepair || needsCompactRewrite {
            // One deferred rewrite converts older pretty-printed snapshots to the compact format,
            // so every later cold launch has fewer bytes to read/decode. This happens after the UI
            // is already interactive and does not initialize cloud storage.
            let normalizedSnapshot = data
            Task {
                do {
                    try await PersistenceService.shared.saveLocalSnapshot(normalizedSnapshot)
                    defaults.set(Self.iconRepairCatalogVersion, forKey: Self.iconRepairCatalogVersionKey)
                    defaults.set(Self.localPersistenceFormatVersion, forKey: Self.localPersistenceFormatVersionKey)
                } catch {
                    // Leave the version markers untouched so a later launch can retry safely.
                }
            }
        }

        if data.plans.isEmpty { _ = ensurePlan(for: DateKey.today) }
        normalizeManualTaskOrder()
        _ = completeElapsedPersonalTasks()
        runScheduledWorkspaceAutomationsIfNeeded()
        // No unconditional WidgetCenter reload here. Widgets are already updated whenever
        // Planning actually persists a change, so reloading them on every launch is redundant.
    }

    /// Non-visual maintenance that used to run directly on every activation.
    /// It is delayed/throttled so returning to Planning can present immediately.
    func performForegroundRefresh(force: Bool = false) async {
        guard isHydrated else { return }
        let now = Date()
        // Returning to the app should be visually instant. Non-urgent system/framework work
        // is intentionally throttled; explicit Sync still forces everything immediately.
        if !force, let lastForegroundRefreshAt, now.timeIntervalSince(lastForegroundRefreshAt) < 300 { return }
        lastForegroundRefreshAt = now

        if force || lastForegroundSubscriptionRefreshAt.map({ now.timeIntervalSince($0) >= 900 }) != false {
            lastForegroundSubscriptionRefreshAt = now
            await refreshSubscriptionTier()
        }
        guard !Task.isCancelled else { return }
        await refreshExternalChanges(force: force)
        guard !Task.isCancelled else { return }
        ensureRecurrenceHorizon()
        _ = completeElapsedPersonalTasks(now: now)
        runScheduledWorkspaceAutomationsIfNeeded()

        if force || lastForegroundHealthRefreshAt.map({ now.timeIntervalSince($0) >= 900 }) != false {
            lastForegroundHealthRefreshAt = now
            await refreshHealthIfNeeded()
        }

        guard !Task.isCancelled else { return }
        if force || lastForegroundExternalSourcesRefreshAt.map({ now.timeIntervalSince($0) >= 900 }) != false {
            lastForegroundExternalSourcesRefreshAt = now
            await refreshExternalSources()
        }

        if force || lastForegroundNotificationRefreshAt.map({ now.timeIntervalSince($0) >= 900 }) != false {
            lastForegroundNotificationRefreshAt = now
            await refreshNotificationSchedules()
        }
    }

    func persist() {
        data.lastModifiedAt = SnapshotClock.stamp(after: data.lastModifiedAt)
        SharedStateService.publish(data)
        pendingPersistenceSnapshot = data
        guard persistenceTask == nil else { return }
        persistenceTask = Task {
            while let next = pendingPersistenceSnapshot {
                pendingPersistenceSnapshot = nil
                do {
                    try await PersistenceService.shared.save(next)
                    if next.settings.cloudSyncEnabled != false, SupabaseService.shared.session != nil { _ = await SupabaseService.shared.saveSnapshot(next) }
                } catch { syncMessage = "Your latest changes could not be saved. Please export your data and try again." }
            }
            persistenceTask = nil
        }
    }
    func record(_ type: String, _ detail: String) { data.events.append(BehaviorEvent(type: type, detail: detail)); if data.events.count > 1000 { data.events.removeFirst(data.events.count - 1000) } }

    var canUndoTimelineChange: Bool { !timelineUndoHistory.isEmpty }

    func captureTimelineUndo(label: String) {
        guard timelineUndoTransactionDepth == 0 else { return }
        timelineUndoHistory.append(UndoCheckpoint(label: label, before: data, after: data))
        if timelineUndoHistory.count > 12 {
            timelineUndoHistory.removeFirst(timelineUndoHistory.count - 12)
        }
        timelineUndoLabel = label
    }

    private func finishTimelineUndoCapture() {
        guard timelineUndoTransactionDepth == 0, let index = timelineUndoHistory.indices.last else { return }
        timelineUndoHistory[index].after = data
        if timelineUndoHistory[index].before == data { timelineUndoHistory.removeLast() }
        timelineUndoLabel = timelineUndoHistory.last?.label
    }

    /// Keeps every confirmed multi-step operation behind one coherent full-state Undo point.
    /// Nested changes are allowed to persist normally but cannot replace the snapshot
    /// captured before the user confirmed the operation.
    @discardableResult
    func performTimelineTransaction<Result>(label: String, _ operation: () -> Result) -> Result {
        let isRootTransaction = timelineUndoTransactionDepth == 0
        if isRootTransaction { captureTimelineUndo(label: label) }
        timelineUndoTransactionDepth += 1
        defer {
            timelineUndoTransactionDepth = max(0, timelineUndoTransactionDepth - 1)
            if isRootTransaction { finishTimelineUndoCapture() }
        }
        return operation()
    }

    func undoLastTimelineChange() {
        guard let checkpoint = timelineUndoHistory.popLast() else { return }
        data = SnapshotUndo.restoring(before: checkpoint.before, after: checkpoint.after, current: data)
        if checkpoint.label.hasPrefix("Automatic completion") {
            let applied = Set(checkpoint.after.plans.flatMap(\.tasks).filter { $0.status == .completed }.map(\.id))
            for planIndex in data.plans.indices {
                for taskIndex in data.plans[planIndex].tasks.indices {
                    if applied.contains(data.plans[planIndex].tasks[taskIndex].id),
                       data.plans[planIndex].tasks[taskIndex].status != .completed {
                        data.plans[planIndex].tasks[taskIndex].autoCompletionSuppressed = true
                    }
                }
            }
        }
        let label = checkpoint.label
        timelineUndoLabel = timelineUndoHistory.last?.label
        record("timeline-undo", label)
        persist()
        Task { await refreshNotificationSchedules() }
    }

    private func normalizeManualTaskOrder() {
        var changed = false
        for planIndex in data.plans.indices {
            for taskIndex in data.plans[planIndex].tasks.indices where data.plans[planIndex].tasks[taskIndex].manualOrder == nil {
                data.plans[planIndex].tasks[taskIndex].manualOrder = taskIndex
                changed = true
            }
        }
        if changed { persist() }
    }

    /// Completes only elapsed, timed, personal tasks when the user enabled this automation.
    /// Calendar/reminder imports and locked anchors stay untouched and every batch is undoable.
    @discardableResult
    func completeElapsedPersonalTasks(now: Date = .now) -> Int {
        guard data.settings.timelineAutoCompleteElapsedTasks != false else { return 0 }
        var targets: [(Int, Int)] = []

        for planIndex in data.plans.indices {
            for taskIndex in data.plans[planIndex].tasks.indices {
                let task = data.plans[planIndex].tasks[taskIndex]
                if TaskSchedule.shouldAutoComplete(task, now: now) {
                    targets.append((planIndex, taskIndex))
                }
            }
        }

        guard !targets.isEmpty else { return 0 }
        captureTimelineUndo(label: targets.count == 1 ? "Automatic completion" : "Automatic completions")
        defer { finishTimelineUndoCapture() }
        let completedAt = ISO8601DateFormatter().string(from: now)
        for (planIndex, taskIndex) in targets {
            data.plans[planIndex].tasks[taskIndex].status = .completed
            data.plans[planIndex].tasks[taskIndex].completedAt = completedAt
            data.plans[planIndex].tasks[taskIndex].skippedReason = nil
        }
        record("timeline-auto-complete", "\(targets.count) elapsed personal task(s)")
        persist()
        Task { await refreshNotificationSchedules() }
        return targets.count
    }

    /// Older prerelease builds could silently build an AI day immediately after onboarding.
    /// This migration removes that prerelease-generated plan only when there is strong
    /// evidence the user never interacted with it. It never deletes manually created,
    /// imported, completed, edited, started or otherwise used tasks.
    private func removeLegacySilentOnboardingPlanIfSafe() {
        guard data.schemaVersion < 11 else { return }
        defer { data.schemaVersion = 11; persist() }

        guard data.profile.onboardingCompleted,
              data.usage.plansBuilt == 1,
              let todayIndex = data.plans.firstIndex(where: { $0.date == DateKey.today }),
              !data.plans[todayIndex].tasks.isEmpty else { return }

        let tasks = data.plans[todayIndex].tasks
        let interactionTypes: Set<String> = [
            "task-added", "task-edited", "task-completed", "task-reopened",
            "task-started", "task-skipped", "plan-replanned"
        ]
        let hasTaskInteraction = data.events.contains { interactionTypes.contains($0.type) }
        let planBuildEvents = data.events.filter { $0.type == "plan-built" }
        let profileAnalysisEvents = data.events.filter { $0.type == "profile-analyzed" }
        let formatter = ISO8601DateFormatter()
        let wasBuiltImmediatelyAfterOnboarding: Bool = {
            guard let analysisEvent = profileAnalysisEvents.last,
                  let buildEvent = planBuildEvents.first,
                  let analysisDate = formatter.date(from: analysisEvent.createdAt),
                  let buildDate = formatter.date(from: buildEvent.createdAt) else { return false }
            return buildDate.timeIntervalSince(analysisDate) >= 0
                && buildDate.timeIntervalSince(analysisDate) <= 60
        }()
        let looksLikeSilentOnboardingPlan = profileAnalysisEvents.count >= 1
            && planBuildEvents.count == 1
            && wasBuiltImmediatelyAfterOnboarding
            && !hasTaskInteraction
            && tasks.allSatisfy { task in
                task.source == .ai
                    && task.status == .pending
                    && task.completedAt == nil
                    && task.skippedReason == nil
                    && task.externalSource == nil
            }

        guard looksLikeSilentOnboardingPlan else { return }

        data.plans[todayIndex].tasks.removeAll()
        data.usage.plansBuilt = 0
        data.events.removeAll { $0.type == "plan-built" }
        if let achievementIndex = data.achievements.firstIndex(where: { $0.id == "achievement-first-plan" }) {
            data.achievements[achievementIndex].progress = 0
            data.achievements[achievementIndex].unlockedAt = nil
        }
        record("migration-removed-silent-onboarding-plan", "Removed legacy prerelease onboarding-generated schedule")
    }

    @discardableResult
    private func repairLegacyAutomaticIcons() -> Bool {
        var changed = false
        for planIndex in data.plans.indices {
            for taskIndex in data.plans[planIndex].tasks.indices {
                let task = data.plans[planIndex].tasks[taskIndex]
                if task.iconIsAutomatic != false && IconEngine.shouldRepair(existing: task.icon, title: task.title, category: task.category) {
                    let repaired = IconEngine.symbol(for: task.title, category: task.category)
                    if data.plans[planIndex].tasks[taskIndex].icon != repaired || data.plans[planIndex].tasks[taskIndex].iconIsAutomatic != true {
                        data.plans[planIndex].tasks[taskIndex].icon = repaired
                        data.plans[planIndex].tasks[taskIndex].iconIsAutomatic = true
                        changed = true
                    }
                }
                if data.plans[planIndex].tasks[taskIndex].color == nil {
                    data.plans[planIndex].tasks[taskIndex].color = IconEngine.suggestedColor(for: task.title, category: task.category)
                    changed = true
                }
            }
        }
        return changed
    }

    private func newestSnapshot(local: AppData, cloud: AppData) -> AppData {
        let localDate = SnapshotClock.date(local.lastModifiedAt) ?? .distantPast
        let cloudDate = SnapshotClock.date(cloud.lastModifiedAt) ?? .distantPast
        if localDate == .distantPast && cloudDate == .distantPast {
            return cloud.plans.count + cloud.notes.count + cloud.inbox.count > local.plans.count + local.notes.count + local.inbox.count ? cloud : local
        }
        return cloudDate > localDate ? cloud : local
    }

    @discardableResult func ensurePlan(for date: String) -> DayPlan {
        if let plan = data.plans.first(where: { $0.date == date }) { return plan }
        let plan = DayPlan(date: date, title: date == DateKey.today ? "Today" : "Plan", mode: .dayChain)
        data.plans.append(plan); persist(); return plan
    }

    func selectDate(_ date: Date) { selectedDate = DateKey.string(date); ensurePlan(for: selectedDate) }

    func addTask(_ incoming: PlannerTask) {
        var task = sanitizedForEntitlements(incoming)
        if task.iconIsAutomatic != false && (task.iconIsAutomatic == true || IconEngine.shouldRepair(existing: task.icon, title: task.title, category: task.category)) {
            task.icon = IconEngine.symbol(for: task.title, category: task.category)
        }
        if task.color == nil { task.color = IconEngine.suggestedColor(for: task.title, category: task.category) }
        if (task.recurrence ?? .none) != .none, task.recurrenceGenerated != true {
            task.recurrenceSeriesId = task.recurrenceSeriesId ?? task.id
            task.recurrenceGenerated = false
        }
        insertTask(task)
        if (task.recurrence ?? .none) != .none, task.recurrenceGenerated != true { regenerateSeries(master: task) }
        record("task-added", task.title)
        persist()
        scheduleNotifications(for: [task])
    }

    func updateTask(_ incoming: PlannerTask) {
        var task = sanitizedForEntitlements(incoming)
        if task.iconIsAutomatic != false && (task.iconIsAutomatic == true || IconEngine.shouldRepair(existing: task.icon, title: task.title, category: task.category)) {
            task.icon = IconEngine.symbol(for: task.title, category: task.category)
        }
        if task.color == nil { task.color = IconEngine.suggestedColor(for: task.title, category: task.category) }
        if (task.recurrence ?? .none) != .none, task.recurrenceGenerated != true {
            task.recurrenceSeriesId = task.recurrenceSeriesId ?? task.id
            task.recurrenceGenerated = false
        }
        for planIndex in data.plans.indices {
            if let index = data.plans[planIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                let previous = data.plans[planIndex].tasks[index]
                if previous.recurrenceGenerated == true && previous.planDate != task.planDate { excludeRecurringOccurrence(previous) }
                if task.recurrenceGenerated == true { task.recurrenceException = true }
                if previous.startTime != task.startTime || previous.endTime != task.endTime || previous.planDate != task.planDate {
                    task.autoCompletionSuppressed = false
                }
                if task.planDate == previous.planDate {
                    if task.manualOrder == nil { task.manualOrder = previous.manualOrder }
                    data.plans[planIndex].tasks[index] = task
                } else {
                    data.plans[planIndex].tasks.remove(at: index)
                    task.manualOrder = nil
                    insertTask(task)
                }
                if task.recurrenceGenerated != true {
                    if (task.recurrence ?? .none) != .none { regenerateSeries(master: task) }
                    else if (previous.recurrence ?? .none) != .none { removeFutureSeriesInstances(master: previous) }
                }
                record("task-edited", task.title)
                persist()
                scheduleNotifications(for: [task])
                return
            }
        }
        addTask(task)
    }

    func deleteTask(_ id: String) {
        let task = findTask(id)
        if let task, task.recurrenceGenerated == true { excludeRecurringOccurrence(task) }
        let series = task?.recurrenceGenerated == true ? nil : task?.recurrenceSeriesId
        for i in data.plans.indices {
            data.plans[i].tasks.removeAll { candidate in
                candidate.id == id || (series != nil && candidate.recurrenceSeriesId == series && candidate.recurrenceGenerated == true && candidate.planDate >= DateKey.today && candidate.status == .pending && candidate.actualStartedAt == nil)
            }
        }
        Task { await NotificationService.shared.cancel(taskId: id) }
        record("task-deleted", task?.title ?? id)
        persist()
    }

    func duplicateTask(_ id: String, to date: String? = nil) {
        guard var copy = findTask(id) else { return }
        copy.id = UUID().uuidString
        copy.planDate = date ?? copy.planDate
        copy.status = .pending
        copy.completedAt = nil
        copy.actualStartedAt = nil
        copy.autoCompletionSuppressed = nil
        copy.recurrenceException = nil
        copy.recurrenceExcludedDates = nil
        copy.subtasks = copy.subtasks?.map { TaskSubtask(title: $0.title) }
        copy.skippedReason = nil
        copy.externalSource = nil
        copy.externalId = nil
        copy.externalCalendarName = nil
        copy.externalLastModified = nil
        copy.recurrenceSeriesId = nil
        copy.recurrenceGenerated = false
        copy.manualOrder = nil
        addTask(copy)
        record("task-duplicated", copy.title)
    }

    func duplicateDay(from sourceDate: String, to targetDate: String) {
        guard sourceDate != targetDate, let source = data.plans.first(where: { $0.date == sourceDate }) else { return }
        _ = ensurePlan(for: targetDate)
        for sourceTask in source.tasks where sourceTask.externalSource == nil {
            var copy = sourceTask
            copy.id = UUID().uuidString
            copy.planDate = targetDate
            copy.status = .pending
            copy.completedAt = nil
        copy.actualStartedAt = nil
        copy.autoCompletionSuppressed = nil
        copy.recurrenceException = nil
        copy.recurrenceExcludedDates = nil
        copy.subtasks = copy.subtasks?.map { TaskSubtask(title: $0.title) }
            copy.skippedReason = nil
            copy.recurrenceSeriesId = nil
            copy.recurrenceGenerated = false
            copy.manualOrder = nil
            insertTask(copy)
        }
        record("day-duplicated", "\(sourceDate) → \(targetDate)")
        persist()
    }

    func moveTask(_ id: String, before targetID: String) {
        guard id != targetID,
              let sourcePlanIndex = data.plans.firstIndex(where: { $0.tasks.contains(where: { $0.id == id }) }),
              let sourceIndex = data.plans[sourcePlanIndex].tasks.firstIndex(where: { $0.id == id }),
              let targetPlanIndex = data.plans.firstIndex(where: { $0.tasks.contains(where: { $0.id == targetID }) }),
              let targetIndex = data.plans[targetPlanIndex].tasks.firstIndex(where: { $0.id == targetID }) else { return }
        let original = data.plans[sourcePlanIndex].tasks[sourceIndex]
        guard !isTimelineFixed(original) else { return }
        captureTimelineUndo(label: "Reorder task")
        defer { finishTimelineUndoCapture() }
        if sourcePlanIndex != targetPlanIndex { excludeRecurringOccurrence(original) }
        var task = data.plans[sourcePlanIndex].tasks.remove(at: sourceIndex)
        if task.recurrenceGenerated == true { task.recurrenceException = true }
        task.planDate = data.plans[targetPlanIndex].date
        let adjustedTarget = sourcePlanIndex == targetPlanIndex && sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        let insertion = min(max(0, adjustedTarget), data.plans[targetPlanIndex].tasks.count)
        data.plans[targetPlanIndex].tasks.insert(task, at: insertion)
        for index in data.plans[targetPlanIndex].tasks.indices {
            data.plans[targetPlanIndex].tasks[index].manualOrder = index
        }
        if sourcePlanIndex != targetPlanIndex {
            for index in data.plans[sourcePlanIndex].tasks.indices {
                data.plans[sourcePlanIndex].tasks[index].manualOrder = index
            }
        }
        record("task-reordered", task.title)
        persist()
    }

    func moveTaskToDate(_ id: String, date: String) {
        guard var task = findTask(id), !isTimelineFixed(task), DateKey.date(date) != nil else { return }
        captureTimelineUndo(label: "Move \(task.title)")
        defer { finishTimelineUndoCapture() }
        let sourceDate = task.planDate
        if sourceDate != date { excludeRecurringOccurrence(task) }
        if task.recurrenceGenerated == true { task.recurrenceException = true }
        for i in data.plans.indices { data.plans[i].tasks.removeAll { $0.id == id } }
        task.planDate = date
        if sourceDate != date { task.manualOrder = nil }
        insertTask(task)
        selectedDate = date
        record("task-moved", "\(task.title) → \(date)")
        persist()
    }

    /// Builds a transparent drag/drop proposal. The requested time is never silently changed.
    func timelineMoveProposal(taskID: String, toDate date: String, startTime: String) -> TimelineMoveProposal? {
        guard let task = findTask(taskID), let requestedStart = TimeMath.minutes(startTime), !isTimelineFixed(task) else { return nil }
        let safeStart = collisionResolvedStart(for: task, on: date, requestedStart: requestedStart)
        return TimelineMoveProposal(
            taskID: taskID,
            taskTitle: task.title,
            sourceDate: task.planDate,
            targetDate: date,
            requestedTime: TimeMath.string(requestedStart),
            safeTime: safeStart.map(TimeMath.string),
            durationMinutes: max(5, task.durationMinutes),
            hasConflict: safeStart != requestedStart
        )
    }

    func confirmTimelineMove(_ proposal: TimelineMoveProposal, useSafeTime: Bool) {
        guard let time = useSafeTime ? proposal.safeTime : proposal.requestedTime else { return }
        moveTask(proposal.taskID, toDate: proposal.targetDate, startTime: time)
    }

    /// Reschedules exactly where the user confirmed. It never resolves or ripples silently.
    func moveTask(_ id: String, toDate date: String, startTime: String) {
        guard var task = findTask(id), let requestedStart = TimeMath.minutes(startTime), DateKey.date(date) != nil else { return }
        guard !isTimelineFixed(task) else { record("timeline-move-blocked", task.title); return }
        captureTimelineUndo(label: "Move \(task.title)")
        defer { finishTimelineUndoCapture() }
        rememberTimelineBaseline(&task)
        let start = requestedStart
        let sourceDate = task.planDate
        let sourceOrder = task.manualOrder
        if sourceDate != date { excludeRecurringOccurrence(task) }
        for i in data.plans.indices { data.plans[i].tasks.removeAll { $0.id == id } }
        task.planDate = date
        task.startTime = TimeMath.string(start)
        task.endTime = TimeMath.clockString(start + max(5, task.durationMinutes))
        task.allDay = false
        task.autoCompletionSuppressed = false
        if task.recurrenceGenerated == true { task.recurrenceException = true }
        task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
        task.manualOrder = sourceDate == date ? sourceOrder : nil
        insertTask(task)
        selectedDate = date
        record("task-rescheduled", "\(task.title) → \(date) \(task.startTime ?? startTime)")
        persist()
        scheduleNotifications(for: [task])
    }


    /// Compatibility entry point for archived prerelease timeline views.
    /// It deliberately performs the same exact, non-rippling move as `moveTask`.
    func moveTaskWithRipple(_ id: String, toDate date: String, startTime: String) {
        moveTask(id, toDate: date, startTime: startTime)
    }

    /// PUSH THE DAY shifts the remaining flexible schedule as one object.
    /// Calendar events, important blocks and explicitly locked tasks stay fixed.
    @discardableResult
    func pushRemainingDay(on date: String, fromMinute: Int, byMinutes delta: Int) -> Int {
        guard delta != 0, let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        struct FixedInterval { let start: Int; let end: Int }
        let fixed = data.plans[planIndex].tasks.compactMap { task -> FixedInterval? in
            guard task.status != .skipped, isTimelineFixed(task), let start = TimeMath.minutes(task.startTime) else { return nil }
            let end = TimeMath.minutes(task.endTime) ?? (start + max(5, task.durationMinutes))
            return FixedInterval(start: start, end: max(start + 5, end))
        }.sorted { $0.start < $1.start }

        let ids = data.plans[planIndex].tasks.filter { task in
            guard task.status == .pending || task.status == .active, !isTimelineFixed(task), let start = TimeMath.minutes(task.startTime) else { return false }
            return start >= fromMinute
        }.sorted { (TimeMath.minutes($0.startTime) ?? Int.max) < (TimeMath.minutes($1.startTime) ?? Int.max) }.map(\.id)

        var cursor = fromMinute
        var changed: [PlannerTask] = []
        for id in ids {
            guard let taskIndex = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }),
                  let originalStart = TimeMath.minutes(data.plans[planIndex].tasks[taskIndex].startTime) else { continue }
            var task = data.plans[planIndex].tasks[taskIndex]
            rememberTimelineBaseline(&task)
            let duration = max(5, task.durationMinutes)
            let buffer = timelineBuffer(for: task)
            var proposed = max(fromMinute, max(cursor, originalStart + delta))
            var searching = true
            while searching {
                searching = false
                if let blocker = fixed.first(where: { proposed < $0.end && proposed + duration > $0.start }) {
                    proposed = blocker.end
                    searching = true
                }
            }
            if proposed != originalStart {
                task.startTime = TimeMath.string(proposed)
                task.endTime = TimeMath.string(proposed + duration)
                task.section = proposed < 720 ? .morning : proposed < 1020 ? .day : proposed < 1320 ? .evening : .night
                data.plans[planIndex].tasks[taskIndex] = task
                changed.append(task)
            }
            cursor = max(cursor, proposed + duration + buffer)
        }
        guard !changed.isEmpty else { return 0 }
        record("timeline-push-day", "\(delta > 0 ? "+" : "")\(delta)m · \(changed.count) task(s)")
        persist()
        scheduleNotifications(for: changed)
        return changed.count
    }

    /// MAGNETIC COMPRESS removes avoidable idle gaps from the remaining flexible
    /// schedule while preserving hard commitments and each task's reset buffer.
    @discardableResult
    func compressRemainingDay(on date: String, fromMinute: Int) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        struct FixedInterval { let start: Int; let end: Int }
        let fixed = data.plans[planIndex].tasks.compactMap { task -> FixedInterval? in
            guard task.status != .skipped, isTimelineFixed(task), let start = TimeMath.minutes(task.startTime) else { return nil }
            let end = TimeMath.minutes(task.endTime) ?? (start + max(5, task.durationMinutes))
            return FixedInterval(start: start, end: max(start + 5, end))
        }.sorted { $0.start < $1.start }

        let ids = data.plans[planIndex].tasks.filter { task in
            guard task.status == .pending,
                  !isTimelineFixed(task),
                  let start = TimeMath.minutes(task.startTime) else { return false }
            return start >= fromMinute
        }
        .sorted { (TimeMath.minutes($0.startTime) ?? Int.max) < (TimeMath.minutes($1.startTime) ?? Int.max) }
        .map(\.id)

        var cursor = fromMinute
        var changed: [PlannerTask] = []
        for id in ids {
            guard let taskIndex = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }),
                  let originalStart = TimeMath.minutes(data.plans[planIndex].tasks[taskIndex].startTime) else { continue }
            var task = data.plans[planIndex].tasks[taskIndex]
            rememberTimelineBaseline(&task)
            let duration = max(5, task.durationMinutes)
            var proposed = min(originalStart, max(fromMinute, cursor))
            var searching = true
            while searching {
                searching = false
                if let blocker = fixed.first(where: { proposed < $0.end && proposed + duration > $0.start }) {
                    proposed = blocker.end
                    searching = true
                }
            }
            if proposed < originalStart {
                task.startTime = TimeMath.string(proposed)
                task.endTime = TimeMath.string(proposed + duration)
                task.section = proposed < 720 ? .morning : proposed < 1020 ? .day : proposed < 1320 ? .evening : .night
                data.plans[planIndex].tasks[taskIndex] = task
                changed.append(task)
            }
            cursor = max(cursor, proposed + duration + timelineBuffer(for: task))
        }
        guard !changed.isEmpty else { return 0 }
        record("timeline-compress", "\(changed.count) task(s) pulled forward")
        persist()
        scheduleNotifications(for: changed)
        return changed.count
    }

    func setTimelineLocked(_ id: String, locked: Bool) {
        guard var task = findTask(id), task.externalSource != .calendar else { return }
        task.timelineLocked = locked
        updateTask(task)
        record(locked ? "timeline-anchor-locked" : "timeline-anchor-unlocked", task.title)
    }

    func planInbox(_ item: InboxTask, on date: String, at startTime: String) {
        var task = PlanEngine.manualTask(title: item.title, date: date)
        task.note = item.note
        task.startTime = startTime
        task.allDay = false
        if let start = TimeMath.minutes(startTime) {
            task.endTime = TimeMath.string(start + max(5, task.durationMinutes))
            task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
        }
        task.iconIsAutomatic = true
        task.icon = IconEngine.symbol(for: task.title, category: task.category)
        insertTask(task)
        data.inbox.removeAll { $0.id == item.id }
        selectedDate = date
        record("inbox-planned-at-time", "\(item.title) → \(date) \(startTime)")
        persist()
        scheduleNotifications(for: [task])
    }

    func moveTaskToInbox(_ id: String) {
        guard let task = findTask(id) else { return }
        let series = task.recurrenceGenerated == true ? nil : task.recurrenceSeriesId
        data.inbox.append(InboxTask(title: task.title, note: task.note))
        for planIndex in data.plans.indices {
            data.plans[planIndex].tasks.removeAll { candidate in
                candidate.id == id || (series != nil && candidate.recurrenceSeriesId == series && candidate.recurrenceGenerated == true)
            }
        }
        Task { await NotificationService.shared.cancel(taskId: id) }
        record("task-moved-to-inbox", task.title)
        persist()
    }

    func planInbox(_ item: InboxTask, before targetID: String? = nil) {
        var task = PlanEngine.manualTask(title: item.title, date: selectedDate)
        task.note = item.note
        insertTask(task)
        if let targetID { moveTask(task.id, before: targetID) }
        data.inbox.removeAll { $0.id == item.id }
        record("inbox-planned", item.title)
        persist()
    }

    private func insertTask(_ task: PlannerTask) {
        let index: Int
        if let existingPlan = data.plans.firstIndex(where: { $0.date == task.planDate }) {
            index = existingPlan
        } else {
            data.plans.append(DayPlan(date: task.planDate, title: task.planDate == DateKey.today ? "Today" : "Plan", mode: .dayChain))
            index = data.plans.count - 1
        }
        if let existing = data.plans[index].tasks.firstIndex(where: { $0.id == task.id }) {
            data.plans[index].tasks[existing] = task
        } else {
            var orderedTask = task
            if orderedTask.manualOrder == nil {
                orderedTask.manualOrder = (data.plans[index].tasks.compactMap(\.manualOrder).max() ?? -1) + 1
            }
            data.plans[index].tasks.append(orderedTask)
        }
    }

    private func upsertExternalTask(_ incoming: PlannerTask) {
        var task = incoming
        if task.iconIsAutomatic != false && (task.iconIsAutomatic == true || IconEngine.shouldRepair(existing: task.icon, title: task.title, category: task.category)) {
            task.icon = IconEngine.symbol(for: task.title, category: task.category)
        }
        if task.color == nil { task.color = IconEngine.suggestedColor(for: task.title, category: task.category) }
        for planIndex in data.plans.indices {
            if let index = data.plans[planIndex].tasks.firstIndex(where: { $0.externalSource == task.externalSource && $0.externalId == task.externalId && $0.externalId != nil }) {
                let previous = data.plans[planIndex].tasks[index]
                if previous.planDate == task.planDate { task.manualOrder = previous.manualOrder }
                task.status = previous.status
                task.completedAt = previous.completedAt
                task.skippedReason = previous.skippedReason
                data.plans[planIndex].tasks.remove(at: index)
                break
            }
        }
        insertTask(task)
    }

    private func isTimelineFixed(_ task: PlannerTask) -> Bool {
        task.externalSource == .calendar || task.externalImportance == .important || task.timelineLocked == true
    }

    private func timelineBuffer(for task: PlannerTask) -> Int {
        isTimelineFixed(task) ? max(0, task.bufferAfterMinutes ?? 0) : max(0, task.bufferAfterMinutes ?? 5)
    }

    private func rememberTimelineBaseline(_ task: inout PlannerTask) {
        if task.timelineOriginalStartTime == nil { task.timelineOriginalStartTime = task.startTime }
        if task.timelineOriginalEndTime == nil {
            if let end = task.endTime { task.timelineOriginalEndTime = end }
            else if let start = TimeMath.minutes(task.startTime) { task.timelineOriginalEndTime = TimeMath.string(start + max(5, task.durationMinutes)) }
        }
    }

    private func collisionResolvedStart(for task: PlannerTask, on date: String, requestedStart: Int) -> Int? {
        TimelinePlacement.nextAvailableStart(for: task, on: date, requestedStart: requestedStart, plans: data.plans)
    }

    private func excludeRecurringOccurrence(_ task: PlannerTask) {
        guard task.recurrenceGenerated == true, let series = task.recurrenceSeriesId else { return }
        for p in data.plans.indices {
            for t in data.plans[p].tasks.indices where data.plans[p].tasks[t].recurrenceGenerated != true &&
                (data.plans[p].tasks[t].recurrenceSeriesId ?? data.plans[p].tasks[t].id) == series {
                var dates = data.plans[p].tasks[t].recurrenceExcludedDates ?? []
                if !dates.contains(task.planDate) { dates.append(task.planDate) }
                data.plans[p].tasks[t].recurrenceExcludedDates = dates.sorted()
            }
        }
    }

    private func findTask(_ id: String) -> PlannerTask? {
        for plan in data.plans { if let task = plan.tasks.first(where: { $0.id == id }) { return task } }
        return nil
    }

    private func regenerateSeries(master: PlannerTask) {
        guard master.recurrenceGenerated != true, let recurrence = master.recurrence, recurrence != .none else { return }
        let series = master.recurrenceSeriesId ?? master.id
        let generated = PlanEngine.recurringInstances(from: master, horizonDays: recurrenceHorizonDays(for: master))
            .filter { $0.planDate >= DateKey.today }
        let desiredDates = Set(generated.map(\.planDate))
        for index in data.plans.indices {
            data.plans[index].tasks.removeAll {
                $0.recurrenceSeriesId == series && $0.recurrenceGenerated == true &&
                $0.planDate >= DateKey.today && $0.status == .pending &&
                $0.actualStartedAt == nil && $0.recurrenceException != true &&
                !desiredDates.contains($0.planDate)
            }
        }
        for var task in generated {
            if let existing = data.plans.flatMap(\.tasks).first(where: {
                $0.recurrenceSeriesId == series && $0.recurrenceGenerated == true && $0.planDate == task.planDate
            }) {
                guard existing.status == .pending, existing.actualStartedAt == nil,
                      existing.recurrenceException != true else { continue }
                task.id = existing.id
                task.manualOrder = existing.manualOrder
            }
            insertTask(task)
        }
        scheduleNotifications(for: generated.filter { DateKey.date($0.planDate)?.timeIntervalSinceNow ?? -1 < 31 * 86400 })
    }

    private func removeFutureSeriesInstances(master: PlannerTask) {
        let series = master.recurrenceSeriesId ?? master.id
        for index in data.plans.indices {
            data.plans[index].tasks.removeAll {
                $0.recurrenceSeriesId == series && $0.recurrenceGenerated == true &&
                $0.planDate >= DateKey.today && $0.status == .pending &&
                $0.actualStartedAt == nil && $0.recurrenceException != true
            }
        }
    }

    private func recurrenceHorizonDays(for master: PlannerTask) -> Int {
        let start = DateKey.date(master.planDate) ?? .now
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(90, elapsed + 90)
    }

    func ensureRecurrenceHorizon() {
        guard hasAccess(.recurrence) else { return }
        let masters = data.plans.flatMap(\.tasks).filter { $0.recurrenceGenerated != true && ($0.recurrence ?? .none) != .none }
        var added: [PlannerTask] = []
        for master in masters {
            let series = master.recurrenceSeriesId ?? master.id
            let existingDates = Set(data.plans.flatMap(\.tasks).filter { $0.recurrenceSeriesId == series && $0.recurrenceGenerated == true }.map(\.planDate))
            for generated in PlanEngine.recurringInstances(from: master, horizonDays: recurrenceHorizonDays(for: master))
                where generated.planDate >= DateKey.today && !existingDates.contains(generated.planDate) {
                insertTask(generated)
                added.append(generated)
            }
        }
        if !added.isEmpty {
            record("recurrence-expanded", "\(added.count) future instances")
            persist()
            scheduleNotifications(for: added.filter { DateKey.date($0.planDate)?.timeIntervalSinceNow ?? -1 < 31 * 86400 })
        }
    }

    private func scheduleNotifications(for tasks: [PlannerTask]) {
        guard !tasks.isEmpty else { return }
        Task { await refreshNotificationSchedules() }
    }

    func refreshNotificationSchedules() async {
        let enabled = data.settings.notificationsEnabled
        let allTasks = data.plans.flatMap(\.tasks)
        if enabled { _ = await NotificationService.shared.requestAuthorization() }
        await NotificationService.shared.scheduleMorningPlanning(
            enabled: enabled && (data.settings.morningPlanningReminder ?? false),
            time: data.settings.morningPlanningTime ?? "08:00"
        )
        await NotificationService.shared.scheduleOverdueRescue(
            enabled: enabled && (data.settings.overdueReminder ?? false),
            tasks: allTasks
        )
        await NotificationService.shared.scheduleEveningReview(enabled: enabled && data.settings.eveningReview, time: data.settings.eveningReviewTime ?? "20:30")
        if !enabled || !data.settings.taskReminders {
            await NotificationService.shared.cancelAllTaskNotifications()
            return
        }
        let upcoming = allTasks.filter {
            guard let date = DateKey.date($0.planDate) else { return false }
            return date >= Calendar.current.startOfDay(for: .now) && date.timeIntervalSinceNow < 31 * 86400
        }
        await NotificationService.shared.rebuildUpcoming(
            tasks: upcoming.map(sanitizedForEntitlements),
            enabled: true,
            quietHoursStart: data.settings.quietHoursStart,
            quietHoursEnd: data.settings.quietHoursEnd,
            maximumTaskAlerts: 48
        )
    }

    func refreshSubscriptionTier() async {
        let tier = await SubscriptionService.shared.currentTier()
        let previousTier = data.subscription
        let previousSettings = data.settings
        data.subscription = tier
        enforceSettingsEntitlements()
        if previousTier != tier || previousSettings != data.settings { persist() }
    }

    private func enforceSettingsEntitlements() {
        if !hasAccess(.appleIntegrations) {
            data.settings.calendarSyncEnabled = false
            data.settings.healthSyncEnabled = false
            data.settings.healthPlanningEnabled = false
        }
        if !hasAccess(.premiumAppearance) {
            if data.settings.canvasTheme != .none && data.settings.canvasTheme != .paper { data.settings.canvasTheme = .none }
            data.settings.customAccentEnabled = false
        }
    }

    func monitorSubscriptionTransactions() async {
        guard SubscriptionService.shared.enabled else { return }
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshSubscriptionTier()
        }
    }

    func refreshExternalSources() async {
        guard hasAccess(.appleIntegrations) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let end = Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .now
        var affectedDates = Set<String>()

        if data.settings.calendarSyncEnabled {
            guard let incoming = await CalendarService.shared.calendarTasks(from: start, to: end),
                  data.settings.calendarSyncEnabled else {
                syncMessage = "Calendar access is unavailable. Your saved events are preserved."
                return
            }
            let incomingIDs = Set(incoming.compactMap(\.externalId))
            for planIndex in data.plans.indices {
                let before = data.plans[planIndex].tasks.count
                data.plans[planIndex].tasks.removeAll { task in
                    task.externalSource == .calendar && task.planDate >= DateKey.string(start) &&
                    task.planDate <= DateKey.string(end) && task.externalId.map { !incomingIDs.contains($0) } == true
                }
                if data.plans[planIndex].tasks.count != before { affectedDates.insert(data.plans[planIndex].date) }
            }
            for task in incoming { affectedDates.insert(task.planDate); upsertExternalTask(task) }
        }


        if !affectedDates.isEmpty {
            record("external-sync", "\(affectedDates.count) affected days")
            syncMessage = "Calendar updated. Review conflict suggestions before changing your plan."
            persist()
        }
    }

    func markTaskCompleted(_ id: String) {
        for p in data.plans.indices {
            guard let t = data.plans[p].tasks.firstIndex(where: { $0.id == id }) else { continue }
            guard data.plans[p].tasks[t].status != .completed else { return }
            data.plans[p].tasks[t].status = .completed
            data.plans[p].tasks[t].completedAt = ISO8601DateFormatter().string(from: .now)
            data.plans[p].tasks[t].skippedReason = nil
            let rescued = data.plans[p].rescuedAt != nil
            refreshCompletionAchievements(planWasRescued: rescued)
            record("task-completed", data.plans[p].tasks[t].title)
            persist()
            Task { await refreshNotificationSchedules() }
            Task { await LiveActivityService.shared.finish() }
            return
        }
    }

    func markSubtaskCompleted(taskID: String, subtaskID: String) {
        for p in data.plans.indices {
            guard let t = data.plans[p].tasks.firstIndex(where: { $0.id == taskID }),
                  var subtasks = data.plans[p].tasks[t].subtasks,
                  let s = subtasks.firstIndex(where: { $0.id == subtaskID }) else { continue }
            guard !subtasks[s].completed else { return }
            subtasks[s].completed = true
            data.plans[p].tasks[t].subtasks = subtasks
            record("subtask-completed", subtasks[s].title)
            persist()
            return
        }
    }

    func toggleTask(_ id: String) {
        for p in data.plans.indices {
            guard let t = data.plans[p].tasks.firstIndex(where: { $0.id == id }) else { continue }
            let completed = data.plans[p].tasks[t].status != .completed
            data.plans[p].tasks[t].status = completed ? .completed : .pending
            data.plans[p].tasks[t].completedAt = completed ? ISO8601DateFormatter().string(from: .now) : nil
            if !completed {
                data.plans[p].tasks[t].skippedReason = nil
                data.plans[p].tasks[t].autoCompletionSuppressed = true
            }
            let rescued = data.plans[p].rescuedAt != nil
            if completed { refreshCompletionAchievements(planWasRescued: rescued) }
            record(completed ? "task-completed" : "task-reopened", data.plans[p].tasks[t].title)
            persist()
            Task { await refreshNotificationSchedules() }
            if completed { Task { await LiveActivityService.shared.finish() } }
            return
        }
    }

    func startTask(_ id: String, focusMinutes: Int? = nil) {
        var started: PlannerTask?
        mutateTask(id) { task in
            task.status = .active
            if task.actualStartedAt == nil { task.actualStartedAt = ISO8601DateFormatter().string(from: .now) }
            started = task
        }
        record("task-started", id)
        persist()
        if let started { Task { await LiveActivityService.shared.start(task: started, minutes: focusMinutes) } }
    }
    func skipTask(_ id: String, reason: String? = nil) {
        guard findTask(id) != nil else { return }
        mutateTask(id) { $0.status = .skipped; $0.skippedReason = reason }
        record("task-skipped", id)
        persist()
        Task { await refreshNotificationSchedules() }
    }
    func mutateTask(_ id: String, _ body: (inout PlannerTask) -> Void) { for p in data.plans.indices { if let t = data.plans[p].tasks.firstIndex(where: { $0.id == id }) { body(&data.plans[p].tasks[t]); return } } }

    /// Apply only the exact preview the user reviewed, against the same day revision.
    /// Unrelated notes/profile edits remain untouched; stale day drafts must be regenerated.
    @discardableResult
    func applyReviewedPlan(_ draft: ReviewedPlanDraft) -> Bool {
        let current = data.plans.first { $0.date == draft.plan.date }
        guard current == draft.original,
              draft.plan.tasks.allSatisfy({ $0.planDate == draft.plan.date }),
              Set(draft.plan.tasks.map(\.id)).count == draft.plan.tasks.count else { return false }
        if let current {
            let protected = current.tasks.filter { $0.status == .completed || $0.status == .active || $0.externalSource != nil || $0.externalImportance == .important || $0.timelineLocked == true || $0.flexible == false }
            guard protected.allSatisfy({ draft.plan.tasks.contains($0) }) else { return false }
        }
        if draft.replan && !hasAccess(.advancedReplan) { return false }
        captureTimelineUndo(label: draft.replan ? "Reviewed day adjustment" : "Reviewed plan")
        defer { finishTimelineUndoCapture() }
        if let index = data.plans.firstIndex(where: { $0.date == draft.plan.date }) { data.plans[index] = draft.plan }
        else { data.plans.append(draft.plan) }
        data.usage.plansBuilt += 1
        if draft.replan { data.usage.rescues += 1 }
        if let index = data.achievements.firstIndex(where: { $0.id == "achievement-first-plan" }) {
            data.achievements[index].progress = 1
            data.achievements[index].unlockedAt = data.achievements[index].unlockedAt ?? SnapshotClock.stamp()
        }
        record("plan-built", draft.fallback ? "Reviewed local draft" : "Reviewed AI draft")
        persist()
        return true
    }

    func buildPlan(_ input: PlanBuildInput, for date: String? = nil, replan: Bool = false) async {
        if replan && !hasAccess(.advancedReplan) { return }
        let target = date ?? selectedDate
        let result = await AIService.shared.buildPlan(input: input, context: data, health: healthSnapshot, date: target, replan: replan)
        captureTimelineUndo(label: replan ? "AI replan" : "AI plan")
        defer { finishTimelineUndoCapture() }
        if let index = data.plans.firstIndex(where: { $0.date == target }) {
            data.plans[index] = PlanEngine.preserveProtected(current: data.plans[index], replacement: result.0)
        } else { data.plans.append(result.0) }
        data.usage.plansBuilt += 1
        if let i = data.achievements.firstIndex(where: { $0.id == "achievement-first-plan" }) {
            data.achievements[i].progress = 1
            data.achievements[i].unlockedAt = data.achievements[i].unlockedAt ?? ISO8601DateFormatter().string(from: .now)
        }
        record("plan-built", result.fallback ? "Fallback planner" : "AI planner"); persist()
    }

    func rescue(reason: String, energy: Int, minutes: Int) async {
        guard hasAccess(.advancedReplan), let current = activePlan else { return }
        var input = PlanBuildInput(brainDump: current.tasks.filter { $0.status != .completed }.map(\.title).joined(separator: "\n"), mustWin: current.intention, fixedCommitments: data.profile.fixedCommitments, energy: energy, style: .minimum, availableMinutes: minutes, plannerMode: current.mode)
        if input.mustWin.isEmpty { input.mustWin = current.tasks.first(where: { $0.mustWin == true })?.title ?? "" }
        await buildPlan(input, for: current.date, replan: true)
        if let index = data.plans.firstIndex(where: { $0.date == current.date }) {
            data.plans[index].rescuedAt = ISO8601DateFormatter().string(from: .now)
        }
        data.usage.rescues += 1; record("plan-replanned", reason); persist()
    }

    func sendCoach(_ text: String, conversationId: String? = nil) async {
        let aiMode = data.settings.aiAssistantMode ?? .planning
        if !hasAccess(.fullAI) {
            guard aiMode == .planning, SubscriptionService.shared.consumeFreePlanningAIRequest() else { return }
        }
        let cid = conversationId ?? activeConversationId
        let user = CoachMessage(role: .user, content: text, mode: data.settings.coachMode, conversationId: cid)
        data.messages.append(user); persist()
        let payload = await AIService.shared.coachReply(
            message: text,
            conversationId: cid,
            selectedDate: selectedDate,
            context: data,
            health: healthSnapshot
        )
        data.messages.append(CoachMessage(role: .assistant, content: payload.reply, mode: data.settings.coachMode, conversationId: cid))
        if data.settings.autoLearn && data.settings.globalMemoryEnabled != false {
            for memory in payload.memories where !memory.fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                data.memories.append(MemoryFact(category: memory.category, fact: memory.fact, source: .coach, confidence: memory.confidence))
            }
        }
        stageCoachActions(payload.actions, source: "AI conversation")
        data.usage.coachMessages += 1; record("coach-used", text); persist()
    }

    var hasPendingCoachActions: Bool { !pendingCoachActions.isEmpty }

    private func stageCoachActions(_ actions: [CoachAction], source: String) {
        guard !actions.isEmpty else { return }
        for action in actions where !pendingCoachActions.contains(action) {
            pendingCoachActions.append(action)
        }
        if pendingCoachActions.count > 200 {
            pendingCoachActions = Array(pendingCoachActions.suffix(200))
        }
        pendingCoachActionSummary = "\(source) proposed:\n" + coachActionSummary(pendingCoachActions)
    }

    func confirmPendingCoachActions() {
        guard !pendingCoachActions.isEmpty else { return }
        let actions = pendingCoachActions
        pendingCoachActions = []
        pendingCoachActionSummary = nil
        performTimelineTransaction(label: "AI changes") {
            apply(actions: actions)
        }
        record("coach-actions-confirmed", "\(actions.count) action(s)")
        persist()
    }

    func discardPendingCoachActions() {
        let count = pendingCoachActions.count
        pendingCoachActions = []
        pendingCoachActionSummary = nil
        if count > 0 { record("coach-actions-cancelled", "\(count) action(s)") }
    }

    private func coachActionSummary(_ actions: [CoachAction]) -> String {
        let labels = actions.prefix(5).map { action -> String in
            let name = action.title ?? action.taskId.flatMap { findTask($0)?.title } ?? action.itemId ?? "item"
            let verb: String = switch action.type {
            case let value where value.hasPrefix("create_"): "Create"
            case let value where value.hasPrefix("delete_"): "Delete"
            case let value where value.hasPrefix("update_"): "Update"
            case "complete_task", "complete": "Complete"
            case "skip_task", "skip": "Skip"
            case "set_setting": "Change setting"
            case "set_profile": "Change profile"
            default: action.type.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return "\(verb): \(name)"
        }
        let extra = actions.count > labels.count ? "\n+ \(actions.count - labels.count) more" : ""
        return labels.joined(separator: "\n") + extra
    }

    func showPlannerToday() {
        if data.settings.experienceMode?.resolved != .planner { setExperienceMode(.planner) }
        selectedTab = .today
    }

    func coachActionDetail(_ action: CoachAction) -> String {
        var lines: [String] = []
        func append(_ label: String, _ value: String?) {
            if let value { lines.append("\(label): \(value.isEmpty ? "(clear)" : value)") }
        }
        append("Task", action.taskId.map { findTask($0)?.title ?? $0 })
        append("Item", action.itemId.map { id in data.notes.first(where: { $0.id == id })?.title ?? data.workspacePages.first(where: { $0.id == id })?.title ?? id })
        append("Title", action.title); append("Field", action.key); append("Value", action.value)
        append("Enabled", action.boolValue.map { $0 ? "On" : "Off" })
        append("Amount", action.intValue.map(String.init)); append("Date", action.date); append("Time", action.startTime)
        append("Duration", action.durationMinutes.map { "\($0) min" }); append("Category", action.category?.rawValue)
        append("Tags", action.tags?.joined(separator: ", ")); append("Content", action.body)
        return lines.isEmpty ? "Apply this action to the current selection." : lines.joined(separator: "\n")
    }

    func newConversation() {
        activeConversationId = UUID().uuidString
    }
    func conversationMessages(_ id: String? = nil) -> [CoachMessage] { data.messages.filter { $0.conversationId == (id ?? activeConversationId) } }

    func apply(actions: [CoachAction]) {
        for action in actions {
            switch action.type {
            case "complete_task", "complete":
                if let id = action.taskId { setTaskStatus(id, .completed) }
            case "skip_task", "skip":
                if let id = action.taskId { setTaskStatus(id, .skipped) }
            case "delete_task", "delete":
                if let id = action.taskId { deleteTask(id) }
            case "create_task", "add":
                guard let title = action.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                var task = PlanEngine.manualTask(title: title, date: action.date?.isEmpty == false ? action.date! : selectedDate)
                task.startTime = action.startTime?.isEmpty == false ? action.startTime : nil
                task.durationMinutes = action.durationMinutes ?? 30
                task.category = action.category ?? .life
                task.note = action.body ?? task.note
                task.priority = min(3, max(1, action.intValue ?? task.priority))
                task.mustWin = action.boolValue ?? task.mustWin
                task.projectID = action.value?.isEmpty == false ? action.value : nil
                task.icon = IconEngine.symbol(for: title, category: task.category)
                if let start = TimeMath.minutes(task.startTime) {
                    task.endTime = TimeMath.clockString(start + max(5, task.durationMinutes))
                    task.allDay = false
                }
                addTask(task)
            case "update_task", "update":
                applyCoachUpdate(action)
            case "create_goal":
                guard let title = action.title, !title.isEmpty else { continue }
                data.goals.append(Goal(title: title, why: action.body ?? "", category: action.category ?? .focus, targetDate: action.date?.isEmpty == false ? action.date : nil))
                record("agent-goal-created", title); persist()
            case "update_goal":
                guard let id = action.itemId, let i = data.goals.firstIndex(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { data.goals[i].title = title }
                if let body = action.body { data.goals[i].why = body }
                if let date = action.date { data.goals[i].targetDate = date.isEmpty ? nil : date }
                if let category = action.category { data.goals[i].category = category }
                record("agent-goal-updated", data.goals[i].title); persist()
            case "update_goal_progress":
                guard let id = action.itemId, let i = data.goals.firstIndex(where: { $0.id == id }) else { continue }
                data.goals[i].progress = min(100, max(0, action.intValue ?? data.goals[i].progress))
                record("agent-goal-progress", data.goals[i].title); persist()
            case "archive_goal":
                guard let id = action.itemId, let i = data.goals.firstIndex(where: { $0.id == id }) else { continue }
                data.goals[i].archived = true; record("agent-goal-archived", data.goals[i].title); persist()
            case "delete_goal":
                if let id = action.itemId { data.goals.removeAll { $0.id == id }; record("agent-goal-deleted", id); persist() }
            case "create_habit":
                guard let title = action.title, !title.isEmpty else { continue }
                data.habits.append(Habit(title: title, reminderTime: action.startTime?.isEmpty == false ? action.startTime : nil))
                record("agent-habit-created", title); persist()
            case "update_habit":
                guard let id = action.itemId, let i = data.habits.firstIndex(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { data.habits[i].title = title }
                if let time = action.startTime { data.habits[i].reminderTime = time.isEmpty ? nil : time }
                record("agent-habit-updated", data.habits[i].title); persist()
            case "delete_habit":
                if let id = action.itemId { data.habits.removeAll { $0.id == id }; record("agent-habit-deleted", id); persist() }
            case "toggle_habit":
                if let id = action.itemId { toggleHabit(id, date: action.date?.isEmpty == false ? action.date! : DateKey.today) }
            case "create_note":
                guard let title = action.title, !title.isEmpty else { continue }
                saveNote(AppNote(title: title, body: action.body ?? ""))
            case "update_note":
                guard let id = action.itemId, let i = data.notes.firstIndex(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { data.notes[i].title = title }
                if let body = action.body { data.notes[i].body = body }
                data.notes[i].updatedAt = ISO8601DateFormatter().string(from: .now); persist()
            case "delete_note":
                if let id = action.itemId { deleteNote(id) }
            case "add_inbox":
                if let title = action.title, !title.isEmpty { addInbox(title) }
            case "update_inbox":
                guard let id = action.itemId, let i = data.inbox.firstIndex(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { data.inbox[i].title = title }
                if let body = action.body { data.inbox[i].note = body.isEmpty ? nil : body }
                record("agent-inbox-updated", data.inbox[i].title); persist()
            case "delete_inbox":
                if let id = action.itemId { deleteInbox(id) }
            case "create_workspace_page":
                guard let title = action.title, !title.isEmpty else { continue }
                saveWorkspacePage(WorkspacePage(title: title, body: action.body ?? "", tags: action.tags ?? []))
            case "update_workspace_page":
                guard let id = action.itemId, var page = data.workspacePages.first(where: { $0.id == id }), page.locked != true else { continue }
                if let title = action.title, !title.isEmpty { page.title = title }
                if let body = action.body { page.body = body }
                if let tags = action.tags { page.tags = tags }
                saveWorkspacePage(page)
            case "set_workspace_page_lock":
                guard let id = action.itemId, let i = data.workspacePages.firstIndex(where: { $0.id == id }), let locked = action.boolValue else { continue }
                data.workspacePages[i].locked = locked; data.workspacePages[i].updatedAt = ISO8601DateFormatter().string(from: .now); persist()
            case "set_workspace_page_verified":
                guard let id = action.itemId, let i = data.workspacePages.firstIndex(where: { $0.id == id }), let verified = action.boolValue else { continue }
                data.workspacePages[i].verified = verified; data.workspacePages[i].verifiedAt = verified ? ISO8601DateFormatter().string(from: .now) : nil; data.workspacePages[i].updatedAt = ISO8601DateFormatter().string(from: .now); persist()
            case "archive_workspace_page":
                if let id = action.itemId { archiveWorkspacePage(id) }
            case "restore_workspace_page":
                guard let id = action.itemId, let i = data.workspacePages.firstIndex(where: { $0.id == id }) else { continue }
                data.workspacePages[i].archived = false; data.workspacePages[i].updatedAt = ISO8601DateFormatter().string(from: .now); persist()
            case "delete_workspace_page":
                if let id = action.itemId { deleteWorkspacePage(id) }
            case "create_workspace_space":
                guard let title = action.title, !title.isEmpty else { continue }
                var space = WorkspaceSpace(title: title)
                if let body = action.body { space.description = body }
                if let value = action.value, !value.isEmpty { space.icon = value }
                if let favorite = action.boolValue { space.favorite = favorite }
                saveWorkspaceSpace(space)
            case "update_workspace_space":
                guard let id = action.itemId, var space = data.workspaceSpaces.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { space.title = title }
                if let body = action.body { space.description = body }
                if let value = action.value, !value.isEmpty { space.icon = value }
                if let favorite = action.boolValue { space.favorite = favorite }
                saveWorkspaceSpace(space)
            case "delete_workspace_space":
                if let id = action.itemId { deleteWorkspaceSpace(id) }
            case "create_workspace_database":
                guard let title = action.title, !title.isEmpty else { continue }
                let view = action.value.flatMap(WorkspaceDatabaseView.init(rawValue:)) ?? .table
                saveWorkspaceDatabase(WorkspaceDatabase(title: title, view: view))
            case "update_workspace_database":
                guard let id = action.itemId, var database = data.workspaceDatabases.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { database.title = title }
                if let value = action.value, let view = WorkspaceDatabaseView(rawValue: value) { database.view = view }
                saveWorkspaceDatabase(database)
            case "delete_workspace_database":
                if let id = action.itemId { deleteWorkspaceDatabase(id) }
            case "create_workspace_canvas":
                guard let title = action.title, !title.isEmpty else { continue }
                saveWorkspaceCanvas(WorkspaceCanvas(title: title))
            case "add_workspace_canvas_node":
                guard let canvasID = action.itemId, let title = action.title, !title.isEmpty else { continue }
                addWorkspaceCanvasNode(canvasID: canvasID, title: title, note: action.body ?? "")
            case "delete_workspace_canvas":
                if let id = action.itemId { deleteWorkspaceCanvas(id) }
            case "create_workspace_record":
                guard let databaseID = action.itemId, let title = action.title, !title.isEmpty else { continue }
                addWorkspaceRecord(databaseID: databaseID, record: WorkspaceRecord(title: title, status: action.value?.isEmpty == false ? action.value! : "Not started", dueDate: action.date?.isEmpty == false ? action.date : nil, tags: action.tags ?? [], note: action.body ?? ""))
            case "update_workspace_record":
                guard let databaseID = action.key, let recordID = action.itemId else { continue }
                updateWorkspaceRecord(databaseID: databaseID, recordID: recordID) { record in
                    if let title = action.title, !title.isEmpty { record.title = title }
                    if let value = action.value, !value.isEmpty { record.status = value }
                    if let date = action.date { record.dueDate = date.isEmpty ? nil : date }
                    if let tags = action.tags { record.tags = tags }
                    if let body = action.body { record.note = body }
                }
            case "delete_workspace_record":
                if let databaseID = action.key, let recordID = action.itemId { deleteWorkspaceRecord(databaseID: databaseID, recordID: recordID) }
            case "create_workspace_project":
                guard let title = action.title, !title.isEmpty else { continue }
                var project = WorkspaceProject(title: title)
                if let value = action.value, let status = WorkspaceProjectStatus(rawValue: value) { project.status = status }
                project.outcome = action.body ?? ""
                project.deadline = action.date?.isEmpty == false ? action.date : nil
                project.priority = min(3, max(1, action.intValue ?? 2))
                saveWorkspaceProject(project)
            case "update_workspace_project":
                guard let id = action.itemId, var project = data.workspaceProjects.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { project.title = title }
                if let body = action.body { project.outcome = body }
                if let value = action.value, let status = WorkspaceProjectStatus(rawValue: value) { project.status = status }
                if let date = action.date { project.deadline = date.isEmpty ? nil : date }
                if let progress = action.intValue { project.progress = min(100, max(0, progress)) }
                if let enabled = action.boolValue { project.autoSchedule = enabled }
                saveWorkspaceProject(project)
            case "delete_workspace_project":
                if let id = action.itemId { deleteWorkspaceProject(id) }
            case "link_task_project":
                guard let taskID = action.taskId else { continue }
                mutateTask(taskID) { $0.projectID = action.itemId?.isEmpty == false ? action.itemId : nil }
                persist()
            case "set_task_dependencies":
                guard let taskID = action.taskId else { continue }
                mutateTask(taskID) { $0.dependencyTaskIDs = action.tags ?? [] }
                persist()
            case "create_workspace_automation":
                guard let title = action.title, !title.isEmpty else { continue }
                let trigger = action.key.flatMap(WorkspaceAutomationTrigger.init(rawValue:)) ?? .manual
                let automationAction = action.value.flatMap(WorkspaceAutomationAction.init(rawValue:)) ?? .createTask
                var automation = WorkspaceAutomation(title: title, trigger: trigger, action: automationAction)
                automation.templateTitle = action.body ?? title
                automation.sourceDatabaseID = action.itemId
                automation.targetDatabaseID = action.taskId
                automation.matchStatus = action.tags?.first
                automation.enabled = action.boolValue ?? true
                saveWorkspaceAutomation(automation)
            case "run_workspace_automation":
                if let id = action.itemId { runWorkspaceAutomation(id) }
            case "delete_workspace_automation":
                if let id = action.itemId { deleteWorkspaceAutomation(id) }
            case "create_workspace_meeting":
                guard let title = action.title, !title.isEmpty else { continue }
                var meeting = WorkspaceMeetingNote(title: title)
                meeting.date = action.date?.isEmpty == false ? action.date! : DateKey.today
                meeting.attendees = action.tags ?? []
                meeting.notes = action.body ?? ""
                saveWorkspaceMeeting(meeting)
            case "update_workspace_meeting":
                guard let id = action.itemId, var meeting = data.workspaceMeetings.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { meeting.title = title }
                if let date = action.date, !date.isEmpty { meeting.date = date }
                if let tags = action.tags { meeting.attendees = tags }
                if let body = action.body { meeting.notes = body }
                if let value = action.value, !value.isEmpty { meeting.decisions = value.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                if let key = action.key, !key.isEmpty { meeting.actionItems = key.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                saveWorkspaceMeeting(meeting)
            case "delete_workspace_meeting":
                if let id = action.itemId { deleteWorkspaceMeeting(id) }
            case "meeting_actions_to_tasks":
                if let id = action.itemId { turnMeetingActionsIntoTasks(id) }
            case "create_scheduling_link":
                guard let title = action.title, !title.isEmpty else { continue }
                var link = WorkspaceSchedulingLink(title: title)
                link.durationMinutes = max(5, action.durationMinutes ?? 30)
                if let start = action.startTime, !start.isEmpty { link.windowStart = start }
                if let end = action.value, !end.isEmpty { link.windowEnd = end }
                link.bufferAfterMinutes = max(0, action.intValue ?? 10)
                link.active = action.boolValue ?? true
                saveWorkspaceSchedulingLink(link)
            case "update_scheduling_link":
                guard let id = action.itemId, var link = data.workspaceSchedulingLinks.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { link.title = title }
                if let duration = action.durationMinutes { link.durationMinutes = max(5, duration) }
                if let start = action.startTime, !start.isEmpty { link.windowStart = start }
                if let end = action.value, !end.isEmpty { link.windowEnd = end }
                if let buffer = action.intValue { link.bufferAfterMinutes = max(0, buffer) }
                if let active = action.boolValue { link.active = active }
                saveWorkspaceSchedulingLink(link)
            case "delete_scheduling_link":
                if let id = action.itemId { deleteWorkspaceSchedulingLink(id) }
            case "create_smart_meeting":
                guard let title = action.title, !title.isEmpty else { continue }
                var meeting = WorkspaceSmartMeeting(title: title)
                meeting.attendees = action.tags ?? []
                meeting.durationMinutes = max(5, action.durationMinutes ?? 30)
                meeting.preferredWeekday = min(7, max(1, action.intValue ?? 2))
                if let start = action.startTime, !start.isEmpty { meeting.windowStart = start }
                if let end = action.value, !end.isEmpty { meeting.windowEnd = end }
                meeting.autoReschedule = action.boolValue ?? true
                saveWorkspaceSmartMeeting(meeting)
            case "update_smart_meeting":
                guard let id = action.itemId, var meeting = data.workspaceSmartMeetings.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { meeting.title = title }
                if let attendees = action.tags { meeting.attendees = attendees }
                if let duration = action.durationMinutes { meeting.durationMinutes = max(5, duration) }
                if let weekday = action.intValue { meeting.preferredWeekday = min(7, max(1, weekday)) }
                if let start = action.startTime, !start.isEmpty { meeting.windowStart = start }
                if let end = action.value, !end.isEmpty { meeting.windowEnd = end }
                if let auto = action.boolValue { meeting.autoReschedule = auto }
                saveWorkspaceSmartMeeting(meeting)
            case "schedule_smart_meeting":
                if let id = action.itemId, let meeting = data.workspaceSmartMeetings.first(where: { $0.id == id }) { _ = scheduleWorkspaceSmartMeeting(meeting) }
            case "delete_smart_meeting":
                if let id = action.itemId { deleteWorkspaceSmartMeeting(id) }
            case "create_workspace_form":
                guard let title = action.title, !title.isEmpty, let databaseID = action.itemId, data.workspaceDatabases.contains(where: { $0.id == databaseID }) else { continue }
                var form = WorkspaceForm(title: title, databaseID: databaseID)
                form.fieldPropertyIDs = action.tags ?? []
                if let body = action.body, !body.isEmpty { form.confirmationMessage = body }
                form.active = action.boolValue ?? true
                saveWorkspaceForm(form)
            case "update_workspace_form":
                guard let id = action.itemId, var form = data.workspaceForms.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { form.title = title }
                if let databaseID = action.value, !databaseID.isEmpty, data.workspaceDatabases.contains(where: { $0.id == databaseID }) { form.databaseID = databaseID }
                if let tags = action.tags { form.fieldPropertyIDs = tags }
                if let body = action.body, !body.isEmpty { form.confirmationMessage = body }
                if let active = action.boolValue { form.active = active }
                saveWorkspaceForm(form)
            case "delete_workspace_form":
                if let id = action.itemId { deleteWorkspaceForm(id) }
            case "add_workspace_property":
                guard let databaseID = action.itemId, let title = action.title, !title.isEmpty else { continue }
                let type = action.value.flatMap(WorkspacePropertyType.init(rawValue:)) ?? .text
                var definition = WorkspacePropertyDefinition(name: title, type: type)
                definition.options = action.tags ?? []
                definition.relationDatabaseID = action.key?.isEmpty == false ? action.key : nil
                definition.formula = action.body?.isEmpty == false ? action.body : nil
                addWorkspaceProperty(databaseID: databaseID, definition: definition)
            case "update_workspace_property":
                guard let databaseID = action.itemId, let propertyID = action.key, let dbIndex = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }), let propertyIndex = data.workspaceDatabases[dbIndex].properties?.firstIndex(where: { $0.id == propertyID }) else { continue }
                if let title = action.title, !title.isEmpty { data.workspaceDatabases[dbIndex].properties?[propertyIndex].name = title }
                if let value = action.value, let type = WorkspacePropertyType(rawValue: value) { data.workspaceDatabases[dbIndex].properties?[propertyIndex].type = type }
                if let tags = action.tags { data.workspaceDatabases[dbIndex].properties?[propertyIndex].options = tags }
                if let relation = action.taskId { data.workspaceDatabases[dbIndex].properties?[propertyIndex].relationDatabaseID = relation.isEmpty ? nil : relation }
                if let formula = action.body { data.workspaceDatabases[dbIndex].properties?[propertyIndex].formula = formula.isEmpty ? nil : formula }
                data.workspaceDatabases[dbIndex].updatedAt = ISO8601DateFormatter().string(from: .now); persist()
            case "delete_workspace_property":
                if let databaseID = action.itemId, let propertyID = action.key { deleteWorkspaceProperty(databaseID: databaseID, propertyID: propertyID) }
            case "auto_schedule_project":
                if let id = action.itemId { _ = autoScheduleWorkspaceProject(id, from: DateKey.date(action.date ?? selectedDate) ?? .now) }
            case "schedule_habit_blocks":
                _ = scheduleHabitTimeBlocks(days: max(1, action.intValue ?? 7), from: DateKey.date(action.date ?? selectedDate) ?? .now)
            case "autopilot_week":
                _ = runWorkspaceAutopilot(containing: DateKey.date(action.date ?? selectedDate) ?? .now)
            case "protect_weekly_focus":
                _ = protectWeeklyFocus(containing: DateKey.date(action.date ?? selectedDate) ?? .now)
            case "build_workspace_agenda":
                _ = buildWorkspaceAgenda(for: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "create_daily_note":
                _ = openOrCreateDailyNote(for: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "save_search":
                guard let title = action.title, !title.isEmpty, let query = action.value, !query.isEmpty else { continue }
                saveWorkspaceSavedSearch(WorkspaceSavedSearch(title: title, query: query, scope: action.key ?? "all"))
            case "update_saved_search":
                guard let id = action.itemId, var search = data.workspaceSavedSearches.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { search.title = title }
                if let query = action.value, !query.isEmpty { search.query = query }
                if let scope = action.key, !scope.isEmpty { search.scope = scope }
                saveWorkspaceSavedSearch(search)
            case "delete_saved_search":
                if let id = action.itemId { deleteWorkspaceSavedSearch(id) }
            case "import_workspace_markdown":
                if let body = action.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    importWorkspaceMarkdown(title: action.title ?? "Imported page", markdown: body, tags: action.tags ?? ["imported", "ai"])
                }
            case "create_clip":
                guard let title = action.title, !title.isEmpty else { continue }
                saveWorkspaceClip(WorkspaceClip(title: title, url: action.value ?? "", note: action.body ?? "", tags: action.tags ?? []))
            case "update_clip":
                guard let id = action.itemId, var clip = data.workspaceClips.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { clip.title = title }
                if let value = action.value { clip.url = value }
                if let body = action.body { clip.note = body }
                if let tags = action.tags { clip.tags = tags }
                if let read = action.boolValue { clip.read = read }
                saveWorkspaceClip(clip)
            case "delete_clip":
                if let id = action.itemId { deleteWorkspaceClip(id) }
            case "clip_to_page":
                if let id = action.itemId { _ = workspaceClipToPage(id) }
            case "add_page_comment":
                if let pageID = action.itemId, let body = action.body { addWorkspaceComment(pageID: pageID, text: body, author: action.title?.isEmpty == false ? action.title! : "Planning AI") }
            case "resolve_page_comment":
                if let id = action.itemId { resolveWorkspaceComment(id, resolved: action.boolValue ?? true) }
            case "delete_page_comment":
                if let id = action.itemId { deleteWorkspaceComment(id) }
            case "restore_page_version":
                if let id = action.itemId { restoreWorkspacePageVersion(id) }
            case "create_workspace_site":
                guard let title = action.title, !title.isEmpty, let pageID = action.itemId, data.workspacePages.contains(where: { $0.id == pageID }) else { continue }
                let slug = action.value?.isEmpty == false ? action.value! : title.lowercased().replacingOccurrences(of: " ", with: "-")
                saveWorkspaceSite(WorkspaceSite(title: title, pageID: pageID, slug: slug, published: action.boolValue ?? true))
            case "update_workspace_site":
                guard let id = action.itemId, var site = data.workspaceSites.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { site.title = title }
                if let value = action.value, !value.isEmpty { site.slug = value }
                if let pageID = action.key, !pageID.isEmpty, data.workspacePages.contains(where: { $0.id == pageID }) { site.pageID = pageID }
                if let published = action.boolValue { site.published = published }
                saveWorkspaceSite(site)
            case "delete_workspace_site":
                if let id = action.itemId { deleteWorkspaceSite(id) }
            case "start_time_tracking":
                guard let title = action.title, !title.isEmpty else { continue }
                startWorkspaceTimer(title: title, category: action.category ?? .focus, projectID: action.itemId?.isEmpty == false ? action.itemId : nil, taskID: action.taskId?.isEmpty == false ? action.taskId : nil)
            case "stop_time_tracking":
                stopWorkspaceTimer()
            case "delete_time_entry":
                if let id = action.itemId { deleteWorkspaceTimeEntry(id) }
            case "create_custom_agent":
                guard let title = action.title, !title.isEmpty, let body = action.body, !body.isEmpty else { continue }
                var agent = WorkspaceCustomAgent(title: title, instructions: body)
                if let value = action.value, let scope = WorkspaceAgentScope(rawValue: value) { agent.scope = scope }
                if let key = action.key, let trigger = WorkspaceAutomationTrigger(rawValue: key) { agent.trigger = trigger }
                agent.enabled = action.boolValue ?? true
                saveWorkspaceCustomAgent(agent)
            case "update_custom_agent":
                guard let id = action.itemId, var agent = data.workspaceCustomAgents.first(where: { $0.id == id }) else { continue }
                if let title = action.title, !title.isEmpty { agent.title = title }
                if let body = action.body, !body.isEmpty { agent.instructions = body }
                if let value = action.value, let scope = WorkspaceAgentScope(rawValue: value) { agent.scope = scope }
                if let key = action.key, let trigger = WorkspaceAutomationTrigger(rawValue: key) { agent.trigger = trigger }
                if let enabled = action.boolValue { agent.enabled = enabled }
                saveWorkspaceCustomAgent(agent)
            case "run_custom_agent":
                if let id = action.itemId { Task { _ = await self.runWorkspaceCustomAgent(id) } }
            case "delete_custom_agent":
                if let id = action.itemId { deleteWorkspaceCustomAgent(id) }
            case "set_setting":
                if let key = action.key { applyAgentSetting(key: key, value: action.value, boolValue: action.boolValue, intValue: action.intValue) }
            case "set_profile":
                if let key = action.key { applyAgentProfile(key: key, value: action.value, boolValue: action.boolValue, intValue: action.intValue) }
            case "select_date":
                if let date = action.date, DateKey.date(date) != nil { selectedDate = date }
            case "set_tab":
                if action.value == "fitness" {
                    selectedTab = .notes
                } else if let value = action.value, let tab = AppTab(rawValue: value) {
                    selectedTab = tab
                }
            case "open_quick_add":
                quickAddRequested = true
            case "set_timeline_layout":
                if let value = action.value,
                   let layout = TimelineLayoutStyle(rawValue: value),
                   layout != .orbit {
                    updateSettings { $0.timelineLayout = layout }
                }
            case "compress_day":
                let date = action.date?.isEmpty == false ? action.date! : selectedDate
                _ = compressRemainingDay(on: date, fromMinute: action.intValue ?? 0)
            case "compress_week":
                _ = compressWeek(containing: DateKey.date(action.date ?? selectedDate) ?? .now)
            case "buffer_guard":
                _ = applyBufferGuard(on: action.date?.isEmpty == false ? action.date! : selectedDate, minimumMinutes: max(5, action.intValue ?? 10))
            case "auto_lock":
                _ = autoLockNearTerm(on: action.date?.isEmpty == false ? action.date! : selectedDate, withinMinutes: max(30, action.intValue ?? 120))
            case "focus_shield":
                _ = focusShield(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "recovery_buffers":
                _ = applyRecoveryBuffers(on: action.date?.isEmpty == false ? action.date! : selectedDate, minutes: max(5, action.intValue ?? 10))
            case "conflict_sweep":
                _ = repairTimelineConflicts(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "energy_fit":
                _ = applyEnergyFit(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "overload_guard":
                _ = applyOverloadGuard(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "context_batching":
                _ = batchContexts(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "travel_buffer":
                _ = applyTravelBuffer(on: action.date?.isEmpty == false ? action.date! : selectedDate, minutes: max(5, action.intValue ?? 15))
            case "focus_budget":
                _ = protectFocusBudget(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "meeting_defrag":
                _ = defragMeetings(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "momentum_chain":
                _ = buildMomentumChain(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "deadline_backplan":
                _ = backplanDeadlines(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "habit_rescue":
                _ = rescueHabits(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "no_meeting_guard":
                _ = applyNoMeetingGuard(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "deep_work_reserve":
                _ = reserveDeepWork(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            case "context_switch_shield":
                _ = applyContextSwitchShield(on: action.date?.isEmpty == false ? action.date! : selectedDate)
            default:
                break
            }
        }
    }

    private func setTaskStatus(_ id: String, _ status: TaskStatus) {
        guard findTask(id) != nil else { return }
        var rescued = false
        var title = id
        for p in data.plans.indices {
            guard let t = data.plans[p].tasks.firstIndex(where: { $0.id == id }) else { continue }
            data.plans[p].tasks[t].status = status
            data.plans[p].tasks[t].completedAt = status == .completed ? ISO8601DateFormatter().string(from: .now) : nil
            data.plans[p].tasks[t].skippedReason = status == .skipped ? "Skipped through AI coach" : nil
            rescued = data.plans[p].rescuedAt != nil
            title = data.plans[p].tasks[t].title
            break
        }
        if status == .completed {
            refreshCompletionAchievements(planWasRescued: rescued)
            Task { await LiveActivityService.shared.finish() }
            record("task-completed", title)
            runWorkspaceAutomations(trigger: .taskCompleted, sourceTitle: title)
        } else if status == .skipped {
            record("task-skipped", title)
        }
        persist()
        Task { await refreshNotificationSchedules() }
    }

    private func refreshCompletionAchievements(planWasRescued: Bool) {
        let honestDays = min(7, Set(data.plans.flatMap(\.tasks).filter { $0.status == .completed }.map(\.planDate)).count)
        if let i = data.achievements.firstIndex(where: { $0.id == "achievement-streak" }) {
            data.achievements[i].progress = honestDays
            if honestDays >= data.achievements[i].target {
                data.achievements[i].unlockedAt = data.achievements[i].unlockedAt ?? ISO8601DateFormatter().string(from: .now)
            }
        }
        if planWasRescued, let i = data.achievements.firstIndex(where: { $0.id == "achievement-comeback" }) {
            data.achievements[i].progress = 1
            data.achievements[i].unlockedAt = data.achievements[i].unlockedAt ?? ISO8601DateFormatter().string(from: .now)
        }
    }

    private func applyCoachUpdate(_ action: CoachAction) {
        guard let id = action.taskId else { return }
        var sourcePlanIndex: Int?
        var sourceTaskIndex: Int?
        for planIndex in data.plans.indices {
            if let taskIndex = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }) {
                sourcePlanIndex = planIndex
                sourceTaskIndex = taskIndex
                break
            }
        }
        guard let planIndex = sourcePlanIndex, let taskIndex = sourceTaskIndex else { return }
        var task = data.plans[planIndex].tasks[taskIndex]
        let originalDate = task.planDate
        if let title = action.title, !title.isEmpty { task.title = title }
        if let body = action.body { task.note = body }
        if let startTime = action.startTime { task.startTime = startTime.isEmpty ? nil : startTime }
        if let duration = action.durationMinutes { task.durationMinutes = max(5, duration) }
        if let category = action.category { task.category = category }
        if let date = action.date, !date.isEmpty { task.planDate = date }
        if let priority = action.intValue { task.priority = min(3, max(1, priority)) }
        if let mustWin = action.boolValue { task.mustWin = mustWin }
        if let key = action.key {
            switch key {
            case "deadline": task.deadline = action.value?.isEmpty == false ? action.value : nil
            case "projectID": task.projectID = action.value?.isEmpty == false ? action.value : nil
            case "timelineLocked": task.timelineLocked = action.value.flatMap(Bool.init) ?? action.boolValue
            case "allDay": task.allDay = action.value.flatMap(Bool.init) ?? action.boolValue
            case "flexible": task.flexible = action.value.flatMap(Bool.init) ?? action.boolValue
            case "status": if let value = action.value, let status = TaskStatus(rawValue: value) { task.status = status }
            default: break
            }
        }
        if let dependencies = action.tags { task.dependencyTaskIDs = dependencies }
        task.icon = IconEngine.symbol(for: task.title, category: task.category)
        if let start = TimeMath.minutes(task.startTime) {
            task.endTime = TimeMath.clockString(start + max(5, task.durationMinutes))
            task.allDay = false
            task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
        }
        if task.planDate == originalDate {
            data.plans[planIndex].tasks[taskIndex] = task
        } else {
            data.plans[planIndex].tasks.remove(at: taskIndex)
            task.manualOrder = nil
            insertTask(task)
        }
        persist()
    }

    @discardableResult
    func compressWeek(containing date: Date) -> Int {
        let monday = TimelineDateMath.startOfWeek(containing: date)
        var total = 0
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: monday) else { continue }
            total += compressRemainingDay(on: DateKey.string(day), fromMinute: 0)
        }
        if total > 0 { record("timeline-compress-week", "\(total) task(s)"); persist() }
        return total
    }

    @discardableResult
    func applyBufferGuard(on date: String, minimumMinutes: Int = 10) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        var changed = 0
        for taskIndex in data.plans[planIndex].tasks.indices {
            guard data.plans[planIndex].tasks[taskIndex].status != .skipped else { continue }
            let current = data.plans[planIndex].tasks[taskIndex].bufferAfterMinutes ?? 0
            if current < minimumMinutes { data.plans[planIndex].tasks[taskIndex].bufferAfterMinutes = minimumMinutes; changed += 1 }
        }
        if changed > 0 { record("timeline-buffer-guard", "\(changed) task(s) · \(minimumMinutes)m"); persist() }
        return changed
    }

    @discardableResult
    func autoLockNearTerm(on date: String, withinMinutes: Int = 120) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let currentMinute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        var changed = 0
        for taskIndex in data.plans[planIndex].tasks.indices {
            let task = data.plans[planIndex].tasks[taskIndex]
            guard task.externalSource != .calendar, task.status == .pending, let start = TimeMath.minutes(task.startTime), start >= currentMinute, start <= currentMinute + withinMinutes, task.timelineLocked != true else { continue }
            data.plans[planIndex].tasks[taskIndex].timelineLocked = true; changed += 1
        }
        if changed > 0 { record("timeline-auto-lock", "\(changed) near-term task(s)"); persist() }
        return changed
    }

    @discardableResult
    func focusShield(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        var changed = 0
        for taskIndex in data.plans[planIndex].tasks.indices {
            let task = data.plans[planIndex].tasks[taskIndex]
            guard task.externalSource != .calendar, task.status == .pending, (task.mustWin == true || task.category == .focus || task.priority == 1), task.timelineLocked != true else { continue }
            data.plans[planIndex].tasks[taskIndex].timelineLocked = true; changed += 1
        }
        if changed > 0 { record("timeline-focus-shield", "\(changed) priority task(s)"); persist() }
        return changed
    }

    @discardableResult
    func applyRecoveryBuffers(on date: String, minutes: Int = 10) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        var changed = 0
        for taskIndex in data.plans[planIndex].tasks.indices {
            let task = data.plans[planIndex].tasks[taskIndex]
            guard task.externalSource == .calendar || task.category == .work || task.category == .study else { continue }
            if (task.bufferAfterMinutes ?? 0) < minutes { data.plans[planIndex].tasks[taskIndex].bufferAfterMinutes = minutes; changed += 1 }
        }
        if changed > 0 { record("timeline-recovery-buffer", "\(changed) task(s)"); persist() }
        return changed
    }

    @discardableResult
    func repairTimelineConflicts(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        let orderedIDs = data.plans[planIndex].tasks.filter { $0.status != .skipped && TimeMath.minutes($0.startTime) != nil }.sorted { (TimeMath.minutes($0.startTime) ?? Int.max) < (TimeMath.minutes($1.startTime) ?? Int.max) }.map(\.id)
        var cursor = 0
        var changed = 0
        for id in orderedIDs {
            guard let i = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }), let start = TimeMath.minutes(data.plans[planIndex].tasks[i].startTime) else { continue }
            let duration = max(5, data.plans[planIndex].tasks[i].durationMinutes)
            if start < cursor && !isTimelineFixed(data.plans[planIndex].tasks[i]) {
                var task = data.plans[planIndex].tasks[i]
                rememberTimelineBaseline(&task)
                task.startTime = TimeMath.string(cursor)
                task.endTime = TimeMath.string(cursor + duration)
                data.plans[planIndex].tasks[i] = task
                changed += 1
            }
            let effectiveStart = TimeMath.minutes(data.plans[planIndex].tasks[i].startTime) ?? start
            cursor = max(cursor, effectiveStart + duration + timelineBuffer(for: data.plans[planIndex].tasks[i]))
        }
        if changed > 0 { record("timeline-conflict-sweep", "\(changed) task(s)"); persist() }
        return changed
    }

    /// ENERGY FIT rearranges only flexible scheduled work, placing higher-energy work
    /// earlier in the available sequence while preserving fixed calendar/locked anchors.
    @discardableResult
    func applyEnergyFit(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        let candidates = data.plans[planIndex].tasks.filter {
            $0.status == .pending && !isTimelineFixed($0) && $0.flexible != false && TimeMath.minutes($0.startTime) != nil
        }
        guard candidates.count > 1 else { return 0 }
        let ordered = candidates.sorted { lhs, rhs in
            let le = lhs.energy ?? (lhs.category == .focus || lhs.category == .study ? 4 : 3)
            let re = rhs.energy ?? (rhs.category == .focus || rhs.category == .study ? 4 : 3)
            if le != re { return le > re }
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.title < rhs.title
        }
        let current = data.plans[planIndex]
        guard let result = PlanEngine.safeReorderedPlan(current, ordered: ordered, bufferMinutes: data.workspaceTimePolicy.breakMinutes, allPlans: data.plans) else { return 0 }
        let changed = result.tasks.filter { task in current.tasks.first(where: { $0.id == task.id })?.startTime != task.startTime }.count
        if changed > 0 {
            data.plans[planIndex] = result
            record("timeline-energy-fit", "\(changed) task(s)")
            persist()
            scheduleNotifications(for: result.tasks)
        }
        return changed
    }

    /// OVERLOAD GUARD moves the least urgent flexible work to the next day when the
    /// scheduled workload exceeds the user's configured work window.
    @discardableResult
    func applyOverloadGuard(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        let start = TimeMath.minutes(data.workspaceTimePolicy.workHoursStart) ?? 480
        let end = TimeMath.minutes(data.workspaceTimePolicy.workHoursEnd) ?? 1080
        let capacity = max(180, end - start)
        let activeMinutes = data.plans[planIndex].tasks.filter { $0.status == .pending || $0.status == .active }.reduce(0) { $0 + max(5, $1.durationMinutes) }
        var overflow = activeMinutes - capacity
        guard overflow > 0, let baseDate = DateKey.date(date), let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) else { return 0 }
        let nextKey = DateKey.string(nextDate)
        let moveIDs = data.plans[planIndex].tasks.filter {
            $0.status == .pending && !isTimelineFixed($0) && $0.flexible != false && $0.mustWin != true && $0.priority > 1
        }.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return (TimeMath.minutes($0.startTime) ?? 0) > (TimeMath.minutes($1.startTime) ?? 0)
        }.map(\.id)
        var moved = 0
        for id in moveIDs where overflow > 0 {
            guard let i = data.plans[planIndex].tasks.firstIndex(where: { $0.id == id }) else { continue }
            var task = data.plans[planIndex].tasks.remove(at: i)
            overflow -= max(5, task.durationMinutes)
            task.planDate = nextKey
            task.startTime = nil
            task.endTime = nil
            task.section = .day
            insertTask(task)
            moved += 1
        }
        if moved > 0 { record("timeline-overload-guard", "\(moved) moved to \(nextKey)"); persist() }
        return moved
    }

    /// CONTEXT BATCHING keeps flexible work from the same category/project next to
    /// each other using the day's existing time slots.
    @discardableResult
    func batchContexts(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        let candidates = data.plans[planIndex].tasks.filter { $0.status == .pending && !isTimelineFixed($0) && $0.flexible != false && TimeMath.minutes($0.startTime) != nil }
        guard candidates.count > 2 else { return 0 }
        let ordered = candidates.sorted {
            let lp = $0.projectID ?? "~\($0.category.rawValue)"
            let rp = $1.projectID ?? "~\($1.category.rawValue)"
            if lp != rp { return lp < rp }
            if $0.category != $1.category { return $0.category.rawValue < $1.category.rawValue }
            return $0.priority < $1.priority
        }
        let current = data.plans[planIndex]
        guard let result = PlanEngine.safeReorderedPlan(current, ordered: ordered, bufferMinutes: data.workspaceTimePolicy.breakMinutes, allPlans: data.plans) else { return 0 }
        let changed = result.tasks.filter { task in current.tasks.first(where: { $0.id == task.id })?.startTime != task.startTime }.count
        if changed > 0 {
            data.plans[planIndex] = result
            record("timeline-context-batch", "\(changed) task(s)")
            persist()
            scheduleNotifications(for: result.tasks)
        }
        return changed
    }

    /// TRAVEL BUFFER adds breathing/travel room around imported calendar commitments.
    @discardableResult
    func applyTravelBuffer(on date: String, minutes: Int = 15) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        var changed = 0
        for i in data.plans[planIndex].tasks.indices {
            guard data.plans[planIndex].tasks[i].externalSource == .calendar else { continue }
            if (data.plans[planIndex].tasks[i].bufferAfterMinutes ?? 0) < minutes {
                data.plans[planIndex].tasks[i].bufferAfterMinutes = minutes
                changed += 1
            }
        }
        if changed > 0 { record("timeline-travel-buffer", "\(changed) event(s)"); persist() }
        return changed
    }

    /// FOCUS BUDGET ensures a protected deep-work reserve exists when the day's focus
    /// total is below the workspace target.
    @discardableResult
    func protectFocusBudget(on date: String) -> Int {
        let goal = max(data.workspaceTimePolicy.minimumFocusBlockMinutes, min(240, data.workspaceTimePolicy.preferredFocusBlockMinutes))
        let existing = data.plans.first(where: { $0.date == date })?.tasks.filter {
            ($0.status == .pending || $0.status == .active) && $0.category == .focus
        }.reduce(0) { $0 + max(5, $1.durationMinutes) } ?? 0
        guard existing < goal else { return focusShield(on: date) }
        let missing = max(data.workspaceTimePolicy.minimumFocusBlockMinutes, goal - existing)
        var task = PlanEngine.manualTask(title: "Deep Work Reserve", date: date)
        task.category = .focus
        task.priority = 1
        task.mustWin = existing == 0
        task.durationMinutes = min(180, missing)
        task.flexible = true
        let requested = max(TimeMath.minutes(data.workspaceTimePolicy.workHoursStart) ?? 540, date == DateKey.today ? TimeMath.nowMinutes : 540)
        guard let start = collisionResolvedStart(for: task, on: date, requestedStart: requested), start + task.durationMinutes <= 1440 else { return 0 }
        task.startTime = TimeMath.string(start)
        task.endTime = TimeMath.string(start + task.durationMinutes)
        task.timelineLocked = true
        insertTask(task)
        record("timeline-focus-budget", "reserved \(task.durationMinutes)m")
        persist()
        return 1
    }

    /// MEETING DEFRAG protects buffers around meetings and compacts flexible work into
    /// the remaining gaps instead of leaving fragmented unusable slivers.
    @discardableResult
    func defragMeetings(on date: String) -> Int {
        var changed = applyRecoveryBuffers(on: date, minutes: max(10, data.workspaceTimePolicy.breakMinutes))
        changed += repairTimelineConflicts(on: date)
        changed += compressRemainingDay(on: date, fromMinute: date == DateKey.today ? TimeMath.nowMinutes : 0)
        if changed > 0 { record("timeline-meeting-defrag", "\(changed) change(s)"); persist() }
        return changed
    }

    /// MOMENTUM CHAIN groups project work and then compresses the result so a user can
    /// stay in one mental context for longer.
    @discardableResult
    func buildMomentumChain(on date: String) -> Int {
        var changed = batchContexts(on: date)
        changed += compressRemainingDay(on: date, fromMinute: date == DateKey.today ? TimeMath.nowMinutes : 0)
        if changed > 0 { record("timeline-momentum-chain", "\(changed) change(s)"); persist() }
        return changed
    }

    /// DEADLINE BACKPLAN promotes deadline-bearing work into protected priority slots.
    @discardableResult
    func backplanDeadlines(on date: String) -> Int {
        guard let planIndex = data.plans.firstIndex(where: { $0.date == date }) else { return 0 }
        var changed = 0
        for i in data.plans[planIndex].tasks.indices {
            var task = data.plans[planIndex].tasks[i]
            guard task.status == .pending, task.deadline?.isEmpty == false else { continue }
            if task.priority != 1 { task.priority = 1; changed += 1 }
            if task.timelineLocked != true { task.timelineLocked = true; changed += 1 }
            if task.mustWin != true { task.mustWin = true; changed += 1 }
            data.plans[planIndex].tasks[i] = task
        }
        if changed > 0 { record("timeline-deadline-backplan", "\(changed) safeguard(s)"); persist() }
        return changed
    }

    /// HABIT RESCUE turns today's incomplete scheduled habits into real timeline work.
    @discardableResult
    func rescueHabits(on date: String) -> Int {
        guard let targetDate = DateKey.date(date) else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: targetDate)
        let due = data.habits.filter { !$0.completedDates.contains(date) && $0.targetDays.contains(weekday) }
        var created = 0
        for habit in due {
            let exists = data.plans.first(where: { $0.date == date })?.tasks.contains(where: { $0.note == "Habit · \(habit.id)" && $0.status != .skipped }) ?? false
            guard !exists else { continue }
            var task = PlanEngine.manualTask(title: habit.title, date: date)
            task.note = "Habit · \(habit.id)"
            task.category = .life
            task.durationMinutes = 20
            task.startTime = habit.reminderTime
            if let start = TimeMath.minutes(task.startTime) { task.endTime = TimeMath.string(start + task.durationMinutes) }
            task.flexible = true
            insertTask(task)
            created += 1
        }
        if created > 0 { record("timeline-habit-rescue", "\(created) habit(s)"); persist() }
        return created
    }

    /// NO-MEETING GUARD reinforces configured no-meeting days without deleting external
    /// calendar events: it protects focus blocks and increases separation around meetings.
    @discardableResult
    func applyNoMeetingGuard(on date: String) -> Int {
        guard let day = DateKey.date(date) else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: day)
        guard data.workspaceTimePolicy.noMeetingWeekdays.contains(weekday) else { return 0 }
        var changed = focusShield(on: date)
        changed += applyTravelBuffer(on: date, minutes: max(15, data.workspaceTimePolicy.breakMinutes))
        if changed > 0 { record("timeline-no-meeting-guard", "\(changed) safeguard(s)"); persist() }
        return changed
    }

    /// DEEP WORK RESERVE is a stronger explicit version of Focus Budget.
    @discardableResult
    func reserveDeepWork(on date: String) -> Int {
        let before = data.plans.first(where: { $0.date == date })?.tasks.filter { $0.category == .focus && $0.status != .skipped }.count ?? 0
        _ = protectFocusBudget(on: date)
        _ = focusShield(on: date)
        let after = data.plans.first(where: { $0.date == date })?.tasks.filter { $0.category == .focus && $0.status != .skipped }.count ?? 0
        return max(0, after - before)
    }

    /// CONTEXT SWITCH SHIELD combines batching, priority locking and conflict repair.
    @discardableResult
    func applyContextSwitchShield(on date: String) -> Int {
        var changed = batchContexts(on: date)
        changed += focusShield(on: date)
        changed += repairTimelineConflicts(on: date)
        if changed > 0 { record("timeline-context-switch-shield", "\(changed) change(s)"); persist() }
        return changed
    }

    func saveWorkspacePage(_ page: WorkspacePage) {
        var page = page
        page.updatedAt = ISO8601DateFormatter().string(from: .now)
        if let i = data.workspacePages.firstIndex(where: { $0.id == page.id }) {
            let previous = data.workspacePages[i]
            if previous.title != page.title || previous.body != page.body || previous.tags != page.tags {
                data.workspacePageVersions.append(WorkspacePageVersion(pageID: previous.id, title: previous.title, body: previous.body, tags: previous.tags))
                let versions = data.workspacePageVersions.filter { $0.pageID == previous.id }.sorted { $0.createdAt > $1.createdAt }
                if versions.count > 40 {
                    let keep = Set(versions.prefix(40).map(\.id))
                    data.workspacePageVersions.removeAll { $0.pageID == previous.id && !keep.contains($0.id) }
                }
            }
            data.workspacePages[i] = page
        } else {
            data.workspacePages.append(page)
        }
        record("workspace-page-saved", page.title); persist()
    }

    func archiveWorkspacePage(_ id: String) {
        guard let i = data.workspacePages.firstIndex(where: { $0.id == id }) else { return }
        data.workspacePages[i].archived = true
        data.workspacePages[i].updatedAt = ISO8601DateFormatter().string(from: .now)
        record("workspace-page-archived", data.workspacePages[i].title); persist()
    }

    func deleteWorkspacePage(_ id: String) { data.workspacePages.removeAll { $0.id == id }; record("workspace-page-deleted", id); persist() }

    func saveWorkspaceDatabase(_ database: WorkspaceDatabase) {
        var database = database
        database.updatedAt = ISO8601DateFormatter().string(from: .now)
        if let i = data.workspaceDatabases.firstIndex(where: { $0.id == database.id }) { data.workspaceDatabases[i] = database } else { data.workspaceDatabases.append(database) }
        record("workspace-database-saved", database.title); persist()
    }

    func deleteWorkspaceDatabase(_ id: String) {
        data.workspaceDatabases.removeAll { $0.id == id }
        record("workspace-database-deleted", id); persist()
    }

    func addWorkspaceRecord(databaseID: String, record: WorkspaceRecord, triggerAutomations: Bool = true) {
        guard let i = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }) else { return }
        data.workspaceDatabases[i].records.append(record)
        data.workspaceDatabases[i].updatedAt = ISO8601DateFormatter().string(from: .now)
        self.record("workspace-record-added", record.title)
        persist()
        if triggerAutomations {
            runWorkspaceAutomations(
                trigger: .recordCreated,
                sourceDatabaseID: databaseID,
                recordID: record.id,
                sourceTitle: record.title
            )
        }
    }

    func updateWorkspaceRecord(databaseID: String, recordID: String, triggerAutomations: Bool = true, _ body: (inout WorkspaceRecord) -> Void) {
        guard let d = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }), let r = data.workspaceDatabases[d].records.firstIndex(where: { $0.id == recordID }) else { return }
        let oldStatus = data.workspaceDatabases[d].records[r].status
        body(&data.workspaceDatabases[d].records[r])
        data.workspaceDatabases[d].records[r].updatedAt = ISO8601DateFormatter().string(from: .now)
        data.workspaceDatabases[d].updatedAt = ISO8601DateFormatter().string(from: .now)
        let record = data.workspaceDatabases[d].records[r]
        persist()
        if triggerAutomations && oldStatus != record.status {
            runWorkspaceAutomations(trigger: .recordStatusChanged, sourceDatabaseID: databaseID, recordID: recordID, sourceTitle: record.title, sourceStatus: record.status)
        }
    }

    func deleteWorkspaceRecord(databaseID: String, recordID: String) {
        guard let d = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }) else { return }
        data.workspaceDatabases[d].records.removeAll { $0.id == recordID }; persist()
    }

    func saveWorkspaceCanvas(_ canvas: WorkspaceCanvas) {
        var canvas = canvas
        canvas.updatedAt = ISO8601DateFormatter().string(from: .now)
        if let i = data.workspaceCanvases.firstIndex(where: { $0.id == canvas.id }) { data.workspaceCanvases[i] = canvas } else { data.workspaceCanvases.append(canvas) }
        record("workspace-canvas-saved", canvas.title); persist()
    }

    func addWorkspaceCanvasNode(canvasID: String, title: String, note: String = "") {
        guard let i = data.workspaceCanvases.firstIndex(where: { $0.id == canvasID }) else { return }
        let count = data.workspaceCanvases[i].nodes.count
        let node = WorkspaceCanvasNode(title: title, note: note, x: 180 + Double(count % 3) * 220, y: 160 + Double(count / 3) * 150)
        data.workspaceCanvases[i].nodes.append(node)
        data.workspaceCanvases[i].updatedAt = ISO8601DateFormatter().string(from: .now)
        record("workspace-canvas-node-added", title); persist()
    }

    func deleteWorkspaceCanvas(_ id: String) {
        data.workspaceCanvases.removeAll { $0.id == id }
        record("workspace-canvas-deleted", id); persist()
    }

    func saveWorkspaceSpace(_ space: WorkspaceSpace) {
        if let i = data.workspaceSpaces.firstIndex(where: { $0.id == space.id }) { data.workspaceSpaces[i] = space } else { data.workspaceSpaces.append(space) }
        record("workspace-space-saved", space.title); persist()
    }

    func deleteWorkspaceSpace(_ id: String) {
        guard id != "space-personal" else { return }
        data.workspaceSpaces.removeAll { $0.id == id }
        for i in data.workspacePages.indices where data.workspacePages[i].spaceID == id { data.workspacePages[i].spaceID = nil }
        record("workspace-space-deleted", id); persist()
    }

    func saveWorkspaceProject(_ project: WorkspaceProject) {
        var project = project
        project.updatedAt = ISO8601DateFormatter().string(from: .now)
        if let i = data.workspaceProjects.firstIndex(where: { $0.id == project.id }) { data.workspaceProjects[i] = project } else { data.workspaceProjects.append(project) }
        record("workspace-project-saved", project.title); persist()
    }

    func deleteWorkspaceProject(_ id: String) {
        data.workspaceProjects.removeAll { $0.id == id }
        for p in data.plans.indices {
            for t in data.plans[p].tasks.indices where data.plans[p].tasks[t].projectID == id { data.plans[p].tasks[t].projectID = nil }
        }
        record("workspace-project-deleted", id); persist()
    }

    func saveWorkspaceAutomation(_ automation: WorkspaceAutomation) {
        if let i = data.workspaceAutomations.firstIndex(where: { $0.id == automation.id }) { data.workspaceAutomations[i] = automation } else { data.workspaceAutomations.append(automation) }
        record("workspace-automation-saved", automation.title); persist()
    }

    func deleteWorkspaceAutomation(_ id: String) {
        data.workspaceAutomations.removeAll { $0.id == id }; record("workspace-automation-deleted", id); persist()
    }

    func runWorkspaceAutomation(_ id: String) {
        guard let automation = data.workspaceAutomations.first(where: { $0.id == id }), automation.enabled else { return }
        performTimelineTransaction(label: "Automation · \(automation.title)") {
            executeWorkspaceAutomation(automation, sourceDatabaseID: automation.sourceDatabaseID, recordID: nil, sourceTitle: automation.title, sourceStatus: nil)
        }
    }

    func runWorkspaceAutomations(trigger: WorkspaceAutomationTrigger, sourceDatabaseID: String? = nil, recordID: String? = nil, sourceTitle: String = "", sourceStatus: String? = nil) {
        let matches = data.workspaceAutomations.filter { automation in
            guard automation.enabled, automation.trigger == trigger else { return false }
            if let requiredDB = automation.sourceDatabaseID, !requiredDB.isEmpty, requiredDB != sourceDatabaseID { return false }
            if let requiredStatus = automation.matchStatus, !requiredStatus.isEmpty, requiredStatus != sourceStatus { return false }
            return true
        }
        if !matches.isEmpty {
            performTimelineTransaction(label: "Workspace automations") {
                for automation in matches {
                    executeWorkspaceAutomation(automation, sourceDatabaseID: sourceDatabaseID, recordID: recordID, sourceTitle: sourceTitle, sourceStatus: sourceStatus)
                }
            }
        }
        runWorkspaceCustomAgents(trigger: trigger, sourceDatabaseID: sourceDatabaseID, recordID: recordID, sourceTitle: sourceTitle, sourceStatus: sourceStatus)
    }

    func runScheduledWorkspaceAutomationsIfNeeded(now: Date = .now) {
        let today = DateKey.string(now)
        let weekKey = DateKey.string(TimelineDateMath.startOfWeek(containing: now))
        let scheduled = data.workspaceAutomations.filter { $0.enabled && ($0.trigger == .daily || $0.trigger == .weekly) }
        let dueAutomations = scheduled.filter { automation in
            let lastDate = automation.lastRunAt.flatMap { ISO8601DateFormatter().date(from: $0) }
            let alreadyRan: Bool
            if automation.trigger == .daily {
                alreadyRan = lastDate.map { DateKey.string($0) == today } ?? false
            } else {
                alreadyRan = lastDate.map { DateKey.string(TimelineDateMath.startOfWeek(containing: $0)) == weekKey } ?? false
            }
            return !alreadyRan
        }
        if !dueAutomations.isEmpty {
            performTimelineTransaction(label: "Scheduled Workspace automations") {
                for automation in dueAutomations {
                    executeWorkspaceAutomation(automation, sourceDatabaseID: automation.sourceDatabaseID, recordID: nil, sourceTitle: automation.title, sourceStatus: nil)
                }
            }
        }

        let agents = data.workspaceCustomAgents.filter { $0.enabled && ($0.trigger == .daily || $0.trigger == .weekly) }
        for agent in agents {
            let lastDate = agent.lastRunAt.flatMap { ISO8601DateFormatter().date(from: $0) }
            let alreadyRan = agent.trigger == .daily
                ? (lastDate.map { DateKey.string($0) == today } ?? false)
                : (lastDate.map { DateKey.string(TimelineDateMath.startOfWeek(containing: $0)) == weekKey } ?? false)
            guard !alreadyRan, !runningCustomAgentIDs.contains(agent.id) else { continue }
            Task { _ = await self.runWorkspaceCustomAgent(agent.id, eventContext: agent.trigger == .daily ? "Daily scheduled run for \(today)." : "Weekly scheduled run for week \(weekKey).") }
        }
    }

    private func runWorkspaceCustomAgents(trigger: WorkspaceAutomationTrigger, sourceDatabaseID: String?, recordID: String?, sourceTitle: String, sourceStatus: String?) {
        let agents = data.workspaceCustomAgents.filter { $0.enabled && $0.trigger == trigger }
        guard !agents.isEmpty else { return }
        let context = [
            sourceTitle.isEmpty ? nil : "Source title: \(sourceTitle)",
            sourceStatus.map { "Source status: \($0)" },
            sourceDatabaseID.map { "Database ID: \($0)" },
            recordID.map { "Record ID: \($0)" }
        ].compactMap { $0 }.joined(separator: "\n")
        for agent in agents where !runningCustomAgentIDs.contains(agent.id) {
            Task { _ = await self.runWorkspaceCustomAgent(agent.id, eventContext: context.isEmpty ? "Triggered by \(trigger.rawValue)." : "Triggered by \(trigger.rawValue).\n\(context)") }
        }
    }

    private func executeWorkspaceAutomation(_ automation: WorkspaceAutomation, sourceDatabaseID: String?, recordID: String?, sourceTitle: String, sourceStatus: String?) {
        let title = automation.templateTitle.isEmpty ? (sourceTitle.isEmpty ? automation.title : sourceTitle) : automation.templateTitle.replacingOccurrences(of: "{{title}}", with: sourceTitle)
        let body = automation.templateBody.replacingOccurrences(of: "{{title}}", with: sourceTitle).replacingOccurrences(of: "{{status}}", with: sourceStatus ?? "")
        switch automation.action {
        case .createTask:
            var task = PlanEngine.manualTask(title: title, date: selectedDate)
            task.note = body.isEmpty ? nil : body
            task.source = .notes
            addTask(task)
        case .addInbox:
            addInbox(title)
        case .createPage:
            saveWorkspacePage(WorkspacePage(title: title, body: body))
        case .createRecord:
            if let target = automation.targetDatabaseID ?? sourceDatabaseID, data.workspaceDatabases.contains(where: { $0.id == target }) {
                addWorkspaceRecord(databaseID: target, record: WorkspaceRecord(title: title, note: body), triggerAutomations: false)
            }
        case .markRecordDone:
            if let databaseID = sourceDatabaseID, let recordID {
                updateWorkspaceRecord(databaseID: databaseID, recordID: recordID, triggerAutomations: false) { $0.status = "Done"; $0.progress = 100 }
            }
        }
        if let i = data.workspaceAutomations.firstIndex(where: { $0.id == automation.id }) {
            data.workspaceAutomations[i].runCount += 1
            data.workspaceAutomations[i].lastRunAt = ISO8601DateFormatter().string(from: .now)
            persist()
        }
    }

    func addWorkspaceProperty(databaseID: String, definition: WorkspacePropertyDefinition) {
        guard let i = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }) else { return }
        var properties = data.workspaceDatabases[i].properties ?? []
        properties.append(definition)
        data.workspaceDatabases[i].properties = properties
        data.workspaceDatabases[i].updatedAt = ISO8601DateFormatter().string(from: .now)
        persist()
    }

    func deleteWorkspaceProperty(databaseID: String, propertyID: String) {
        guard let i = data.workspaceDatabases.firstIndex(where: { $0.id == databaseID }) else { return }
        let name = data.workspaceDatabases[i].properties?.first(where: { $0.id == propertyID })?.name
        data.workspaceDatabases[i].properties?.removeAll { $0.id == propertyID }
        if let name {
            for r in data.workspaceDatabases[i].records.indices { data.workspaceDatabases[i].records[r].properties?.removeValue(forKey: name) }
        }
        persist()
    }

    func saveWorkspaceMeeting(_ meeting: WorkspaceMeetingNote) {
        if let i = data.workspaceMeetings.firstIndex(where: { $0.id == meeting.id }) { data.workspaceMeetings[i] = meeting } else { data.workspaceMeetings.append(meeting) }
        record("workspace-meeting-saved", meeting.title); persist()
    }

    func deleteWorkspaceMeeting(_ id: String) { data.workspaceMeetings.removeAll { $0.id == id }; persist() }

    func turnMeetingActionsIntoTasks(_ meetingID: String) {
        guard let meeting = data.workspaceMeetings.first(where: { $0.id == meetingID }) else { return }
        for item in meeting.actionItems where !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var task = PlanEngine.manualTask(title: item, date: meeting.date)
            task.note = "From meeting: \(meeting.title)"
            task.source = .notes
            addTask(task)
        }
    }

    func saveWorkspaceSchedulingLink(_ link: WorkspaceSchedulingLink) {
        if let i = data.workspaceSchedulingLinks.firstIndex(where: { $0.id == link.id }) { data.workspaceSchedulingLinks[i] = link } else { data.workspaceSchedulingLinks.append(link) }
        persist()
    }

    func deleteWorkspaceSchedulingLink(_ id: String) { data.workspaceSchedulingLinks.removeAll { $0.id == id }; persist() }

    func saveWorkspaceSmartMeeting(_ meeting: WorkspaceSmartMeeting) {
        if let i = data.workspaceSmartMeetings.firstIndex(where: { $0.id == meeting.id }) { data.workspaceSmartMeetings[i] = meeting } else { data.workspaceSmartMeetings.append(meeting) }
        persist()
    }

    func deleteWorkspaceSmartMeeting(_ id: String) { data.workspaceSmartMeetings.removeAll { $0.id == id }; persist() }

    @discardableResult
    func scheduleWorkspaceSmartMeeting(_ meeting: WorkspaceSmartMeeting, from startDate: Date = .now) -> Bool {
        let existing = data.plans.flatMap(\.tasks).contains { task in
            task.status != .skipped && task.title == meeting.title && (task.note?.hasPrefix("Smart Meeting") ?? false) && task.planDate >= DateKey.string(startDate)
        }
        if existing { return false }
        let calendar = Calendar.current
        let weekday = max(1, min(7, meeting.preferredWeekday))
        for offset in 0..<21 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDate), calendar.component(.weekday, from: day) == weekday else { continue }
            let dateKey = DateKey.string(day)
            let windowStart = TimeMath.minutes(meeting.windowStart) ?? 9 * 60
            let windowEnd = TimeMath.minutes(meeting.windowEnd) ?? 17 * 60
            let occupied = data.plans.first(where: { $0.date == dateKey })?.tasks.compactMap { task -> (Int, Int)? in
                guard task.status != .skipped, let start = TimeMath.minutes(task.startTime) else { return nil }
                return (start, start + max(5, task.durationMinutes) + timelineBuffer(for: task))
            }.sorted { $0.0 < $1.0 } ?? []
            var cursor = windowStart
            for interval in occupied {
                if cursor + meeting.durationMinutes <= interval.0 { break }
                cursor = max(cursor, interval.1)
            }
            if cursor + meeting.durationMinutes <= windowEnd {
                var task = PlanEngine.manualTask(title: meeting.title, date: dateKey)
                task.startTime = TimeMath.string(cursor)
                task.endTime = TimeMath.string(cursor + meeting.durationMinutes)
                task.durationMinutes = meeting.durationMinutes
                task.category = .work
                task.note = meeting.attendees.isEmpty ? "Smart Meeting" : "Smart Meeting · \(meeting.attendees.joined(separator: ", "))"
                task.timelineLocked = true
                task.flexible = meeting.autoReschedule
                addTask(task)
                return true
            }
        }
        return false
    }

    func saveWorkspaceForm(_ form: WorkspaceForm) {
        if let i = data.workspaceForms.firstIndex(where: { $0.id == form.id }) { data.workspaceForms[i] = form } else { data.workspaceForms.append(form) }
        persist()
    }

    func deleteWorkspaceForm(_ id: String) { data.workspaceForms.removeAll { $0.id == id }; persist() }

    func saveWorkspaceSavedSearch(_ search: WorkspaceSavedSearch) {
        if let i = data.workspaceSavedSearches.firstIndex(where: { $0.id == search.id }) { data.workspaceSavedSearches[i] = search } else { data.workspaceSavedSearches.append(search) }
        persist()
    }

    func deleteWorkspaceSavedSearch(_ id: String) { data.workspaceSavedSearches.removeAll { $0.id == id }; persist() }

    func restoreWorkspacePageVersion(_ versionID: String) {
        guard let version = data.workspacePageVersions.first(where: { $0.id == versionID }),
              var page = data.workspacePages.first(where: { $0.id == version.pageID }) else { return }
        page.title = version.title
        page.body = version.body
        page.tags = version.tags
        saveWorkspacePage(page)
        record("workspace-version-restored", page.title)
    }

    func addWorkspaceComment(pageID: String, text: String, author: String = "You") {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, data.workspacePages.contains(where: { $0.id == pageID }) else { return }
        data.workspaceComments.append(WorkspaceComment(pageID: pageID, author: author, text: value))
        record("workspace-comment-added", value); persist()
    }

    func resolveWorkspaceComment(_ id: String, resolved: Bool = true) {
        guard let i = data.workspaceComments.firstIndex(where: { $0.id == id }) else { return }
        data.workspaceComments[i].resolved = resolved
        record("workspace-comment-\(resolved ? "resolved" : "reopened")", data.workspaceComments[i].text); persist()
    }

    func deleteWorkspaceComment(_ id: String) {
        data.workspaceComments.removeAll { $0.id == id }; persist()
    }

    func saveWorkspaceClip(_ clip: WorkspaceClip) {
        if let i = data.workspaceClips.firstIndex(where: { $0.id == clip.id }) { data.workspaceClips[i] = clip } else { data.workspaceClips.append(clip) }
        record("workspace-clip-saved", clip.title); persist()
    }

    func deleteWorkspaceClip(_ id: String) { data.workspaceClips.removeAll { $0.id == id }; persist() }

    @discardableResult
    func workspaceClipToPage(_ id: String) -> WorkspacePage? {
        guard let clip = data.workspaceClips.first(where: { $0.id == id }) else { return nil }
        let body = "# \(clip.title)\n\n" + (clip.url.isEmpty ? "" : "Source: \(clip.url)\n\n") + clip.note
        let page = WorkspacePage(title: clip.title, body: body, icon: "bookmark.fill", tags: Array(Set(clip.tags + ["clip"])))
        saveWorkspacePage(page)
        return page
    }

    func saveWorkspaceSite(_ site: WorkspaceSite) {
        if let i = data.workspaceSites.firstIndex(where: { $0.id == site.id }) { data.workspaceSites[i] = site } else { data.workspaceSites.append(site) }
        record("workspace-site-saved", site.title); persist()
    }

    func deleteWorkspaceSite(_ id: String) { data.workspaceSites.removeAll { $0.id == id }; persist() }

    func startWorkspaceTimer(title: String, category: TaskCategory = .focus, projectID: String? = nil, taskID: String? = nil) {
        guard data.workspaceTimeEntries.contains(where: { $0.endedAt == nil }) == false else { return }
        data.workspaceTimeEntries.append(WorkspaceTimeEntry(title: title, category: category, projectID: projectID, taskID: taskID))
        record("workspace-timer-started", title); persist()
    }

    func stopWorkspaceTimer() {
        guard let i = data.workspaceTimeEntries.lastIndex(where: { $0.endedAt == nil }),
              let started = ISO8601DateFormatter().date(from: data.workspaceTimeEntries[i].startedAt) else { return }
        let end = Date()
        data.workspaceTimeEntries[i].endedAt = ISO8601DateFormatter().string(from: end)
        data.workspaceTimeEntries[i].durationMinutes = max(1, Int(end.timeIntervalSince(started) / 60.0))
        record("workspace-timer-stopped", data.workspaceTimeEntries[i].title); persist()
    }

    func deleteWorkspaceTimeEntry(_ id: String) { data.workspaceTimeEntries.removeAll { $0.id == id }; persist() }

    func saveWorkspaceCustomAgent(_ agent: WorkspaceCustomAgent) {
        if let i = data.workspaceCustomAgents.firstIndex(where: { $0.id == agent.id }) { data.workspaceCustomAgents[i] = agent } else { data.workspaceCustomAgents.append(agent) }
        record("workspace-agent-saved", agent.title); persist()
    }

    func deleteWorkspaceCustomAgent(_ id: String) { data.workspaceCustomAgents.removeAll { $0.id == id }; persist() }

    @discardableResult
    func runWorkspacePageAI(_ pageID: String, instruction: String) async -> String {
        guard let page = data.workspacePages.first(where: { $0.id == pageID }), !page.archived else { return "Page not found." }
        guard page.locked != true else { return "This page is locked. Unlock it before running Page AI." }
        if !hasAccess(.fullAI) && !SubscriptionService.shared.consumeFreePlanningAIRequest() {
            return "Daily Free AI limit reached. Planning Pro unlocks unlimited page AI."
        }
        var agentContext = data
        agentContext.settings.aiAssistantMode = .workspace
        let request = "Page-specific Workspace AI operation. Target page ID: \(page.id). Target page title: \(page.title). User instruction: \(instruction). Use update_workspace_page when the page itself should change. When extracting actions, create the smallest correct tasks/projects and preserve unrelated content."
        let payload = await AIService.shared.coachReply(
            message: request,
            conversationId: "workspace-page-ai-\(pageID)",
            selectedDate: selectedDate,
            context: agentContext,
            health: healthSnapshot
        )
        stageCoachActions(payload.actions, source: "Page AI · \(page.title)")
        record("workspace-page-ai", "\(page.title) · \(payload.actions.count) proposed action(s)"); persist()
        return payload.actions.isEmpty ? payload.reply : payload.reply + "\n\nReview the proposed changes below before applying them."
    }

    @discardableResult
    func runWorkspaceCustomAgent(_ id: String, eventContext: String? = nil) async -> String {
        guard let i = data.workspaceCustomAgents.firstIndex(where: { $0.id == id }), data.workspaceCustomAgents[i].enabled else { return "Agent is disabled." }
        guard !runningCustomAgentIDs.contains(id) else { return "Agent is already running." }
        if !hasAccess(.fullAI) && !SubscriptionService.shared.consumeFreePlanningAIRequest() {
            return "Daily Free AI limit reached. Planning Pro unlocks unlimited agent runs."
        }
        runningCustomAgentIDs.insert(id)
        defer { runningCustomAgentIDs.remove(id) }

        let agent = data.workspaceCustomAgents[i]
        let triggerContext = eventContext.map { "\nTrigger context:\n\($0)" } ?? ""
        let request = "Custom Workspace Agent: \(agent.title)\nScope: \(agent.scope.rawValue)\nInstructions: \(agent.instructions)\(triggerContext)\nExecute the instructions against the current app state. Preserve unrelated data and use app actions when useful."
        var agentContext = data
        agentContext.settings.aiAssistantMode = .workspace
        let payload = await AIService.shared.coachReply(
            message: request,
            conversationId: "workspace-custom-agent-\(id)",
            selectedDate: selectedDate,
            context: agentContext,
            health: healthSnapshot
        )
        stageCoachActions(payload.actions, source: "Agent · \(agent.title)")
        if let refreshed = data.workspaceCustomAgents.firstIndex(where: { $0.id == id }) {
            data.workspaceCustomAgents[refreshed].runCount += 1
            data.workspaceCustomAgents[refreshed].lastRunAt = ISO8601DateFormatter().string(from: .now)
        }
        record("workspace-agent-ran", "\(agent.title) · \(payload.actions.count) proposed action(s)"); persist()
        return payload.actions.isEmpty ? payload.reply : payload.reply + "\n\nReview the proposed changes before applying them."
    }

    func workspaceMarkdownExport() -> String {
        var sections: [String] = ["# Planning Workspace Export", "Generated \(ISO8601DateFormatter().string(from: .now))"]
        for page in data.workspacePages.filter({ !$0.archived }) {
            sections.append("\n---\n\n# \(page.title)\n\n\(page.body)\n\nTags: \(page.tags.joined(separator: ", "))")
        }
        if !data.workspaceProjects.isEmpty {
            sections.append("\n---\n\n# Projects\n" + data.workspaceProjects.filter { !$0.archived }.map { "- \($0.title) · \($0.status.label) · \($0.progress)%" }.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n")
    }

    func workspaceJSONExport() -> String {
        struct Export: Codable {
            let pages: [WorkspacePage]; let databases: [WorkspaceDatabase]; let canvases: [WorkspaceCanvas]; let projects: [WorkspaceProject]
            let clips: [WorkspaceClip]; let sites: [WorkspaceSite]; let comments: [WorkspaceComment]; let exportedAt: String
        }
        let payload = Export(pages: data.workspacePages, databases: data.workspaceDatabases, canvases: data.workspaceCanvases, projects: data.workspaceProjects, clips: data.workspaceClips, sites: data.workspaceSites, comments: data.workspaceComments, exportedAt: ISO8601DateFormatter().string(from: .now))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(payload) else { return "{}" }
        return String(data: encoded, encoding: .utf8) ?? "{}"
    }

    func importWorkspaceMarkdown(title: String, markdown: String, tags: [String] = ["imported"]) {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveWorkspacePage(WorkspacePage(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported page" : title, body: trimmed, icon: "square.and.arrow.down.fill", tags: tags))
        record("workspace-import", title)
    }

    func updateWorkspaceTimePolicy(_ body: (inout WorkspaceTimePolicy) -> Void) {
        let previous = data.workspaceTimePolicy
        body(&data.workspaceTimePolicy)
        data.workspaceTimePolicy.weeklyFocusGoalMinutes = min(2400, max(0, data.workspaceTimePolicy.weeklyFocusGoalMinutes))
        data.workspaceTimePolicy.minimumFocusBlockMinutes = min(240, max(15, data.workspaceTimePolicy.minimumFocusBlockMinutes))
        data.workspaceTimePolicy.preferredFocusBlockMinutes = min(240, max(data.workspaceTimePolicy.minimumFocusBlockMinutes, data.workspaceTimePolicy.preferredFocusBlockMinutes))
        data.workspaceTimePolicy.breakMinutes = min(60, max(0, data.workspaceTimePolicy.breakMinutes))
        data.workspaceTimePolicy.noMeetingWeekdays = Array(Set(data.workspaceTimePolicy.noMeetingWeekdays.filter { (1...7).contains($0) })).sorted()
        for key in [\WorkspaceTimePolicy.workHoursStart, \.workHoursEnd, \.meetingHoursStart, \.meetingHoursEnd] {
            if TimeMath.minutes(data.workspaceTimePolicy[keyPath: key]) == nil { data.workspaceTimePolicy[keyPath: key] = previous[keyPath: key] }
        }
        persist()
    }

    @discardableResult
    func autoScheduleWorkspaceProject(_ projectID: String, from startDate: Date = .now) -> Int {
        guard var project = data.workspaceProjects.first(where: { $0.id == projectID }), !project.archived else { return 0 }
        let candidateTasks: [PlannerTask] = data.plans.flatMap(\.tasks).filter { task in
            let belongsToProject = task.projectID == projectID || project.taskIDs.contains(task.id)
            let isOpen = task.status == .pending || task.status == .active
            return belongsToProject && isOpen && task.externalSource == nil && task.flexible != false
        }
        let candidateIDs = candidateTasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            let lhsDate: String = lhs.deadline ?? lhs.planDate
            let rhsDate: String = rhs.deadline ?? rhs.planDate
            return lhsDate < rhsDate
        }.map(\.id)
        guard !candidateIDs.isEmpty else { return 0 }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let deadlineDay = project.deadline.flatMap(DateKey.date) ?? calendar.date(byAdding: .day, value: 30, to: startDay)!
        let maxDays = max(1, min(60, (calendar.dateComponents([.day], from: startDay, to: deadlineDay).day ?? 30) + 1))
        let workStart = TimeMath.minutes(data.workspaceTimePolicy.workHoursStart) ?? 8 * 60
        let workEnd = TimeMath.minutes(data.workspaceTimePolicy.workHoursEnd) ?? 18 * 60
        var moved = 0
        for taskID in candidateIDs {
            guard let task = findTask(taskID) else { continue }
            let duration = max(5, task.durationMinutes)
            var placed = false
            for offset in 0..<maxDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                if data.workspaceTimePolicy.protectPersonalTime && (weekday == 1 || weekday == 7) { continue }
                let key = DateKey.string(day)
                let occupied = data.plans.first(where: { $0.date == key })?.tasks.compactMap { existing -> (Int, Int)? in
                    guard existing.id != taskID, existing.status != .skipped, let start = TimeMath.minutes(existing.startTime) else { return nil }
                    return (start, start + max(5, existing.durationMinutes) + timelineBuffer(for: existing))
                }.sorted { $0.0 < $1.0 } ?? []
                var cursor = workStart
                for interval in occupied {
                    if cursor + duration <= interval.0 { break }
                    cursor = max(cursor, interval.1)
                }
                guard cursor + duration <= workEnd else { continue }
                moveTask(taskID, toDate: key, startTime: TimeMath.string(cursor))
                moved += 1
                placed = true
                break
            }
            if !placed { record("project-autoschedule-unplaced", task.title) }
        }
        let allProjectTasks = data.plans.flatMap(\.tasks).filter { $0.projectID == projectID || project.taskIDs.contains($0.id) }
        if !allProjectTasks.isEmpty {
            let completed = allProjectTasks.filter { $0.status == .completed }.count
            project.progress = Int((Double(completed) / Double(allProjectTasks.count) * 100).rounded())
            if project.progress >= 100 { project.status = .done }
            else if project.status == .planned { project.status = .active }
            saveWorkspaceProject(project)
        }
        if moved > 0 { record("workspace-project-autoscheduled", "\(project.title) · \(moved) task(s)"); persist() }
        return moved
    }

    @discardableResult
    func scheduleHabitTimeBlocks(days: Int = 7, from startDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let boundedDays = max(1, min(30, days))
        var created = 0
        for offset in 0..<boundedDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let date = DateKey.string(day)
            for habit in data.habits {
                guard let time = habit.reminderTime, !time.isEmpty else { continue }
                let marker = "habit:\(habit.id)"
                let exists = data.plans.first(where: { $0.date == date })?.tasks.contains(where: { $0.source == .habit && $0.note == marker }) ?? false
                guard !exists else { continue }
                var task = PlanEngine.manualTask(title: habit.title, date: date)
                task.startTime = time
                task.durationMinutes = 20
                task.category = .life
                task.source = .habit
                task.note = marker
                task.flexible = true
                addTask(task)
                created += 1
            }
        }
        if created > 0 { record("habit-time-blocks-created", "\(created) block(s)"); persist() }
        return created
    }

    @discardableResult
    func runWorkspaceAutopilot(containing date: Date = .now) -> Int {
        let monday = TimelineDateMath.startOfWeek(containing: date)
        var changes = protectWeeklyFocus(containing: date)
        for project in data.workspaceProjects where project.autoSchedule && !project.archived && project.status != .done {
            changes += autoScheduleWorkspaceProject(project.id, from: date)
        }
        changes += scheduleHabitTimeBlocks(days: 7, from: monday)
        for meeting in data.workspaceSmartMeetings { if scheduleWorkspaceSmartMeeting(meeting, from: monday) { changes += 1 } }
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: monday) else { continue }
            let key = DateKey.string(day)
            changes += applyBufferGuard(on: key, minimumMinutes: max(5, data.workspaceTimePolicy.breakMinutes))
            changes += repairTimelineConflicts(on: key)

            // Planning Intelligence is data-level, not renderer-level: every adjustment below
            // is reflected identically in Horizontal and Vertical timelines.
            if data.settings.timelineEnergyFitEnabled == true { changes += applyEnergyFit(on: key) }
            if data.settings.timelineOverloadGuardEnabled == true { changes += applyOverloadGuard(on: key) }
            if data.settings.timelineContextBatchingEnabled == true { changes += batchContexts(on: key) }
            if data.settings.timelineTravelBufferEnabled == true { changes += applyTravelBuffer(on: key) }
            if data.settings.timelineFocusBudgetEnabled == true { changes += protectFocusBudget(on: key) }
            if data.settings.timelineMeetingDefragEnabled == true { changes += defragMeetings(on: key) }
            if data.settings.timelineMomentumChainEnabled == true { changes += buildMomentumChain(on: key) }
            if data.settings.timelineDeadlineBackplanEnabled == true { changes += backplanDeadlines(on: key) }
            if data.settings.timelineHabitRescueEnabled == true { changes += rescueHabits(on: key) }
            if data.settings.timelineNoMeetingGuardEnabled == true { changes += applyNoMeetingGuard(on: key) }
            if data.settings.timelineDeepWorkReserveEnabled == true { changes += reserveDeepWork(on: key) }
            if data.settings.timelineContextSwitchShieldEnabled == true { changes += applyContextSwitchShield(on: key) }
        }
        if changes > 0 { record("workspace-autopilot", "\(changes) scheduling adjustment(s)"); persist() }
        return changes
    }

    @discardableResult
    func protectWeeklyFocus(containing date: Date = .now) -> Int {
        let monday = TimelineDateMath.startOfWeek(containing: date)
        let target = max(0, data.workspaceTimePolicy.weeklyFocusGoalMinutes)
        let block = max(data.workspaceTimePolicy.minimumFocusBlockMinutes, data.workspaceTimePolicy.preferredFocusBlockMinutes)
        let existing = (0..<7).reduce(0) { partial, offset in
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: monday) else { return partial }
            let key = DateKey.string(day)
            return partial + (data.plans.first(where: { $0.date == key })?.tasks.filter { $0.category == .focus && $0.status != .skipped }.reduce(0) { $0 + $1.durationMinutes } ?? 0)
        }
        var remaining = max(0, target - existing)
        var created = 0
        for offset in 0..<7 where remaining > 0 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: monday) else { continue }
            let weekday = Calendar.current.component(.weekday, from: day)
            if data.workspaceTimePolicy.noMeetingWeekdays.contains(weekday) == false && (weekday == 1 || weekday == 7) { continue }
            let key = DateKey.string(day)
            let startWindow = TimeMath.minutes(data.workspaceTimePolicy.workHoursStart) ?? 8 * 60
            let endWindow = TimeMath.minutes(data.workspaceTimePolicy.workHoursEnd) ?? 18 * 60
            let duration = min(block, remaining)
            let occupied = data.plans.first(where: { $0.date == key })?.tasks.compactMap { task -> (Int, Int)? in
                guard task.status != .skipped, let start = TimeMath.minutes(task.startTime) else { return nil }
                return (start, start + max(5, task.durationMinutes) + timelineBuffer(for: task))
            }.sorted { $0.0 < $1.0 } ?? []
            var cursor = startWindow
            for interval in occupied {
                if cursor + duration <= interval.0 { break }
                cursor = max(cursor, interval.1)
            }
            guard cursor + duration <= endWindow else { continue }
            var focus = PlanEngine.manualTask(title: "Focus time", date: key)
            focus.startTime = TimeMath.string(cursor)
            focus.endTime = TimeMath.string(cursor + duration)
            focus.durationMinutes = duration
            focus.category = .focus
            focus.priority = 1
            focus.note = "Protected weekly focus goal"
            focus.timelineLocked = true
            addTask(focus)
            remaining -= duration
            created += 1
        }
        if created > 0 { record("workspace-focus-protected", "\(created) block(s)"); persist() }
        return created
    }

    @discardableResult
    func buildWorkspaceAgenda(for date: String = DateKey.today) -> WorkspacePage {
        let tasks = data.plans.first(where: { $0.date == date })?.tasks ?? []
        let today = TaskTimelineOrder.sorted(tasks.filter { $0.status == .pending || $0.status == .active })
        let overdue = data.plans.flatMap(\.tasks).filter { ($0.status == .pending || $0.status == .active) && $0.planDate < date }
        let todayLines: String
        if today.isEmpty {
            todayLines = "- Nothing scheduled"
        } else {
            todayLines = today.map { task in
                let timePrefix = task.startTime.map { "\($0) · " } ?? ""
                return "- [ ] \(timePrefix)\(task.title)"
            }.joined(separator: "\n")
        }

        let overdueLines: String
        if overdue.isEmpty {
            overdueLines = "- Clear"
        } else {
            overdueLines = overdue.prefix(12).map { task in
                "- [ ] \(task.title) · \(task.planDate)"
            }.joined(separator: "\n")
        }

        let inboxLines: String
        if data.inbox.isEmpty {
            inboxLines = "- Clear"
        } else {
            inboxLines = data.inbox.prefix(12).map { item in
                "- \(item.title)"
            }.joined(separator: "\n")
        }

        let body = "# Agenda · \(date)\n\n## Today's tasks\n\(todayLines)\n\n## Past due\n\(overdueLines)\n\n## Inbox\n\(inboxLines)"
        let page = WorkspacePage(title: "Agenda · \(date)", body: body, icon: "list.bullet.clipboard.fill", tags: ["agenda", date])
        saveWorkspacePage(page)
        return page
    }

    @discardableResult
    func openOrCreateDailyNote(for date: String = DateKey.today) -> WorkspacePage {
        if let existing = data.workspacePages.first(where: { !$0.archived && $0.tags.contains("daily") && $0.tags.contains(date) }) { return existing }
        let page = WorkspacePage(title: date, body: "# \(date)\n\n## Priorities\n\n## Notes\n\n## Decisions\n\n## Tomorrow\n", icon: "sun.max.fill", tags: ["daily", date])
        saveWorkspacePage(page)
        return page
    }

    private func applyAgentSetting(key: String, value: String?, boolValue: Bool?, intValue: Int?) {
        // Agent control deliberately excludes subscription, authentication, account deletion and secrets.
        if key == "experienceMode", let value, let mode = AppExperienceMode(rawValue: value) {
            setExperienceMode(mode)
            return
        }
        if key == "globalMemoryEnabled", let boolValue {
            setGlobalMemoryEnabled(boolValue)
            return
        }
        if key.hasPrefix("timePolicy.") {
            let policyKey = String(key.dropFirst("timePolicy.".count))
            updateWorkspaceTimePolicy { policy in
                switch policyKey {
                case "weeklyFocusGoalMinutes": if let intValue { policy.weeklyFocusGoalMinutes = max(0, intValue) }
                case "minimumFocusBlockMinutes": if let intValue { policy.minimumFocusBlockMinutes = max(15, intValue) }
                case "preferredFocusBlockMinutes": if let intValue { policy.preferredFocusBlockMinutes = max(15, intValue) }
                case "breakMinutes": if let intValue { policy.breakMinutes = max(0, intValue) }
                case "workHoursStart": if let value, !value.isEmpty { policy.workHoursStart = value }
                case "workHoursEnd": if let value, !value.isEmpty { policy.workHoursEnd = value }
                case "meetingHoursStart": if let value, !value.isEmpty { policy.meetingHoursStart = value }
                case "meetingHoursEnd": if let value, !value.isEmpty { policy.meetingHoursEnd = value }
                case "autoScheduleBreaks": if let boolValue { policy.autoScheduleBreaks = boolValue }
                case "protectPersonalTime": if let boolValue { policy.protectPersonalTime = boolValue }
                case "noMeetingWeekdays": if let value { policy.noMeetingWeekdays = value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (1...7).contains($0) } }
                default: break
                }
            }
            return
        }
        updateSettings { settings in
            switch key {
            case "coachMode": if let value, let parsed = CoachMode(rawValue: value) { settings.coachMode = parsed }
            case "accountability": if let value, let parsed = AccountabilityLevel(rawValue: value) { settings.accountability = parsed }
            case "language": if let value, let parsed = AppLanguage(rawValue: value) { settings.language = parsed }
            case "theme": if let value, let parsed = ThemeMode(rawValue: value) { settings.theme = parsed }
            case "accentTheme": if let value, let parsed = AccentTheme(rawValue: value) { settings.accentTheme = parsed }
            case "customAccentEnabled": if let boolValue { settings.customAccentEnabled = boolValue }
            case "customAccentHue": if let intValue { settings.customAccentHue = Double(min(360, max(0, intValue))) }
            case "customAccentSaturation": if let intValue { settings.customAccentSaturation = Double(min(100, max(0, intValue))) }
            case "customAccentLightness": if let intValue { settings.customAccentLightness = Double(min(100, max(0, intValue))) }
            case "canvasTheme": if let value, let parsed = CanvasTheme(rawValue: value) { settings.canvasTheme = parsed }
            case "visualEnergy": if let value, let parsed = VisualEnergy(rawValue: value) { settings.visualEnergy = parsed }
            case "fontScale": if let value, let parsed = FontScaleMode(rawValue: value) { settings.fontScale = parsed }
            case "fontDesign": if let value, let parsed = AppFontDesign(rawValue: value) { settings.fontDesign = parsed }
            case "notificationsEnabled": if let boolValue { settings.notificationsEnabled = boolValue }
            case "taskReminders": if let boolValue { settings.taskReminders = boolValue }
            case "eveningReview": if let boolValue { settings.eveningReview = boolValue }
            case "eveningReviewTime": if let value { settings.eveningReviewTime = value.isEmpty ? nil : value }
            case "morningPlanningReminder": if let boolValue { settings.morningPlanningReminder = boolValue }
            case "morningPlanningTime": if let value { settings.morningPlanningTime = value.isEmpty ? nil : value }
            case "overdueReminder": if let boolValue { settings.overdueReminder = boolValue }
            case "quietHoursStart": if let value, !value.isEmpty { settings.quietHoursStart = value }
            case "quietHoursEnd": if let value, !value.isEmpty { settings.quietHoursEnd = value }
            case "safeMode": if let boolValue { settings.safeMode = boolValue }
            case "autoLearn": if let boolValue { settings.autoLearn = boolValue }
            case "aiAssistantMode": if let value, let parsed = AIAssistantMode(rawValue: value) { settings.aiAssistantMode = parsed }
            case "studyExplanationLevel": if let value, let parsed = StudyExplanationLevel(rawValue: value) { settings.studyExplanationLevel = parsed }
            case "studyInteractiveSteps": if let boolValue { settings.studyInteractiveSteps = boolValue }
            case "studyVisualizations": if let boolValue { settings.studyVisualizations = boolValue }
            case "studyCheckYourself": if let boolValue { settings.studyCheckYourself = boolValue }
            case "calendarSyncEnabled": if let boolValue { settings.calendarSyncEnabled = boolValue }
            case "healthSyncEnabled": if let boolValue { settings.healthSyncEnabled = boolValue }
            case "healthPlanningEnabled": if let boolValue { settings.healthPlanningEnabled = boolValue }
            case "iCloudSyncEnabled": if let boolValue { settings.iCloudSyncEnabled = boolValue }
            case "cloudSyncEnabled": if let boolValue { settings.cloudSyncEnabled = boolValue }
            case "timelineShowDayPath": if let boolValue { settings.timelineShowDayPath = boolValue }
            case "timelineSmartDensity": if let boolValue { settings.timelineSmartDensity = boolValue }
            case "timelineRealityEnabled": if let boolValue { settings.timelineRealityEnabled = boolValue }
            case "timelineGravityEnabled": if let boolValue { settings.timelineGravityEnabled = boolValue }
            case "timelineBufferGuardEnabled": if let boolValue { settings.timelineBufferGuardEnabled = boolValue }
            case "timelineAutoLockEnabled": if let boolValue { settings.timelineAutoLockEnabled = boolValue }
            case "timelineDeadlineRadarEnabled": if let boolValue { settings.timelineDeadlineRadarEnabled = boolValue }
            case "timelineRecoveryBuffersEnabled": if let boolValue { settings.timelineRecoveryBuffersEnabled = boolValue }
            case "timelineConflictSweepEnabled": if let boolValue { settings.timelineConflictSweepEnabled = boolValue }
            case "timelineEnergyFitEnabled": if let boolValue { settings.timelineEnergyFitEnabled = boolValue }
            case "timelineOverloadGuardEnabled": if let boolValue { settings.timelineOverloadGuardEnabled = boolValue }
            case "timelineContextBatchingEnabled": if let boolValue { settings.timelineContextBatchingEnabled = boolValue }
            case "timelineTravelBufferEnabled": if let boolValue { settings.timelineTravelBufferEnabled = boolValue }
            case "timelineFocusBudgetEnabled": if let boolValue { settings.timelineFocusBudgetEnabled = boolValue }
            case "timelineMeetingDefragEnabled": if let boolValue { settings.timelineMeetingDefragEnabled = boolValue }
            case "timelineMomentumChainEnabled": if let boolValue { settings.timelineMomentumChainEnabled = boolValue }
            case "timelineDeadlineBackplanEnabled": if let boolValue { settings.timelineDeadlineBackplanEnabled = boolValue }
            case "timelineHabitRescueEnabled": if let boolValue { settings.timelineHabitRescueEnabled = boolValue }
            case "timelineNoMeetingGuardEnabled": if let boolValue { settings.timelineNoMeetingGuardEnabled = boolValue }
            case "timelineDeepWorkReserveEnabled": if let boolValue { settings.timelineDeepWorkReserveEnabled = boolValue }
            case "timelineContextSwitchShieldEnabled": if let boolValue { settings.timelineContextSwitchShieldEnabled = boolValue }
            case "timelineAutoCompleteElapsedTasks": if let boolValue { settings.timelineAutoCompleteElapsedTasks = boolValue }
            case "timelineSuggestionsEnabled": if let boolValue { settings.timelineSuggestionsEnabled = boolValue }
            case "timelineLayout": if let value, let parsed = TimelineLayoutStyle(rawValue: value), parsed != .orbit { settings.timelineLayout = parsed }
            case "weekTimelineLayout": if let value, let parsed = TimelineLayoutStyle(rawValue: value), parsed != .orbit { settings.weekTimelineLayout = parsed }
            default: break
            }
        }
    }

    private func applyAgentProfile(key: String, value: String?, boolValue: Bool?, intValue: Int?) {
        updateProfile { profile in
            switch key {
            case "name": if let value { profile.name = value }
            case "nickname": if let value { profile.nickname = String(value.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }.prefix(32)) }
            case "category": if let value, let parsed = UserProfile.Category(rawValue: value) { profile.category = parsed }
            case "primaryGoal": if let value { profile.primaryGoal = value }
            case "goalWhy": if let value { profile.goalWhy = value }
            case "struggle": if let value { profile.struggle = value }
            case "wakeTime": if let value, !value.isEmpty { profile.wakeTime = value }
            case "sleepTime": if let value, !value.isEmpty { profile.sleepTime = value }
            case "chronotype": if let value, let parsed = UserProfile.Chronotype(rawValue: value) { profile.chronotype = parsed }
            case "discipline": if let intValue { profile.discipline = min(5, max(1, intValue)) }
            case "fixedCommitments": if let value { profile.fixedCommitments = value }
            case "currentHabits": if let value { profile.currentHabits = value }
            case "productiveHours": if let value { profile.productiveHours = value }
            case "planningPreferences": if let value { profile.planningPreferences = value }
            case "selfDescription": if let value { profile.selfDescription = value }
            case "bodyRhythmEnabled": if let boolValue { profile.bodyRhythmEnabled = boolValue }
            case "cycleStartDate": if let value { profile.cycleStartDate = value }
            case "cycleLengthDays": if let intValue { profile.cycleLengthDays = min(60, max(15, intValue)) }
            case "cyclePeriodDays": if let intValue { profile.cyclePeriodDays = min(14, max(1, intValue)) }
            default: break
            }
        }
    }

    func generateSubtasks(for task: PlannerTask) async -> [TaskSubtask] { await AIService.shared.subtasks(for: task, context: data) }

    func saveNote(_ note: AppNote) { if let i = data.notes.firstIndex(where: { $0.id == note.id }) { data.notes[i] = note } else { data.notes.append(note) }; record("note-added", note.title); persist() }
    func deleteNote(_ id: String) { data.notes.removeAll { $0.id == id }; persist() }
    func addInbox(_ title: String) { data.inbox.append(InboxTask(title: title)); record("inbox-added", title); persist() }
    func deleteInbox(_ id: String) { data.inbox.removeAll { $0.id == id }; persist() }

    func toggleHabit(_ id: String, date: String = DateKey.today) {
        guard let i = data.habits.firstIndex(where: { $0.id == id }) else { return }
        if data.habits[i].completedDates.contains(date) { data.habits[i].completedDates.removeAll { $0 == date } } else { data.habits[i].completedDates.append(date) }
        data.habits[i].currentStreak = calculateStreak(data.habits[i].completedDates); data.habits[i].bestStreak = max(data.habits[i].bestStreak, data.habits[i].currentStreak); persist()
    }

    func updateSettings(_ body: (inout AppSettings) -> Void) {
        let wasHealthEnabled = data.settings.healthSyncEnabled
        body(&data.settings)
        data.settings.soundEffectsEnabled = false
        data.settings.autoCalendarReplan = false
        data.settings.timelineFlowShiftEnabled = false
        persist()
        if wasHealthEnabled != data.settings.healthSyncEnabled {
            Task { await refreshHealthIfNeeded() }
        }
    }

    func setExperienceMode(_ mode: AppExperienceMode) {
        let mode = mode.resolved
        data.settings.experienceMode = mode
        switch mode {
        case .planner:
            if selectedTab == .workspace { selectedTab = .today }
            if data.settings.aiAssistantMode == .workspace { data.settings.aiAssistantMode = .planning }
        case .hybrid, .workspace:
            selectedTab = .workspace
            data.settings.aiAssistantMode = .workspace
        }
        record("experience-mode", mode.rawValue)
        persist()
    }

    func setGlobalMemoryEnabled(_ enabled: Bool) {
        data.settings.globalMemoryEnabled = enabled
        if !enabled { data.settings.autoLearn = false }
        record("memory-mode", enabled ? "enabled" : "disabled")
        persist()
    }

    func updateProfile(_ body: (inout UserProfile) -> Void) { body(&data.profile); persist() }

    func deferOnboarding() {
        data.profile.onboardingCompleted = true
        record("onboarding-deferred", "User chose to complete onboarding later")
        persist()
    }

    func completeOnboarding(_ profile: UserProfile) async {
        var profile = profile
        let analysis = await AIService.shared.analyzeProfile(profile, settings: data.settings)
        profile.aiSummary = analysis.summary
        profile.onboardingCompleted = true
        data.profile = profile
        if data.settings.autoLearn && data.settings.globalMemoryEnabled != false {
            var knownFacts = Set(data.memories.map { $0.fact.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            for fact in analysis.planningRules {
                let key = fact.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty, !knownFacts.contains(key) else { continue }
                data.memories.append(MemoryFact(category: .preference, fact: fact, source: .coach, confidence: 0.85))
                knownFacts.insert(key)
            }
        }
        // Onboarding must never silently create or save a schedule. The user starts with
        // an empty day and can explicitly add tasks or ask AI to build a plan afterward.
        record("profile-analyzed", analysis.summary)
        persist()
    }

    func refreshExternalChanges(force: Bool = false) async {
        if !force, let lastCloudRefreshAt, Date().timeIntervalSince(lastCloudRefreshAt) < 120 { return }
        lastCloudRefreshAt = .now

        let verifiedTier = data.subscription
        // Re-read the compact local snapshot here because Siri/App Intents and extensions can
        // legitimately change it while the app is suspended. This work happens after the UI is
        // already visible and now uses memory-mapped/compact JSON, so correctness is preserved
        // without putting the read on the resume-critical path.
        var candidate = await PersistenceService.shared.load()
        var source = "iCloud"
        if data.settings.cloudSyncEnabled != false,
           SupabaseService.shared.session != nil,
           let remote = await SupabaseService.shared.loadSnapshot() {
            let newest = newestSnapshot(local: candidate, cloud: remote)
            if newest.lastModifiedAt == remote.lastModifiedAt { source = "cross-platform cloud" }
            candidate = newest
        }
        let resolved = newestSnapshot(local: data, cloud: candidate)
        guard resolved != data else { return }
        candidate = resolved
        candidate.subscription = verifiedTier
        candidate.settings.soundEffectsEnabled = false
        candidate.settings.autoCalendarReplan = false
        candidate.settings.timelineFlowShiftEnabled = false
        if candidate.settings.timelineLayout == .orbit { candidate.settings.timelineLayout = .horizontal }
        if candidate.settings.weekTimelineLayout == .orbit { candidate.settings.weekTimelineLayout = .horizontal }
        if candidate.settings.experienceMode == .hybrid { candidate.settings.experienceMode = .workspace }
        data = candidate
        enforceSettingsEntitlements()
        ensureRecurrenceHorizon()
        SharedStateService.publish(data)
        try? await PersistenceService.shared.save(data)
        syncMessage = "Updated from \(source)."
    }

    func eraseAllLocalPlanningData() async {
        await persistenceTask?.value
        let verifiedTier = data.subscription
        var fresh = AppData()
        fresh.subscription = verifiedTier
        fresh.lastModifiedAt = SnapshotClock.stamp(after: data.lastModifiedAt)
        fresh.settings.iCloudSyncEnabled = false
        fresh.settings.cloudSyncEnabled = false
        data = fresh
        healthSnapshot = HealthSnapshot()
        timelineUndoHistory = []
        timelineUndoLabel = nil
        pendingCoachActions = []
        pendingCoachActionSummary = nil
        selectedDate = DateKey.today
        activeConversationId = "default"
        SharedStateService.publish(data)
        try? await PersistenceService.shared.saveLocalSnapshot(data)
        await refreshNotificationSchedules()
        await HealthService.shared.stopBackgroundDelivery()
    }

    func syncNow() async {
        await persistenceTask?.value
        await refreshExternalChanges(force: true)
        let snapshot = data
        do { try await PersistenceService.shared.save(snapshot) }
        catch {
            syncMessage = "The latest changes could not be saved. Please try again."
            return
        }
        if snapshot.settings.cloudSyncEnabled != false, SupabaseService.shared.session != nil {
            let saved = await SupabaseService.shared.saveSnapshot(snapshot)
            syncMessage = saved ? "Local copy saved and account snapshot sent." : "Local copy saved. Account sync could not finish; please retry."
        } else {
            var cloudReady = false
            if snapshot.settings.iCloudSyncEnabled != false {
                cloudReady = await PersistenceService.shared.cloudStatus()
            }
            syncMessage = cloudReady ? "Local copy saved. iCloud sync is handled by the system." : "Local copy saved. iCloud sync is off or unavailable."
        }
    }

    func requestNotificationAccess() async -> Bool {
        let granted = await NotificationService.shared.requestAuthorization()
        data.settings.notificationsEnabled = granted
        await refreshNotificationSchedules()
        persist()
        return granted
    }

    func refreshHealthIfNeeded() async {
        guard data.settings.healthSyncEnabled else {
            healthSnapshot = HealthSnapshot()
            await HealthService.shared.stopBackgroundDelivery()
            return
        }
        guard !healthRefreshInProgress else { return }
        healthRefreshInProgress = true
        defer { healthRefreshInProgress = false }
        await HealthService.shared.startBackgroundDelivery()
        let snapshot = await HealthService.shared.snapshot()
        guard data.settings.healthSyncEnabled else { return }
        healthSnapshot = snapshot
    }

    private func calculateStreak(_ dates: [String]) -> Int {
        let completed = Set(dates); var cursor = Calendar.current.startOfDay(for: .now)
        if !completed.contains(DateKey.string(cursor)) { cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var streak = 0
        while completed.contains(DateKey.string(cursor)) { streak += 1; cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        return streak
    }
}
