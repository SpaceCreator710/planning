import Foundation

enum DateKey {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    static var today: String { formatter.string(from: .now) }
    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
    static func startOfDay(_ key: String) -> Date { date(key) ?? Calendar.current.startOfDay(for: .now) }
}

enum TimeMath {
    static func minutes(_ time: String?) -> Int? {
        guard let time else { return nil }
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
    static func string(_ minutes: Int) -> String {
        let bounded = max(0, min(1439, minutes))
        return String(format: "%02d:%02d", bounded / 60, bounded % 60)
    }
    /// A clock value that can cross midnight while keeping the task duration intact.
    static func clockString(_ minutes: Int) -> String {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }
    static var nowMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}


enum TaskTimelineOrder {
    static func sortMinute(_ task: PlannerTask) -> Int {
        if task.allDay == true { return -1 }
        if let minute = TimeMath.minutes(task.startTime) { return minute }
        return 2_000
    }

    static func less(_ lhs: PlannerTask, _ rhs: PlannerTask) -> Bool {
        let left = sortMinute(lhs)
        let right = sortMinute(rhs)
        if left != right { return left < right }

        if let leftOrder = lhs.manualOrder, let rightOrder = rhs.manualOrder, leftOrder != rightOrder {
            return leftOrder < rightOrder
        }
        return lhs.id < rhs.id
    }

    static func sorted(_ tasks: [PlannerTask]) -> [PlannerTask] {
        // Preserve explicit saved/user order when times match so
        // refresh, sync and completion cannot reshuffle the user's sequence.
        tasks.enumerated().sorted { left, right in
            let leftMinute = sortMinute(left.element)
            let rightMinute = sortMinute(right.element)
            if leftMinute != rightMinute { return leftMinute < rightMinute }
            let leftOrder = left.element.manualOrder ?? left.offset
            let rightOrder = right.element.manualOrder ?? right.offset
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            return left.offset < right.offset
        }.map(\.element)
    }
}

enum TimelineDateMath {
    static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let mondayOffset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -mondayOffset, to: start) ?? start
    }

    static func shifted(_ date: Date, days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}

enum TimeIntervals {
    static func totalDuration(_ intervals: [(Date, Date)]) -> TimeInterval {
        let ordered = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        guard var current = ordered.first else { return 0 }
        var total: TimeInterval = 0
        for interval in ordered.dropFirst() {
            if interval.0 <= current.1 { current.1 = max(current.1, interval.1) }
            else { total += current.1.timeIntervalSince(current.0); current = interval }
        }
        return total + current.1.timeIntervalSince(current.0)
    }
}

/// Three-way Undo restores the confirmed operation without erasing later unrelated edits.
/// Collections are matched by stable IDs, including tasks moved between different days.
enum SnapshotUndo {
    private indirect enum Value: Codable, Equatable {
        case object([String: Value]), array([Value]), string(String), number(Double), bool(Bool), null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null }
            else if let value = try? container.decode(Bool.self) { self = .bool(value) }
            else if let value = try? container.decode(Double.self) { self = .number(value) }
            else if let value = try? container.decode(String.self) { self = .string(value) }
            else if let value = try? container.decode([Value].self) { self = .array(value) }
            else { self = .object(try container.decode([String: Value].self)) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .object(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }

        var id: String? {
            guard case .object(let fields) = self, case .string(let id) = fields["id"] else { return nil }
            return id
        }
    }

    static func restoring(before: AppData, after: AppData, current: AppData) -> AppData {
        do {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            func value<T: Encodable>(_ object: T) throws -> Value {
                try decoder.decode(Value.self, from: encoder.encode(object))
            }
            let merged = revert(before: try value(before), after: try value(after), current: try value(current))
            guard let merged else { return current }
            var result = try decoder.decode(AppData.self, from: encoder.encode(merged))

            // Flatten first so a move is an edit to one task, not a deletion plus a creation.
            let taskValue = revert(
                before: try value(before.plans.flatMap(\.tasks)),
                after: try value(after.plans.flatMap(\.tasks)),
                current: try value(current.plans.flatMap(\.tasks))
            ) ?? .array([])
            let tasks = try decoder.decode([PlannerTask].self, from: encoder.encode(taskValue))
            for index in result.plans.indices { result.plans[index].tasks = [] }
            for task in tasks {
                if let index = result.plans.firstIndex(where: { $0.date == task.planDate }) {
                    result.plans[index].tasks.append(task)
                } else {
                    result.plans.append(DayPlan(date: task.planDate, tasks: [task]))
                }
            }
            // Billing, audit history and sync clocks are never rolled back by content Undo.
            result.subscription = current.subscription
            result.events = current.events
            result.lastModifiedAt = current.lastModifiedAt
            return result
        } catch {
            // A failed decode must preserve the latest data, never restore an entire stale file.
            return current
        }
    }

