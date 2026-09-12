import Foundation

enum CoachMode: String, Codable, CaseIterable, Identifiable { case soft, strict, aggressive; var id: String { rawValue } }

enum AppExperienceMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    // `hybrid` remains decode-only so an older snapshot can be migrated without losing data.
    // It is never presented in the product and resolves directly to Workspace.
    case planner, hybrid, workspace
    var id: String { rawValue }
    static var selectableCases: [AppExperienceMode] { [.planner, .workspace] }
    var resolved: AppExperienceMode { self == .hybrid ? .workspace : self }
    var label: String {
        switch self {
        case .planner: return "Planner"
        case .hybrid: return "Workspace"
        case .workspace: return "Workspace"
        }
    }
    var symbol: String {
        switch self {
        case .planner: return "calendar.badge.clock"
        case .hybrid: return "square.grid.3x3.fill"
        case .workspace: return "square.grid.3x3.fill"
        }
    }
    var description: String {
        switch self {
        case .planner: return "Timeline-first planning, calendar, focus and execution."
        case .hybrid: return "Knowledge, databases, projects, agents and scheduling."
        case .workspace: return "Knowledge, databases, projects, agents and scheduling."
        }
    }
}

enum AIAssistantMode: String, Codable, CaseIterable, Identifiable {
    case planning, school, general, workspace
    var id: String { rawValue }
    var label: String {
        switch self {
        case .planning: return "Planning"
        case .school: return "School"
        case .general: return "General"
        case .workspace: return "Workspace"
        }
    }
    var symbol: String {
        switch self {
        case .planning: return "calendar.badge.clock"
        case .school: return "graduationcap.fill"
        case .general: return "sparkles"
        case .workspace: return "rectangle.3.group.bubble.left.fill"
        }
    }
}

enum StudyExplanationLevel: String, Codable, CaseIterable, Identifiable {
    case grade1 = "grade-1"
    case grade2 = "grade-2"
    case grade3 = "grade-3"
    case grade4 = "grade-4"
    case grade5 = "grade-5"
    case grade6 = "grade-6"
    case grade7 = "grade-7"
    case grade8 = "grade-8"
    case grade9 = "grade-9"
    case grade10 = "grade-10"
    case grade11 = "grade-11"
    case grade12 = "grade-12"
    // Keep the existing raw value so previously saved `student` settings migrate automatically.
    case college = "student"
    case university = "university"
    case professional = "professional"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grade1: return "1st grade"
        case .grade2: return "2nd grade"
        case .grade3: return "3rd grade"
        case .grade4: return "4th grade"
        case .grade5: return "5th grade"
        case .grade6: return "6th grade"
        case .grade7: return "7th grade"
        case .grade8: return "8th grade"
        case .grade9: return "9th grade"
        case .grade10: return "10th grade"
        case .grade11: return "11th grade"
        case .grade12: return "12th grade"
        case .college: return "College"
        case .university: return "University"
        case .professional: return "Professional"
        }
    }

    var promptLabel: String {
        switch self {
        case .grade1: return "Explain at approximately 1st-grade level"
        case .grade2: return "Explain at approximately 2nd-grade level"
        case .grade3: return "Explain at approximately 3rd-grade level"
        case .grade4: return "Explain at approximately 4th-grade level"
        case .grade5: return "Explain at approximately 5th-grade level"
        case .grade6: return "Explain at approximately 6th-grade level"
        case .grade7: return "Explain at approximately 7th-grade level"
        case .grade8: return "Explain at approximately 8th-grade level"
        case .grade9: return "Explain at approximately 9th-grade level"
        case .grade10: return "Explain at approximately 10th-grade level"
        case .grade11: return "Explain at approximately 11th-grade level"
        case .grade12: return "Explain at approximately 12th-grade level"
        case .college: return "Explain at college level"
        case .university: return "Explain at advanced university level"
        case .professional: return "Explain at professional/expert level"
        }
    }
}
enum AccountabilityLevel: String, Codable, CaseIterable, Identifiable { case light, balanced, high; var id: String { rawValue } }
enum SubscriptionTier: String, Codable, CaseIterable, Identifiable {
    // `plus` and `max` stay decodable for snapshots from older prerelease builds.
    // The public product lineup is simply Free + Pro.
    case free, plus, pro, max
    var id: String { rawValue }
    var rank: Int {
        switch self { case .free: 0; case .plus, .pro, .max: 1 }
    }
    var isPro: Bool { rank >= 1 }
}

enum PremiumFeature: String, CaseIterable, Identifiable {
    case recurrence, customAlerts, appleIntegrations, advancedReplan, horizonPlanner, premiumAppearance
    case advancedTimelineViews, advancedTimelineTools, fullAI
    var id: String { rawValue }
    var requiredTier: SubscriptionTier { .pro }
    var label: String {
        switch self {
        case .recurrence: "Recurring tasks"
        case .customAlerts: "Multiple & custom alerts"
        case .appleIntegrations: "Calendar & Health integrations"
        case .advancedReplan: "Reality Replan"
        case .horizonPlanner: "Horizon Planner"
        case .premiumAppearance: "Premium appearance"
        case .advancedTimelineViews: "Vertical Day & Week timelines"
        case .advancedTimelineTools: "Time Machine & Magnetic Compress"
        case .fullAI: "Workspace Agent + School & General AI + unlimited Planning AI"
        }
    }
}
enum ThemeMode: String, Codable, CaseIterable, Identifiable { case light, dark, system; var id: String { rawValue } }
enum AccentTheme: String, Codable, CaseIterable, Identifiable { case crimson, ocean, violet, forest, sunset, blossom, sky, lavender, mint, amber; var id: String { rawValue } }
enum CanvasTheme: String, Codable, CaseIterable, Identifiable { case none, paper, spring, summer, autumn, winter, botanical, wildlife, midnight; var id: String { rawValue } }
enum VisualEnergy: String, Codable, CaseIterable, Identifiable { case calm, balanced, vivid; var id: String { rawValue } }
enum FontScaleMode: String, Codable, CaseIterable, Identifiable { case compact, standard, large; var id: String { rawValue } }
enum AppFontDesign: String, Codable, CaseIterable, Identifiable { case system, rounded, serif; var id: String { rawValue } }
enum AppLanguage: String, Codable, CaseIterable, Identifiable { case en, ru; var id: String { rawValue } }
enum PlanStyle: String, Codable, CaseIterable, Identifiable { case full, realistic, minimum; var id: String { rawValue } }
enum PlannerMode: String, Codable, CaseIterable, Identifiable { case aiPlan = "ai-plan", dayChain = "day-chain"; var id: String { rawValue } }
enum TaskStatus: String, Codable, CaseIterable, Identifiable { case pending, active, completed, skipped; var id: String { rawValue } }
enum TaskRecurrence: String, Codable, CaseIterable, Identifiable { case none, daily, weekdays, weekly, biweekly, monthly, yearly, custom; var id: String { rawValue } }
enum RecurrenceUnit: String, Codable, CaseIterable, Identifiable { case days, weeks, months; var id: String { rawValue } }
enum DaySection: String, Codable, CaseIterable, Identifiable { case morning, day, evening, night; var id: String { rawValue } }
enum TaskCategory: String, Codable, CaseIterable, Identifiable { case focus, work, study, fitness, life, rest; var id: String { rawValue } }
enum TaskColor: String, Codable, CaseIterable, Identifiable { case red, orange, yellow, green, teal, blue, indigo, violet, pink, gray; var id: String { rawValue } }
enum TaskSource: String, Codable { case ai, manual, habit, rescue, calendar, reminder, notes, workout }
enum TaskShape: String, Codable, CaseIterable, Identifiable { case capsule, rounded, circle; var id: String { rawValue } }
enum TimelineLayoutStyle: String, Codable, CaseIterable, Identifiable {
    case horizontal, vertical, orbit
    /// Orbit remains decode-only so prerelease snapshots recover safely. It is not exposed by the product.
    static var selectableCases: [TimelineLayoutStyle] { [.horizontal, .vertical] }
    var id: String { rawValue }
    var label: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .orbit: return "Horizontal"
        }
    }
    var symbol: String {
        switch self {
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        case .orbit: return "arrow.left.and.right"
        }
    }
}
enum PlanningHorizon: String, Codable, CaseIterable, Identifiable { case day, week, month, year; var id: String { rawValue } }
enum WorkoutKind: String, Codable, CaseIterable, Identifiable { case walk, run, cycling, strength, mobility, sport; var id: String { rawValue } }
enum MemoryCategory: String, Codable { case goal, routine, blocker, preference, pattern }
enum MemorySource: String, Codable { case user, behavior, coach }
enum MessageRole: String, Codable { case user, assistant }
enum NoteSource: String, Codable { case manual, appleShare = "apple-share", `import` }
enum ExternalSource: String, Codable { case calendar, reminder }
enum ExternalImportance: String, Codable { case standard, important }

