import Foundation
import SwiftUI
@preconcurrency import HealthKit
import HealthKitUI

struct HealthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var requesting = false
    @State private var mode: WellnessMode = .fitness
    @State private var connectionMessage: String?
    @State private var showPaywall = false

    private enum WellnessMode: String, CaseIterable, Identifiable {
        case health = "Health"
        case fitness = "Fitness"
        var id: String { rawValue }
        var symbol: String { self == .health ? "heart.text.square.fill" : "figure.run.circle.fill" }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                modeSwitcher(palette: p)

                if store.data.settings.healthSyncEnabled {
                    if mode == .health { healthHome(palette: p) }
                    else { fitnessHome(palette: p) }

                    PremiumGlassCard(tint: p.accent.opacity(0.035)) {
                        Label {
                            Text("Health access is read-only. AI uses a summary only when you enable it in Health or Integrations.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "lock.shield.fill").foregroundStyle(p.accent)
                        }
                    }
                } else {
                    connectionCard(palette: p)
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .appCanvas()
        .navigationTitle("Health & Fitness")
        .refreshable { await store.refreshHealthIfNeeded() }
        .task {
            if store.data.settings.healthSyncEnabled { await store.refreshHealthIfNeeded() }
        }
        .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
        .alert("Health connection", isPresented: Binding(
            get: { connectionMessage != nil },
            set: { if !$0 { connectionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { connectionMessage = nil }
        } message: {
            Text(connectionMessage ?? "")
        }
    }

    private func modeSwitcher(palette p: AppPalette) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(WellnessMode.allCases) { item in
                    if item == mode {
                        modeButton(item)
                            .buttonStyle(.glassProminent)
                            .tint(p.accent)
                            .accessibilityAddTraits(.isSelected)
                    } else {
                        modeButton(item)
                            .buttonStyle(.glass)
                    }
                }
            }
        }
        .planningFeedback(.selection, trigger: mode)
    }

    private func modeButton(_ item: WellnessMode) -> some View {
        Button {
            withAnimation(.spring(duration: 0.34, bounce: 0.08)) { mode = item }
        } label: {
            Label(item.rawValue, systemImage: item.symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
    }

    private func connectionCard(palette p: AppPalette) -> some View {
        PremiumGlassCard(tint: p.accent.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: "heart.text.square.fill")
                    .font(.largeTitle)
                    .foregroundStyle(p.accent)
                Text("Connect Health & Fitness")
                    .font(.title2.bold())
                Text("Choose the Health categories you want Planning to read. Activity, workouts and Apple Watch summaries appear here automatically after permission is granted.")
                    .foregroundStyle(p.secondary)
                Button {
                    connect()
                } label: {
                    if requesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(store.hasAccess(.appleIntegrations) ? "Connect Health" : "Unlock Health", systemImage: store.hasAccess(.appleIntegrations) ? "link" : "lock.fill")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(requesting)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func healthHome(palette p: AppPalette) -> some View {
        PremiumGlassCard(tint: p.accent.opacity(0.065)) {
            HStack(spacing: 13) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(p.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Health sync is active").font(.headline)
                    Text("\(syncedMetricCount) of \(HealthService.catalog.count) readable metrics currently have shared data")
                        .font(.caption)
                        .foregroundStyle(p.secondary)
                }
                Spacer()
                Button { Task { await store.refreshHealthIfNeeded() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Refresh Health data")
            }
        }

        PremiumGlassCard(tint: p.accent.opacity(0.035)) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use Health summaries with Planning AI", isOn: Binding(
                    get: { store.data.settings.healthPlanningEnabled },
                    set: { value in store.updateSettings { $0.healthPlanningEnabled = value } }
                ))
                Text(store.data.settings.healthPlanningEnabled
                     ? "On · the current summary can help AI suggest a realistic schedule. Every proposed app change still requires review."
                     : "Off · AI cannot see Health or Fitness summaries.")
                    .font(.caption)
                    .foregroundStyle(p.secondary)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Today", subtitle: lastUpdatedLabel)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                metric("Sleep", value: sharedValue("HKCategoryTypeIdentifierSleepAnalysis"), icon: "bed.double.fill", palette: p)
                metric("Steps", value: sharedValue("HKQuantityTypeIdentifierStepCount"), icon: "figure.walk", palette: p)
                metric("Exercise", value: sharedValue("HKQuantityTypeIdentifierAppleExerciseTime"), icon: "figure.run", palette: p)
                metric("Distance", value: sharedValue("HKQuantityTypeIdentifierDistanceWalkingRunning"), icon: "map.fill", palette: p)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Your shared data", subtitle: "Latest available summaries")
            ForEach(HealthDataSection.allCases.filter { section in
                (store.healthSnapshot.metrics ?? []).contains { $0.section == section && $0.value != nil }
            }.prefix(3)) { section in
                healthCategoryRow(section, palette: p)
            }
            NavigationLink { HealthLibraryView() } label: {
                PlanningDestinationRow(title: "Browse all Health sections", subtitle: "Search every supported category and metric", symbol: "heart.text.square", detail: "\(HealthDataSection.allCases.count) sections")
            }.buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Planning insight", subtitle: "Private, neutral and always optional.")
            capacityCard
            if let rhythm = InsightsEngine.bodyRhythm(profile: store.data.profile) { bodyRhythmCard(rhythm) }
        }
    }

    @ViewBuilder
    private func fitnessHome(palette p: AppPalette) -> some View {
        activityRingsCard(palette: p)

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Fitness today", subtitle: "Synced from Apple Watch and HealthKit.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                metric("Workouts", value: store.healthSnapshot.recentWorkouts == nil ? "—" : store.healthSnapshot.workoutCount.formatted(), icon: "figure.mixed.cardio", palette: p)
                metric("Workout time", value: store.healthSnapshot.recentWorkouts == nil ? "—" : "\(store.healthSnapshot.workoutMinutes) min", icon: "timer", palette: p)
                metric("Stand", value: sharedValue("HKQuantityTypeIdentifierAppleStandTime"), icon: "figure.stand", palette: p)
                metric("Steps", value: sharedValue("HKQuantityTypeIdentifierStepCount"), icon: "shoeprints.fill", palette: p)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Recent workouts", subtitle: "The latest 30 days from HealthKit.")
            let workouts = store.healthSnapshot.recentWorkouts ?? []
            if workouts.isEmpty {
                PremiumGlassCard {
                    Label("No shared workouts yet", systemImage: "figure.run.circle")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(workouts.prefix(3)) { workout in
                    HealthWorkoutRow(workout: workout)
                }
                NavigationLink { HealthWorkoutHistoryView() } label: {
                    PlanningDestinationRow(title: "All workouts", subtitle: "Search your shared workout history", symbol: "figure.run", detail: "\(workouts.count)")
                }.buttonStyle(.plain)
            }
        }

        PremiumGlassCard {
            Label {
                Text("Planning syncs the Activity Rings, goals, workouts and statistics Apple exposes through HealthKit. Fitness+ plans and private Fitness app preferences remain managed by Apple.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(p.accent)
            }
        }
    }

    private func activityRingsCard(palette p: AppPalette) -> some View {
        let rings = store.healthSnapshot.fitnessRings ?? FitnessRingSnapshot()
        return PremiumGlassCard(tint: p.accent.opacity(0.075)) {
            PlanningAdaptiveRow(spacing: 20) {
                ZStack {
                    ring(progress: rings.moveProgress, color: .pink, width: 13, inset: 0)
                    ring(progress: rings.exerciseProgress, color: .green, width: 11, inset: 17)
                    ring(progress: rings.standProgress, color: .cyan, width: 9, inset: 32)
                }
                .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Activity Rings").font(.title3.bold())
                    if store.healthSnapshot.fitnessRings != nil {
                        ringLabel("Move", rings.moveProgress, .pink)
                        ringLabel("Exercise", rings.exerciseProgress, .green)
                        ringLabel("Stand", rings.standProgress, .cyan)
                    } else {
                        Text("No shared ring data for today")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Goals come from Apple Fitness when available.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func ring(progress: Double, color: Color, width: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: width)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6, bounce: 0.08), value: progress)
        }
        .padding(inset)
    }

    private func ringLabel(_ title: String, _ progress: Double, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption.weight(.semibold))
            Spacer()
            Text("\(Int((progress * 100).rounded()))%")
                .font(.caption.weight(.bold).monospacedDigit())
        }
    }

    private func metric(_ title: String, value: String, icon: String, palette p: AppPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(p.accent)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .premiumGlassRounded(cornerRadius: 22, tint: p.accent.opacity(0.04), interactive: true)
    }

    private func sharedValue(_ id: String) -> String {
        guard let metric = store.healthSnapshot.metrics?.first(where: { $0.id == id }),
              let value = metric.value else { return "—" }
        return String(format: "%.*f", metric.precision, value) + (metric.unit.isEmpty ? "" : " \(metric.unit)")
    }

    private var capacityCard: some View {
        let signal = InsightsEngine.capacity(from: store.healthSnapshot)
        return PremiumGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Capacity Twin", subtitle: signal.summary)
                if signal.level != "unknown" {
                    ProgressView(value: Double(signal.score), total: 100)
                    Text("Planning estimate · \(signal.score)% · suggested focus \(signal.suggestedFocusMinutes) min").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func bodyRhythmCard(_ rhythm: BodyRhythmSignal) -> some View {
        PremiumGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Body Rhythm", subtitle: "Day \(rhythm.day) · \(rhythm.phase.rawValue.capitalized)")
                Text(rhythm.guidance).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var collisionCards: some View {
        let capacity = InsightsEngine.capacity(from: store.healthSnapshot)
        let collisions = InsightsEngine.scheduleCollisions(plan: store.activePlan, capacity: capacity)
        return Group {
            ForEach(collisions) { collision in
                PremiumGlassCard {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(collision.title).font(.headline)
                            Text(collision.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: collision.severity == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    }
                }
            }
        }
    }

    private var lastUpdatedLabel: String {
        guard let date = ISO8601DateFormatter().date(from: store.healthSnapshot.lastUpdated) else { return "Synced from HealthKit" }
        return "Updated \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func sectionSummary(_ section: HealthDataSection) -> String {
        let values = store.healthSnapshot.metrics ?? []
        let available = values.filter { $0.section == section && $0.value != nil }.count
        return available == 0 ? "Ready when shared" : "\(available) synced"
    }

    private var syncedMetricCount: Int {
        (store.healthSnapshot.metrics ?? []).filter { $0.value != nil }.count
    }

    private func healthCategoryRow(_ section: HealthDataSection, palette p: AppPalette) -> some View {
        let metrics = (store.healthSnapshot.metrics ?? []).filter { $0.section == section && $0.value != nil }
        let preview = metrics.prefix(2).map { metric -> String in
            guard let value = metric.value else { return metric.title }
            let number = String(format: "%.*f", metric.precision, value)
            return "\(metric.title) \(number)\(metric.unit.isEmpty ? "" : " \(metric.unit)")"
        }.joined(separator: " · ")

        return NavigationLink { HealthSectionDetailView(section: section) } label: {
            HStack(spacing: 13) {
                Image(systemName: section.symbol)
                    .font(.headline)
                    .foregroundStyle(p.accent)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.tint(p.accent.opacity(0.065)).interactive(), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.rawValue).font(.headline).foregroundStyle(p.text)
                    Text(preview.isEmpty ? "Ready when you share data" : preview)
                        .font(.caption)
                        .foregroundStyle(p.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(sectionSummary(section))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(metrics.isEmpty ? p.secondary : p.accent)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(p.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .premiumGlassRounded(cornerRadius: 22, tint: p.accent.opacity(0.035), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func workoutDate(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func connect() {
        guard store.hasAccess(.appleIntegrations) else { showPaywall = true; return }
        guard !requesting else { return }
        requesting = true
        Task {
            let ok = await HealthService.shared.requestReadAccess()
            await MainActor.run {
                store.updateSettings {
                    $0.healthSyncEnabled = ok
                    if !ok { $0.healthPlanningEnabled = false }
                }
                requesting = false
                if !ok { connectionMessage = "Health access was not granted. You can choose permissions later in iOS Settings." }
            }
            if ok { await store.refreshHealthIfNeeded() }
        }
    }
}

private struct HealthSectionDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let section: HealthDataSection
    @State private var showAllMetrics = false
    @State private var metricSearch = ""
    @State private var medicationAccessTrigger = false
    @State private var medicationAccessMessage: String?
    @State private var medicationStore = HKHealthStore()

    private var metrics: [HealthMetricSnapshot] {
        let actual = Dictionary(uniqueKeysWithValues: (store.healthSnapshot.metrics ?? []).map { ($0.id, $0) })
        return HealthService.catalog
            .filter { $0.section == section }
            .map { actual[$0.id] ?? $0 }
            .sorted { lhs, rhs in
                if (lhs.value != nil) != (rhs.value != nil) { return lhs.value != nil }
                return lhs.title < rhs.title
            }
    }

    private var visibleMetrics: [HealthMetricSnapshot] {
        metrics.filter { (showAllMetrics || $0.value != nil) && (metricSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(metricSearch)) }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(spacing: 11) {
                PremiumGlassCard(tint: p.accent.opacity(0.07)) {
                    HStack(spacing: 13) {
                        Image(systemName: section.symbol)
                            .font(.title2)
                            .foregroundStyle(p.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.rawValue).font(.title3.bold())
                            Text("Only categories authorized in Apple Health show values.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if section == .medications {
                    PremiumGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Share selected medications").font(.headline)
                            Text("Choose which medication records Planning may read. Dose records stay read-only; manage schedules and treatments in Apple Health.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Choose medications", systemImage: "pills.fill") { medicationAccessTrigger.toggle() }
                                .buttonStyle(.glass)
                            if let medicationAccessMessage {
                                Text(medicationAccessMessage).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Toggle("Include metrics without shared data", isOn: $showAllMetrics)
                    .font(.subheadline).padding(.vertical, 8)
                if visibleMetrics.isEmpty {
                    PlanningEmptyState(title: "No shared values here yet", message: "Choose which data to share in Apple Health, or include all metrics to explore this category.", symbol: section.symbol)
                }
                ForEach(visibleMetrics) { metric in
                    HStack(spacing: 13) {
                        Image(systemName: metric.symbol)
                            .font(.headline)
                            .foregroundStyle(metric.value == nil ? p.tertiary : p.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(metric.title).font(.headline)
                            if let raw = metric.recordedAt, let date = ISO8601DateFormatter().date(from: raw) {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(metric.value == nil ? "No shared data" : "Today")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formatted(metric))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(metric.value == nil ? p.tertiary : p.text)
                    }
                    .padding(14)
                    .premiumGlassRounded(cornerRadius: 21, tint: p.accent.opacity(0.035), interactive: true)
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .appCanvas()
        .navigationTitle(section.rawValue)
        .searchable(text: $metricSearch, prompt: "Find a metric")
        .navigationBarTitleDisplayMode(.inline)
        .healthDataAccessRequest(store: medicationStore, objectType: HKObjectType.userAnnotatedMedicationType(), trigger: medicationAccessTrigger) { result in
            Task { @MainActor in
                switch result {
                case .success: medicationAccessMessage = "Only the records you choose to share can appear here."
                case .failure: medicationAccessMessage = "Could not open medication access. Try again in Apple Health."
                }
                await store.refreshHealthIfNeeded()
            }
        }
    }

    private func formatted(_ metric: HealthMetricSnapshot) -> String {
        guard let value = metric.value else { return "—" }
        let number = String(format: "%.*f", metric.precision, value)
        return metric.unit.isEmpty ? number : "\(number) \(metric.unit)"
    }
}


private struct HealthLibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    private var sections: [HealthDataSection] {
        HealthDataSection.allCases.filter { section in
            search.isEmpty || section.rawValue.localizedCaseInsensitiveContains(search) ||
            HealthService.catalog.contains { $0.section == section && $0.title.localizedCaseInsensitiveContains(search) }
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sections) { section in
                    let available = (store.healthSnapshot.metrics ?? []).filter { $0.section == section && $0.value != nil }.count
                    NavigationLink { HealthSectionDetailView(section: section) } label: {
                        PlanningDestinationRow(title: section.rawValue, subtitle: available == 0 ? "No shared values yet" : "\(available) available summaries", symbol: section.symbol)
                    }.buttonStyle(.plain)
                }
                if sections.isEmpty { ContentUnavailableView.search(text: search) }
            }.padding(18).padding(.bottom, 28)
        }.appCanvas().navigationTitle("Health library")
            .searchable(text: $search, prompt: "Category or metric")
    }
}

private struct HealthWorkoutRow: View {
    let workout: HealthWorkoutSummary
    var body: some View {
        PlanningAdaptiveRow(spacing: 12) {
            Image(systemName: workout.symbol).font(.title3).foregroundStyle(.tint).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title).font(.headline)
                Text(dateLabel).font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workout.durationMinutes) min").font(.subheadline.weight(.semibold))
                if let distance = workout.distanceKilometers {
                    Text(distance.formatted(.number.precision(.fractionLength(1))) + " km").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(16).premiumGlassRounded(cornerRadius: 22)
    }
    private var dateLabel: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: workout.startedAt) ?? ISO8601DateFormatter().date(from: workout.startedAt)
        return date?.formatted(date: .abbreviated, time: .shortened) ?? workout.startedAt
    }
}

private struct HealthWorkoutHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    private var workouts: [HealthWorkoutSummary] {
        (store.healthSnapshot.recentWorkouts ?? []).filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Shared workouts from the last 30 days").font(.subheadline).foregroundStyle(.secondary)
                if workouts.isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(workouts) { HealthWorkoutRow(workout: $0) }
            }.padding(18)
        }.appCanvas().navigationTitle("Workouts").searchable(text: $query, prompt: "Find a workout")
    }
}
