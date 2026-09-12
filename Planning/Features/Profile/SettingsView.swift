import SwiftUI
import UniformTypeIdentifiers
import UIKit


private enum SettingsArea: String, CaseIterable, Identifiable {
    case appearance = "Appearance", planning = "Planner", intelligence = "AI & Memory"
    case notifications = "Notifications", wellbeing = "Wellbeing", data = "Data & Sync"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .planning: "calendar"
        case .intelligence: "sparkles"
        case .notifications: "bell"
        case .wellbeing: "heart"
        case .data: "icloud"
        }
    }
    var detail: String {
        switch self {
        case .appearance: "Theme, color, typography, app icon and haptics"
        case .planning: "Timeline, completion, buffers, locks and intelligence"
        case .intelligence: "App mode, AI mode, learning, memory and tutor"
        case .notifications: "Task alerts, morning reminders and evening review"
        case .wellbeing: "Optional body rhythm context"
        case .data: "iCloud, account sync, import and export"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    private var areas: [SettingsArea] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return SettingsArea.allCases.filter { query.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if search.isEmpty { AppearancePreview() }
                ForEach(areas) { area in
                    NavigationLink { SettingsDetailView(area: area) } label: {
                        PlanningDestinationRow(title: area.rawValue, subtitle: area.detail, symbol: area.symbol, detail: status(area))
                    }.buttonStyle(.plain)
                }
                if areas.isEmpty { ContentUnavailableView.search(text: search) }
            }.padding(18).padding(.bottom, 28)
        }
        .appCanvas().navigationTitle("Settings")
        .searchable(text: $search, prompt: "Find a setting")
    }
    private func status(_ area: SettingsArea) -> String? {
        switch area {
        case .appearance: return store.data.settings.theme.rawValue.capitalized + " · " + store.data.settings.accentTheme.rawValue.capitalized
        case .planning: return (store.data.settings.timelineLayout ?? .horizontal).label
        case .intelligence: return store.data.settings.globalMemoryEnabled == false ? "Memory off" : "Memory on"
        case .notifications: return store.data.settings.notificationsEnabled ? "On" : "Off"
        case .data: return store.syncMessage
        case .wellbeing: return store.data.profile.bodyRhythmEnabled ? "On" : "Off"
        }
    }
}

private struct SettingsDetailView: View {
    let area: SettingsArea
    @Environment(AppStore.self) private var store
    @State private var importing = false
    @State private var importMessage: String?
    @State private var notificationMessage: String?

