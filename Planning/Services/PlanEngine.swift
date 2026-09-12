import Foundation

enum PlanEngine {

    static func safeReorderedPlan(_ plan: DayPlan, ordered: [PlannerTask], bufferMinutes: Int = 0, allPlans: [DayPlan] = []) -> DayPlan? {
        let ids = Set(ordered.map(\.id))
        guard !ordered.isEmpty, ids.count == ordered.count,
              var cursor = ordered.compactMap({ TimeMath.minutes($0.startTime) }).min() else { return nil }
        var result = plan
        result.tasks.removeAll { ids.contains($0.id) }
        let otherPlans = allPlans.filter { $0.date != plan.date }
        for var task in ordered {
            guard let start = TimelinePlacement.nextAvailableStart(for: task, on: plan.date, requestedStart: cursor, plans: otherPlans + [result]),
                  start + max(5, task.durationMinutes) <= 1440 else { return nil }
            task.timelineOriginalStartTime = task.timelineOriginalStartTime ?? task.startTime
            task.timelineOriginalEndTime = task.timelineOriginalEndTime ?? task.endTime
            task.startTime = TimeMath.string(start)
            task.endTime = TimeMath.clockString(start + max(5, task.durationMinutes))
            task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
            if task.recurrenceGenerated == true { task.recurrenceException = true }
            result.tasks.append(task)
            cursor = start + max(5, task.durationMinutes) + max(0, bufferMinutes)
        }
        result.tasks = TaskTimelineOrder.sorted(result.tasks)
        return result
    }

    static func manualTask(title: String, date: String = DateKey.today) -> PlannerTask {
        PlannerTask(title: title, durationMinutes: 30, section: .day, category: .life, status: .pending, priority: 2, planDate: date, source: .manual, color: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : IconEngine.suggestedColor(for: title), icon: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : IconEngine.symbol(for: title), shape: .capsule)
    }

