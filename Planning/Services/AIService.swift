import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor AIService {
    static let shared = AIService()

    enum Schema: String, Codable { case plan, coach, profile, horizon, subtasks }

    struct Request: Codable {
        var schema: String
        var prompt: String
        var mode: String?
        var accountability: String
        var safeMode: Bool
        var language: String
        var assistantMode: String?
        var studyLevel: String?
        var interactiveSteps: Bool?
        var visualizations: Bool?
        var checkYourself: Bool?
        var memoryEnabled: Bool?
        var experienceMode: String?
        var operation: String?
        var horizon: String?
    }

    struct ServerEnvelope: Codable {
        var content: String?
        var response: String?
        var text: String?
        var error: String?
    }

    private struct BackendPlan: Codable {
        var title: String
        var intention: String
        var planScore: Int
        var coachNote: String
        var tasks: [BackendPlanTask]
    }

    private struct BackendPlanTask: Codable {
        var title: String
        var note: String
        var startTime: String
        var endTime: String
        var durationMinutes: Int
        var section: DaySection
        var category: TaskCategory
        var priority: Int
        var mustWin: Bool
    }

    private struct SubtasksPayload: Codable { var subtasks: [String] }

    private struct HorizonPayload: Codable {
        var title: String
        var summary: String
        var checkpoints: [HorizonCheckpoint]
    }


    private var endpointURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_API_BASE_URL") as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        let allowed: Bool
        if scheme == "https" {
            allowed = true
        } else {
            #if DEBUG
            let host = url.host?.lowercased()
            allowed = scheme == "http" && (host == "localhost" || host == "127.0.0.1")
            #else
            allowed = false
            #endif
        }
        guard allowed else { return nil }

        // A full function URL (for example Supabase Edge Functions) is used as-is.
        // A bare host keeps compatibility with the previous /api/ai backend contract.
        if url.path.isEmpty || url.path == "/" {
            return url.appending(path: "api/ai")
        }
        return url
    }

    private var backendPublicKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func authorize(_ request: inout URLRequest) {
        if let backendPublicKey {
            request.setValue(backendPublicKey, forHTTPHeaderField: "apikey")
        }
    }

    func testConnection() async -> Bool {
        guard let endpointURL else { return false }
        var request = URLRequest(url: endpointURL)
        authorize(&request)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return 200..<300 ~= http.statusCode
    }

    func raw(
        schema: Schema,
        prompt: String,
        settings: AppSettings,
        operation: String? = nil,
        horizon: PlanningHorizon? = nil
    ) async throws -> String {
        guard let endpointURL else { throw URLError(.badURL) }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.timeoutInterval = 35
        request.httpBody = try JSONEncoder().encode(Request(
            schema: schema.rawValue,
            prompt: prompt,
            mode: settings.coachMode.rawValue,
            accountability: settings.accountability.rawValue,
            safeMode: settings.safeMode,
            language: settings.language.rawValue,
            assistantMode: (settings.aiAssistantMode ?? .planning).rawValue,
            studyLevel: (settings.studyExplanationLevel ?? .grade9).rawValue,
            interactiveSteps: settings.studyInteractiveSteps ?? true,
            visualizations: settings.studyVisualizations ?? true,
            checkYourself: settings.studyCheckYourself ?? true,
            memoryEnabled: settings.globalMemoryEnabled != false,
            experienceMode: (settings.experienceMode ?? .planner).rawValue,
            operation: operation,
            horizon: horizon?.rawValue
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            if let envelope = try? JSONDecoder().decode(ServerEnvelope.self, from: data), let error = envelope.error {
                throw NSError(domain: "AIService", code: (response as? HTTPURLResponse)?.statusCode ?? 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            throw URLError(.badServerResponse)
        }
        if let envelope = try? JSONDecoder().decode(ServerEnvelope.self, from: data) {
            if let error = envelope.error {
                throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            if let value = envelope.content ?? envelope.response ?? envelope.text { return value }
        }
        if let plain = String(data: data, encoding: .utf8), !plain.isEmpty { return plain }
        throw URLError(.cannotDecodeContentData)
    }


    func buildPlan(
        input: PlanBuildInput,
        context: AppData,
        health: HealthSnapshot? = nil,
        date: String = DateKey.today,
        replan: Bool = false
    ) async -> (DayPlan, fallback: Bool) {
        let fallback = PlanEngine.deterministicPlan(input, profile: context.profile, date: date)
        let healthContext = context.settings.healthPlanningEnabled && health != nil
            ? compactHealthContext(health!)
            : "HEALTH & FITNESS: context disabled or not authorized"
        let prompt = compactContext(context, query: input.brainDump, selectedDate: date) + "\n\(healthContext)\n\nBUILD INPUT: \(jsonString(input))\nTARGET DATE: \(date)"
        do {
            let raw = try await raw(
                schema: .plan,
                prompt: prompt,
                settings: context.settings,
                operation: replan ? "replan" : "build"
            )
            guard let json = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(BackendPlan.self, from: json),
                  !decoded.tasks.isEmpty else { return (fallback, true) }

            let tasks = decoded.tasks.map { item in
                PlannerTask(
                    title: item.title,
                    note: item.note.isEmpty ? nil : item.note,
                    startTime: item.startTime.isEmpty ? nil : item.startTime,
                    endTime: item.endTime.isEmpty ? nil : item.endTime,
                    durationMinutes: item.durationMinutes,
                    section: item.section,
                    category: item.category,
                    status: .pending,
                    priority: item.priority,
                    mustWin: item.mustWin,
                    planDate: date,
                    source: .ai,
                    color: IconEngine.suggestedColor(for: item.title, category: item.category),
                    icon: IconEngine.symbol(for: item.title, category: item.category),
                    shape: .capsule,
                    subtasks: []
                )
            }
            let plan = DayPlan(
                date: date,
                title: decoded.title,
                style: input.style,
                mode: input.plannerMode ?? .dayChain,
                energy: input.energy,
                intention: decoded.intention,
                tasks: tasks,
                planScore: decoded.planScore
            )
            return (plan, false)
        } catch {
            return (fallback, true)
        }
    }

    func coachReply(
        message: String,
        conversationId: String,
        selectedDate: String = DateKey.today,
        context: AppData,
        health: HealthSnapshot? = nil
    ) async -> CoachPayload {
        let relevant = context.messages.filter { $0.conversationId == conversationId }.suffix(12)
        let history = ContextSelection.bounded(relevant.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n"), bytes: 16_000)
        let healthContext = context.settings.healthPlanningEnabled && health != nil
            ? compactHealthContext(health!)
            : "HEALTH & FITNESS: context disabled or not authorized"
        let prompt = compactContext(context, query: message, selectedDate: selectedDate) + "\n\(healthContext)\nTODAY: \(DateKey.today)\nCURRENT TIME: \(TimeMath.string(TimeMath.nowMinutes))\nCURRENT SELECTED DATE: \(selectedDate)\n\nCONVERSATION:\n\(history)\n\nUSER: \(message)"
        do {
            let raw = try await raw(schema: .coach, prompt: prompt, settings: context.settings)
            if let json = raw.data(using: .utf8), let payload = try? JSONDecoder().decode(CoachPayload.self, from: json) {
                return payload
            }
            return CoachPayload(reply: "Planning AI returned an unreadable response. No app changes were made. Please send the request again.")
        } catch {
            return CoachPayload(reply: "Planning AI is temporarily unavailable for this request. No app changes were made. Please try again in a moment.")
        }
    }

    func subtasks(for task: PlannerTask, context: AppData) async -> [TaskSubtask] {
        let prompt = compactContext(context, query: task.title, selectedDate: task.planDate) + "\n\nTASK: \(task.title)\nNOTE: \(task.note ?? "")\nSuggest 3-7 concise, concrete subtasks."
        do {
            let raw = try await raw(schema: .subtasks, prompt: prompt, settings: context.settings)
            if let data = raw.data(using: .utf8),
               let payload = try? JSONDecoder().decode(SubtasksPayload.self, from: data),
               !payload.subtasks.isEmpty {
                return payload.subtasks.prefix(7).map { TaskSubtask(title: $0) }
            }
        } catch { }
        return PlanEngine.suggestedSubtasks(for: task.title)
    }

    func analyzeProfile(_ profile: UserProfile, settings: AppSettings) async -> AIProfileAnalysis {
        do {
            var textProfile = profile
            textProfile.avatarImageData = nil
            let raw = try await raw(schema: .profile, prompt: jsonString(textProfile), settings: settings)
            if let data = raw.data(using: .utf8), let value = try? JSONDecoder().decode(AIProfileAnalysis.self, from: data) {
                return value
            }
        } catch { }
        return AIProfileAnalysis(
            summary: "Protect \(profile.primaryGoal.isEmpty ? "the main goal" : profile.primaryGoal), respect the user's real schedule, and start with a small visible action.",
            planningRules: ["Protect one must-win result per day.", "Keep transition buffers between fixed commitments."],
            risks: [profile.struggle.isEmpty ? "Unclear first steps can create friction." : profile.struggle],
            suggestedHabits: []
        )
    }

    func buildHorizon(objective: String, horizon: PlanningHorizon, context: AppData, health: HealthSnapshot? = nil) async -> HorizonPlan? {
        let healthContext = context.settings.healthPlanningEnabled && health != nil
            ? compactHealthContext(health!)
            : "HEALTH & FITNESS: context disabled or not authorized"
        let prompt = compactContext(context, query: objective) + "\n\(healthContext)\n\nOBJECTIVE: \(objective)"
        do {
            let raw = try await raw(schema: .horizon, prompt: prompt, settings: context.settings, horizon: horizon)
            guard let data = raw.data(using: .utf8), let payload = try? JSONDecoder().decode(HorizonPayload.self, from: data) else { return nil }
            return HorizonPlan(horizon: horizon, objective: objective, title: payload.title, summary: payload.summary, checkpoints: payload.checkpoints)
        } catch {
            return nil
        }
    }

    func compactContext(_ incoming: AppData, query: String = "", selectedDate: String = DateKey.today) -> String {
        var data = incoming
        data.notes = ContextSelection.ranked(Array(data.notes.reversed()), query: query) { $0.title + " " + $0.body }
        data.workspacePages = ContextSelection.ranked(Array(data.workspacePages.reversed()), query: query) { $0.title + " " + $0.body }
        data.workspaceDatabases = ContextSelection.ranked(data.workspaceDatabases, query: query) { $0.title }
        data.workspaceProjects = ContextSelection.ranked(data.workspaceProjects, query: query) { $0.title + " " + $0.outcome }
        data.goals = ContextSelection.ranked(data.goals, query: query) { $0.title }
        data.habits = ContextSelection.ranked(data.habits, query: query) { $0.title }
        data.inbox = ContextSelection.ranked(data.inbox, query: query) { $0.title + " " + ($0.note ?? "") }
        for key in [\UserProfile.name, \.primaryGoal, \.goalWhy, \.struggle, \.fixedCommitments, \.currentHabits, \.productiveHours, \.planningPreferences, \.selfDescription] {
            data.profile[keyPath: key] = ContextSelection.bounded(data.profile[keyPath: key], bytes: 600)
        }
        let goals = data.goals.filter { !$0.archived }.prefix(12).map { "id=\($0.id) title=\($0.title) progress=\($0.progress)% target=\($0.targetDate ?? "none")" }.joined(separator: "\n")
        let habits = data.habits.prefix(12).map { "id=\($0.id) title=\($0.title) streak=\($0.currentStreak) reminder=\($0.reminderTime ?? "none")" }.joined(separator: "\n")
        let memories = data.settings.globalMemoryEnabled == false
            ? "DISABLED — do not use learned cross-mode memory"
            : data.memories.filter(\.enabled).suffix(12).map(\.fact).joined(separator: "; ")
        let target = DateKey.date(selectedDate) ?? .now
        let allPlans = data.plans.sorted {
            let left = abs((DateKey.date($0.date) ?? .distantPast).timeIntervalSince(target))
            let right = abs((DateKey.date($1.date) ?? .distantPast).timeIntervalSince(target))
            return left == right ? $0.date < $1.date : left < right
        }
        let taskIndex = allPlans.flatMap { plan in
            plan.tasks.map { task in "id=\(task.id) date=\(task.planDate) title=\(task.title) status=\(task.status.rawValue) project=\(task.projectID ?? "")" }
        }.prefix(400).joined(separator: "\n")
        let sortedPlans = allPlans.prefix(21)
        let tasks = sortedPlans.flatMap { plan in
            plan.tasks.prefix(30).map { task in
                "id=\(task.id) date=\(task.planDate) time=\(task.startTime ?? "any") title=\(task.title) status=\(task.status.rawValue) duration=\(task.durationMinutes) category=\(task.category.rawValue) priority=\(task.priority) mustWin=\(task.mustWin ?? false) project=\(task.projectID ?? "") flexible=\(task.flexible ?? true) deps=\((task.dependencyTaskIDs ?? []).joined(separator: ",")) note=\(String((task.note ?? "").prefix(180)))"
            }
        }.joined(separator: "\n")
        let notes = data.notes.prefix(16).map { "id=\($0.id) title=\($0.title) body=\(String($0.body.prefix(500)))" }.joined(separator: "\n")
        let inbox = data.inbox.prefix(24).map { "id=\($0.id) title=\($0.title) note=\($0.note ?? "")" }.joined(separator: "\n")
        let spaces = data.workspaceSpaces.prefix(12).map { "id=\($0.id) title=\($0.title) description=\(String($0.description.prefix(180)))" }.joined(separator: "\n")
        let projects = data.workspaceProjects.filter { !$0.archived }.prefix(20).map {
            "id=\($0.id) title=\($0.title) status=\($0.status.rawValue) priority=\($0.priority) deadline=\($0.deadline ?? "") progress=\($0.progress) autoSchedule=\($0.autoSchedule) outcome=\(String($0.outcome.prefix(300))) taskIDs=\($0.taskIDs.joined(separator: ","))"
        }.joined(separator: "\n")
        let pageIndex = data.workspacePages.prefix(120).map { "id=\($0.id) title=\($0.title) archived=\($0.archived) locked=\($0.locked ?? false) verified=\($0.verified ?? false) space=\($0.spaceID ?? "") aliases=\(($0.aliases ?? []).joined(separator: ",")) tags=\($0.tags.joined(separator: ","))" }.joined(separator: "\n")
        let pages = data.workspacePages.filter { !$0.archived }.prefix(32).map { "id=\($0.id) title=\($0.title) space=\($0.spaceID ?? "") parent=\($0.parentID ?? "") wiki=\($0.wikiHome ?? false) locked=\($0.locked ?? false) verified=\($0.verified ?? false) aliases=\(($0.aliases ?? []).joined(separator: ",")) tags=\($0.tags.joined(separator: ",")) favorite=\($0.favorite) body=\(String($0.body.prefix(900)))" }.joined(separator: "\n")
        let databaseIndex = data.workspaceDatabases.prefix(60).map { "id=\($0.id) title=\($0.title) view=\($0.view.rawValue) records=\($0.records.count)" }.joined(separator: "\n")
        let databases = data.workspaceDatabases.prefix(18).map { db in
            let properties = (db.properties ?? []).map { "\($0.id):\($0.name):\($0.type.rawValue)" }.joined(separator: ",")
            let rows = ContextSelection.ranked(db.records, query: query) { $0.title + " " + $0.note }.prefix(16).map { record in
                let latitude = record.latitude.map { String($0) } ?? ""
                let longitude = record.longitude.map { String($0) } ?? ""
                let notePreview = String(record.note.prefix(220))
                return "row=\(record.id):\(record.title)[\(record.status)] due=\(record.dueDate ?? "") progress=\(record.progress ?? 0) project=\(record.projectID ?? "") assignee=\(record.assignee ?? "") location=\(record.locationName ?? "") coords=\(latitude),\(longitude) note=\(notePreview)"
            }.joined(separator: ";")
            return "id=\(db.id) title=\(db.title) view=\(db.view.rawValue) props={\(properties)} filter=\(db.filterQuery ?? "") sort=\(db.sortProperty ?? "") records={\(rows)}"
        }.joined(separator: "\n")
        let canvases = data.workspaceCanvases.prefix(12).map { canvas in
            let nodes = canvas.nodes.prefix(20).map { "\($0.id):\($0.title)" }.joined(separator: ",")
            return "id=\(canvas.id) title=\(canvas.title) nodes={\(nodes)}"
        }.joined(separator: "\n")
        let savedSearches = data.workspaceSavedSearches.prefix(16).map { "id=\($0.id) title=\($0.title) query=\($0.query) scope=\($0.scope)" }.joined(separator: "\n")
        let automations = data.workspaceAutomations.prefix(16).map { "id=\($0.id) title=\($0.title) enabled=\($0.enabled) trigger=\($0.trigger.rawValue) action=\($0.action.rawValue) sourceDB=\($0.sourceDatabaseID ?? "") targetDB=\($0.targetDatabaseID ?? "") match=\($0.matchStatus ?? "")" }.joined(separator: "\n")
        let meetings = data.workspaceMeetings.suffix(12).map { "id=\($0.id) title=\($0.title) date=\($0.date) attendees=\($0.attendees.joined(separator: ",")) decisions=\($0.decisions.joined(separator: " | ")) actions=\($0.actionItems.joined(separator: " | "))" }.joined(separator: "\n")
        let schedulingLinks = data.workspaceSchedulingLinks.prefix(12).map { "id=\($0.id) title=\($0.title) duration=\($0.durationMinutes) window=\($0.windowStart)-\($0.windowEnd) active=\($0.active)" }.joined(separator: "\n")
        let smartMeetings = data.workspaceSmartMeetings.prefix(12).map { "id=\($0.id) title=\($0.title) duration=\($0.durationMinutes) weekday=\($0.preferredWeekday) window=\($0.windowStart)-\($0.windowEnd) autoreschedule=\($0.autoReschedule)" }.joined(separator: "\n")
        let forms = data.workspaceForms.prefix(12).map { "id=\($0.id) title=\($0.title) databaseID=\($0.databaseID) active=\($0.active) fields=\($0.fieldPropertyIDs.joined(separator: ","))" }.joined(separator: "\n")
        let clips = data.workspaceClips.filter { !$0.archived }.prefix(16).map { "id=\($0.id) title=\($0.title) url=\($0.url) read=\($0.read) tags=\($0.tags.joined(separator: ",")) note=\(String($0.note.prefix(300)))" }.joined(separator: "\n")
        let sites = data.workspaceSites.prefix(12).map { "id=\($0.id) title=\($0.title) pageID=\($0.pageID) slug=\($0.slug) published=\($0.published)" }.joined(separator: "\n")
        let comments = data.workspaceComments.filter { !$0.resolved }.suffix(20).map { "id=\($0.id) pageID=\($0.pageID) author=\($0.author) text=\(String($0.text.prefix(240)))" }.joined(separator: "\n")
        let versions = data.workspacePageVersions.suffix(16).map { "id=\($0.id) pageID=\($0.pageID) title=\($0.title) createdAt=\($0.createdAt)" }.joined(separator: "\n")
        let timeEntries = data.workspaceTimeEntries.suffix(20).map { "id=\($0.id) title=\($0.title) category=\($0.category.rawValue) project=\($0.projectID ?? "") task=\($0.taskID ?? "") active=\($0.endedAt == nil) minutes=\($0.durationMinutes)" }.joined(separator: "\n")
        let customAgents = data.workspaceCustomAgents.prefix(16).map { "id=\($0.id) title=\($0.title) scope=\($0.scope.rawValue) trigger=\($0.trigger.rawValue) enabled=\($0.enabled) runs=\($0.runCount) instructions=\(String($0.instructions.prefix(300)))" }.joined(separator: "\n")
        let timePolicy = data.workspaceTimePolicy
        let settings = [
            "tier=\(data.subscription.rawValue)", "language=\(data.settings.language.rawValue)", "theme=\(data.settings.theme.rawValue)", "coachMode=\(data.settings.coachMode.rawValue)", "accountability=\(data.settings.accountability.rawValue)",
            "aiAssistantMode=\((data.settings.aiAssistantMode ?? .planning).rawValue)", "studyExplanationLevel=\((data.settings.studyExplanationLevel ?? .grade9).rawValue)", "studyInteractiveSteps=\(data.settings.studyInteractiveSteps ?? true)", "studyVisualizations=\(data.settings.studyVisualizations ?? true)", "studyCheckYourself=\(data.settings.studyCheckYourself ?? true)",
            "accentTheme=\(data.settings.accentTheme.rawValue)", "canvasTheme=\(data.settings.canvasTheme.rawValue)", "visualEnergy=\(data.settings.visualEnergy.rawValue)", "fontScale=\(data.settings.fontScale.rawValue)", "fontDesign=\((data.settings.fontDesign ?? .system).rawValue)",
            "notificationsEnabled=\(data.settings.notificationsEnabled)", "taskReminders=\(data.settings.taskReminders)", "eveningReview=\(data.settings.eveningReview)", "morningPlanningReminder=\(data.settings.morningPlanningReminder ?? false)", "overdueReminder=\(data.settings.overdueReminder ?? false)", "quietHours=\(data.settings.quietHoursStart)-\(data.settings.quietHoursEnd)",
            "calendarSyncEnabled=\(data.settings.calendarSyncEnabled)", "calendarChangesRequireConfirmation=true", "healthSyncEnabled=\(data.settings.healthSyncEnabled)", "healthPlanningEnabled=\(data.settings.healthPlanningEnabled)", "iCloudSyncEnabled=\(data.settings.iCloudSyncEnabled ?? true)", "cloudSyncEnabled=\(data.settings.cloudSyncEnabled ?? true)",
            "safeMode=\(data.settings.safeMode)", "autoLearn=\(data.settings.autoLearn)", "globalMemoryEnabled=\(data.settings.globalMemoryEnabled != false)", "experienceMode=\((data.settings.experienceMode ?? .planner).rawValue)", "timelineLayout=\((data.settings.timelineLayout ?? .horizontal).rawValue)", "weekTimelineLayout=\((data.settings.weekTimelineLayout ?? .horizontal).rawValue)",
            "timelineRealityEnabled=\(data.settings.timelineRealityEnabled != false)", "timelineGravityEnabled=\(data.settings.timelineGravityEnabled ?? false)", "timelineBufferGuardEnabled=\(data.settings.timelineBufferGuardEnabled ?? false)",
            "timelineAutoLockEnabled=\(data.settings.timelineAutoLockEnabled ?? false)", "timelineDeadlineRadarEnabled=\(data.settings.timelineDeadlineRadarEnabled != false)", "timelineRecoveryBuffersEnabled=\(data.settings.timelineRecoveryBuffersEnabled ?? false)", "timelineConflictSweepEnabled=\(data.settings.timelineConflictSweepEnabled ?? false)",
            "timelineEnergyFitEnabled=\(data.settings.timelineEnergyFitEnabled ?? false)", "timelineOverloadGuardEnabled=\(data.settings.timelineOverloadGuardEnabled ?? false)", "timelineContextBatchingEnabled=\(data.settings.timelineContextBatchingEnabled ?? false)", "timelineTravelBufferEnabled=\(data.settings.timelineTravelBufferEnabled ?? false)",
            "timelineFocusBudgetEnabled=\(data.settings.timelineFocusBudgetEnabled ?? false)", "timelineMeetingDefragEnabled=\(data.settings.timelineMeetingDefragEnabled ?? false)", "timelineMomentumChainEnabled=\(data.settings.timelineMomentumChainEnabled ?? false)", "timelineDeadlineBackplanEnabled=\(data.settings.timelineDeadlineBackplanEnabled ?? false)",
            "timelineHabitRescueEnabled=\(data.settings.timelineHabitRescueEnabled ?? false)", "timelineNoMeetingGuardEnabled=\(data.settings.timelineNoMeetingGuardEnabled ?? false)", "timelineDeepWorkReserveEnabled=\(data.settings.timelineDeepWorkReserveEnabled ?? false)", "timelineContextSwitchShieldEnabled=\(data.settings.timelineContextSwitchShieldEnabled ?? false)",
            "timelineAutoCompleteElapsedTasks=\(data.settings.timelineAutoCompleteElapsedTasks != false)", "timelineSuggestionsEnabled=\(data.settings.timelineSuggestionsEnabled != false)"
        ].joined(separator: "; ")
        return """
        PROFILE: name=\(data.profile.name); category=\(data.profile.category.rawValue); goal=\(data.profile.primaryGoal); why=\(data.profile.goalWhy); struggle=\(data.profile.struggle); wake=\(data.profile.wakeTime); sleep=\(data.profile.sleepTime); chronotype=\(data.profile.chronotype.rawValue); discipline=\(data.profile.discipline); commitments=\(data.profile.fixedCommitments); habits=\(data.profile.currentHabits); productiveHours=\(data.profile.productiveHours); preferences=\(data.profile.planningPreferences); self=\(data.profile.selfDescription)
        SETTINGS (subscription is READ-ONLY): \(settings)
        TIME POLICY: weeklyFocus=\(timePolicy.weeklyFocusGoalMinutes)m; minFocus=\(timePolicy.minimumFocusBlockMinutes)m; preferredFocus=\(timePolicy.preferredFocusBlockMinutes)m; break=\(timePolicy.breakMinutes)m; work=\(timePolicy.workHoursStart)-\(timePolicy.workHoursEnd); meeting=\(timePolicy.meetingHoursStart)-\(timePolicy.meetingHoursEnd); noMeetingWeekdays=\(timePolicy.noMeetingWeekdays.map(String.init).joined(separator: ",")); autoBreaks=\(timePolicy.autoScheduleBreaks); protectPersonal=\(timePolicy.protectPersonalTime)
        GOALS:
        \(ContextSelection.bounded(goals, bytes: 2000))
        HABITS:
        \(ContextSelection.bounded(habits, bytes: 2000))
        MEMORY: \(ContextSelection.bounded(memories, bytes: 2000))
        ALL TASK INDEX (up to 400 tasks):
        \(ContextSelection.bounded(taskIndex, bytes: 10000))
        DETAILED SCHEDULE (up to 21 saved days):
        \(ContextSelection.bounded(tasks, bytes: 10000))
        NOTES:
        \(ContextSelection.bounded(notes, bytes: 2000))
        INBOX:
        \(ContextSelection.bounded(inbox, bytes: 2000))
        WORKSPACE SPACES:
        \(ContextSelection.bounded(spaces, bytes: 2000))
        WORKSPACE PROJECTS:
        \(ContextSelection.bounded(projects, bytes: 2000))
        WORKSPACE PAGE INDEX:
        \(ContextSelection.bounded(pageIndex, bytes: 2000))
        WORKSPACE PAGES (recent active detail):
        \(ContextSelection.bounded(pages, bytes: 7000))
        WORKSPACE DATABASE INDEX:
        \(ContextSelection.bounded(databaseIndex, bytes: 2000))
        WORKSPACE DATABASES:
        \(ContextSelection.bounded(databases, bytes: 6000))
        WORKSPACE CANVASES:
        \(ContextSelection.bounded(canvases, bytes: 2000))
        SAVED SEARCHES:
        \(ContextSelection.bounded(savedSearches, bytes: 2000))
        WORKSPACE AUTOMATIONS:
        \(ContextSelection.bounded(automations, bytes: 2000))
        WORKSPACE MEETINGS:
        \(ContextSelection.bounded(meetings, bytes: 2000))
        SCHEDULING LINKS:
        \(ContextSelection.bounded(schedulingLinks, bytes: 2000))
        SMART MEETINGS:
        \(ContextSelection.bounded(smartMeetings, bytes: 2000))
        FORMS:
        \(ContextSelection.bounded(forms, bytes: 2000))
        WEB CLIPS / READ LATER:
        \(ContextSelection.bounded(clips, bytes: 2000))
        SITES / PUBLISHED VIEWS:
        \(ContextSelection.bounded(sites, bytes: 2000))
        OPEN PAGE COMMENTS:
        \(ContextSelection.bounded(comments, bytes: 2000))
        RECENT PAGE VERSIONS:
        \(ContextSelection.bounded(versions, bytes: 2000))
        TIME TRACKING:
        \(ContextSelection.bounded(timeEntries, bytes: 2000))
        CUSTOM WORKSPACE AGENTS:
        \(ContextSelection.bounded(customAgents, bytes: 2000))
        """
    }

    private func compactHealthContext(_ health: HealthSnapshot) -> String {
        let metrics = (health.metrics ?? []).filter { $0.value != nil }.prefix(80).map { metric in
            let value = metric.value.map { String(format: "%.*f", metric.precision, $0) } ?? ""
            return "\(metric.section.rawValue): \(metric.title)=\(value) \(metric.unit) at \(metric.recordedAt ?? "today")"
        }.joined(separator: "\n")
        let workouts = (health.recentWorkouts ?? []).prefix(16).map {
            "\($0.startedAt): \($0.title), \($0.durationMinutes)m, distance=\($0.distanceKilometers.map { String($0) } ?? "n/a")km"
        }.joined(separator: "\n")
        let rings = health.fitnessRings ?? FitnessRingSnapshot()
        return """
        HEALTH & FITNESS (read-only Apple data; never diagnose or edit source records):
        available=\(health.available); missing metrics are unknown, never zero. Only use the recorded metrics below.
        rings: \(health.fitnessRings == nil ? "unknown" : "move=\(rings.moveProgress); exercise=\(rings.exerciseProgress); stand=\(rings.standProgress)")
        METRICS:
        \(metrics)
        RECENT WORKOUTS:
        \(workouts)
        """
    }

    private func jsonString<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func localCoach(_ message: String, context: AppData) -> String {
        let assistantMode = context.settings.aiAssistantMode ?? .planning
        let coachMode = context.settings.coachMode

        if assistantMode == .workspace {
            switch coachMode {
            case .soft:
                return "Workspace Agent is ready. Ask me to create or edit pages, databases, records, notes, tasks, goals, habits, schedule items, or app preferences. I can connect workspace knowledge to your plan."
            case .strict:
                return "Workspace Agent is ready. Tell me the exact workspace or app change you want. I’ll make the smallest correct set of changes and report what changed."
            case .aggressive:
                return "Workspace Agent is ready. Give me the outcome, not a vague intention. I’ll turn it into concrete workspace and planning changes without touching billing, account security, or private keys."
            }
        }

        if assistantMode == .school {
            let level = (context.settings.studyExplanationLevel ?? .grade9).promptLabel
            switch coachMode {
            case .soft:
                if context.settings.studyInteractiveSteps ?? true {
                    return "School mode is ready (\(level)). Send the exact question or your current attempt. I’ll explain one step at a time, calmly and clearly, then wait for you before continuing."
                }
                return "School mode is ready (\(level)). Send the exact question or your current attempt and I’ll explain it clearly at that level, with diagrams or a practice problem when useful."
            case .strict:
                return "School mode is ready (\(level)). Send the exact question or your current attempt now. I’ll be direct about the first mistake or missing step and give you one concrete thing to do next."
            case .aggressive:
                return "School mode is ready (\(level)). No stalling: send the exact question or your current attempt now. I’ll challenge gaps in the work directly and give you an immediate next action, without insults or threats."
            }
        }

        if assistantMode == .general {
            switch coachMode {
            case .soft:
                return "General AI mode is ready. Ask a question, compare options, brainstorm, summarize, or work through an idea. I’ll keep the response calm and supportive."
            case .strict:
                return "General AI mode is ready. State the exact question or decision. I’ll answer directly, point out the key gap or contradiction when relevant, and give one concrete next action when the request is actionable."
            case .aggressive:
                return "General AI mode is ready. State the exact question or decision. I’ll cut through vague reasoning, challenge contradictions directly, and give an immediate next action when there is one, without insults or threats."
            }
        }

        let task = context.plans.first(where: { $0.date == DateKey.today })?.tasks.first(where: { $0.status == .pending || $0.status == .active })
        if let task {
            switch coachMode {
            case .soft:
                switch context.settings.accountability {
                case .light: return "Start gently with \(task.title). Make the first step small enough to begin now, then reassess the rest of the plan."
                case .balanced: return "Start with \(task.title). Make the first step small enough to begin now, then reassess the rest of the plan."
                case .high: return "Start \(task.title) now. Define one visible five-minute result, finish it, then reassess the remaining plan."
                }
            case .strict:
                return "Start \(task.title) now. Define one visible five-minute result, complete it, then decide the next step."
            case .aggressive:
                return "No more delay: start \(task.title) now. Pick one measurable five-minute result and finish it before renegotiating the plan."
            }
        }

        switch coachMode {
        case .soft:
            return "Pick one concrete result for today. I can turn it into a realistic sequence and protect the important parts of your schedule."
        case .strict:
            return "Choose one concrete result for today now. State it in one sentence, then I’ll turn it into an executable sequence."
        case .aggressive:
            return "Stop keeping the goal vague. Name one concrete result for today now, and I’ll turn it into an immediate executable sequence."
        }
    }
}