    var body: some View {
        Form {
            settingsContent
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle(area.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
            handleImportResult(result)
        }
        .onDisappear { store.persist() }
        .onChange(of: store.data.settings.notificationsEnabled) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.taskReminders) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.morningPlanningReminder) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.morningPlanningTime) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.overdueReminder) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.eveningReview) { _, _ in Task { await store.refreshNotificationSchedules() } }
        .onChange(of: store.data.settings.eveningReviewTime) { _, _ in Task { await store.refreshNotificationSchedules() } }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch area {
        case .appearance:
            appearanceSettings
        case .planning:
            planningSettings
        case .intelligence:
            intelligenceSettings
        case .notifications:
            notificationSettings
        case .wellbeing:
            wellbeingSettings
        case .data:
            dataSettings
        }
    }

    @ViewBuilder
    private var appearanceSettings: some View {
        @Bindable var store = store
        Section {
            AppearancePreview()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }


        Section("Appearance") {
            Picker("Mode", selection: $store.data.settings.theme) {
                Label("Light", systemImage: "sun.max.fill").tag(ThemeMode.light)
                Label("Dark", systemImage: "moon.fill").tag(ThemeMode.dark)
                Label("System", systemImage: "iphone").tag(ThemeMode.system)
            }
            .pickerStyle(.segmented)

            Picker("Canvas", selection: $store.data.settings.canvasTheme) {
                ForEach(store.hasAccess(.premiumAppearance) ? CanvasTheme.allCases : [.none, .paper]) { theme in
                    Label(canvasName(theme), systemImage: themeIcon(theme)).tag(theme)
                }
            }
            if !store.hasAccess(.premiumAppearance) {
                NavigationLink { PaywallView() } label: { Label("Seasonal craft canvases · Pro", systemImage: "lock.fill") }
            }

            if store.data.settings.canvasTheme == .none {
                Label("Two-tone mode uses only pure white/black + your matte accent.", systemImage: "circle.lefthalf.filled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label("Seasonal canvases add subtle craft-paper grain and restrained tonal atmosphere.", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Picker("Accent", selection: $store.data.settings.accentTheme) {
                ForEach(AccentTheme.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .disabled(store.data.settings.customAccentEnabled)

            if store.hasAccess(.premiumAppearance) {
                Toggle("Custom matte accent", isOn: $store.data.settings.customAccentEnabled)
                if store.data.settings.customAccentEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hue · \(Int(store.data.settings.customAccentHue))°")
                        Slider(value: $store.data.settings.customAccentHue, in: 0...360, step: 1)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saturation · \(Int(store.data.settings.customAccentSaturation))%")
                        Slider(value: $store.data.settings.customAccentSaturation, in: 5...65, step: 1)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lightness · \(Int(store.data.settings.customAccentLightness))%")
                        Slider(value: $store.data.settings.customAccentLightness, in: 32...76, step: 1)
                    }
                }
            } else {
                NavigationLink { PaywallView() } label: { Label("Custom HSL matte accent · Pro", systemImage: "slider.horizontal.3") }
            }

            Picker("Visual energy", selection: $store.data.settings.visualEnergy) {
                ForEach(VisualEnergy.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Text size", selection: $store.data.settings.fontScale) {
                ForEach(FontScaleMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Font", selection: Binding(get: { store.data.settings.fontDesign ?? .system }, set: { store.data.settings.fontDesign = $0 })) {
                Label("System", systemImage: "textformat").tag(AppFontDesign.system)
                Label("Rounded", systemImage: "character.cursor.ibeam").tag(AppFontDesign.rounded)
                Label("Serif", systemImage: "textformat.size").tag(AppFontDesign.serif)
            }
        }


        Section("Interaction") {
            Toggle("Haptic feedback", isOn: Binding(
                get: { store.data.settings.hapticFeedbackEnabled != false },
                set: { store.data.settings.hapticFeedbackEnabled = $0 }
            ))
            Text("Planning stays silent. Important controls use subtle system haptics only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }


        Section("App Icon") {
            if store.hasAccess(.premiumAppearance) {
                AppIconPicker()
            } else {
                NavigationLink { PaywallView() } label: { Label("18 alternate matte icons · Pro", systemImage: "app.badge") }
            }
        }
    }

    @ViewBuilder
    private var planningSettings: some View {
        @Bindable var store = store
        Section("Timeline") {
            Picker("Layout", selection: Binding(
                get: { store.data.settings.timelineLayout ?? .horizontal },
                set: { store.data.settings.timelineLayout = $0 }
            )) {
                ForEach(TimelineLayoutStyle.selectableCases) { style in
                    Label(style.label, systemImage: style.symbol).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show connected Day Path", isOn: Binding(
                get: { store.data.settings.timelineShowDayPath != false },
                set: { store.data.settings.timelineShowDayPath = $0 }
            ))

            Toggle("Smart density", isOn: Binding(
                get: { store.data.settings.timelineSmartDensity != false },
                set: { store.data.settings.timelineSmartDensity = $0 }
            ))

            Toggle("Complete elapsed personal tasks", isOn: Binding(
                get: { store.data.settings.timelineAutoCompleteElapsedTasks != false },
                set: { store.data.settings.timelineAutoCompleteElapsedTasks = $0 }
            ))

            Toggle("Intelligence suggestions", isOn: Binding(
                get: { store.data.settings.timelineSuggestionsEnabled != false },
                set: { store.data.settings.timelineSuggestionsEnabled = $0 }
            ))

            Toggle("Reality", isOn: Binding(
                get: { store.data.settings.timelineRealityEnabled != false },
                set: { store.data.settings.timelineRealityEnabled = $0 }
            ))
            Toggle("Buffer Guard", isOn: Binding(
                get: { store.data.settings.timelineBufferGuardEnabled ?? false },
                set: { store.data.settings.timelineBufferGuardEnabled = $0 }
            ))
            Toggle("Auto Lock", isOn: Binding(
                get: { store.data.settings.timelineAutoLockEnabled ?? false },
                set: { store.data.settings.timelineAutoLockEnabled = $0 }
            ))
            Toggle("Deadline Radar", isOn: Binding(
                get: { store.data.settings.timelineDeadlineRadarEnabled != false },
                set: { store.data.settings.timelineDeadlineRadarEnabled = $0 }
            ))
            Toggle("Recovery Buffers", isOn: Binding(
                get: { store.data.settings.timelineRecoveryBuffersEnabled ?? false },
                set: { store.data.settings.timelineRecoveryBuffersEnabled = $0 }
            ))
            Toggle("Conflict Sweep", isOn: Binding(
                get: { store.data.settings.timelineConflictSweepEnabled ?? false },
                set: { store.data.settings.timelineConflictSweepEnabled = $0 }
            ))

            NavigationLink {
                TimelineFeaturesGuideView()
            } label: {
                Label("Timeline Features", systemImage: "info.circle")
            }
            NavigationLink {
                TimelineIntelligenceSettingsView()
            } label: {
                Label("Autopilot modules", systemImage: "brain.head.profile.fill")
            }

            Text("Planning Intelligence shows a preview first. Your schedule changes only after you confirm, and every applied change can be undone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var intelligenceSettings: some View {
        @Bindable var store = store
        Section("App Mode & Memory") {
            ExperienceModeGlassSwitcher()

            Text((store.data.settings.experienceMode ?? .planner).resolved.description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Memory across all modes", isOn: Binding(
                get: { store.data.settings.globalMemoryEnabled != false },
                set: { store.setGlobalMemoryEnabled($0) }
            ))

            if store.data.settings.globalMemoryEnabled == false {
                Label("Learned AI memory and cross-mode personalization are off. Your explicit tasks, pages, notes, projects and settings remain saved.", systemImage: "brain.head.profile.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if store.data.settings.globalMemoryEnabled != false {
                Toggle("Auto-learn patterns", isOn: $store.data.settings.autoLearn)
            }
            }
        }


        Section("AI") {
            Picker("Default AI mode", selection: Binding(
                get: { store.data.settings.aiAssistantMode ?? .planning },
                set: { store.data.settings.aiAssistantMode = $0 }
            )) {
                ForEach(AIAssistantMode.allCases) { Text($0.label).tag($0) }
            }

            if (store.data.settings.aiAssistantMode ?? .planning) == .school {
                Picker("Explanation level", selection: Binding(
                    get: { store.data.settings.studyExplanationLevel ?? .grade9 },
                    set: { store.data.settings.studyExplanationLevel = $0 }
                )) {
                    ForEach(StudyExplanationLevel.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Interactive one-step replies", isOn: Binding(
                    get: { store.data.settings.studyInteractiveSteps ?? true },
                    set: { store.data.settings.studyInteractiveSteps = $0 }
                ))
                Toggle("Text diagrams & graphs", isOn: Binding(
                    get: { store.data.settings.studyVisualizations ?? true },
                    set: { store.data.settings.studyVisualizations = $0 }
                ))
                Toggle("Check yourself", isOn: Binding(
                    get: { store.data.settings.studyCheckYourself ?? true },
                    set: { store.data.settings.studyCheckYourself = $0 }
                ))
            }

            if (store.data.settings.aiAssistantMode ?? .planning) == .planning {
                Picker("Coach style", selection: $store.data.settings.coachMode) {
                    ForEach(CoachMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Accountability", selection: $store.data.settings.accountability) {
                    ForEach(AccountabilityLevel.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
            }

            if store.data.settings.globalMemoryEnabled != false {
                Toggle("Auto-learn patterns", isOn: $store.data.settings.autoLearn)
            }
            Toggle("Safety guardrails", isOn: $store.data.settings.safeMode)
        }
    }

    @ViewBuilder
    private var notificationSettings: some View {
        @Bindable var store = store
        Section("Notifications") {
            Toggle("Notifications", isOn: $store.data.settings.notificationsEnabled)
            Toggle("Task reminders", isOn: $store.data.settings.taskReminders)
                .disabled(!store.data.settings.notificationsEnabled)

            Toggle("Morning planning", isOn: morningPlanningEnabledBinding)
                .disabled(!store.data.settings.notificationsEnabled)
            if store.data.settings.notificationsEnabled && (store.data.settings.morningPlanningReminder ?? false) {
                DatePicker("Planning time", selection: morningPlanningTimeBinding, displayedComponents: .hourAndMinute)
                Text("A quiet prompt to look at today before the day starts moving.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Toggle("Overdue rescue", isOn: overdueReminderBinding)
                .disabled(!store.data.settings.notificationsEnabled)
            if store.data.settings.notificationsEnabled && (store.data.settings.overdueReminder ?? false) {
                Text("One rescue prompt appears only after four unfinished timed tasks in a row have passed.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Toggle("Evening review", isOn: $store.data.settings.eveningReview)
                .disabled(!store.data.settings.notificationsEnabled)
            if store.data.settings.notificationsEnabled && store.data.settings.eveningReview {
                DatePicker("Review time", selection: eveningReviewBinding, displayedComponents: .hourAndMinute)
            }
            Button("Request notification access", systemImage: "bell.badge") {
                Task {
                    let granted = await store.requestNotificationAccess()
                    await MainActor.run { notificationMessage = granted ? "Notifications are enabled." : "Notification access was not granted." }
                }
            }
            .buttonStyle(.glass)
            if let notificationMessage { Text(notificationMessage).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder
    private var wellbeingSettings: some View {
        @Bindable var store = store
        Section("Optional Body Rhythm") {
            Toggle("Use body rhythm context", isOn: $store.data.profile.bodyRhythmEnabled)
            if store.data.profile.bodyRhythmEnabled {
                TextField("Start date · YYYY-MM-DD", text: $store.data.profile.cycleStartDate)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                Stepper("Cycle length · \(store.data.profile.cycleLengthDays) days", value: $store.data.profile.cycleLengthDays, in: 20...45)
                Stepper("Reset window · \(store.data.profile.cyclePeriodDays) days", value: $store.data.profile.cyclePeriodDays, in: 2...10)
                Text("This is optional planning context. It never replaces how you actually feel today.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dataSettings: some View {
        @Bindable var store = store
        Section("Sync") {
            Toggle("Apple iCloud sync", isOn: iCloudSyncBinding)
                .disabled(PlanningCloudConfiguration.containerIdentifier == nil)
            if PlanningCloudConfiguration.containerIdentifier == nil {
                Text("iCloud is unavailable in this installation. Your data is saved on this iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if SupabaseService.shared.configured {
                Toggle("Cross-platform cloud sync", isOn: cloudSyncBinding)
                Label("Private CloudKit keeps Apple devices in sync. Your connected Planning account can additionally restore data across supported platforms.", systemImage: "icloud.and.arrow.up")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Label("Private CloudKit keeps your Apple devices in sync.", systemImage: "icloud.and.arrow.up")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                Task { await store.syncNow() }
            }
            .buttonStyle(.glass)
            if let message = store.syncMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }


        Section("Data") {
            Button("Save settings") { store.persist() }
                .buttonStyle(.glassProminent)
            ShareLink(item: exportURL) { Label("Export data", systemImage: "square.and.arrow.up") }
                .buttonStyle(.glass)
            Button("Import data", systemImage: "square.and.arrow.down") { importing = true }
                .buttonStyle(.glass)
            if let importMessage { Text(importMessage).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importData(from: url)
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func importData(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let imported = try await PersistenceService.shared.importLegacyJSON(from: url)
                await MainActor.run {
                    store.adoptSnapshot(imported)
                    importMessage = "Imported successfully."
                }
            } catch {
                await MainActor.run {
                    importMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var morningPlanningEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.data.settings.morningPlanningReminder ?? false },
            set: { store.data.settings.morningPlanningReminder = $0 }
        )
    }

    private var overdueReminderBinding: Binding<Bool> {
        Binding(
            get: { store.data.settings.overdueReminder ?? false },
            set: { store.data.settings.overdueReminder = $0 }
        )
    }

    private var morningPlanningTimeBinding: Binding<Date> {
        Binding(
            get: {
                let value = store.data.settings.morningPlanningTime ?? "08:00"
                let parts = value.split(separator: ":").compactMap { Int($0) }
                return Calendar.current.date(bySettingHour: parts.first ?? 8, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.data.settings.morningPlanningTime = String(format: "%02d:%02d", parts.hour ?? 8, parts.minute ?? 0)
            }
        )
    }

    private var eveningReviewBinding: Binding<Date> {
        Binding(
            get: {
                let value = store.data.settings.eveningReviewTime ?? "20:30"
                let parts = value.split(separator: ":").compactMap { Int($0) }
                return Calendar.current.date(bySettingHour: parts.first ?? 20, minute: parts.count > 1 ? parts[1] : 30, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.data.settings.eveningReviewTime = String(format: "%02d:%02d", parts.hour ?? 20, parts.minute ?? 30)
            }
        )
    }

    private var iCloudSyncBinding: Binding<Bool> {
        Binding(
            get: { store.data.settings.iCloudSyncEnabled != false },
            set: { store.data.settings.iCloudSyncEnabled = $0; store.persist() }
        )
    }

    private var cloudSyncBinding: Binding<Bool> {
        Binding(
            get: { store.data.settings.cloudSyncEnabled != false },
            set: { store.data.settings.cloudSyncEnabled = $0; store.persist() }
        )
    }

    private var exportURL: URL {
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("Planning.json")
        if let url = try? syncExport() { return url }
        return fallback
    }

    private func syncExport() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Planning-export.json")
        try JSONEncoder().encode(store.data).write(to: url)
        return url
    }

    private func canvasName(_ theme: CanvasTheme) -> String {
        switch theme {
        case .none: return "None · Two-tone"
        case .paper: return "Craft Paper"
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        case .botanical: return "Botanical"
        case .wildlife: return "Wildlife"
        case .midnight: return "Midnight Paper"
        }
    }

    private func themeIcon(_ theme: CanvasTheme) -> String {
        switch theme {
        case .none: return "circle.lefthalf.filled"
        case .paper: return "doc.text"
        case .spring: return "camera.macro"
        case .summer: return "sun.max.fill"
        case .autumn: return "leaf.fill"
        case .winter: return "snowflake"
        case .botanical: return "tree.fill"
        case .wildlife: return "pawprint.fill"
        case .midnight: return "moon.stars.fill"
        }
    }
}

private struct TimelineFeaturesGuideView: View {
    private let features: [(String, String, String)] = [
        ("Reality", "square.stack.3d.up", "Compares the original plan with what actually happened. Week Reality summarizes all seven days together."),
        ("Gravity", "circle.hexagongrid", "Focuses the live view around the most relevant time window and current work."),
        ("Time Machine", "clock.arrow.circlepath", "Scrubs the day through time; Week Time Machine lets you inspect a day in the selected week."),
        ("Magnetic Compress", "arrow.down.right.and.arrow.up.left", "Pulls remaining flexible tasks into safe gaps. Week Compress runs across all seven days."),
        ("Buffer Guard", "shield.lefthalf.filled", "Adds a minimum reset buffer after scheduled work so the timeline stays realistic."),
        ("Auto Lock", "lock.fill", "Locks near-term tasks so even a confirmed adjustment preserves what is about to happen."),
        ("Focus Shield", "scope", "Protects must-win, focus and highest-priority work from schedule adjustments."),
        ("Recovery Buffers", "cup.and.saucer.fill", "Adds recovery time after meetings and demanding work or study blocks."),
        ("Conflict Sweep", "wand.and.stars", "Repairs avoidable overlaps while preserving calendar events, important blocks and locked anchors."),
        ("Deadline Radar", "exclamationmark.triangle.fill", "Surfaces deadline-bearing tasks that need attention before they become schedule emergencies."),
        ("Energy Fit", "bolt.heart.fill", "Reorders flexible work so higher-energy tasks land in stronger earlier slots while fixed anchors stay untouched."),
        ("Overload Guard", "gauge.with.dots.needle.67percent", "Detects when the day exceeds your work-hour capacity and pushes the least urgent flexible work forward."),
        ("Context Batching", "square.stack.3d.up.fill", "Groups tasks from the same project or category to reduce context switching."),
        ("Travel Buffer", "car.fill", "Adds travel/reset room around imported calendar commitments."),
        ("Focus Budget", "scope", "Creates a protected deep-work reserve when the day has less focus time than your target."),
        ("Meeting Defrag", "person.2.badge.clock.fill", "Adds meeting recovery, repairs conflicts and compacts flexible work into usable gaps."),
        ("Momentum Chain", "link.circle.fill", "Chains related work into a smoother execution sequence and removes avoidable gaps."),
        ("Deadline Backplan", "calendar.badge.exclamationmark", "Promotes deadline-bearing work to protected must-win priority before it becomes urgent."),
        ("Habit Rescue", "repeat.circle.fill", "Turns today's incomplete scheduled habits into actual timeline blocks."),
        ("No-Meeting Guard", "calendar.badge.minus", "Reinforces your configured no-meeting days by protecting focus work and adding separation around unavoidable meetings."),
        ("Deep Work Reserve", "brain.fill", "Creates and locks a dedicated focus block instead of leaving deep work to chance."),
        ("Context Switch Shield", "shield.checkered", "Combines batching, focus protection and conflict repair to reduce mental switching cost.")
    ]

    var body: some View {
        List {
            Section {
                ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.1)
                            .font(.headline)
                            .frame(width: 28)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.0)
                                .font(.headline)
                            Text(feature.2)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("These controls change how the live Timeline behaves or what it shows. They do not replace your task details.")
            }
        }
        .navigationTitle("Timeline Features")
        .navigationBarTitleDisplayMode(.inline)
    }
}


private struct TimelineIntelligenceSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section {
                Text("These switches choose which optional modules run only after you explicitly confirm Workspace Autopilot. Every tool can still be run manually from Day or Week Intelligence, with confirmation and Undo.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Capacity & focus") {
                toggle("Energy Fit", \AppSettings.timelineEnergyFitEnabled)
                toggle("Overload Guard", \AppSettings.timelineOverloadGuardEnabled)
                toggle("Focus Budget", \AppSettings.timelineFocusBudgetEnabled)
                toggle("Deep Work Reserve", \AppSettings.timelineDeepWorkReserveEnabled)
                toggle("Deadline Backplan", \AppSettings.timelineDeadlineBackplanEnabled)
            }
            Section("Flow & context") {
                toggle("Context Batching", \AppSettings.timelineContextBatchingEnabled)
                toggle("Momentum Chain", \AppSettings.timelineMomentumChainEnabled)
                toggle("Context Switch Shield", \AppSettings.timelineContextSwitchShieldEnabled)
                toggle("Meeting Defrag", \AppSettings.timelineMeetingDefragEnabled)
            }
            Section("Recovery & routines") {
                toggle("Travel Buffer", \AppSettings.timelineTravelBufferEnabled)
                toggle("Habit Rescue", \AppSettings.timelineHabitRescueEnabled)
                toggle("No-Meeting Guard", \AppSettings.timelineNoMeetingGuardEnabled)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Autopilot Modules")
    }

    @ViewBuilder
    private func toggle(_ title: String, _ keyPath: WritableKeyPath<AppSettings, Bool?>) -> some View {
        Toggle(title, isOn: Binding(
            get: { store.data.settings[keyPath: keyPath] ?? false },
            set: { value in store.updateSettings { $0[keyPath: keyPath] = value } }
        ))
    }
}

private struct AppearancePreview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live appearance")
                        .font(.headline)
                    Text(store.data.settings.canvasTheme == .none ? "Pure two-tone" : "Craft matte · \(store.data.settings.canvasTheme.rawValue.capitalized)")
                        .font(.caption).foregroundStyle(p.secondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(p.accent).frame(width: 22, height: 22)
                }
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(p.accent.opacity(0.12)).interactive(), in: Circle())
            }

            HStack(spacing: 8) {
                Label("Focus", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .premiumGlassCapsule(tint: p.accent.opacity(0.24), interactive: true)
                Label("Study", systemImage: "book.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .premiumGlassCapsule(tint: p.accent.opacity(0.16), interactive: true)
                Circle().fill(.clear).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "sparkles").font(.caption).foregroundStyle(p.accent))
                    .glassEffect(.regular.tint(p.accent.opacity(0.14)).interactive(), in: Circle())
            }
        }
        .padding(18)
        .premiumGlassRounded(cornerRadius: 28, tint: p.accent.opacity(0.08), interactive: true)
        .padding(.vertical, 4)
    }
}


private struct AppIconChoice: Identifiable {
    let id: String
    let assetName: String?
    let title: String
    let background: Color
    let foreground: Color
}

private struct AppIconPicker: View {
    @State private var selectedName: String?
    @State private var errorMessage: String?

    private let choices: [AppIconChoice] = [
        .init(id: "primary", assetName: nil, title: "Original", background: .white, foreground: .rgb(169,104,104)),
        .init(id: "light", assetName: "AppIcon-Light", title: "Light", background: .white, foreground: .rgb(169,104,104)),
        .init(id: "dark", assetName: "AppIcon-Dark", title: "Dark", background: .black, foreground: .rgb(215,154,153)),
        .init(id: "spring", assetName: "AppIcon-Spring", title: "Spring", background: .rgb(243,239,234), foreground: .rgb(170,116,129)),
        .init(id: "summer", assetName: "AppIcon-Summer", title: "Summer", background: .rgb(240,241,232), foreground: .rgb(164,140,91)),
        .init(id: "autumn", assetName: "AppIcon-Autumn", title: "Autumn", background: .rgb(242,237,228), foreground: .rgb(166,122,87)),
        .init(id: "winter", assetName: "AppIcon-Winter", title: "Winter", background: .rgb(238,240,241), foreground: .rgb(112,139,150)),
        .init(id: "botanical", assetName: "AppIcon-Botanical", title: "Botanical", background: .rgb(238,241,235), foreground: .rgb(111,136,113)),
        .init(id: "wildlife", assetName: "AppIcon-Wildlife", title: "Wildlife", background: .rgb(240,237,231), foreground: .rgb(134,112,87)),
        .init(id: "midnight", assetName: "AppIcon-Midnight", title: "Midnight", background: .rgb(16,17,15), foreground: .rgb(185,164,191)),
        .init(id: "ocean", assetName: "AppIcon-Ocean", title: "Ocean", background: .rgb(245,246,247), foreground: .rgb(110,127,149)),
        .init(id: "violet", assetName: "AppIcon-Violet", title: "Violet", background: .rgb(247,245,247), foreground: .rgb(136,116,142)),
        .init(id: "forest", assetName: "AppIcon-Forest", title: "Forest", background: .rgb(245,247,244), foreground: .rgb(111,136,113)),
        .init(id: "sunset", assetName: "AppIcon-Sunset", title: "Sunset", background: .rgb(248,245,241), foreground: .rgb(166,122,87)),
        .init(id: "blossom", assetName: "AppIcon-Blossom", title: "Blossom", background: .rgb(249,245,246), foreground: .rgb(170,116,129)),
        .init(id: "sky", assetName: "AppIcon-Sky", title: "Sky", background: .rgb(244,247,248), foreground: .rgb(112,139,150)),
        .init(id: "lavender", assetName: "AppIcon-Lavender", title: "Lavender", background: .rgb(247,245,249), foreground: .rgb(139,125,151)),
        .init(id: "mint", assetName: "AppIcon-Mint", title: "Mint", background: .rgb(244,248,246), foreground: .rgb(114,141,130)),
        .init(id: "amber", assetName: "AppIcon-Amber", title: "Amber", background: .rgb(249,247,241), foreground: .rgb(164,140,91))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(choices) { choice in
                        Button { apply(choice) } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                                        .fill(choice.background)
                                    Text("P")
                                        .font(.system(size: 27, weight: .black, design: .rounded))
                                        .foregroundStyle(choice.foreground)
                                    if selectedName == choice.assetName {
                                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                                            .stroke(choice.foreground, lineWidth: 2.5)
                                            .padding(2)
                                    }
                                }
                                .frame(width: 62, height: 62)
                                Text(choice.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(7)
                            .premiumGlassRounded(
                                cornerRadius: 22,
                                tint: selectedName == choice.assetName ? choice.foreground.opacity(0.12) : nil,
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Text("These are real Home Screen icon variants, not an in-app preview.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .onAppear { selectedName = UIApplication.shared.alternateIconName }
    }

    private func apply(_ choice: AppIconChoice) {
        errorMessage = nil
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.assetName)
                await MainActor.run { selectedName = choice.assetName }
            } catch {
                await MainActor.run { errorMessage = "Could not change icon: \(error.localizedDescription)" }
            }
        }
    }
}
