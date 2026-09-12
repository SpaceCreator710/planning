import Foundation
import SwiftData

// Generated from the active CODE_SIGN_ENTITLEMENTS at build time. This is a
// configuration preflight, not a replacement for iOS code-signature validation.
// Missing/malformed configuration must never initialize CloudKit.
enum PlanningCloudConfiguration {
    static var containerIdentifier: String? {
        guard let url = Bundle.main.url(forResource: "PlanningCapabilities", withExtension: "plist"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return containerIdentifier(in: raw)
    }

    static func containerIdentifier(in raw: Data) -> String? {
        guard let object = try? PropertyListSerialization.propertyList(from: raw, format: nil),
              let entitlements = object as? [String: Any],
              let services = entitlements["com.apple.developer.icloud-services"] as? [String],
              services.contains("CloudKit"),
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String]
        else { return nil }
        let usable = containers.filter {
            $0.hasPrefix("iCloud.") && $0.count > "iCloud.".count &&
            !$0.contains("$") && !$0.contains("*") && !$0.contains(where: { $0.isWhitespace })
        }
        let original = "iCloud.com.aiplanyourday.app"
        return usable.contains(original) ? original : usable.first
    }
}

@Model
final class CloudAppSnapshot {
    var key: String = "primary"
    var payload: Data = Data()
    var updatedAt: Date = Date()
    var revision: String = UUID().uuidString

    init(key: String = "primary", payload: Data, updatedAt: Date = .now, revision: String = UUID().uuidString) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
        self.revision = revision
    }
}

private enum FastBootstrapCache {
    private static let filename = "app-data-fast-bootstrap.plist"

