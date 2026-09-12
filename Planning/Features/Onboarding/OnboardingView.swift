import SwiftUI

struct OnboardingView: View {
    private enum Requirement {
        case required
        case optional

        var label: String { self == .required ? "Required" : "Optional" }
        var symbol: String { self == .required ? "checkmark.seal.fill" : "circle.dashed" }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var profile = UserProfile()
    @State private var page = 0
    @State private var working = false
    @State private var showFinishChoice = false
    @State private var loadedExistingProfile = false

    private let reconfigure: Bool
    private let total = 10

    init(reconfigure: Bool = false) {
        self.reconfigure = reconfigure
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(page + 1) / \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(page + 1), total: Double(total))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                namePage.tag(0)
                goalPage.tag(1)
                whyPage.tag(2)
                strugglePage.tag(3)
                schedulePage.tag(4)
                chronotypePage.tag(5)
                disciplinePage.tag(6)
                commitmentsPage.tag(7)
                habitsPage.tag(8)
                describePage.tag(9)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(duration: 0.4, bounce: 0.08), value: page)

            bottomControls
        }
        .appCanvas()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard reconfigure, !loadedExistingProfile else { return }
            profile = store.data.profile
            loadedExistingProfile = true
        }
        .confirmationDialog(reconfigure ? "Save your updated profile?" : "How do you want to start?", isPresented: $showFinishChoice, titleVisibility: .visible) {
            Button(reconfigure ? "Save changes" : "Start empty") { finish(buildFirstPlan: false) }
            Button(reconfigure ? "Save & build a plan" : "Build my first plan") { finish(buildFirstPlan: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(reconfigure
                 ? "Your updated onboarding answers replace the previous profile. You can run onboarding again whenever you want."
                 : "Nothing will be added unless you choose to build a plan. You can always ask AI to plan later.")
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button(reconfigure && page == 0 ? "Close" : "Back") {
                if page > 0 {
                    page -= 1
                } else if reconfigure {
                    dismiss()
                }
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity)
            .disabled((page == 0 && !reconfigure) || working)
            .opacity(page == 0 && !reconfigure ? 0 : 1)

            Button("Skip") {
                if page == 0 && !reconfigure {
                    deferForLater()
                } else {
                    skipCurrentPage()
                }
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity)
            .disabled((currentRequirement == .required && !(page == 0 && !reconfigure)) || working)

            Button(page == total - 1 ? (working ? "Finishing…" : "Finish") : "Continue") {
                if page == total - 1 {
                    showFinishChoice = true
                } else {
                    advance()
                }
            }
            .buttonStyle(.glassProminent)
            .frame(maxWidth: .infinity)
            .disabled(!canContinue || working)
        }
        .padding(20)
    }

    private var currentRequirement: Requirement {
        switch page {
        case 0, 4: return .required
        default: return .optional
        }
    }

    private var canContinue: Bool {
        switch page {
        case 0:
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 4:
            return TimeMath.minutes(profile.wakeTime) != nil
                && TimeMath.minutes(profile.sleepTime) != nil
                && profile.wakeTime != profile.sleepTime
        default:
            return true
        }
    }

    private func shell(
        _ title: String,
        _ subtitle: String,
        requirement: Requirement,
        showLaterNotice: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(title)
                            .font(.largeTitle.bold())
                        Spacer(minLength: 8)
                        Label(requirement.label, systemImage: requirement.symbol)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .premiumGlassCapsule(interactive: true)
                    }
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if showLaterNotice && !reconfigure {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("You can finish this later", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Text("Onboarding is never one-time only. You can open More → Onboarding later, change these answers, and run it again as many times as you want.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .premiumGlassRounded(cornerRadius: 22, interactive: true)
                }

                content()
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }

    private var namePage: some View {
        shell("What should we call you?", "This keeps the coach personal without making daily planning slower.", requirement: .required, showLaterNotice: true) {
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Name", requirement: .required)
                TextField("Name", text: $profile.name)
                    .textContentType(.name)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .premiumGlassRounded(cornerRadius: 18, interactive: true)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Main area", requirement: .required)
                Picker("Main area", selection: $profile.category) {
                    Text("Study").tag(UserProfile.Category.study)
                    Text("Career").tag(UserProfile.Category.career)
                    Text("Fitness").tag(UserProfile.Category.fitness)
                    Text("Money").tag(UserProfile.Category.money)
                    Text("Something else").tag(UserProfile.Category.custom)
                }
            }
        }
    }

    private var goalPage: some View {
        shell("What are you moving toward?", "Give the planner one outcome that matters most right now.", requirement: .optional) {
            fieldLabel("Primary goal", requirement: .optional)
            TextField("Primary goal", text: $profile.primaryGoal, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var whyPage: some View {
        shell("Why does it matter?", "A short reason helps AI protect important work when the day changes.", requirement: .optional) {
            fieldLabel("Why this goal matters", requirement: .optional)
            TextField("Why this goal matters", text: $profile.goalWhy, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var strugglePage: some View {
        shell("What usually gets in the way?", "Examples: procrastination, too many tasks, low energy, unclear first steps.", requirement: .optional) {
            fieldLabel("Main difficulty", requirement: .optional)
            TextField("Main difficulty", text: $profile.struggle, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var schedulePage: some View {
        shell("Your usual day", "These become the outer boundaries of the timeline.", requirement: .required) {
            fieldLabel("Wake & sleep times", requirement: .required)
            DatePicker("Wake time", selection: timeBinding(\.wakeTime), displayedComponents: .hourAndMinute)
            DatePicker("Sleep time", selection: timeBinding(\.sleepTime), displayedComponents: .hourAndMinute)
        }
    }

    private var chronotypePage: some View {
        shell("When do you work best?", "The planner will prefer demanding work in your stronger hours.", requirement: .optional) {
            fieldLabel("Chronotype", requirement: .optional)
            Picker("Chronotype", selection: $profile.chronotype) {
                Text("Morning").tag(UserProfile.Chronotype.earlyBird)
                Text("Balanced").tag(UserProfile.Chronotype.balanced)
                Text("Evening").tag(UserProfile.Chronotype.nightOwl)
            }
            .pickerStyle(.segmented)

            fieldLabel("Productive hours", requirement: .optional)
            TextField("Productive hours, if you know them", text: $profile.productiveHours)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var disciplinePage: some View {
        shell("How much structure helps?", "This controls how aggressively the coach protects the plan.", requirement: .optional) {
            fieldLabel("Structure level", requirement: .optional)
            Stepper("Structure level · \(profile.discipline)/5", value: $profile.discipline, in: 1...5)

            fieldLabel("Coach style", requirement: .optional)
            Picker("Coach style", selection: Binding(
                get: { store.data.settings.coachMode },
                set: { value in store.updateSettings { $0.coachMode = value } }
            )) {
                ForEach(CoachMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var commitmentsPage: some View {
        shell("What cannot move?", "School, work, lessons, appointments or other fixed commitments.", requirement: .optional) {
            fieldLabel("Fixed commitments", requirement: .optional)
            TextField("Fixed commitments", text: $profile.fixedCommitments, axis: .vertical)
                .lineLimit(4...10)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var habitsPage: some View {
        shell("What already repeats?", "Existing routines help us avoid asking you to enter the same schedule every day.", requirement: .optional) {
            fieldLabel("Current habits and routines", requirement: .optional)
            TextField("Current habits and routines", text: $profile.currentHabits, axis: .vertical)
                .lineLimit(4...10)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)

            fieldLabel("Planning preferences", requirement: .optional)
            TextField("How do you like plans to feel?", text: $profile.planningPreferences, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .premiumGlassRounded(cornerRadius: 18, interactive: true)
        }
    }

    private var describePage: some View {
        shell("Describe yourself", "Anything the coach should understand about your routine, preferences, weak points, goals or how you like to work.", requirement: .optional) {
            fieldLabel("Extra context", requirement: .optional)
            TextEditor(text: $profile.selfDescription)
                .frame(minHeight: 220)
                .padding(8)
                .scrollContentBackground(.hidden)
                .premiumGlassRounded(cornerRadius: 22, interactive: true)

            Toggle("Use optional body rhythm context", isOn: $profile.bodyRhythmEnabled)
        }
    }

    private func fieldLabel(_ title: String, requirement: Requirement) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("· \(requirement.label)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func advance() {
        guard canContinue else { return }
        if page < total - 1 { page += 1 }
    }

    private func skipCurrentPage() {
        guard currentRequirement == .optional else { return }
        if page == total - 1 {
            showFinishChoice = true
        } else {
            page += 1
        }
    }

    private func deferForLater() {
        guard !working else { return }
        working = true
        store.deferOnboarding()
        Task {
            if SupabaseService.shared.session != nil {
                _ = await SupabaseService.shared.saveSnapshot(store.data)
            }
            await MainActor.run { working = false }
        }
    }

    private func finish(buildFirstPlan: Bool) {
        guard !working else { return }
        working = true
        Task {
            await store.completeOnboarding(profile)
            if buildFirstPlan {
                let input = PlanBuildInput(
                    brainDump: profile.currentHabits,
                    mustWin: profile.primaryGoal,
                    fixedCommitments: profile.fixedCommitments,
                    energy: 3,
                    style: .realistic,
                    plannerMode: .dayChain
                )
                await store.buildPlan(input, for: DateKey.today)
            }
            if SupabaseService.shared.session != nil {
                _ = await SupabaseService.shared.saveSnapshot(store.data)
            }
            await MainActor.run {
                working = false
                if reconfigure { dismiss() }
            }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<UserProfile, String>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = TimeMath.minutes(profile[keyPath: keyPath]) ?? 480
                return Calendar.current.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                profile[keyPath: keyPath] = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
            }
        )
    }
}
