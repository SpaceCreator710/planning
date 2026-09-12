import ActivityKit
import Foundation

struct SharedSubtaskSummary: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var completed: Bool
}

struct SharedTaskSummary: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var time: String?
    var icon: String
    var completed: Bool
    var subtasks: [SharedSubtaskSummary] = []
}

struct SharedPlannerSnapshot: Codable, Hashable {
    var date: String
    var title: String
    var nextTaskTitle: String?
    var nextTaskTime: String?
    var nextTaskIcon: String?
    var completed: Int
    var total: Int
    var updatedAt: Date
    var tasks: [SharedTaskSummary] = []
    var inboxTitles: [String] = []
    // Optional for compatibility with widget snapshots created by older app builds.
    var accentRGB: [Double]? = nil
}

enum SharedPlannerActionKind: String, Codable, Hashable {
    case completeTask
    case completeSubtask
    case skipTask
    case addInbox
}

struct SharedPlannerAction: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    var kind: SharedPlannerActionKind
    var taskID: String?
    var subtaskID: String?
    var text: String?
    var createdAt = Date()
}

enum SharedActionQueue {
    private static let key = "planner-pending-actions"

    static func enqueue(_ action: SharedPlannerAction) {
        let defaults = UserDefaults(suiteName: appGroupID)
        var actions = load(from: defaults)
        actions.append(action)
        if let raw = try? JSONEncoder().encode(actions) { defaults?.set(raw, forKey: key) }
    }

    static func drain() -> [SharedPlannerAction] {
        let defaults = UserDefaults(suiteName: appGroupID)
        let actions = load(from: defaults)
        defaults?.removeObject(forKey: key)
        return actions
    }

    private static func load(from defaults: UserDefaults?) -> [SharedPlannerAction] {
        guard let raw = defaults?.data(forKey: key), let actions = try? JSONDecoder().decode([SharedPlannerAction].self, from: raw) else { return [] }
        return actions
    }
}


enum SharedDataFile {
    static let filename = "app-data-v4.json"
    static func timestamp(after previous: String? = nil) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let old = previous.flatMap { f.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } ?? .distantPast
        return f.string(from: max(.now, old.addingTimeInterval(0.002)))
    }

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(filename)
    }

    static func read() -> Data? {
        guard let url else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    @discardableResult
    static func mutate(_ body: (inout [String: Any]) -> Bool) -> Bool {
        guard let url, let raw = try? Data(contentsOf: url),
              var root = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any],
              body(&root),
              let encoded = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]) else { return false }
        do {
            try encoded.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}

enum SharedPlannerPersistence {
    @discardableResult
    static func completeTask(_ id: String) -> Bool {
        SharedDataFile.mutate { root in
            guard updateTask(id, root: &root, status: "completed") else { return false }
            root["lastModifiedAt"] = SharedDataFile.timestamp(after: root["lastModifiedAt"] as? String)
            return true
        }
    }

    @discardableResult
    static func completeSubtask(taskID: String, subtaskID: String) -> Bool {
        SharedDataFile.mutate { root in
            guard var plans = root["plans"] as? [[String: Any]] else { return false }
            for planIndex in plans.indices {
                guard var tasks = plans[planIndex]["tasks"] as? [[String: Any]],
                      let taskIndex = tasks.firstIndex(where: { ($0["id"] as? String) == taskID }),
                      var subtasks = tasks[taskIndex]["subtasks"] as? [[String: Any]],
                      let subtaskIndex = subtasks.firstIndex(where: { ($0["id"] as? String) == subtaskID }) else { continue }
                subtasks[subtaskIndex]["completed"] = true
                tasks[taskIndex]["subtasks"] = subtasks
                plans[planIndex]["tasks"] = tasks
                root["plans"] = plans
                root["lastModifiedAt"] = SharedDataFile.timestamp(after: root["lastModifiedAt"] as? String)
                return true
            }
            return false
        }
    }

    @discardableResult
    static func skipTask(_ id: String) -> Bool {
        SharedDataFile.mutate { root in
            guard updateTask(id, root: &root, status: "skipped") else { return false }
            root["lastModifiedAt"] = SharedDataFile.timestamp(after: root["lastModifiedAt"] as? String)
            return true
        }
    }

    @discardableResult
    static func addInbox(_ title: String) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return SharedDataFile.mutate { root in
            var inbox = root["inbox"] as? [[String: Any]] ?? []
            inbox.append([
                "id": UUID().uuidString,
                "title": clean,
                "createdAt": ISO8601DateFormatter().string(from: .now)
            ])
            root["inbox"] = inbox
            root["lastModifiedAt"] = SharedDataFile.timestamp(after: root["lastModifiedAt"] as? String)
            return true
        }
    }

    private static func updateTask(_ id: String, root: inout [String: Any], status: String) -> Bool {
        guard var plans = root["plans"] as? [[String: Any]] else { return false }
        for planIndex in plans.indices {
            guard var tasks = plans[planIndex]["tasks"] as? [[String: Any]],
                  let taskIndex = tasks.firstIndex(where: { ($0["id"] as? String) == id }) else { continue }
            tasks[taskIndex]["status"] = status
            if status == "completed" {
                tasks[taskIndex]["completedAt"] = ISO8601DateFormatter().string(from: .now)
            } else if status == "skipped" {
                tasks[taskIndex]["skippedReason"] = "Skipped from widget or system control"
            }
            plans[planIndex]["tasks"] = tasks
            root["plans"] = plans
            return true
        }
        return false
    }
}

struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskTitle: String
        var startDate: Date
        var endDate: Date
    }
    var taskID: String
    var icon: String
}