typealias EnergyLevel = Int

struct TaskSubtask: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var completed: Bool = false
}

struct UserProfile: Codable, Hashable {
    enum Category: String, Codable { case money, fitness, study, career, custom }
    enum Chronotype: String, Codable { case earlyBird = "early-bird", balanced, nightOwl = "night-owl" }
    var name = ""
    var nickname: String?
    var avatarImageData: Data?
    var email: String?
    var category: Category = .custom
    var primaryGoal = ""
    var goalWhy = ""
    var struggle = ""
    var wakeTime = "08:00"
    var sleepTime = "23:00"
    var chronotype: Chronotype = .balanced
    var discipline = 3
    var excuses: [String] = []
    var fixedCommitments = ""
    var currentHabits = ""
    var productiveHours = ""
    var planningPreferences = ""
    var selfDescription = ""
    var bodyRhythmEnabled = false
    var cycleStartDate = ""
    var cycleLengthDays = 28
    var cyclePeriodDays = 5
    var aiSummary: String?
    var onboardingCompleted = false
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct AppSettings: Codable, Hashable {
    var coachMode: CoachMode = .soft
    var accountability: AccountabilityLevel = .balanced
    var language: AppLanguage = .en
    var theme: ThemeMode = .light
    var accentTheme: AccentTheme = .crimson
    var customAccentEnabled = false
    var customAccentHue = 350.0
    var customAccentSaturation = 28.0
    var customAccentLightness = 54.0
    var canvasTheme: CanvasTheme = .none
    var visualEnergy: VisualEnergy = .balanced
    var fontScale: FontScaleMode = .standard
    var fontDesign: AppFontDesign?
    var notificationsEnabled = false
    var taskReminders = true
    var eveningReview = true
    var eveningReviewTime: String? = nil
    // Optional so legacy V7/V8 snapshots decode without migration failures.
    var morningPlanningReminder: Bool? = nil
    var morningPlanningTime: String? = nil
    var overdueReminder: Bool? = nil
    var quietHoursStart = "22:00"
    var quietHoursEnd = "07:30"
    var autoLearn = true
    var safeMode = true

    // Three complete product experiences. Optional fields keep every pre-mode snapshot decodable.
    var experienceMode: AppExperienceMode? = .planner
    // Master long-term memory switch shared by Planner, Workspace and every AI mode.
    // Explicitly saved tasks/pages/notes remain user data; this controls learned/personalized memory.
    var globalMemoryEnabled: Bool? = true

    // Dedicated AI experiences. Optional values preserve compatibility with older saved snapshots.
    var aiAssistantMode: AIAssistantMode? = .planning
    var studyExplanationLevel: StudyExplanationLevel? = .grade9
    var studyInteractiveSteps: Bool? = true
    var studyVisualizations: Bool? = true
    var studyCheckYourself: Bool? = true

    var calendarSyncEnabled = false
    var autoCalendarReplan = false
    var healthSyncEnabled = false
    var healthPlanningEnabled = false
    // Optional interaction preferences keep every V8 snapshot decodable.
    var soundEffectsEnabled: Bool? = false
    var hapticFeedbackEnabled: Bool? = true
    // Optional flags preserve V7/V8 JSON compatibility while enabling native Apple + cross-platform sync.
    var iCloudSyncEnabled: Bool? = true
    var cloudSyncEnabled: Bool? = true

    // Timeline presentation is optional for seamless migration from older snapshots.
    var timelineLayout: TimelineLayoutStyle? = .horizontal
    var weekTimelineLayout: TimelineLayoutStyle? = .horizontal
    var timelineShowDayPath: Bool? = true
    var timelineSmartDensity: Bool? = true

    // Timeline intelligence toggles. Optional fields keep old snapshots compatible.
    var timelineFlowShiftEnabled: Bool? = false
    var timelineRealityEnabled: Bool? = true
    var timelineGravityEnabled: Bool? = false
    var timelineBufferGuardEnabled: Bool? = false
    var timelineAutoLockEnabled: Bool? = false
    var timelineDeadlineRadarEnabled: Bool? = true
    var timelineRecoveryBuffersEnabled: Bool? = false
    var timelineConflictSweepEnabled: Bool? = false
    // Final scheduling intelligence layer. All are optional for backward compatibility.
    var timelineEnergyFitEnabled: Bool? = false
    var timelineOverloadGuardEnabled: Bool? = false
    var timelineContextBatchingEnabled: Bool? = false
    var timelineTravelBufferEnabled: Bool? = false
    var timelineFocusBudgetEnabled: Bool? = false
    var timelineMeetingDefragEnabled: Bool? = false
    var timelineMomentumChainEnabled: Bool? = false
    var timelineDeadlineBackplanEnabled: Bool? = false
    var timelineHabitRescueEnabled: Bool? = false
    var timelineNoMeetingGuardEnabled: Bool? = false
    var timelineDeepWorkReserveEnabled: Bool? = false
    var timelineContextSwitchShieldEnabled: Bool? = false
    // Elapsed personal tasks can be completed automatically. External and locked tasks are excluded.
    var timelineAutoCompleteElapsedTasks: Bool? = true
    // Intelligence can surface previews, but may never rewrite a schedule without confirmation.
    var timelineSuggestionsEnabled: Bool? = true
}


struct PlannerTask: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var note: String?
    var startTime: String?
    var endTime: String?
    var durationMinutes: Int = 30
    var section: DaySection = .day
    var category: TaskCategory = .life
    var status: TaskStatus = .pending
    var priority: Int = 2
    var mustWin: Bool?
    var planDate: String = DateKey.today
    var source: TaskSource = .manual
    var recurrence: TaskRecurrence? = TaskRecurrence.none
    var recurrenceDays: [Int]?
    var recurrenceInterval: Int? = nil
    var recurrenceUnit: RecurrenceUnit? = nil
    var color: TaskColor? = .pink
    var icon: String?
    // nil keeps legacy behavior; true means the icon should always follow the task title/category.
    var iconIsAutomatic: Bool? = nil
    var allDay: Bool?
    var allDayAlertTime: String? = nil
    var externalSource: ExternalSource?
    var externalId: String?
    var externalCalendarName: String?
    var externalImportance: ExternalImportance?
    var externalLastModified: String?
    var reminderMinutesBefore: Int?
    var additionalReminderMinutesBefore: [Int]? = nil
    var recurrenceSeriesId: String? = nil
    var recurrenceGenerated: Bool? = nil
    var recurrenceUntil: String? = nil
    var deadline: String?
    var energy: EnergyLevel?
    var shape: TaskShape? = .capsule
    var customTintHue: Double?
    var customTintSaturation: Double?
    var customTintLightness: Double?
    var subtasks: [TaskSubtask]? = []
    var completedAt: String?
    var skippedReason: String?

