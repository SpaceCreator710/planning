import Foundation

struct BodyRhythmSignal: Hashable {
    enum Phase: String, Hashable { case reset, build, peak, restore }
    var day: Int
    var phase: Phase
    var guidance: String
}

struct ScheduleCollision: Identifiable, Hashable {
    enum Severity: String, Hashable { case medium, high }
    var id: String
    var severity: Severity
    var title: String
    var detail: String
}

struct PlanDNA: Hashable {
    var confidence: Int
    var sampleSize: Int
    var strongestWindow: DaySection?
    var strongestCategory: TaskCategory?
    var idealBlockMinutes: Int
    var completionRate: Int
    var experiment: String
}

struct RealitySignal: Hashable {
    enum State: String, Hashable { case empty, onTrack = "on-track", drifting, overloaded, recovered, complete }
    var state: State
    var score: Int
    var title: String
    var message: String
    var overdueMinutes: Int
    var skippedCount: Int
    var recovery: RescueInput?
}

enum InsightsEngine {
    static func bodyRhythm(profile: UserProfile, now: Date = .now) -> BodyRhythmSignal? {
        guard profile.bodyRhythmEnabled, let start = DateKey.date(profile.cycleStartDate) else { return nil }
        let length = max(20, min(45, profile.cycleLengthDays))
        let elapsed = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: now)).day ?? 0
        let normalized = ((elapsed % length) + length) % length
        let day = normalized + 1
        if day <= profile.cyclePeriodDays {
            return .init(day: day, phase: .reset, guidance: "Consider lower load, more recovery margin and shorter focus blocks.")
        }
        if day <= Int(floor(Double(length) * 0.45)) {
            return .init(day: day, phase: .build, guidance: "A steady build window: protect learning and progressive work.")
        }
        if day <= Int(floor(Double(length) * 0.60)) {
            return .init(day: day, phase: .peak, guidance: "If your energy agrees, place one demanding or social task here.")
        }
        return .init(day: day, phase: .restore, guidance: "Reduce overbooking and leave a larger buffer around the must-win.")
    }

    static func capacity(from snapshot: HealthSnapshot) -> CapacitySignal {
        guard snapshot.available, snapshot.sleepHours > 0 else {
            return CapacitySignal(score: 0, level: "unknown", summary: "Not enough shared sleep data to estimate planning capacity.", suggestedFocusMinutes: 25, sourceDate: snapshot.lastUpdated)
        }
        let sleepScore = snapshot.sleepHours <= 0 ? 58.0 : max(25, min(100, (snapshot.sleepHours / 8.0) * 100))
        let movementScore = max(35, min(100, 45 + Double(snapshot.exerciseMinutes) * 1.1 + min(20, Double(snapshot.steps) / 500.0)))
        let score = Int((sleepScore * 0.72 + movementScore * 0.28).rounded())
        let level = score < 58 ? "recover" : score < 78 ? "steady" : "strong"
        let summary: String
        switch level {
        case "recover": summary = "Protect essentials, shorten focus blocks, and add recovery margin."
        case "steady": summary = "Use a realistic workload with normal transition buffers."
        default: summary = "Capacity looks strong; protect one demanding block without filling every free minute."
        }
        return CapacitySignal(score: score, level: level, summary: summary, suggestedFocusMinutes: level == "recover" ? 20 : level == "steady" ? 40 : 55, sourceDate: snapshot.lastUpdated)
    }

    static func scheduleCollisions(plan: DayPlan?, capacity: CapacitySignal?) -> [ScheduleCollision] {
        guard let plan else { return [] }
        var collisions: [ScheduleCollision] = []
        let tasks = plan.tasks.filter {
            ($0.status == .pending || $0.status == .active) && $0.allDay != true && TimeMath.minutes($0.startTime) != nil
        }.sorted { (TimeMath.minutes($0.startTime) ?? 0) < (TimeMath.minutes($1.startTime) ?? 0) }
        for (index, task) in tasks.enumerated() {
            guard let end = TaskSchedule.endMinute(task) else { continue }
            for next in tasks.dropFirst(index + 1) {
                guard let start = TimeMath.minutes(next.startTime), start < end else { break }
                collisions.append(.init(id: task.id + "-" + next.id, severity: .medium, title: "Time overlap", detail: "\(task.title) and \(next.title) share scheduled time. Your chosen times stay unchanged."))
                if collisions.count == 8 { return collisions }
            }
        }
        return collisions
    }

    static func planDNA(plans: [DayPlan]) -> PlanDNA {
        let tasks = plans.flatMap(\.tasks).filter { $0.status == .completed || $0.status == .skipped }
        let completed = tasks.filter { $0.status == .completed }
        let durations = completed.map(\.durationMinutes).filter { $0 >= 5 }.sorted()
        let median = durations.isEmpty ? 25 : durations[durations.count / 2]
        let strongestWindow: DaySection? = bestRate(tasks.map { ($0.section, $0.status == .completed) })
        let strongestCategory: TaskCategory? = bestRate(tasks.map { ($0.category, $0.status == .completed) })
        let ideal = max(10, min(90, Int((Double(median) / 5.0).rounded()) * 5))
        let rate = tasks.isEmpty ? 0 : Int((Double(completed.count) / Double(tasks.count) * 100).rounded())
        let experiment: String
        if let window = strongestWindow, let category = strongestCategory {
            experiment = "For seven days, place one \(ideal)-minute \(category.rawValue) block in the \(window.rawValue) and compare completion."
        } else {
            experiment = "Complete or skip five scheduled actions honestly to reveal your first reliable pattern."
        }
        return .init(confidence: min(100, Int((Double(tasks.count) * 6.5).rounded())), sampleSize: tasks.count, strongestWindow: strongestWindow, strongestCategory: strongestCategory, idealBlockMinutes: ideal, completionRate: rate, experiment: experiment)
    }

    static func reality(plan: DayPlan?, now: Date = .now) -> RealitySignal {
        guard let plan, !plan.tasks.isEmpty else {
            return .init(state: .empty, score: 0, title: "No reality signal yet", message: "Build a day and Drift Guard will compare the schedule with what actually happens.", overdueMinutes: 0, skippedCount: 0)
        }
        let currentMinute = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let completed = plan.tasks.filter { $0.status == .completed }.count
        let skipped = plan.tasks.filter { $0.status == .skipped }.count
        let unfinished = plan.tasks.filter { $0.status == .pending || $0.status == .active }
        let overdue = unfinished.reduce(0) { largest, task in
            guard let start = TimeMath.minutes(task.startTime) else { return largest }
            return max(largest, currentMinute - start)
        }
        let state: RealitySignal.State
        let recovery: RescueInput?
        if unfinished.isEmpty && completed > 0 {
            state = .complete; recovery = nil
        } else if plan.rescuedAt != nil {
            state = .recovered; recovery = nil
        } else if skipped >= 2 || overdue >= 75 {
            state = .overloaded; recovery = RescueInput(reason: "unexpected", energy: plan.energy <= 2 ? plan.energy : 3, availableMinutes: 60)
        } else if skipped > 0 || overdue >= 25 {
            state = .drifting; recovery = RescueInput(reason: "task-too-big", energy: plan.energy, availableMinutes: 10)
        } else {
            state = .onTrack; recovery = nil
        }
        let words: (String, String) = switch state {
        case .onTrack: ("You are on track", "The plan still matches reality. Protect the next block and keep the day simple.")
        case .drifting: ("Drift detected", "The schedule is slipping. A ten-minute launch is enough to regain momentum.")
        case .overloaded: ("Schedule review available", "Some blocks may overlap your available time. Your plan stays unchanged until you choose an adjustment.")
        case .recovered: ("Recovery plan active", "The day has already been repaired. Finish the protected action before adding anything.")
        case .complete: ("Day complete", "Real work is finished. Capture one lesson so tomorrow starts smarter.")
        case .empty: ("No reality signal yet", "Build a day first.")
        }
        let completionBoost = Int((Double(completed) / Double(max(1, plan.tasks.count)) * 18).rounded())
        let rawScore = plan.planScore + completionBoost - skipped * 12 - max(0, overdue) / 4
        let score = state == .complete ? 100 : max(5, min(99, rawScore))
        return .init(state: state, score: score, title: words.0, message: words.1, overdueMinutes: max(0, overdue), skippedCount: skipped, recovery: recovery)
    }

    private static func bestRate<K: Hashable>(_ items: [(K, Bool)]) -> K? {
        var groups: [K: (total: Int, completed: Int)] = [:]
        for (key, done) in items {
            var score = groups[key] ?? (0, 0)
            score.total += 1
            if done { score.completed += 1 }
            groups[key] = score
        }
        return groups.filter { $0.value.total >= 2 }.max {
            Double($0.value.completed) / Double($0.value.total) < Double($1.value.completed) / Double($1.value.total)
        }?.key
    }
}