    private static func revert(before: Value?, after: Value?, current: Value?) -> Value? {
        if before == after { return current }
        if current == after { return before }
        if case .object(let old) = before, case .object(let applied) = after, case .object(var latest) = current {
            for key in Set(old.keys).union(applied.keys) {
                latest[key] = revert(before: old[key], after: applied[key], current: latest[key])
            }
            return .object(latest)
        }
        if case .array(let old) = before, case .array(let applied) = after, case .array(let latest) = current,
           (old + applied + latest).allSatisfy({ $0.id != nil }) {
            func index(_ values: [Value]) -> [String: Value] {
                values.reduce(into: [:]) { result, item in if let id = item.id { result[id] = item } }
            }
            let oldIndex = index(old), appliedIndex = index(applied), latestIndex = index(latest)
            var result: [Value] = []
            var visited = Set<String>()
            for item in latest + old {
                guard let id = item.id, visited.insert(id).inserted else { continue }
                if let restored = revert(before: oldIndex[id], after: appliedIndex[id], current: latestIndex[id]) {
                    result.append(restored)
                }
            }
            return .array(result)
        }
        return current
    }
}

enum SnapshotClock {
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    static func stamp(after previous: String? = nil, now: Date = .now) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: max(now, (date(previous) ?? .distantPast).addingTimeInterval(0.002)))
    }
}

enum TaskSchedule {
    static func endMinute(_ task: PlannerTask) -> Int? {
        guard let start = TimeMath.minutes(task.startTime) else { return nil }
        guard let end = TimeMath.minutes(task.endTime), end != start else { return start + max(5, task.durationMinutes) }
        return end < start ? end + 1440 : end
    }
    static func endDate(_ task: PlannerTask, calendar: Calendar = .current) -> Date? {
        guard let day = DateKey.date(task.planDate), let end = endMinute(task),
              let endDay = calendar.date(byAdding: .day, value: end / 1440, to: calendar.startOfDay(for: day)) else { return nil }
        return calendar.date(bySettingHour: (end % 1440) / 60, minute: end % 60, second: 0, of: endDay)
    }
    static func shouldAutoComplete(_ task: PlannerTask, now: Date) -> Bool {
        guard task.status == .pending || task.status == .active, task.externalSource == nil,
              task.timelineLocked != true, task.autoCompletionSuppressed != true, task.allDay != true,
              let end = endDate(task) else { return false }
        return end <= now
    }
}

enum TimelinePlacement {
    static func nextAvailableStart(for task: PlannerTask, on date: String, requestedStart: Int, plans: [DayPlan]) -> Int? {
        guard (0..<1440).contains(requestedStart), let day = DateKey.date(date) else { return nil }
        var blockers: [(Int, Int)] = []
        for other in plans.flatMap(\.tasks) {
            guard other.id != task.id, other.status != .skipped, other.allDay != true,
                  let start = TimeMath.minutes(other.startTime), let end = TaskSchedule.endMinute(other),
                  let otherDay = DateKey.date(other.planDate),
                  let offset = Calendar.current.dateComponents([.day], from: day, to: otherDay).day else { continue }
            blockers.append((offset * 1440 + start, offset * 1440 + end))
        }
        blockers.sort { $0.0 < $1.0 }
        var proposed = requestedStart
        for blocker in blockers where proposed < blocker.1 && proposed + max(5, task.durationMinutes) > blocker.0 {
            proposed = blocker.1
            if proposed >= 1440 { return nil }
        }
        return proposed
    }
}

enum ContextSelection {
    static func ranked<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        let terms = Array(Set(query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 1 }.map(String.init))).prefix(64)
        var scored: [(Int, Int, T)] = []
        for (index, item) in items.enumerated() {
            let value = text(item).lowercased()
            var score = 0
            for term in terms where value.contains(term) { score += 1 }
            scored.append((index, score, item))
        }
        scored.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
        return scored.map { $0.2 }
    }
    static func bounded(_ value: String, bytes: Int) -> String {
        var raw = Array(value.utf8.prefix(max(0, bytes)))
        for _ in 0...3 {
            if let result = String(bytes: raw, encoding: .utf8) { return result }
            if !raw.isEmpty { raw.removeLast() }
        }
        return ""
    }
}


/// Calendar grids use the locale's first weekday and calendar arithmetic across DST.
enum CalendarProjection {
    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -offset, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