    // Planning 1.0 Live Timeline metadata. Optional fields keep older snapshots compatible.
    var timelineOriginalStartTime: String? = nil
    var timelineOriginalEndTime: String? = nil
    var actualStartedAt: String? = nil
    var bufferAfterMinutes: Int? = nil
    var timelineLocked: Bool? = nil
    // true = Planning chooses a stable circle/oval automatically; false = respect `shape`.
    var timelineShapeAutomatic: Bool? = true
    // Length multiplier for oval timeline beads. Optional keeps older saved snapshots compatible.
    // 1.45 is the visual default; users can tune it from the task editor.
    var timelineOvalLengthScale: Double? = nil
    // Workspace/project scheduling links. Optional to preserve every existing snapshot.
    var projectID: String? = nil
    var dependencyTaskIDs: [String]? = nil
    var assignee: String? = nil
    var flexible: Bool? = true
    // Stable user-controlled order for tasks sharing the same start time.
    var manualOrder: Int? = nil
    // A manual reopen or Undo takes precedence over elapsed-time completion.
    var autoCompletionSuppressed: Bool? = nil
    // Editing one generated occurrence must never rewrite it from the series template.
    var recurrenceException: Bool? = nil
    var recurrenceExcludedDates: [String]? = nil
}

struct TimelineMoveProposal: Identifiable, Hashable {
    var id: String { "\(taskID)-\(targetDate)-\(requestedTime)" }
    let taskID: String
    let taskTitle: String
    let sourceDate: String
    let targetDate: String
    let requestedTime: String
    let safeTime: String?
    let durationMinutes: Int
    let hasConflict: Bool
}

enum TimelineShapeEngine {
    static func resolvedShape(for task: PlannerTask) -> TaskShape {
        if task.timelineShapeAutomatic == false {
            return task.shape == .circle ? .circle : .capsule
        }
        let seed = task.id.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return seed.isMultiple(of: 2) ? .circle : .capsule
    }
}

struct DayPlan: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: String = DateKey.today
    var title = "Today"
    var style: PlanStyle = .realistic
    var mode: PlannerMode = .dayChain
    var energy: EnergyLevel = 3
    var intention = ""
    var tasks: [PlannerTask] = []
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var rescuedAt: String?
    var planScore = 0
}

struct ReviewedPlanDraft: Identifiable {
    var id: String { plan.id }
    let plan: DayPlan
    let original: DayPlan?
    let fallback: Bool
    var replan = false
}

struct GoalMilestone: Codable, Identifiable, Hashable { var id = UUID().uuidString; var title: String; var completed = false }
struct Goal: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var title: String; var why = ""; var category: TaskCategory = .focus
    var progress = 0; var targetDate: String?; var milestones: [GoalMilestone] = []; var archived = false
}
struct Habit: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var title: String; var icon = "checkmark.circle"; var targetDays: [Int] = [1,2,3,4,5]
    var completedDates: [String] = []; var currentStreak = 0; var bestStreak = 0; var reminderTime: String?
}
struct MemoryFact: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var category: MemoryCategory; var fact: String; var source: MemorySource = .user
    var confidence = 1.0; var enabled = true; var createdAt = ISO8601DateFormatter().string(from: .now); var updatedAt = ISO8601DateFormatter().string(from: .now)
}
struct CoachMessage: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var role: MessageRole; var content: String; var createdAt = ISO8601DateFormatter().string(from: .now)
    var mode: CoachMode?; var safetyOverride: Bool?; var conversationId: String?
}
struct InboxTask: Codable, Identifiable, Hashable { var id = UUID().uuidString; var title: String; var note: String?; var createdAt = ISO8601DateFormatter().string(from: .now) }
struct AppNote: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var title: String; var body = ""; var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now); var source: NoteSource = .manual
}
struct WorkoutSession: Codable, Identifiable, Hashable {
    var id = UUID().uuidString; var kind: WorkoutKind; var title: String; var durationMinutes: Int; var startedAt: String; var completedAt: String; var note: String?
}

enum HealthDataSection: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case activity = "Activity"
    case body = "Body Measurements"
    case cycle = "Cycle Tracking"
    case hearing = "Hearing"
    case heart = "Heart"
    case medications = "Medications"
    case mindfulness = "Mental Wellbeing"
    case mobility = "Mobility"
    case nutrition = "Nutrition"
    case respiratory = "Respiratory"
    case sleep = "Sleep"
    case symptoms = "Symptoms"
    case vitals = "Vitals"
    case other = "Other Data"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .activity: return "figure.run"
        case .body: return "figure.arms.open"
        case .cycle: return "circle.hexagonpath.fill"
        case .hearing: return "ear.fill"
        case .heart: return "heart.fill"
        case .medications: return "pills.fill"
        case .mindfulness: return "brain.head.profile"
        case .mobility: return "figure.walk.motion"
        case .nutrition: return "fork.knife"
        case .respiratory: return "lungs.fill"
        case .sleep: return "bed.double.fill"
        case .symptoms: return "cross.case.fill"
        case .vitals: return "waveform.path.ecg"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