    static func deterministicPlan(_ input: PlanBuildInput, profile: UserProfile, date: String = DateKey.today) -> DayPlan {
        let raw = input.brainDump.split(whereSeparator: { $0 == "\n" || $0 == "," }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let titles = raw.isEmpty ? [input.mustWin].filter { !$0.isEmpty } : raw
        let wake = TimeMath.minutes(profile.wakeTime) ?? 450
        let start = date == DateKey.today ? min(1439, max(wake, TimeMath.nowMinutes + 10)) : wake
        let budget = max(20, input.availableMinutes ?? 360)
        let count = max(1, titles.count)
        let block = max(15, min(90, budget / count))
        var tasks: [PlannerTask] = []
        var cursor = start
        for (index, title) in titles.enumerated() {
            let clean = title.isEmpty ? "Next action" : title
            let category: TaskCategory = clean.lowercased().contains("study") ? .study : clean.lowercased().contains("work") ? .work : .focus
            tasks.append(PlannerTask(
                title: clean,
                startTime: cursor < 1440 ? TimeMath.string(cursor) : nil,
                endTime: cursor < 1440 ? TimeMath.clockString(cursor + block) : nil,
                durationMinutes: block,
                section: cursor < 720 ? .morning : cursor < 1020 ? .day : .evening,
                category: category,
                status: .pending,
                priority: index == 0 ? 1 : 2,
                mustWin: index == 0,
                planDate: date,
                source: .ai,
                color: IconEngine.suggestedColor(for: clean, category: category),
                icon: IconEngine.symbol(for: clean, category: category),
                shape: .capsule
            ))
            cursor += block + 10
        }
        return DayPlan(date: date, title: "Your day", style: input.style, mode: input.plannerMode ?? .dayChain, energy: input.energy, intention: input.mustWin, tasks: tasks, planScore: min(100, 55 + tasks.count * 7))
    }

    static func preserveProtected(current: DayPlan, replacement: DayPlan) -> DayPlan {
        let protected = current.tasks.filter {
            $0.status == .completed || $0.status == .active || $0.externalSource != nil ||
            $0.externalImportance == .important || $0.timelineLocked == true || $0.flexible == false
        }
        let protectedTitles = Set(protected.map { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        var result = replacement
        result.id = current.id
        result.tasks = (protected + replacement.tasks.filter { !protectedTitles.contains($0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) })
            .sorted { (TimeMath.minutes($0.startTime) ?? 1440) < (TimeMath.minutes($1.startTime) ?? 1440) }
        result.mode = current.mode
        return result
    }

    static func suggestedSubtasks(for title: String) -> [TaskSubtask] {
        let lower = title.lowercased()
        if lower.contains("presentation") || lower.contains("презентац") {
            return ["Define the key message", "Write the outline", "Create slides", "Add visuals", "Review and rehearse"].map { TaskSubtask(title: $0) }
        }
        if lower.contains("clean") {
            return ["Prepare supplies", "Clear surfaces", "Clean main area", "Put items back", "Final check"].map { TaskSubtask(title: $0) }
        }
        return ["Define the first visible step", "Do the core work", "Check the result"].map { TaskSubtask(title: $0) }
    }

    static func recurrenceDates(for task: PlannerTask, horizonDays: Int = 90) -> [String] {
        guard let recurrence = task.recurrence, recurrence != .none,
              let start = DateKey.date(task.planDate) else { return [] }
        let calendar = Calendar.current
        let limit = calendar.date(byAdding: .day, value: max(1, horizonDays), to: start) ?? start
        let until = task.recurrenceUntil.flatMap(DateKey.date)
        var result: [String] = []

        func allowed(_ date: Date) -> Bool {
            if date <= start { return false }
            if date > limit { return false }
            if let until, date > until { return false }
            return true
        }

        switch recurrence {
        case .none:
            break
        case .daily:
            var cursor = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            while allowed(cursor) {
                result.append(DateKey.string(cursor))
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? limit.addingTimeInterval(86400)
            }
        case .weekdays:
            var cursor = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            while allowed(cursor) {
                let weekday = calendar.component(.weekday, from: cursor)
                if (2...6).contains(weekday) { result.append(DateKey.string(cursor)) }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? limit.addingTimeInterval(86400)
            }
        case .weekly, .biweekly:
            let stride = recurrence == .weekly ? 7 : 14
            if let days = task.recurrenceDays, !days.isEmpty {
                var cursor = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                while allowed(cursor) {
                    let weekday = calendar.component(.weekday, from: cursor)
                    let daysFromStart = calendar.dateComponents([.day], from: start, to: cursor).day ?? 0
                    let weekIndex = daysFromStart / 7
                    let strideOK = recurrence == .weekly || weekIndex % 2 == 0
                    if days.contains(weekday), strideOK { result.append(DateKey.string(cursor)) }
                    cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? limit.addingTimeInterval(86400)
                }
            } else {
                var cursor = calendar.date(byAdding: .day, value: stride, to: start) ?? start
                while allowed(cursor) {
                    result.append(DateKey.string(cursor))
                    cursor = calendar.date(byAdding: .day, value: stride, to: cursor) ?? limit.addingTimeInterval(86400)
                }
            }
        case .monthly:
            var step = 1
            while let cursor = calendar.date(byAdding: .month, value: step, to: start), allowed(cursor) {
                result.append(DateKey.string(cursor))
                step += 1
            }
        case .yearly:
            var step = 1
            while let cursor = calendar.date(byAdding: .year, value: step, to: start), allowed(cursor) {
                result.append(DateKey.string(cursor))
                step += 1
            }
        case .custom:
            let interval = max(1, task.recurrenceInterval ?? 1)
            let unit = task.recurrenceUnit ?? .days
            let component: Calendar.Component = switch unit {
            case .days: .day
            case .weeks: .weekOfYear
            case .months: .month
            }
            var step = interval
            while let cursor = calendar.date(byAdding: component, value: step, to: start), allowed(cursor) {
                result.append(DateKey.string(cursor))
                step += interval
            }
        }
        return result.filter { !(task.recurrenceExcludedDates ?? []).contains($0) }
    }

    static func recurringInstances(from master: PlannerTask, horizonDays: Int = 90) -> [PlannerTask] {
        let seriesID = master.recurrenceSeriesId ?? master.id
        return recurrenceDates(for: master, horizonDays: horizonDays).map { date in
            var copy = master
            copy.id = "recurrence-\(seriesID)-\(date)"
            copy.planDate = date
            copy.status = .pending
            copy.completedAt = nil
            copy.skippedReason = nil
            copy.externalId = nil
            copy.externalSource = nil
            copy.externalCalendarName = nil
            copy.externalLastModified = nil
            copy.recurrenceSeriesId = seriesID
            copy.recurrenceGenerated = true
            copy.recurrenceException = nil
            copy.recurrenceExcludedDates = nil
            copy.actualStartedAt = nil
            copy.autoCompletionSuppressed = nil
            copy.manualOrder = nil
            copy.timelineOriginalStartTime = nil
            copy.timelineOriginalEndTime = nil
            copy.subtasks = master.subtasks?.map { TaskSubtask(title: $0.title) }
            return copy
        }
    }


    static func reflowAroundExternalCommitments(_ plan: DayPlan) -> DayPlan {
        let fixed = plan.tasks.filter {
            $0.externalSource != nil && $0.allDay != true && TimeMath.minutes($0.startTime) != nil
        }.sorted { (TimeMath.minutes($0.startTime) ?? 1440) < (TimeMath.minutes($1.startTime) ?? 1440) }
        guard !fixed.isEmpty else { return plan }

        var result = plan
        for index in result.tasks.indices {
            guard result.tasks[index].externalSource == nil,
                  result.tasks[index].allDay != true,
                  result.tasks[index].status != .completed,
                  var start = TimeMath.minutes(result.tasks[index].startTime) else { continue }
            let duration = max(5, result.tasks[index].durationMinutes)
            var changed = false
            var searching = true
            while searching {
                searching = false
                let end = start + duration
                for commitment in fixed {
                    guard let fixedStart = TimeMath.minutes(commitment.startTime) else { continue }
                    let fixedEnd = TimeMath.minutes(commitment.endTime) ?? fixedStart + commitment.durationMinutes
                    if start < fixedEnd && end > fixedStart {
                        start = fixedEnd + 5
                        changed = true
                        searching = true
                        break
                    }
                }
            }
            if changed {
                result.tasks[index].startTime = TimeMath.string(start)
                result.tasks[index].endTime = TimeMath.string(start + duration)
                result.tasks[index].section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
            }
        }
        return result
    }

}
