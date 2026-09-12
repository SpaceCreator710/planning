import Foundation
import SwiftUI

struct CoachView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var text = ""
    @State private var sending = false
    @State private var showThreads = false
    @State private var showPaywall = false
    @State private var showTutorSettings = false
    @FocusState private var composerFocused: Bool

    private let planningPrompts: [(title: String, icon: String, seed: String)] = [
        ("Plan my day", "calendar.badge.clock", "Help me make a realistic plan for today: "),
        ("Repair my schedule", "arrow.triangle.2.circlepath", "My day changed. Help me repair the rest of my schedule: "),
        ("Break down a task", "list.bullet.clipboard", "Break this task into small concrete steps: "),
        ("Prioritize", "scope", "Help me decide what matters most today: "),
        ("Optimize my week", "wand.and.stars", "Audit my week and apply the smallest useful scheduling improvements: "),
        ("Change Planning", "slider.horizontal.3", "Change this allowed Planning setting, timeline behavior, or workspace item for me: ")
    ]

    private let schoolPrompts: [(title: String, icon: String, seed: String)] = [
        ("Explain a topic", "book.closed.fill", "Explain this topic: "),
        ("Solve with me", "function", "Help me solve this problem with me, one step at a time: "),
        ("Check my answer", "checkmark.seal.fill", "Check my answer and explain the first thing I should fix: "),
        ("Quiz me", "graduationcap.fill", "Quiz me on this topic, one question at a time: "),
        ("Study plan", "calendar.badge.clock", "Build a realistic study plan for: "),
        ("Homework steps", "list.bullet.clipboard", "Break this homework into small steps and help me start: ")
    ]

    private let generalPrompts: [(title: String, icon: String, seed: String)] = [
        ("Explain", "lightbulb.fill", "Explain this clearly: "),
        ("Compare", "arrow.left.arrow.right", "Compare these options and their trade-offs: "),
        ("Brainstorm", "sparkles", "Brainstorm strong ideas for: "),
        ("Summarize", "text.alignleft", "Summarize this and keep the important points: ")
    ]

    private let workspacePrompts: [(title: String, icon: String, seed: String)] = [
        ("Build a hub", "rectangle.3.group", "Create a workspace hub for: "),
        ("Database", "tablecells", "Create or improve a workspace database for: "),
        ("Turn notes into action", "wand.and.stars", "Turn my workspace notes into concrete tasks and schedule them: "),
        ("Organize workspace", "square.grid.3x3", "Organize my workspace, remove clutter, and connect related pages: "),
        ("Change app", "slider.horizontal.3", "Change this Planning setting or behavior for me: "),
        ("Run an agent", "sparkles.rectangle.stack", "Create or run a reusable Workspace Agent for this job: "),
        ("Publish & share", "globe", "Turn this workspace content into a clean publishable page or presentation: "),
        ("Automate it", "bolt.badge.clock", "Create an automation for this recurring workspace process: ")
    ]

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    modeSwitcher(p: p)

                    if assistantMode == .school {
                        Button { showTutorSettings = true } label: {
                            HStack {
                                Label(studyLevel.label, systemImage: "graduationcap")
                                Spacer()
                                Text("Tutor settings").font(.caption)
                            }.frame(maxWidth: .infinity, minHeight: 32)
                        }.buttonStyle(.glass)
                    }

                    if messages.isEmpty {
                        welcomeCard(p: p)
                        shortcutStrip(p: p)
                    }

                    ForEach(messages) { message in
                        messageBubble(message, p: p)
                            .id(message.id)
                    }

                    if sending {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Working on your request…").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }.padding(.vertical, 12)
                    }
                    if store.hasPendingCoachActions { AIActionReviewCard().id("pending-ai-actions") }
                    Color.clear.frame(height: 1).id("conversation-end")
                }
                .padding(16)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .appCanvas()
            .onChange(of: messages.count) { _, _ in
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo("conversation-end", anchor: .bottom) }
            }
            .onChange(of: store.pendingCoachActions.count) { _, _ in
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo("conversation-end", anchor: .bottom) }
            }
            .onChange(of: sending) { _, _ in
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo("conversation-end", anchor: .bottom) }
            }
        }
        .navigationTitle("AI")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showThreads = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Conversations")

                Menu {
                    ForEach(CoachMode.allCases) { mode in
                        Button {
                            store.updateSettings { $0.coachMode = mode }
                        } label: {
                            if store.data.settings.coachMode == mode {
                                Label(mode.rawValue.capitalized, systemImage: "checkmark")
                            } else {
                                Text(mode.rawValue.capitalized)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("AI response style")
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .sheet(isPresented: $showTutorSettings) {
            NavigationStack {
                ScrollView { schoolControls(p: p).padding(18) }
                    .appCanvas().navigationTitle("Tutor settings")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTutorSettings = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showThreads) { NavigationStack { ConversationListView() } }
        .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
        .planningFeedback(.impact(weight: .light), trigger: sending) { oldValue, newValue in
            !oldValue && newValue
        }
    }

    private var messages: [CoachMessage] { store.conversationMessages() }
    private var assistantMode: AIAssistantMode { store.data.settings.aiAssistantMode ?? .planning }
    private var studyLevel: StudyExplanationLevel { store.data.settings.studyExplanationLevel ?? .grade9 }

    private func modeSwitcher(p: AppPalette) -> some View {
        Menu {
            ForEach(AIAssistantMode.allCases) { mode in
                Button { selectMode(mode) } label: {
                    Label(mode.label, systemImage: assistantMode == mode ? "checkmark" : mode.symbol)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: assistantMode.symbol).foregroundStyle(p.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(assistantMode.label).font(.headline)
                    Text(modeSubtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 44).padding(14)
            .premiumGlassRounded(cornerRadius: 24)
        }.buttonStyle(.plain)
            .disabled(sending || store.hasPendingCoachActions)
            .accessibilityLabel("AI mode: " + assistantMode.label)
    }

    private var modeSubtitle: String {
        switch assistantMode {
        case .planning: return "Schedule, tasks, goals and realistic execution"
        case .school: return "A separate tutor with adjustable explanation level"
        case .general: return "Questions, ideas, comparisons and everyday reasoning"
        case .workspace: return "Agentic pages, databases, knowledge and app control"
        }
    }

    private func schoolControls(p: AppPalette) -> some View {
        PremiumGlassCard(tint: p.accent.opacity(0.06)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Explanation level", systemImage: "graduationcap.fill")
                        .font(.headline)
                    Spacer()
                    Text(studyLevel.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.accent)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(StudyExplanationLevel.allCases) { level in
                            Button {
                                store.updateSettings { $0.studyExplanationLevel = level }
                            } label: {
                                Text(level.label)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.glass)
                            .tint(studyLevel == level ? p.accent : p.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Divider().opacity(0.35)

                Toggle(isOn: Binding(
                    get: { store.data.settings.studyInteractiveSteps ?? true },
                    set: { value in store.updateSettings { $0.studyInteractiveSteps = value } }
                )) {
                    Label("Interactive steps", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }

                Toggle(isOn: Binding(
                    get: { store.data.settings.studyVisualizations ?? true },
                    set: { value in store.updateSettings { $0.studyVisualizations = value } }
                )) {
                    Label("Text diagrams & graphs", systemImage: "chart.xyaxis.line")
                }

                Toggle(isOn: Binding(
                    get: { store.data.settings.studyCheckYourself ?? true },
                    set: { value in store.updateSettings { $0.studyCheckYourself = value } }
                )) {
                    Label("Check yourself", systemImage: "checkmark.seal")
                }

                if store.data.settings.studyInteractiveSteps ?? true {
                    Text("The tutor explains one meaningful step, then waits: “Clear? Continue or repeat this step?”")
                        .font(.footnote)
                        .foregroundStyle(p.secondary)
                }
            }
        }
    }

    private func welcomeCard(p: AppPalette) -> some View {
        PremiumGlassCard(tint: p.accent.opacity(0.10)) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: assistantMode.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(p.accent)
                Text(welcomeTitle)
                    .font(.title2.bold())
                Text(welcomeBody)
                    .foregroundStyle(p.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var welcomeTitle: String {
        switch assistantMode {
        case .planning: return "Your planning coach"
        case .school: return "Your study tutor"
        case .general: return "Your general AI"
        case .workspace: return "Your workspace agent"
        }
    }

    private var welcomeBody: String {
        switch assistantMode {
        case .planning:
            return "Planning Agent is the operational command layer for your app: it can plan and repair schedules, manage tasks, goals, habits, notes and workspace content, run timeline intelligence, and change allowed settings when you explicitly ask."
        case .school:
            return "Learn at the level you choose. Work one step at a time, use compact visual diagrams when useful, and test yourself without getting the answer first."
        case .general:
            return "Ask questions, compare options, brainstorm, summarize or reason through an idea without forcing it into a planning or school workflow."
        case .workspace:
            return "Operate pages, wiki, databases, projects, forms, clips, comments, sites, meetings, automations, time tracking and custom agents. Workspace Agent can turn knowledge into real Planning tasks and schedule changes through the safe action layer."
        }
    }

    private func shortcutStrip(p: AppPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(shortcutTitle)
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(activePrompts, id: \.title) { prompt in
                            Button {
                                text = prompt.seed
                                composerFocused = true
                            } label: {
                                Label(prompt.title, systemImage: prompt.icon)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 4)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
    }

    private var shortcutTitle: String {
        switch assistantMode {
        case .planning: return "Planning shortcuts"
        case .school: return "School shortcuts"
        case .general: return "Quick starts"
        case .workspace: return "Workspace actions"
        }
    }

    private var activePrompts: [(title: String, icon: String, seed: String)] {
        switch assistantMode {
        case .planning: return planningPrompts
        case .school: return schoolPrompts
        case .general: return generalPrompts
        case .workspace: return workspacePrompts
        }
    }

    private func messageBubble(_ message: CoachMessage, p: AppPalette) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 7) {
            HStack {
                if message.role == .user { Spacer(minLength: 48) }

                if message.role == .assistant {
                    CoachMessageBody(content: message.content, accent: p.accent, secondary: p.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .premiumGlassRounded(cornerRadius: 21, interactive: true)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .premiumGlassRounded(
                            cornerRadius: 21,
                            tint: p.accent.opacity(0.18),
                            interactive: true
                        )
                }

                if message.role == .assistant { Spacer(minLength: 48) }
            }

            if message.role == .assistant,
               assistantMode == .school,
               message.id == latestAssistantMessageID {
                HStack(spacing: 8) {
                    if store.data.settings.studyCheckYourself ?? true {
                        Button {
                            sendPreset("Give me one similar practice problem based on what we just covered. Do not include the solution. Wait for my answer, then check it and explain the first mistake if there is one.")
                        } label: {
                            Label("Check yourself", systemImage: "checkmark.seal")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                        .disabled(sending)
                    }

                    Button {
                        sendPreset("Repeat the current step more simply, with one concrete example. Do not move to the next step yet.")
                    } label: {
                        Label("Repeat simpler", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .disabled(sending)
                }
                .padding(.leading, 4)
            }
        }
    }

    private var latestAssistantMessageID: String? {
        messages.last(where: { $0.role == .assistant })?.id
    }

    private var composer: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 8) {
                TextField(composerPlaceholder, text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .premiumGlassCapsule(interactive: true)
                    .submitLabel(.send)
                    .onSubmit { if !sending { send() } }
                    .disabled(store.hasPendingCoachActions)

                Button { send() } label: {
                    Image(systemName: "arrow.up").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Send message")
                .buttonStyle(.glassProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                .disabled(store.hasPendingCoachActions)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var modeMenu: some View {
        Menu {
            Section("AI mode") {
                ForEach(AIAssistantMode.allCases) { mode in
                    let locked = mode != .planning && !store.hasAccess(.fullAI)
                    Button { selectMode(mode) } label: {
                        if locked {
                            Label(mode.label + " · Pro", systemImage: "lock.fill")
                        } else if assistantMode == mode {
                            Label(mode.label, systemImage: "checkmark")
                        } else {
                            Label(mode.label, systemImage: mode.symbol)
                        }
                    }
                }
            }

            if assistantMode == .school {
                Section("Explanation level") {
                    ForEach(StudyExplanationLevel.allCases) { level in
                        Button {
                            store.updateSettings { $0.studyExplanationLevel = level }
                        } label: {
                            if studyLevel == level {
                                Label(level.label, systemImage: "checkmark")
                            } else {
                                Text(level.label)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: assistantMode.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(assistantMode.label)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 42)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Change AI mode")
    }

    private var composerPlaceholder: String {
        if store.hasPendingCoachActions { return "Review pending changes first" }
        switch assistantMode {
        case .planning: return "Ask Planning AI…"
        case .school: return "Ask the tutor…"
        case .general: return "Ask anything…"
        case .workspace: return "Ask Workspace Agent…"
        }
    }

    private func selectMode(_ mode: AIAssistantMode) {
        guard !sending, !store.hasPendingCoachActions else { return }
        if mode != .planning && !store.hasAccess(.fullAI) {
            showPaywall = true
            return
        }
        store.updateSettings { $0.aiAssistantMode = mode }
    }

    private func send() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !sending, !store.hasPendingCoachActions else { return }
        guard store.canUseAIMode(assistantMode) else { showPaywall = true; return }
        text = ""
        sendValue(value)
    }

    private func sendPreset(_ value: String) {
        guard !sending, !store.hasPendingCoachActions else { return }
        guard store.canUseAIMode(assistantMode) else { showPaywall = true; return }
        sendValue(value)
    }

    private func sendValue(_ value: String) {
        sending = true
        Task {
            await store.sendCoach(value)
            await MainActor.run {
                sending = false
                composerFocused = true
            }
        }
    }
}

struct AIActionReviewCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checklist.checked")
                    .font(.title3)
                    .foregroundStyle(p.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review AI changes").font(.headline)
                    Text("Nothing has changed yet")
                        .font(.caption)
                        .foregroundStyle(p.secondary)
                }
                Spacer()
                Text("\(store.pendingCoachActions.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(p.accent)
            }

            Text(store.pendingCoachActionSummary ?? "Review the proposed actions before applying them.")
                .font(.subheadline)
                .foregroundStyle(p.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(store.pendingCoachActions.enumerated()), id: \.offset) { index, action in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(index + 1). \(action.type.replacingOccurrences(of: "_", with: " ").capitalized)").font(.subheadline.weight(.semibold))
                            Text(store.coachActionDetail(action)).font(.footnote).foregroundStyle(p.secondary).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if index + 1 < store.pendingCoachActions.count { Divider() }
                    }
                }.padding(.vertical, 4)
            }.frame(maxHeight: 280).accessibilityLabel("All proposed changes")

            HStack(spacing: 10) {
                Button("Cancel") { store.discardPendingCoachActions() }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)
                Button("Apply changes") { store.confirmPendingCoachActions() }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .premiumGlassRounded(cornerRadius: 24, tint: p.accent.opacity(0.075), interactive: true)
        .accessibilityElement(children: .contain)
    }
}

private struct CoachMessageBody: View {
    let content: String
    let accent: Color
    let secondary: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(Self.segments(content).enumerated()), id: \.offset) { _, segment in
                switch segment.kind {
                case .text:
                    if let attributed = try? AttributedString(markdown: segment.value) {
                        Text(attributed)
                            .textSelection(.enabled)
                    } else {
                        Text(segment.value)
                            .textSelection(.enabled)
                    }
                case .code:
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(segment.value)
                            .font(.system(.callout, design: .monospaced).weight(.medium))
                            .textSelection(.enabled)
                            .padding(11)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumGlassRounded(cornerRadius: 14, tint: accent.opacity(0.10), interactive: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum SegmentKind { case text, code }
    private struct Segment { var kind: SegmentKind; var value: String }

    private static func segments(_ content: String) -> [Segment] {
        let parts = content.components(separatedBy: "```")
        guard parts.count > 1 else { return [Segment(kind: .text, value: content)] }
        return parts.enumerated().compactMap { index, raw in
            guard !raw.isEmpty else { return nil }
            if index.isMultiple(of: 2) {
                return Segment(kind: .text, value: raw.trimmingCharacters(in: .newlines))
            }
            var code = raw.trimmingCharacters(in: .newlines)
            if let newline = code.firstIndex(of: "\n") {
                let first = String(code[..<newline]).lowercased()
                if ["text", "ascii", "plaintext", "txt"].contains(first) {
                    code = String(code[code.index(after: newline)...])
                }
            }
            return Segment(kind: .code, value: code)
        }
    }
}

private struct ConversationListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var ids: [String] { Array(Set(store.data.messages.compactMap(\.conversationId))).sorted() }

    var body: some View {
        List {
            Button("New conversation", systemImage: "plus.bubble") {
                store.newConversation()
                dismiss()
            }
            ForEach(ids, id: \.self) { id in
                Button {
                    store.activeConversationId = id
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(store.data.messages.first(where: { $0.conversationId == id && $0.role == .user })?.content ?? "Conversation")
                            .lineLimit(1)
                        Text("\(store.data.messages.filter { $0.conversationId == id }.count) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