struct HealthMetricSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var section: HealthDataSection
    var symbol: String
    var value: Double?
    var unit: String
    var precision: Int = 0
    var recordedAt: String? = nil
}

struct FitnessRingSnapshot: Codable, Hashable, Sendable {
    // Planning deliberately stores only completion ratios, not energy totals. This keeps the
    // Fitness surface useful and neutral while still matching the user's Apple ring goals.
    var moveProgress = 0.0
    var exerciseProgress = 0.0
    var standProgress = 0.0
}

struct HealthWorkoutSummary: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var symbol: String
    var startedAt: String
    var durationMinutes: Int
    var distanceKilometers: Double?
}

struct HealthSnapshot: Codable, Hashable, Sendable {
    var available = false; var startDate = DateKey.today; var endDate = DateKey.today; var sleepHours = 0.0; var steps = 0
    var exerciseMinutes = 0; var standMinutes = 0; var distanceKilometers = 0.0; var restingHeartRate: Double?; var workoutCount = 0; var workoutMinutes = 0
    var lastUpdated = ISO8601DateFormatter().string(from: .now)
    var metrics: [HealthMetricSnapshot]? = []
    var fitnessRings: FitnessRingSnapshot? = nil
    var recentWorkouts: [HealthWorkoutSummary]? = []
}
struct CapacitySignal: Codable, Hashable { var score: Int; var level: String; var summary: String; var suggestedFocusMinutes: Int; var sourceDate: String }
struct BehaviorEvent: Codable, Identifiable, Hashable { var id = UUID().uuidString; var type: String; var detail: String; var createdAt = ISO8601DateFormatter().string(from: .now) }
struct HorizonCheckpoint: Codable, Identifiable, Hashable { var id = UUID().uuidString; var label: String; var outcome: String; var actions: [String] }
struct HorizonPlan: Codable, Identifiable, Hashable { var id = UUID().uuidString; var horizon: PlanningHorizon; var objective: String; var title: String; var summary: String; var checkpoints: [HorizonCheckpoint]; var createdAt = ISO8601DateFormatter().string(from: .now) }
struct DailyReview: Codable, Identifiable, Hashable { var id = UUID().uuidString; var date = DateKey.today; var score: Int; var wins: [String]; var blocker: String?; var lesson: String?; var mood: Int }
struct Achievement: Codable, Identifiable, Hashable { var id = UUID().uuidString; var title: String; var description: String; var icon: String; var unlockedAt: String?; var progress: Int; var target: Int }
struct UsageLedger: Codable, Hashable { var date = DateKey.today; var coachMessages = 0; var plansBuilt = 0; var rescues = 0 }

enum WorkspaceDatabaseView: String, Codable, CaseIterable, Identifiable {
    case table, board, calendar, list, gallery, timeline, form, chart, map
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .table: return "tablecells"
        case .board: return "rectangle.3.group"
        case .calendar: return "calendar"
        case .list: return "list.bullet"
        case .gallery: return "square.grid.2x2"
        case .timeline: return "chart.bar.xaxis"
        case .form: return "list.clipboard"
        case .chart: return "chart.bar.fill"
        case .map: return "map.fill"
        }
    }
}

enum WorkspacePropertyType: String, Codable, CaseIterable, Identifiable {
    case text, number, select, multiSelect, date, checkbox, url, email, phone, relation, rollup, formula, progress, status, people, files, rating, location, createdTime, lastEditedTime
    var id: String { rawValue }
    var label: String {
        switch self {
        case .multiSelect: return "Multi-select"
        default: return rawValue.capitalized
        }
    }
    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .number: return "number"
        case .select: return "checklist"
        case .multiSelect: return "tag.fill"
        case .date: return "calendar"
        case .checkbox: return "checkmark.square"
        case .url: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .relation: return "point.3.connected.trianglepath.dotted"
        case .rollup: return "sum"
        case .formula: return "function"
        case .progress: return "chart.bar.fill"
        case .status: return "circlebadge.2.fill"
        case .people: return "person.2.fill"
        case .files: return "paperclip"
        case .rating: return "star.fill"
        case .location: return "mappin.and.ellipse"
        case .createdTime: return "clock.badge.plus"
        case .lastEditedTime: return "clock.arrow.circlepath"
        }
    }
}

struct WorkspacePropertyDefinition: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var type: WorkspacePropertyType = .text
    var options: [String] = []
    var relationDatabaseID: String? = nil
    var formula: String? = nil
}

enum WorkspaceProjectStatus: String, Codable, CaseIterable, Identifiable {
    case planned, active, blocked, done, archived
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum WorkspaceAutomationTrigger: String, Codable, CaseIterable, Identifiable {
    case manual, recordCreated, recordStatusChanged, taskCompleted, daily, weekly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recordCreated: return "Record created"
        case .recordStatusChanged: return "Record status changed"
        case .taskCompleted: return "Task completed"
        default: return rawValue.capitalized
        }
    }
}

enum WorkspaceAutomationAction: String, Codable, CaseIterable, Identifiable {
    case createTask, addInbox, createPage, createRecord, markRecordDone
    var id: String { rawValue }
    var label: String {
        switch self {
        case .createTask: return "Create task"
        case .addInbox: return "Add to Inbox"
        case .createPage: return "Create page"
        case .createRecord: return "Create record"
        case .markRecordDone: return "Mark record done"
        }
    }
}

struct WorkspacePage: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var body = ""
    var icon = "doc.text"
    var tags: [String] = []
    var parentID: String? = nil
    var relatedPageIDs: [String] = []
    var favorite = false
    var archived = false
    var spaceID: String? = nil
    var folderID: String? = nil
    var coverSymbol: String? = nil
    var wikiHome: Bool? = nil
    // Notion/knowledge-management parity helpers. Optional for backward compatibility.
    var verified: Bool? = nil
    var verifiedAt: String? = nil
    var locked: Bool? = nil
    var aliases: [String]? = nil
    var properties: [String: String]? = nil
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceRecord: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var status = "Not started"
    var dueDate: String? = nil
    var tags: [String] = []
    var note = ""
    var linkedPageID: String? = nil
    var properties: [String: String]? = nil
    var relationRecordIDs: [String]? = nil
    var progress: Int? = nil
    var assignee: String? = nil
    var projectID: String? = nil
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceDatabase: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var icon = "tablecells"
    var view: WorkspaceDatabaseView = .table
    var records: [WorkspaceRecord] = []
    var properties: [WorkspacePropertyDefinition]? = nil
    var groupByProperty: String? = nil
    var filterQuery: String? = nil
    var sortProperty: String? = nil
    var sortAscending: Bool? = true
    var description: String? = nil
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceCanvasNode: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var note = ""
    var pageID: String? = nil
    var x = 120.0
    var y = 120.0
}

