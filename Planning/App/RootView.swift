import SwiftUI

struct RootView: View {
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if !store.data.profile.onboardingCompleted {
                WelcomeView()
            } else {
                MainTabView()
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.12), value: store.data.profile.onboardingCompleted)
        .preferredColorScheme(preferredScheme)
        .fontDesign(preferredFontDesign)
        .dynamicTypeSize(preferredDynamicTypeSize)
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .keyboardDismissOnBackgroundTap()
        .globalInteractionFeedback(hapticsEnabled: store.data.settings.hapticFeedbackEnabled != false)
        .scrollDismissesKeyboard(.interactively)
        .onReceive(NotificationCenter.default.publisher(for: .planningHealthDataDidChange)) { _ in
            Task { await store.refreshHealthIfNeeded() }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch store.data.settings.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var preferredFontDesign: Font.Design? {
        switch store.data.settings.fontDesign ?? .system {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }

    private var preferredDynamicTypeSize: DynamicTypeSize {
        if systemDynamicTypeSize.isAccessibilitySize { return systemDynamicTypeSize }
        switch store.data.settings.fontScale {
        case .compact: return .medium
        case .standard: return systemDynamicTypeSize
        case .large: return .xLarge
        }
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var showQuickAdd = false
    @State private var showExperiencePicker = false

    private var experienceMode: AppExperienceMode { (store.data.settings.experienceMode ?? .planner).resolved }

    var body: some View {
        @Bindable var store = store
        let palette = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        ZStack {
            TabView(selection: $store.selectedTab) {
                switch experienceMode {
                case .planner:
                    Tab("Today", systemImage: "circle.grid.cross", value: .today) { rootScreen { TodayView() } }
                    Tab("Calendar", systemImage: "calendar", value: .calendar) { rootScreen { CalendarHomeView() } }
                    Tab("AI", systemImage: "brain.head.profile", value: .coach) { rootScreen { CoachView() } }
                    Tab("Fitness", systemImage: "figure.run.circle.fill", value: .notes) { rootScreen { HealthView() } }
                    Tab("More", systemImage: "ellipsis", value: .profile) { rootScreen { ProfileView() } }
                case .hybrid, .workspace:
                    Tab("Workspace", systemImage: "square.grid.3x3.fill", value: .workspace) { rootScreen { WorkspaceView() } }
                    Tab("Calendar", systemImage: "calendar", value: .calendar) { rootScreen { CalendarHomeView() } }
                    Tab("AI", systemImage: "brain.head.profile", value: .coach) { rootScreen { CoachView() } }
                    Tab("Fitness", systemImage: "figure.run.circle.fill", value: .notes) { rootScreen { HealthView() } }
                    Tab("More", systemImage: "ellipsis", value: .profile) { rootScreen { ProfileView() } }
                }
            }
            .tint(palette.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .blur(radius: showExperiencePicker ? 11 : 0)
            .scaleEffect(showExperiencePicker ? 0.985 : 1)
            .allowsHitTesting(!showExperiencePicker)
            .accessibilityHidden(showExperiencePicker)

            if showExperiencePicker {
                ExperienceModePickerOverlay(isPresented: $showExperiencePicker)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .planningFeedback(.selection, trigger: store.selectedTab)
        .planningFeedback(.impact(weight: .light), trigger: showQuickAdd) { oldValue, newValue in
            !oldValue && newValue
        }
        .sheet(isPresented: $showQuickAdd) {
            if experienceMode == .planner {
                NavigationStack {
                    TaskEditorView(task: PlanEngine.manualTask(title: "", date: store.selectedDate), isNew: true)
                }
            } else {
                NavigationStack { UniversalQuickAddView(mode: experienceMode) }
            }
        }
        .sheet(item: $store.presentedTask) { task in
            NavigationStack {
                TaskEditorView(task: task, isNew: true)
            }
        }
        .onChange(of: store.quickAddRequested) { _, requested in
            guard requested else { return }
            showQuickAdd = true
            store.quickAddRequested = false
        }
        .onChange(of: experienceMode, initial: true) { _, mode in
            let allowed: Set<AppStore.AppTab>
            switch mode {
            case .planner: allowed = [.today, .calendar, .coach, .notes, .profile]
            case .hybrid, .workspace: allowed = [.workspace, .calendar, .coach, .notes, .profile]
            }
            if !allowed.contains(store.selectedTab) {
                store.selectedTab = mode == .workspace ? .workspace : .today
            }
        }
    }

    private func rootScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(duration: 0.32, bounce: 0.06)) {
                                showExperiencePicker.toggle()
                            }
                        } label: {
                            Image(systemName: experienceMode.symbol)
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("Choose Planner or Workspace")
                        .accessibilityValue(experienceMode.label)
                    }
                }
        }
    }

}