    static var url: URL? {
        if let shared = SharedDataFile.url {
            return shared.deletingLastPathComponent().appendingPathComponent(filename)
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIPlanYourDay", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(filename)
    }

    static func readIfCurrent() -> AppData? {
        guard let cacheURL = url, FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        if let jsonURL = SharedDataFile.url,
           let jsonDate = (try? jsonURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           let cacheDate = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           jsonDate > cacheDate {
            return nil
        }
        guard let raw = try? Data(contentsOf: cacheURL, options: .mappedIfSafe) else { return nil }
        return try? PropertyListDecoder().decode(AppData.self, from: raw)
    }

    static func write(_ data: AppData) {
        guard let url else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

actor PersistenceService {
    static let shared = PersistenceService()

    // On-device persistence is machine data, so keep it compact. Pretty-printing and sorting
    // every key added CPU work and file I/O to every save, and made the next launch read more
    // bytes. Human-readable formatting is kept only for explicit exports below.
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cloudContainer: ModelContainer?
    private var didInitializeCloudContainer = false

    init() {}

    private var fileURL: URL {
        if let sharedURL = SharedDataFile.url {
            migrateLegacyFileIfNeeded(to: sharedURL)
            return sharedURL
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIPlanYourDay", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(SharedDataFile.filename)
    }

    private func migrateLegacyFileIfNeeded(to destination: URL) {
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIPlanYourDay", isDirectory: true)
        let legacy = root.appendingPathComponent(SharedDataFile.filename)
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        try? FileManager.default.copyItem(at: legacy, to: destination)
    }

    /// Save only the on-device snapshot. Used for deferred launch maintenance where forcing
    /// CloudKit initialization would defeat the purpose of keeping startup lightweight.
    func saveLocalSnapshot(_ data: AppData) throws {
        try saveLocal(data)
    }

    nonisolated static func fastBootstrapSnapshot() -> AppData? {
        FastBootstrapCache.readIfCurrent()
    }

    func load() -> AppData {
        let local = loadLocal()
        guard local.settings.iCloudSyncEnabled != false,
              let cloud = loadCloud(),
              isNewer(cloud, than: local) else {
            return local
        }
        try? saveLocal(cloud)
        return cloud
    }

    func save(_ data: AppData) throws {
        guard try saveLocal(data) else { return }
        if data.settings.iCloudSyncEnabled != false {
            try? saveCloud(data)
        }
    }

    func importLegacyJSON(from url: URL) throws -> AppData {
        let raw = try Data(contentsOf: url)
        return try decoder.decode(AppData.self, from: raw)
    }

    func exportJSON(_ data: AppData) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Planning-export-\(DateKey.today).json")
        let exportEncoder = JSONEncoder()
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try exportEncoder.encode(data).write(to: url, options: .atomic)
        return url
    }

    func cloudStatus() -> Bool { cloudContainerIfNeeded() != nil }

    private func loadLocal() -> AppData {
        guard let raw = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              let decoded = try? decoder.decode(AppData.self, from: raw) else {
            return AppData()
        }
        return decoded
    }

    @discardableResult
    private func saveLocal(_ data: AppData) throws -> Bool {
        if let existing = try? Data(contentsOf: fileURL), let saved = try? decoder.decode(AppData.self, from: existing),
           let savedTime = SnapshotClock.date(saved.lastModifiedAt), let incomingTime = SnapshotClock.date(data.lastModifiedAt), savedTime > incomingTime { return false }
        let raw = try encoder.encode(data)
        try raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Binary plist decode is materially cheaper than decoding the full JSON model on a cold launch.
        // The JSON remains canonical for widgets/App Intents; mtime checks prevent stale cache use.
        FastBootstrapCache.write(data)
        return true
    }

    private func cloudContainerIfNeeded() -> ModelContainer? {
        guard let containerID = PlanningCloudConfiguration.containerIdentifier else { return nil }
        if !didInitializeCloudContainer {
            didInitializeCloudContainer = true
            let configuration = ModelConfiguration(cloudKitDatabase: .private(containerID))
            cloudContainer = try? ModelContainer(for: CloudAppSnapshot.self, configurations: configuration)
        }
        return cloudContainer
    }

    private func loadCloud() -> AppData? {
        guard let cloudContainer = cloudContainerIfNeeded() else { return nil }
        let context = ModelContext(cloudContainer)
        var descriptor = FetchDescriptor<CloudAppSnapshot>(
            predicate: #Predicate { $0.key == "primary" },
            sortBy: [SortDescriptor(\CloudAppSnapshot.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let snapshot = try? context.fetch(descriptor).first,
              let decoded = try? decoder.decode(AppData.self, from: snapshot.payload) else {
            return nil
        }
        return decoded
    }

    private func saveCloud(_ data: AppData) throws {
        guard let cloudContainer = cloudContainerIfNeeded() else { return }
        let context = ModelContext(cloudContainer)
        let descriptor = FetchDescriptor<CloudAppSnapshot>(
            predicate: #Predicate { $0.key == "primary" },
            sortBy: [SortDescriptor(\CloudAppSnapshot.updatedAt, order: .reverse)]
        )
        let snapshots = try context.fetch(descriptor)
        let raw = try encoder.encode(data)
        if let snapshot = snapshots.first {
            snapshot.payload = raw
            snapshot.updatedAt = .now
            snapshot.revision = UUID().uuidString
            // CloudKit does not support SwiftData uniqueness constraints. Keep a single
            // canonical snapshot explicitly so duplicate rows cannot accumulate after sync.
            for duplicate in snapshots.dropFirst() { context.delete(duplicate) }
        } else {
            context.insert(CloudAppSnapshot(payload: raw))
        }
        try context.save()
    }

    private func isNewer(_ candidate: AppData, than baseline: AppData) -> Bool {
        guard let candidateString = candidate.lastModifiedAt,
              let candidateDate = SnapshotClock.date(candidateString) else {
            return baseline.plans.isEmpty && !candidate.plans.isEmpty
        }
        guard let baselineString = baseline.lastModifiedAt,
              let baselineDate = SnapshotClock.date(baselineString) else {
            return true
        }
        return candidateDate > baselineDate
    }
}