struct WorkspaceCanvasEdge: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var fromNodeID: String
    var toNodeID: String
    var label: String? = nil
}

struct WorkspaceCanvas: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var nodes: [WorkspaceCanvasNode] = []
    var edges: [WorkspaceCanvasEdge]? = nil
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceTemplate: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var icon = "sparkles.rectangle.stack"
    var body: String
    var tags: [String] = []
}

struct WorkspaceSpace: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var icon = "square.grid.2x2.fill"
    var description = ""
    var favorite = false
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceProject: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var status: WorkspaceProjectStatus = .planned
    var priority = 2
    var deadline: String? = nil
    var progress = 0
    var outcome = ""
    var taskIDs: [String] = []
    var pageIDs: [String] = []
    var milestoneTitles: [String] = []
    var completedMilestones: [String] = []
    var autoSchedule = true
    var archived = false
    var createdAt = ISO8601DateFormatter().string(from: .now)
    var updatedAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceAutomation: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var trigger: WorkspaceAutomationTrigger = .manual
    var action: WorkspaceAutomationAction = .createTask
    var sourceDatabaseID: String? = nil
    var targetDatabaseID: String? = nil
    var matchStatus: String? = nil
    var templateTitle = ""
    var templateBody = ""
    var enabled = true
    var runCount = 0
    var lastRunAt: String? = nil
}

struct WorkspaceMeetingNote: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var date = DateKey.today
    var attendees: [String] = []
    var notes = ""
    var decisions: [String] = []
    var actionItems: [String] = []
    var linkedPageID: String? = nil
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceSchedulingLink: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var durationMinutes = 30
    var windowStart = "09:00"
    var windowEnd = "17:00"
    var bufferBeforeMinutes = 0
    var bufferAfterMinutes = 10
    var active = true
}

struct WorkspaceSmartMeeting: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var attendees: [String] = []
    var durationMinutes = 30
    var preferredWeekday = 2
    var windowStart = "09:00"
    var windowEnd = "17:00"
    var autoReschedule = true
    var priority = 2
}

struct WorkspaceTimePolicy: Codable, Hashable {
    var weeklyFocusGoalMinutes = 480
    var minimumFocusBlockMinutes = 45
    var preferredFocusBlockMinutes = 90
    var breakMinutes = 10
    var workHoursStart = "08:00"
    var workHoursEnd = "18:00"
    var meetingHoursStart = "10:00"
    var meetingHoursEnd = "16:00"
    var noMeetingWeekdays: [Int] = []
    var autoScheduleBreaks = true
    var protectPersonalTime = true
}

struct WorkspaceSavedSearch: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var query: String
    var scope = "all"
}

struct WorkspaceForm: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var databaseID: String
    var fieldPropertyIDs: [String] = []
    var confirmationMessage = "Response saved."
    var active = true
}

struct WorkspaceClip: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var url = ""
    var note = ""
    var tags: [String] = []
    var read = false
    var archived = false
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspacePageVersion: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var pageID: String
    var title: String
    var body: String
    var tags: [String]
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceComment: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var pageID: String
    var author = "You"
    var text: String
    var resolved = false
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceSite: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var pageID: String
    var slug: String
    var published = true
    var showUpdatedAt = true
    var createdAt = ISO8601DateFormatter().string(from: .now)
}

struct WorkspaceTimeEntry: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var category: TaskCategory = .focus
    var projectID: String? = nil
    var taskID: String? = nil
    var startedAt = ISO8601DateFormatter().string(from: .now)
    var endedAt: String? = nil
    var durationMinutes = 0
}

enum WorkspaceAgentScope: String, Codable, CaseIterable, Identifiable {
    case workspace, planning, meetings, knowledge, databases, scheduling
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct WorkspaceCustomAgent: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var instructions: String
    var scope: WorkspaceAgentScope = .workspace
    var trigger: WorkspaceAutomationTrigger = .manual
    var enabled = true
    var runCount = 0
    var lastRunAt: String? = nil
}

struct AppData: Codable, Hashable {
    var schemaVersion = 17
    var lastModifiedAt: String? = nil
    var profile = UserProfile()
    var settings = AppSettings()
    var subscription: SubscriptionTier = .free
    var plans: [DayPlan] = []
    var goals: [Goal] = []
    var habits: [Habit] = []
    var memories: [MemoryFact] = []
    var messages: [CoachMessage] = []
    var reviews: [DailyReview] = []
    var achievements: [Achievement] = [
        Achievement(id: "achievement-first-plan", title: "Day architect", description: "Build your first realistic day.", icon: "scope", progress: 0, target: 1),
        Achievement(id: "achievement-comeback", title: "Comeback", description: "Rebuild a disrupted day and complete the next action.", icon: "figure.walk", progress: 0, target: 1),
        Achievement(id: "achievement-streak", title: "Seven honest days", description: "Complete at least one real action on seven different days.", icon: "flame.fill", progress: 0, target: 7)
    ]
    var events: [BehaviorEvent] = []
    var horizonPlans: [HorizonPlan] = []
    var inbox: [InboxTask] = []
    var notes: [AppNote] = []
    var workspacePages: [WorkspacePage] = []
    var workspaceDatabases: [WorkspaceDatabase] = []
    var workspaceCanvases: [WorkspaceCanvas] = []
    var workspaceSpaces: [WorkspaceSpace] = [WorkspaceSpace(id: "space-personal", title: "Personal", icon: "person.crop.square.fill", description: "Your private workspace")]
    var workspaceProjects: [WorkspaceProject] = []
    var workspaceAutomations: [WorkspaceAutomation] = []
    var workspaceMeetings: [WorkspaceMeetingNote] = []
    var workspaceSchedulingLinks: [WorkspaceSchedulingLink] = []
    var workspaceSmartMeetings: [WorkspaceSmartMeeting] = []
    var workspaceForms: [WorkspaceForm] = []
    var workspaceClips: [WorkspaceClip] = []
    var workspacePageVersions: [WorkspacePageVersion] = []
    var workspaceComments: [WorkspaceComment] = []
    var workspaceSites: [WorkspaceSite] = []
    var workspaceTimeEntries: [WorkspaceTimeEntry] = []
    var workspaceCustomAgents: [WorkspaceCustomAgent] = []
    var workspaceSavedSearches: [WorkspaceSavedSearch] = []
    var workspaceTimePolicy = WorkspaceTimePolicy()
    var workspaceTemplates: [WorkspaceTemplate] = [
        WorkspaceTemplate(title: "Project hub", icon: "shippingbox.fill", body: "# Project hub\n\n## Outcome\n\n## Next actions\n- [ ] \n\n## Notes\n"),
        WorkspaceTemplate(title: "Study dashboard", icon: "graduationcap.fill", body: "# Study dashboard\n\n## Topics\n\n## Deadlines\n\n## Questions\n"),
        WorkspaceTemplate(title: "Weekly review", icon: "calendar.badge.checkmark", body: "# Weekly review\n\n## Wins\n\n## Friction\n\n## Next week\n"),
        WorkspaceTemplate(title: "Meeting notes", icon: "person.2.wave.2.fill", body: "# Meeting\n\n## Agenda\n\n## Notes\n\n## Decisions\n\n## Action items\n- [ ] \n"),
        WorkspaceTemplate(title: "Product roadmap", icon: "point.topleft.down.curvedto.point.bottomright.up", body: "# Product roadmap\n\n## Outcome\n\n## Milestones\n\n## Risks\n\n## Decisions\n"),
        WorkspaceTemplate(title: "Daily note", icon: "sun.max.fill", body: "# Daily note\n\n## Priorities\n\n## Notes\n\n## Decisions\n\n## Tomorrow\n"),
        WorkspaceTemplate(title: "Knowledge wiki", icon: "books.vertical.fill", body: "# Knowledge wiki\n\n## Verified knowledge\n\n## Sources\n\n## Related pages\n"),
        WorkspaceTemplate(title: "Sprint board", icon: "rectangle.3.group.fill", body: "# Sprint\n\n## Outcome\n\n## Backlog\n\n## In progress\n\n## Done\n"),
        WorkspaceTemplate(title: "Research brief", icon: "magnifyingglass.circle.fill", body: "# Research brief\n\n## Question\n\n## Evidence\n\n## Findings\n\n## Next actions\n")
    ]
    var workouts: [WorkoutSession] = []
    var usage = UsageLedger()
    var activePlanId: String?
}

