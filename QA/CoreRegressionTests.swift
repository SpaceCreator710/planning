import Foundation

@main
struct CoreRegressionTests {
    static func main() throws {
        testDailyRecurrence()
        testRecurrenceEndDate()
        testCustomRecurrence()
        testYearlyRecurrence()
        testExternalCommitmentReflow()
        testSemanticTaskIcons()
        testTimelineOrdering()
        testStableEqualTimeOrdering()
        testClockWrappingPreservesDuration()
        testTimelineDateNavigation()
        try testBackwardCompatiblePlannerTaskJSON()
        try testBackwardCompatibleAppDataJSON()
        testWorkspaceParityModels()
        testExperienceModeMigrationContract()
        testTimelineLayoutMigrationContract()
        print("Core regression tests: PASS")
    }

    static func testDailyRecurrence() {
        var task = PlannerTask(title: "Read", planDate: "2026-08-17")
        task.recurrence = .daily
        let dates = PlanEngine.recurrenceDates(for: task, horizonDays: 4)
        precondition(dates == ["2026-08-18", "2026-08-19", "2026-08-20", "2026-08-21"], "Daily recurrence mismatch: \(dates)")
    }

    static func testRecurrenceEndDate() {
        var task = PlannerTask(title: "Practice", planDate: "2026-08-17")
        task.recurrence = .daily
        task.recurrenceUntil = "2026-08-19"
        let dates = PlanEngine.recurrenceDates(for: task, horizonDays: 10)
        precondition(dates == ["2026-08-18", "2026-08-19"], "Recurrence end date mismatch: \(dates)")
    }

    static func testCustomRecurrence() {
        var task = PlannerTask(title: "Deep clean", planDate: "2026-08-17")
        task.recurrence = .custom
        task.recurrenceInterval = 2
        task.recurrenceUnit = .weeks
        let dates = PlanEngine.recurrenceDates(for: task, horizonDays: 45)
        precondition(dates.prefix(3) == ["2026-08-31", "2026-09-14", "2026-09-28"], "Custom recurrence mismatch: \(dates)")
    }

    static func testYearlyRecurrence() {
        var task = PlannerTask(title: "Birthday", planDate: "2026-08-17")
        task.recurrence = .yearly
        let dates = PlanEngine.recurrenceDates(for: task, horizonDays: 800)
        precondition(dates.prefix(2) == ["2027-08-17", "2028-08-17"], "Yearly recurrence mismatch: \(dates)")
    }

    static func testExternalCommitmentReflow() {
        let flexible = PlannerTask(title: "Deep work", startTime: "10:00", endTime: "11:00", durationMinutes: 60, planDate: "2026-08-17")
        let fixed = PlannerTask(title: "Class", startTime: "10:30", endTime: "11:30", durationMinutes: 60, planDate: "2026-08-17", externalSource: .calendar)
        let result = PlanEngine.reflowAroundExternalCommitments(DayPlan(date: "2026-08-17", tasks: [flexible, fixed]))
        let moved = result.tasks.first(where: { $0.title == "Deep work" })
        precondition(moved?.startTime == "11:35" && moved?.endTime == "12:35", "External reflow mismatch: \(String(describing: moved))")
    }

    static func testSemanticTaskIcons() {
        precondition(IconEngine.symbol(for: "Take a shower", category: .life) == "shower.fill")
        precondition(IconEngine.symbol(for: "Душ", category: .life) == "shower.fill")
        precondition(IconEngine.symbol(for: "Workout", category: .fitness) == "dumbbell.fill")
        precondition(IconEngine.symbol(for: "Тренировка", category: .fitness) == "dumbbell.fill")
        precondition(IconEngine.symbol(for: "Тренировка", category: .fitness) != "tram.fill")
        precondition(IconEngine.symbol(for: "Алгебра", category: .study) == "function")
        precondition(IconEngine.symbol(for: "Chemistry homework", category: .study) == "flask.fill")
        precondition(IconEngine.symbol(for: "Football practice", category: .fitness) == "figure.soccer")
        precondition(IconEngine.symbol(for: "Go to school", category: .study) == "backpack.fill")
        precondition(IconEngine.symbol(for: "Русский язык", category: .study) == "textformat")
        precondition(IconEngine.symbol(for: "Физра", category: .fitness) == "figure.run")
        precondition(IconEngine.symbol(for: "Пилатес", category: .fitness) == "figure.pilates")
        precondition(IconEngine.shouldRepair(existing: "tram.fill", title: "Training", category: .fitness))

        var automatic = PlannerTask(title: "Тренировка", category: .fitness, icon: "tram.fill")
        automatic.iconIsAutomatic = true
        precondition(IconEngine.symbol(for: automatic) == "dumbbell.fill")

        var custom = PlannerTask(title: "Тренировка", category: .fitness, icon: "star.fill")
        custom.iconIsAutomatic = false
        precondition(IconEngine.symbol(for: custom) == "star.fill")
    }

