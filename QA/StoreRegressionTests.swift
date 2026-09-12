import Foundation

@main @MainActor
struct StoreRegressionTests {
    static func main() async throws {
        try preferences()
        clockAndMidnight()
        placement()
        exactMoveAndUndo()
        completionAndRecurrence()
        atomicReorder()
        aiActions()
        await relevantContext()
        realConflictsOnly()
        calendarProjection()
        reviewedPlanCommit()
        pausedAutomation()
        print("Release 12 regression tests: PASS (12 scenarios)")
    }
    static func freshStore() -> AppStore {
        let store = AppStore()
        store.data = AppData()
        store.data.settings.cloudSyncEnabled = false
        store.data.settings.iCloudSyncEnabled = false
        return store
    }
    static func preferences() throws {
        let d = JSONDecoder()
        var profile = try d.decode(UserProfile.self, from: Data(#"{"name":"Alex","nickname":"alex"}"#.utf8))
        precondition(profile.name == "Alex" && profile.wakeTime == "08:00")
        profile.avatarImageData = Data([1,2,3])
        let decoded = try d.decode(UserProfile.self, from: JSONEncoder().encode(profile))
        precondition(decoded == profile)
        let settings = try d.decode(AppSettings.self, from: Data(#"{"language":"ru","notificationsEnabled":true}"#.utf8))
        precondition(settings.language == .ru && settings.notificationsEnabled && settings.timelineFlowShiftEnabled == false)
    }
    static func clockAndMidnight() {
        let first = SnapshotClock.stamp(), second = SnapshotClock.stamp(after: first)
        precondition(SnapshotClock.date(second)! > SnapshotClock.date(first)!)
        precondition(SnapshotClock.date("2026-09-06T00:00:00Z") != nil)
        var task = PlannerTask(title: "Night", startTime: "23:45", endTime: "00:15", durationMinutes: 30, planDate: "2026-09-05")
        let nextDay = DateKey.date("2026-09-06")!
        precondition(TaskSchedule.endMinute(task) == 1455)
        precondition(!TaskSchedule.shouldAutoComplete(task, now: nextDay))
        precondition(TaskSchedule.shouldAutoComplete(task, now: nextDay.addingTimeInterval(16*60)))
        task.endTime = task.startTime
        precondition(TaskSchedule.endMinute(task) == 1455)
        task.autoCompletionSuppressed = true
        precondition(!TaskSchedule.shouldAutoComplete(task, now: nextDay.addingTimeInterval(16*60)))
        for bad in ["24:00","12:99","no","12:"] { precondition(TimeMath.minutes(bad) == nil) }
        let t = Date(timeIntervalSince1970: 0)
        precondition(TimeIntervals.totalDuration([(t,t.addingTimeInterval(100)),(t.addingTimeInterval(50),t.addingTimeInterval(150))]) == 150)
    }
    static func placement() {
        let date = "2026-09-06"
        let task = PlannerTask(title: "Move", durationMinutes: 30, planDate: date)
        let previous = PlannerTask(title: "Late", startTime: "23:45", endTime: "00:30", durationMinutes: 45, planDate: "2026-09-05")
        let personal = PlannerTask(title: "Personal", startTime: "00:30", endTime: "01:00", planDate: date)
        let plans = [DayPlan(date: previous.planDate, tasks: [previous]),DayPlan(date: date,tasks:[personal])]
        precondition(TimelinePlacement.nextAvailableStart(for: task,on:date,requestedStart:0,plans:plans) == 60)
        var full = personal; full.startTime = "00:00"; full.endTime = "00:00"; full.durationMinutes = 1440
        precondition(TimelinePlacement.nextAvailableStart(for:task,on:date,requestedStart:1,plans:[DayPlan(date:date,tasks:[full])]) == nil)
    }
    static func exactMoveAndUndo() {
        let store = freshStore(), date = DateKey.today
        let task = PlannerTask(title:"Mine",startTime:"09:00",endTime:"09:30",planDate:date)
        let neighbor = PlannerTask(title:"Stay",startTime:"10:00",endTime:"11:00",durationMinutes:60,planDate:date)
        store.data.plans = [DayPlan(date:date,tasks:[task,neighbor])]
        let proposal = store.timelineMoveProposal(taskID:task.id,toDate:date,startTime:"10:15")!
        precondition(proposal.hasConflict && proposal.safeTime == "11:00")
        store.confirmTimelineMove(proposal,useSafeTime:false)
        precondition(store.data.plans[0].tasks.first(where:{$0.id == task.id})?.startTime == "10:15")
        precondition(store.data.plans[0].tasks.first(where:{$0.id == neighbor.id})?.startTime == "10:00")
        store.data.profile.name = "Keep"
        store.data.notes.append(AppNote(title:"Keep note"))
        store.undoLastTimelineChange()
        precondition(store.data.plans[0].tasks.first(where:{$0.id == task.id})?.startTime == "09:00")
        precondition(store.data.profile.name == "Keep" && store.data.notes.count == 1)
    }
    static func completionAndRecurrence() {
        let store = freshStore()
        let task = PlannerTask(title:"Timed",startTime:"09:00",endTime:"09:30",planDate:"2026-09-05")
        var external = task; external.id = "external"; external.externalSource = .calendar
        store.data.plans = [DayPlan(date:task.planDate,tasks:[task,external])]
        let now = DateKey.date("2026-09-06")!
        precondition(store.completeElapsedPersonalTasks(now:now) == 1)
        store.toggleTask(task.id)
        precondition(store.completeElapsedPersonalTasks(now:now) == 0)
        var master = PlannerTask(title:"Repeat",planDate:DateKey.today)
        master.recurrence = .daily
        store.addTask(master)
        let generated = store.data.plans.flatMap(\.tasks).first(where:{$0.recurrenceGenerated == true})!
        store.deleteTask(generated.id)
        store.ensureRecurrenceHorizon()
        precondition(!store.data.plans.flatMap(\.tasks).contains(where:{$0.id == generated.id}))
    }
    static func atomicReorder() {
        let date = "2026-09-06"
        let short = PlannerTask(title:"Short",startTime:"09:00",durationMinutes:15,planDate:date)
        let long = PlannerTask(title:"Long",startTime:"09:15",durationMinutes:90,planDate:date)
        let meeting = PlannerTask(title:"Meeting",startTime:"10:00",endTime:"11:00",durationMinutes:60,planDate:date)
        let plan = DayPlan(date:date,tasks:[short,long,meeting])
        let result = PlanEngine.safeReorderedPlan(plan,ordered:[long,short])!
        precondition(result.tasks.first(where:{$0.id == long.id})?.startTime == "11:00")
        precondition(result.tasks.first(where:{$0.id == short.id})?.startTime == "12:30")
        precondition(result.tasks.first(where:{$0.id == meeting.id})?.startTime == "10:00")
        var late = long; late.startTime = "23:30"
        precondition(PlanEngine.safeReorderedPlan(DayPlan(date:date,tasks:[late]),ordered:[late]) == nil)
    }
    static func aiActions() {
        let store = freshStore()
        let theme = CoachAction(type:"set_setting",key:"theme",value:"dark")
        let nickname = CoachAction(type:"set_profile",key:"nickname",value:"alex")
        precondition(store.coachActionDetail(theme).contains("dark"))
        store.performTimelineTransaction(label:"AI") { store.apply(actions:[theme,nickname]) }
        precondition(store.data.settings.theme == .dark && store.data.profile.nickname == "alex")
        store.apply(actions:[CoachAction(type:"set_setting",key:"subscription",value:"pro")])
        precondition(store.data.subscription == .free)
        store.undoLastTimelineChange()
        precondition(store.data.settings.theme == .light && store.data.profile.nickname == nil)
    }
    static func relevantContext() async {
        var data = AppData()
        for index in 0..<150 {
            let date = DateKey.string(Calendar.current.date(byAdding:.day,value:index,to:DateKey.date("2026-09-06")!)!)
            data.plans.append(DayPlan(date:date,tasks:[PlannerTask(title:"Task \(index)",planDate:date)]))
        }
        data.notes = [AppNote(title:"Release checklist",body:"Important old requirements")] + (0..<50).map {AppNote(title:"Unrelated \($0)")}
        data.settings.globalMemoryEnabled = false
        let context = await AIService.shared.compactContext(data,query:"release checklist",selectedDate:"2026-09-06")
        precondition(context.contains("date=2026-09-06") && context.contains("Important old requirements") && context.contains("DISABLED"))
        precondition(context.utf8.count < 150_000)
        precondition(ContextSelection.bounded("Привет 💎",bytes:5) == "Пр")
    }
    static func realConflictsOnly() {
        let date = "2026-09-06"
        let tasks = (0..<12).map { PlannerTask(title: "Task \($0)", startTime: TimeMath.string(480 + $0 * 60), durationMinutes: 30, planDate: date) }
        let plan = DayPlan(date: date, tasks: tasks)
        precondition(InsightsEngine.scheduleCollisions(plan: plan, capacity: InsightsEngine.capacity(from: HealthSnapshot())).isEmpty)
        precondition(InsightsEngine.capacity(from: HealthSnapshot()).level == "unknown")
        var overlap = plan
        overlap.tasks[1].startTime = overlap.tasks[0].startTime
        precondition(InsightsEngine.scheduleCollisions(plan: overlap, capacity: nil).count == 1)
    }
    static func calendarProjection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 1
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let week = CalendarProjection.weekDates(containing: day, calendar: calendar)
        precondition(week.count == 7 && Set(week).count == 7)
        precondition(week.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        precondition(week[1].timeIntervalSince(week[0]) == 23 * 3600)
        calendar.firstWeekday = 2
        let mondayWeek = CalendarProjection.weekDates(containing: day, calendar: calendar)
        precondition(calendar.component(.weekday, from: mondayWeek[0]) == 2)
        precondition(calendar.component(.day, from: mondayWeek[0]) == 23)
    }

    static func reviewedPlanCommit() {
        let store = freshStore()
        let date = "2026-09-08"
        var protected = PlannerTask(title: "Meeting", startTime: "10:00", planDate: date)
        protected.timelineLocked = true
        let old = PlannerTask(title: "Old", startTime: "12:00", planDate: date)
        let original = DayPlan(date: date, tasks: [protected, old])
        store.data.plans = [original]
        let replacement = DayPlan(date: date, tasks: [PlannerTask(title: "New", startTime: "14:00", planDate: date)])
        let prepared = PlanEngine.preserveProtected(current: original, replacement: replacement)
        let draft = ReviewedPlanDraft(plan: prepared, original: original, fallback: true)
        precondition(!store.applyReviewedPlan(ReviewedPlanDraft(plan: replacement, original: original, fallback: true)))
        store.data.profile.name = "Independent edit"
        precondition(store.applyReviewedPlan(draft))
        precondition(store.data.plans.first == prepared)
        precondition(store.data.profile.name == "Independent edit")
        store.data.notes.append(AppNote(title: "Keep me"))
        store.undoLastTimelineChange()
        precondition(store.data.plans.first == original && store.data.notes.count == 1)
        store.data.plans[0].tasks[1].startTime = "12:15"
        let before = store.data.plans
        precondition(!store.applyReviewedPlan(draft))
        precondition(store.data.plans == before)
    }

    static func pausedAutomation() {
        let store = freshStore()
        var rule = WorkspaceAutomation(title: "Capture", action: .addInbox, templateTitle: "An idea", enabled: false)
        store.saveWorkspaceAutomation(rule)
        store.runWorkspaceAutomation(rule.id)
        precondition(store.data.inbox.isEmpty)
        rule.enabled = true
        store.saveWorkspaceAutomation(rule)
        store.runWorkspaceAutomation(rule.id)
        precondition(store.data.inbox.count == 1)
        precondition(store.data.workspaceAutomations.first?.runCount == 1)
        store.undoLastTimelineChange()
        precondition(store.data.inbox.isEmpty)
    }

}