private struct ExperienceModePickerOverlay: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Binding var isPresented: Bool

    private var selected: AppExperienceMode { (store.data.settings.experienceMode ?? .planner).resolved }

    var body: some View {
        let palette = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        ZStack {
            Button {
                withAnimation(.spring(duration: 0.34, bounce: 0.08)) { isPresented = false }
            } label: {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(scheme == .dark ? 0.18 : 0.06))
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close experience picker")

            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 18) {
                    Text("Choose your space")
                        .font(.title2.bold())
                    Text("One account. Two ways to plan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(AppExperienceMode.selectableCases) { mode in
                        if selected == mode {
                            Button { select(mode) } label: { modeLabel(mode, palette: palette) }
                                .buttonStyle(.glassProminent)
                                .tint(palette.accent)
                                .accessibilityAddTraits(.isSelected)
                        } else {
                            Button { select(mode) } label: { modeLabel(mode, palette: palette) }
                                .buttonStyle(.glass)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .accessibilityElement(children: .contain)
        }
        .accessibilityAction(.escape) { isPresented = false }
        .animation(.spring(duration: 0.32, bounce: 0.10), value: selected)
        .planningFeedback(.selection, trigger: selected)
    }

    private func modeLabel(_ mode: AppExperienceMode, palette: AppPalette) -> some View {
        HStack(spacing: 14) {
            Image(systemName: mode.symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.label).font(.headline)
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: selected == mode ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected == mode ? palette.accent : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.horizontal, 18)
        .contentShape(Capsule())
    }

    private func select(_ mode: AppExperienceMode) {
        if mode != selected {
            store.setExperienceMode(mode.resolved)
        }
        withAnimation(.spring(duration: 0.34, bounce: 0.08)) {
            isPresented = false
        }
    }
}


struct ExperienceModeGlassSwitcher: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    var compact = false

    private var selected: AppExperienceMode {
        (store.data.settings.experienceMode ?? .planner).resolved
    }

    var body: some View {
        let palette = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        GlassEffectContainer(spacing: compact ? 5 : 7) {
            HStack(spacing: compact ? 5 : 7) {
                ForEach(AppExperienceMode.selectableCases) { mode in
                    if selected == mode {
                        Button { select(mode) } label: {
                            modeLabel(mode)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(palette.accent)
                        .accessibilityAddTraits(.isSelected)
                    } else {
                        Button { select(mode) } label: {
                            modeLabel(mode)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.32, bounce: 0.10), value: selected)
        .planningFeedback(.selection, trigger: selected)
    }

    @ViewBuilder
    private func modeLabel(_ mode: AppExperienceMode) -> some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: mode.symbol)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            Text(mode.label)
                .font(compact ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 6 : 10)
    }

    private func select(_ mode: AppExperienceMode) {
        guard mode != selected else { return }
        store.setExperienceMode(mode.resolved)
    }
}

private struct UniversalQuickAddView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let mode: AppExperienceMode

    @State private var title = ""
    @State private var note = ""
    @State private var kind: Kind = .task

    enum Kind: String, CaseIterable, Identifiable {
        case task = "Task", inbox = "Inbox", page = "Page", project = "Project", database = "Database", clip = "Web Clip"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .task: return "checkmark.circle"
            case .inbox: return "tray.and.arrow.down"
            case .page: return "doc.badge.plus"
            case .project: return "shippingbox.fill"
            case .database: return "tablecells.badge.ellipsis"
            case .clip: return "bookmark.fill"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.menu)
                TextField(kind == .clip ? "Title" : "What do you want to add?", text: $title)
                TextField(kind == .clip ? "URL or note" : "Optional note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                Text("Saved to your workspace, ready to organize later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Quick Add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { add() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func add() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        switch kind {
        case .task:
            var task = PlanEngine.manualTask(title: clean, date: store.selectedDate)
            task.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            store.addTask(task)
        case .inbox:
            store.addInbox(clean)
        case .page:
            store.saveWorkspacePage(WorkspacePage(title: clean, body: note))
        case .project:
            store.saveWorkspaceProject(WorkspaceProject(title: clean, status: .active, outcome: note))
        case .database:
            store.saveWorkspaceDatabase(WorkspaceDatabase(title: clean, description: note.isEmpty ? nil : note))
        case .clip:
            store.saveWorkspaceClip(WorkspaceClip(title: clean, url: note, tags: ["quick-add"]))
        }
        dismiss()
    }
}