    static func testTimelineOrdering() {
        let untimed = PlannerTask(title: "Anytime", planDate: "2026-08-20")
        let late = PlannerTask(title: "Physics", startTime: "11:00", planDate: "2026-08-20")
        let early = PlannerTask(title: "Math", startTime: "09:00", planDate: "2026-08-20")
        let middle = PlannerTask(title: "English", startTime: "10:00", planDate: "2026-08-20")
        let allDay = PlannerTask(title: "Birthday", planDate: "2026-08-20", allDay: true)

        let ordered = TaskTimelineOrder.sorted([late, untimed, middle, allDay, early])
        precondition(ordered.map(\.title) == ["Birthday", "Math", "English", "Physics", "Anytime"], "Timeline order mismatch: \(ordered.map(\.title))")
    }

    static func testStableEqualTimeOrdering() {
        var first = PlannerTask(id: "first", title: "First", startTime: "09:00", planDate: "2026-08-20")
        var second = PlannerTask(id: "second", title: "Second", startTime: "09:00", planDate: "2026-08-20")
        first.manualOrder = 0
        second.manualOrder = 1
        precondition(TaskTimelineOrder.sorted([second, first]).map(\.id) == ["first", "second"])

        first.manualOrder = nil
        second.manualOrder = nil
        precondition(TaskTimelineOrder.sorted([second, first]).map(\.id) == ["second", "first"], "Equal-time tasks must preserve saved array order")
    }

    static func testClockWrappingPreservesDuration() {
        precondition(TimeMath.clockString(23 * 60 + 45 + 60) == "00:45")
        precondition(TimeMath.clockString(-15) == "23:45")
    }


    static func testTimelineDateNavigation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        let monday = TimelineDateMath.startOfWeek(containing: date, calendar: calendar)
        precondition(DateKey.string(monday) == "2026-08-17", "Week start mismatch: \(DateKey.string(monday))")
        let nextWeek = TimelineDateMath.shifted(monday, days: 7, calendar: calendar)
        precondition(DateKey.string(nextWeek) == "2026-08-24", "Next week mismatch: \(DateKey.string(nextWeek))")
        let nextDay = TimelineDateMath.shifted(date, days: 1, calendar: calendar)
        precondition(DateKey.string(nextDay) == "2026-08-21", "Next day mismatch: \(DateKey.string(nextDay))")
    }

    static func testBackwardCompatiblePlannerTaskJSON() throws {
        let oldJSON = #"{"id":"old","title":"Legacy task","durationMinutes":30,"section":"day","category":"life","status":"pending","priority":2,"planDate":"2026-08-17","source":"manual"}"#.data(using: .utf8)!
        let task = try JSONDecoder().decode(PlannerTask.self, from: oldJSON)
        precondition(task.additionalReminderMinutesBefore == nil)
        precondition(task.recurrenceSeriesId == nil)
        precondition(task.recurrenceGenerated == nil)
        precondition(task.recurrenceUntil == nil)
        precondition(task.recurrenceInterval == nil)
        precondition(task.recurrenceUnit == nil)
        precondition(task.allDayAlertTime == nil)
        precondition(task.iconIsAutomatic == nil)
    }
    static func testBackwardCompatibleAppDataJSON() throws {
        let oldJSON = #"{"schemaVersion":12}"#.data(using: .utf8)!
        let data = try JSONDecoder().decode(AppData.self, from: oldJSON)
        precondition(data.schemaVersion == 17)
        precondition(data.workspaceClips.isEmpty)
        precondition(data.workspacePageVersions.isEmpty)
        precondition(data.workspaceComments.isEmpty)
        precondition(data.workspaceSites.isEmpty)
        precondition(data.workspaceTimeEntries.isEmpty)
        precondition(data.workspaceCustomAgents.isEmpty)
        precondition((data.settings.experienceMode ?? .planner) == .planner)
        precondition(data.settings.globalMemoryEnabled != false)
    }

    static func testWorkspaceParityModels() {
        precondition(WorkspaceDatabaseView.allCases.contains(.map))
        precondition(WorkspacePropertyType.allCases.contains(.status))
        precondition(WorkspacePropertyType.allCases.contains(.people))
        precondition(WorkspacePropertyType.allCases.contains(.files))
        precondition(WorkspacePropertyType.allCases.contains(.rating))
        precondition(WorkspacePropertyType.allCases.contains(.location))
        precondition(WorkspaceAgentScope.allCases.count >= 6)
    }

    static func testExperienceModeMigrationContract() {
        precondition(AppExperienceMode.selectableCases == [.planner, .workspace])
        precondition(AppExperienceMode.hybrid.resolved == .workspace)
        precondition(AppExperienceMode.hybrid.label == AppExperienceMode.workspace.label)
    }

    static func testTimelineLayoutMigrationContract() {
        precondition(TimelineLayoutStyle.selectableCases == [.horizontal, .vertical])
        precondition(TimelineLayoutStyle.orbit.label == TimelineLayoutStyle.horizontal.label)
    }

}