// Backward-compatible decoding: older Planning snapshots do not contain Workspace fields.
// Decode every collection/property with its existing default so upgrading never drops local data.
extension AppData {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, lastModifiedAt, profile, settings, subscription, plans, goals, habits, memories, messages, reviews, achievements, events, horizonPlans, inbox, notes, workspacePages, workspaceDatabases, workspaceCanvases, workspaceSpaces, workspaceProjects, workspaceAutomations, workspaceMeetings, workspaceSchedulingLinks, workspaceSmartMeetings, workspaceForms, workspaceClips, workspacePageVersions, workspaceComments, workspaceSites, workspaceTimeEntries, workspaceCustomAgents, workspaceSavedSearches, workspaceTimePolicy, workspaceTemplates, workouts, usage, activePlanId
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = max(17, try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? schemaVersion)
        lastModifiedAt = try c.decodeIfPresent(String.self, forKey: .lastModifiedAt)
        profile = try c.decodeIfPresent(UserProfile.self, forKey: .profile) ?? profile
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? settings
        subscription = try c.decodeIfPresent(SubscriptionTier.self, forKey: .subscription) ?? subscription
        plans = try c.decodeIfPresent([DayPlan].self, forKey: .plans) ?? plans
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? goals
        habits = try c.decodeIfPresent([Habit].self, forKey: .habits) ?? habits
        memories = try c.decodeIfPresent([MemoryFact].self, forKey: .memories) ?? memories
        messages = try c.decodeIfPresent([CoachMessage].self, forKey: .messages) ?? messages
        reviews = try c.decodeIfPresent([DailyReview].self, forKey: .reviews) ?? reviews
        achievements = try c.decodeIfPresent([Achievement].self, forKey: .achievements) ?? achievements
        events = try c.decodeIfPresent([BehaviorEvent].self, forKey: .events) ?? events
        horizonPlans = try c.decodeIfPresent([HorizonPlan].self, forKey: .horizonPlans) ?? horizonPlans
        inbox = try c.decodeIfPresent([InboxTask].self, forKey: .inbox) ?? inbox
        notes = try c.decodeIfPresent([AppNote].self, forKey: .notes) ?? notes
        workspacePages = try c.decodeIfPresent([WorkspacePage].self, forKey: .workspacePages) ?? workspacePages
        workspaceDatabases = try c.decodeIfPresent([WorkspaceDatabase].self, forKey: .workspaceDatabases) ?? workspaceDatabases
        workspaceCanvases = try c.decodeIfPresent([WorkspaceCanvas].self, forKey: .workspaceCanvases) ?? workspaceCanvases
        workspaceSpaces = try c.decodeIfPresent([WorkspaceSpace].self, forKey: .workspaceSpaces) ?? workspaceSpaces
        workspaceProjects = try c.decodeIfPresent([WorkspaceProject].self, forKey: .workspaceProjects) ?? workspaceProjects
        workspaceAutomations = try c.decodeIfPresent([WorkspaceAutomation].self, forKey: .workspaceAutomations) ?? workspaceAutomations
        workspaceMeetings = try c.decodeIfPresent([WorkspaceMeetingNote].self, forKey: .workspaceMeetings) ?? workspaceMeetings
        workspaceSchedulingLinks = try c.decodeIfPresent([WorkspaceSchedulingLink].self, forKey: .workspaceSchedulingLinks) ?? workspaceSchedulingLinks
        workspaceSmartMeetings = try c.decodeIfPresent([WorkspaceSmartMeeting].self, forKey: .workspaceSmartMeetings) ?? workspaceSmartMeetings
        workspaceForms = try c.decodeIfPresent([WorkspaceForm].self, forKey: .workspaceForms) ?? workspaceForms
        workspaceClips = try c.decodeIfPresent([WorkspaceClip].self, forKey: .workspaceClips) ?? workspaceClips
        workspacePageVersions = try c.decodeIfPresent([WorkspacePageVersion].self, forKey: .workspacePageVersions) ?? workspacePageVersions
        workspaceComments = try c.decodeIfPresent([WorkspaceComment].self, forKey: .workspaceComments) ?? workspaceComments
        workspaceSites = try c.decodeIfPresent([WorkspaceSite].self, forKey: .workspaceSites) ?? workspaceSites
        workspaceTimeEntries = try c.decodeIfPresent([WorkspaceTimeEntry].self, forKey: .workspaceTimeEntries) ?? workspaceTimeEntries
        workspaceCustomAgents = try c.decodeIfPresent([WorkspaceCustomAgent].self, forKey: .workspaceCustomAgents) ?? workspaceCustomAgents
        workspaceSavedSearches = try c.decodeIfPresent([WorkspaceSavedSearch].self, forKey: .workspaceSavedSearches) ?? workspaceSavedSearches
        workspaceTimePolicy = try c.decodeIfPresent(WorkspaceTimePolicy.self, forKey: .workspaceTimePolicy) ?? workspaceTimePolicy
        workspaceTemplates = try c.decodeIfPresent([WorkspaceTemplate].self, forKey: .workspaceTemplates) ?? workspaceTemplates
        workouts = try c.decodeIfPresent([WorkoutSession].self, forKey: .workouts) ?? workouts
        usage = try c.decodeIfPresent(UsageLedger.self, forKey: .usage) ?? usage
        activePlanId = try c.decodeIfPresent(String.self, forKey: .activePlanId)
    }
}

struct PlanBuildInput: Codable, Hashable {
    var brainDump = ""; var mustWin = ""; var fixedCommitments = ""; var energy = 3; var style: PlanStyle = .realistic; var availableMinutes: Int?; var plannerMode: PlannerMode? = .dayChain
}
struct RescueInput: Codable, Hashable { var reason: String; var energy: Int; var availableMinutes: Int }

struct AIProfileAnalysis: Codable, Hashable {
    var summary: String
    var planningRules: [String]
    var risks: [String]
    var suggestedHabits: [String]
}

struct CoachAction: Codable, Hashable {
    var type: String
    var taskId: String?
    var itemId: String? = nil
    var title: String?
    var body: String? = nil
    var date: String?
    var startTime: String?
    var durationMinutes: Int?
    var category: TaskCategory?
    var key: String? = nil
    var value: String? = nil
    var boolValue: Bool? = nil
    var intValue: Int? = nil
    var tags: [String]? = nil
}

struct CoachMemorySuggestion: Codable, Hashable {
    var category: MemoryCategory
    var fact: String
    var confidence: Double
}

struct CoachPayload: Codable, Hashable {
    var reply: String
    var memories: [CoachMemorySuggestion] = []
    var actions: [CoachAction] = []
}

extension UserProfile {
    private enum CodingKeys: String, CodingKey {
        case name, nickname, avatarImageData, email, category, primaryGoal, goalWhy, struggle, wakeTime, sleepTime, chronotype, discipline, excuses, fixedCommitments, currentHabits, productiveHours, planningPreferences, selfDescription, bodyRhythmEnabled, cycleStartDate, cycleLengthDays, cyclePeriodDays, aiSummary, onboardingCompleted, createdAt
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? name
        nickname = try values.decodeIfPresent(String.self, forKey: .nickname) ?? nickname
        avatarImageData = try values.decodeIfPresent(Data.self, forKey: .avatarImageData) ?? avatarImageData
        email = try values.decodeIfPresent(String.self, forKey: .email) ?? email
        category = try values.decodeIfPresent(Category.self, forKey: .category) ?? category
        primaryGoal = try values.decodeIfPresent(String.self, forKey: .primaryGoal) ?? primaryGoal
        goalWhy = try values.decodeIfPresent(String.self, forKey: .goalWhy) ?? goalWhy
        struggle = try values.decodeIfPresent(String.self, forKey: .struggle) ?? struggle
        wakeTime = try values.decodeIfPresent(String.self, forKey: .wakeTime) ?? wakeTime
        sleepTime = try values.decodeIfPresent(String.self, forKey: .sleepTime) ?? sleepTime
        chronotype = try values.decodeIfPresent(Chronotype.self, forKey: .chronotype) ?? chronotype
        discipline = try values.decodeIfPresent(Int.self, forKey: .discipline) ?? discipline
        excuses = try values.decodeIfPresent([String].self, forKey: .excuses) ?? excuses
        fixedCommitments = try values.decodeIfPresent(String.self, forKey: .fixedCommitments) ?? fixedCommitments
        currentHabits = try values.decodeIfPresent(String.self, forKey: .currentHabits) ?? currentHabits
        productiveHours = try values.decodeIfPresent(String.self, forKey: .productiveHours) ?? productiveHours
        planningPreferences = try values.decodeIfPresent(String.self, forKey: .planningPreferences) ?? planningPreferences
        selfDescription = try values.decodeIfPresent(String.self, forKey: .selfDescription) ?? selfDescription
        bodyRhythmEnabled = try values.decodeIfPresent(Bool.self, forKey: .bodyRhythmEnabled) ?? bodyRhythmEnabled
        cycleStartDate = try values.decodeIfPresent(String.self, forKey: .cycleStartDate) ?? cycleStartDate
        cycleLengthDays = try values.decodeIfPresent(Int.self, forKey: .cycleLengthDays) ?? cycleLengthDays
        cyclePeriodDays = try values.decodeIfPresent(Int.self, forKey: .cyclePeriodDays) ?? cyclePeriodDays
        aiSummary = try values.decodeIfPresent(String.self, forKey: .aiSummary) ?? aiSummary
        onboardingCompleted = try values.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? onboardingCompleted
        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt) ?? createdAt
    }
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case coachMode, accountability, language, theme, accentTheme, customAccentEnabled, customAccentHue, customAccentSaturation, customAccentLightness, canvasTheme, visualEnergy, fontScale, fontDesign, notificationsEnabled, taskReminders, eveningReview, eveningReviewTime, morningPlanningReminder, morningPlanningTime, overdueReminder, quietHoursStart, quietHoursEnd, autoLearn, safeMode, experienceMode, globalMemoryEnabled, aiAssistantMode, studyExplanationLevel, studyInteractiveSteps, studyVisualizations, studyCheckYourself, calendarSyncEnabled, autoCalendarReplan, healthSyncEnabled, healthPlanningEnabled, soundEffectsEnabled, hapticFeedbackEnabled, iCloudSyncEnabled, cloudSyncEnabled, timelineLayout, weekTimelineLayout, timelineShowDayPath, timelineSmartDensity, timelineFlowShiftEnabled, timelineRealityEnabled, timelineGravityEnabled, timelineBufferGuardEnabled, timelineAutoLockEnabled, timelineDeadlineRadarEnabled, timelineRecoveryBuffersEnabled, timelineConflictSweepEnabled, timelineEnergyFitEnabled, timelineOverloadGuardEnabled, timelineContextBatchingEnabled, timelineTravelBufferEnabled, timelineFocusBudgetEnabled, timelineMeetingDefragEnabled, timelineMomentumChainEnabled, timelineDeadlineBackplanEnabled, timelineHabitRescueEnabled, timelineNoMeetingGuardEnabled, timelineDeepWorkReserveEnabled, timelineContextSwitchShieldEnabled, timelineAutoCompleteElapsedTasks, timelineSuggestionsEnabled
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        coachMode = try values.decodeIfPresent(CoachMode.self, forKey: .coachMode) ?? coachMode
        accountability = try values.decodeIfPresent(AccountabilityLevel.self, forKey: .accountability) ?? accountability
        language = try values.decodeIfPresent(AppLanguage.self, forKey: .language) ?? language
        theme = try values.decodeIfPresent(ThemeMode.self, forKey: .theme) ?? theme
        accentTheme = try values.decodeIfPresent(AccentTheme.self, forKey: .accentTheme) ?? accentTheme
        customAccentEnabled = try values.decodeIfPresent(Bool.self, forKey: .customAccentEnabled) ?? customAccentEnabled
        customAccentHue = try values.decodeIfPresent(Double.self, forKey: .customAccentHue) ?? customAccentHue
        customAccentSaturation = try values.decodeIfPresent(Double.self, forKey: .customAccentSaturation) ?? customAccentSaturation
        customAccentLightness = try values.decodeIfPresent(Double.self, forKey: .customAccentLightness) ?? customAccentLightness
        canvasTheme = try values.decodeIfPresent(CanvasTheme.self, forKey: .canvasTheme) ?? canvasTheme
        visualEnergy = try values.decodeIfPresent(VisualEnergy.self, forKey: .visualEnergy) ?? visualEnergy
        fontScale = try values.decodeIfPresent(FontScaleMode.self, forKey: .fontScale) ?? fontScale
        fontDesign = try values.decodeIfPresent(AppFontDesign.self, forKey: .fontDesign) ?? fontDesign
        notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? notificationsEnabled
        taskReminders = try values.decodeIfPresent(Bool.self, forKey: .taskReminders) ?? taskReminders
        eveningReview = try values.decodeIfPresent(Bool.self, forKey: .eveningReview) ?? eveningReview
        eveningReviewTime = try values.decodeIfPresent(String.self, forKey: .eveningReviewTime) ?? eveningReviewTime
        morningPlanningReminder = try values.decodeIfPresent(Bool.self, forKey: .morningPlanningReminder) ?? morningPlanningReminder
        morningPlanningTime = try values.decodeIfPresent(String.self, forKey: .morningPlanningTime) ?? morningPlanningTime
        overdueReminder = try values.decodeIfPresent(Bool.self, forKey: .overdueReminder) ?? overdueReminder
        quietHoursStart = try values.decodeIfPresent(String.self, forKey: .quietHoursStart) ?? quietHoursStart
        quietHoursEnd = try values.decodeIfPresent(String.self, forKey: .quietHoursEnd) ?? quietHoursEnd
        autoLearn = try values.decodeIfPresent(Bool.self, forKey: .autoLearn) ?? autoLearn
        safeMode = try values.decodeIfPresent(Bool.self, forKey: .safeMode) ?? safeMode
        experienceMode = try values.decodeIfPresent(AppExperienceMode.self, forKey: .experienceMode) ?? experienceMode
        globalMemoryEnabled = try values.decodeIfPresent(Bool.self, forKey: .globalMemoryEnabled) ?? globalMemoryEnabled
        aiAssistantMode = try values.decodeIfPresent(AIAssistantMode.self, forKey: .aiAssistantMode) ?? aiAssistantMode
        studyExplanationLevel = try values.decodeIfPresent(StudyExplanationLevel.self, forKey: .studyExplanationLevel) ?? studyExplanationLevel
        studyInteractiveSteps = try values.decodeIfPresent(Bool.self, forKey: .studyInteractiveSteps) ?? studyInteractiveSteps
        studyVisualizations = try values.decodeIfPresent(Bool.self, forKey: .studyVisualizations) ?? studyVisualizations
        studyCheckYourself = try values.decodeIfPresent(Bool.self, forKey: .studyCheckYourself) ?? studyCheckYourself
        calendarSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .calendarSyncEnabled) ?? calendarSyncEnabled
        autoCalendarReplan = try values.decodeIfPresent(Bool.self, forKey: .autoCalendarReplan) ?? autoCalendarReplan
        healthSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .healthSyncEnabled) ?? healthSyncEnabled
        healthPlanningEnabled = try values.decodeIfPresent(Bool.self, forKey: .healthPlanningEnabled) ?? healthPlanningEnabled
        soundEffectsEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEffectsEnabled) ?? soundEffectsEnabled
        hapticFeedbackEnabled = try values.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? hapticFeedbackEnabled
        iCloudSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? iCloudSyncEnabled
        cloudSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? cloudSyncEnabled
        timelineLayout = try values.decodeIfPresent(TimelineLayoutStyle.self, forKey: .timelineLayout) ?? timelineLayout
        weekTimelineLayout = try values.decodeIfPresent(TimelineLayoutStyle.self, forKey: .weekTimelineLayout) ?? weekTimelineLayout
        timelineShowDayPath = try values.decodeIfPresent(Bool.self, forKey: .timelineShowDayPath) ?? timelineShowDayPath
        timelineSmartDensity = try values.decodeIfPresent(Bool.self, forKey: .timelineSmartDensity) ?? timelineSmartDensity
        timelineFlowShiftEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineFlowShiftEnabled) ?? timelineFlowShiftEnabled
        timelineRealityEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineRealityEnabled) ?? timelineRealityEnabled
        timelineGravityEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineGravityEnabled) ?? timelineGravityEnabled
        timelineBufferGuardEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineBufferGuardEnabled) ?? timelineBufferGuardEnabled
        timelineAutoLockEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineAutoLockEnabled) ?? timelineAutoLockEnabled
        timelineDeadlineRadarEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineDeadlineRadarEnabled) ?? timelineDeadlineRadarEnabled
        timelineRecoveryBuffersEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineRecoveryBuffersEnabled) ?? timelineRecoveryBuffersEnabled
        timelineConflictSweepEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineConflictSweepEnabled) ?? timelineConflictSweepEnabled
        timelineEnergyFitEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineEnergyFitEnabled) ?? timelineEnergyFitEnabled
        timelineOverloadGuardEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineOverloadGuardEnabled) ?? timelineOverloadGuardEnabled
        timelineContextBatchingEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineContextBatchingEnabled) ?? timelineContextBatchingEnabled
        timelineTravelBufferEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineTravelBufferEnabled) ?? timelineTravelBufferEnabled
        timelineFocusBudgetEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineFocusBudgetEnabled) ?? timelineFocusBudgetEnabled
        timelineMeetingDefragEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineMeetingDefragEnabled) ?? timelineMeetingDefragEnabled
        timelineMomentumChainEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineMomentumChainEnabled) ?? timelineMomentumChainEnabled
        timelineDeadlineBackplanEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineDeadlineBackplanEnabled) ?? timelineDeadlineBackplanEnabled
        timelineHabitRescueEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineHabitRescueEnabled) ?? timelineHabitRescueEnabled
        timelineNoMeetingGuardEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineNoMeetingGuardEnabled) ?? timelineNoMeetingGuardEnabled
        timelineDeepWorkReserveEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineDeepWorkReserveEnabled) ?? timelineDeepWorkReserveEnabled
        timelineContextSwitchShieldEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineContextSwitchShieldEnabled) ?? timelineContextSwitchShieldEnabled
        timelineAutoCompleteElapsedTasks = try values.decodeIfPresent(Bool.self, forKey: .timelineAutoCompleteElapsedTasks) ?? timelineAutoCompleteElapsedTasks
        timelineSuggestionsEnabled = try values.decodeIfPresent(Bool.self, forKey: .timelineSuggestionsEnabled) ?? timelineSuggestionsEnabled
    }
}
