import Foundation
import SwiftUI
import MapKit
import PhotosUI
import ImageIO

/// Any Workspace command that can alter the plan goes through the same explicit
/// confirmation and full-state Undo transaction. The entire row is tappable.
private struct ConfirmedScheduleActionButton: View {
    @Environment(AppStore.self) private var store
    let title: String
    let systemImage: String
    let confirmationTitle: String
    let message: String
    let undoLabel: String
    let action: @MainActor () -> Void
    @State private var isConfirming = false

    var body: some View {
        Button {
            isConfirming = true
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .confirmationDialog(confirmationTitle, isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Confirm and apply") {
                store.performTimelineTransaction(label: undoLabel) { action() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                NavigationLink { UserProfileView() } label: {
                    HStack(spacing: 16) {
                        ProfileIdentityAvatar(name: store.data.profile.name, tint: p.accent, size: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.data.profile.name.isEmpty ? "Make it yours" : store.data.profile.name)
                                .font(.title2.weight(.semibold)).foregroundStyle(p.text)
                            Text(store.data.profile.nickname.map { $0.isEmpty ? "Profile & account" : "@" + $0 } ?? "Profile & account")
                                .font(.subheadline).foregroundStyle(p.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(p.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        .premiumGlassRounded(cornerRadius: 28, tint: p.accent.opacity(0.04), interactive: true)
                }.buttonStyle(.plain)

                NavigationLink { SettingsView() } label: {
                    PlanningDestinationRow(title: "Personalize Planning", subtitle: "Appearance, planning, notifications and your data", symbol: "slider.horizontal.3")
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Your library", subtitle: "Ideas and progress across both modes")
                    VStack(spacing: 0) {
                        destination("Notes", subtitle: "Write, search and turn ideas into tasks", symbol: "note.text") { NotesView() }
                        destination("Inbox", subtitle: "Capture now. Decide when you are ready", symbol: "tray") { InboxView() }
                        destination("Goals", subtitle: "Outcomes and the next steps that matter", symbol: "scope") { GoalsView() }
                        destination("Progress", subtitle: "Your activity and completed work", symbol: "chart.line.uptrend.xyaxis") { ProgressViewScreen() }
                    }.premiumGlassRounded(cornerRadius: 26)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Go further", subtitle: "Open a focused space for the work ahead")
                    VStack(spacing: 0) {
                        destination("Workspace", subtitle: "Pages, projects and your saved spaces", symbol: "square.grid.3x3") { WorkspaceView() }
                        destination("Horizon Planner", subtitle: "Turn a longer-term outcome into a roadmap", symbol: "map") { HorizonPlannerView() }
                        destination("AI Memory", subtitle: store.data.settings.globalMemoryEnabled == false ? "Off · review saved preferences" : "On · manage what AI remembers", symbol: "brain.head.profile") { MemoryView() }
                    }.premiumGlassRounded(cornerRadius: 26)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Connections & setup")
                    VStack(spacing: 0) {
                        destination("Apple integrations", subtitle: "Calendar, Health and Fitness permissions", symbol: "link") { IntegrationsView() }
                        destination("Built-in AI", subtitle: "Connection, capabilities and diagnostics", symbol: "sparkles") { BuiltInAIView() }
                        destination("Subscription", subtitle: store.data.subscription.isPro ? "Planning Pro" : "Free and Pro features", symbol: "crown") { PaywallView() }
                        destination("Revisit onboarding", subtitle: "Update your routine and planning preferences", symbol: "person.text.rectangle") { OnboardingView(reconfigure: true) }
                    }.premiumGlassRounded(cornerRadius: 26)
                }
                Text("Planning · " + versionText).font(.footnote).foregroundStyle(p.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(18).padding(.bottom, 28)
        }
        .appCanvas().navigationTitle("More")
    }

    private func destination<Destination: View>(_ title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Destination) -> some View {
        NavigationLink(destination: content()) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(.tint).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(buildNumber))"
    }
}

private struct UserProfileView: View {
    @State private var selectedAvatar: PhotosPickerItem?
    @Environment(AppStore.self) private var store
    @State private var showConnection = false
    @State private var deletionStatus = AccountDeletionStatus()
    @State private var accountInfo: SupabaseAccountInfo?
    @State private var exportURL: URL?
    @State private var message: String?
    @State private var working = false
    @State private var linkingProvider: String?
    @State private var confirmDeleteCloud = false
    @State private var confirmDeleteAllData = false
    @State private var confirmDeleteAccount = false
    @State private var identityToUnlink: SupabaseIdentityInfo?

    private let providers = ["google", "apple", "github"]

    var body: some View {
        List {
            Section("Identity") {
                PhotosPicker(selection: $selectedAvatar, matching: .images) {
                    HStack(spacing: 14) {
                        ProfileIdentityAvatar(name: store.data.profile.name, tint: .accentColor, size: 62)
                        Text("Choose profile photo")
                        Spacer()
                        Image(systemName: "photo")
                    }.frame(maxWidth: .infinity, minHeight: 62).contentShape(Rectangle())
                }.buttonStyle(.plain)
                TextField("Display name", text: Binding(get: { store.data.profile.name }, set: { store.data.profile.name = String($0.prefix(80)); store.persist() }))
                TextField("Nickname", text: Binding(get: { store.data.profile.nickname ?? "" }, set: { store.data.profile.nickname = String($0.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }.prefix(32)); store.persist() }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if store.data.profile.avatarImageData != nil {
                    Button("Remove photo", role: .destructive) { store.data.profile.avatarImageData = nil; store.persist() }
                }
                Text("Your nickname is a display name, not a reserved username. Your photo follows your data sync settings and is excluded from AI requests.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Profile") {
                LabeledContent("Name") {
                    Text(store.data.profile.name.isEmpty ? "Not set" : store.data.profile.name)
                        .foregroundStyle(store.data.profile.name.isEmpty ? .secondary : .primary)
                }
                LabeledContent("Main area") {
                    Text(categoryName(store.data.profile.category))
                }
                LabeledContent("Primary goal") {
                    Text(store.data.profile.primaryGoal.isEmpty ? "Not set" : store.data.profile.primaryGoal)
                        .foregroundStyle(store.data.profile.primaryGoal.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.trailing)
                }
                NavigationLink {
                    OnboardingView(reconfigure: true)
                } label: {
                    Label("Edit profile with Onboarding", systemImage: "slider.horizontal.3")
                }
            }

            Section("Account") {
                if !SupabaseService.shared.configured {
                    Label("Account connection is not configured yet", systemImage: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                } else if SupabaseService.shared.session == nil {
                    LabeledContent("Status") {
                        Text("Not connected").foregroundStyle(.secondary)
                    }
                    Button { showConnection = true } label: {
                        Label("Connect account", systemImage: "person.crop.circle.badge.plus")
                    }
                } else {
                    Label(
                        deletionStatus.pending ? "Deletion scheduled" : "Cloud account connected",
                        systemImage: deletionStatus.pending ? "clock.badge.exclamationmark" : "checkmark.icloud.fill"
                    )

                    if let email = accountInfo?.email, !email.isEmpty {
                        LabeledContent("Email") { Text(email).foregroundStyle(.secondary) }
                    }

                    Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await syncNow() }
                    }
                    .disabled(working || deletionStatus.pending)

                    Button("Sign out", role: .destructive) {
                        SupabaseService.shared.signOut()
                        accountInfo = nil
                        deletionStatus = AccountDeletionStatus()
                    }
                }
            }

            if SupabaseService.shared.session != nil {
                Section("Sign-in methods") {
                    ForEach(providers, id: \.self) { provider in
                        providerRow(provider)
                    }

                    Text("You can link Google, Apple and GitHub to the same Planning account, then unlink any method you no longer need. At least one sign-in identity must remain connected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Save all data", systemImage: "square.and.arrow.down") {
                        Task { await saveData() }
                    }
                    .disabled(working || deletionStatus.pending)

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export saved copy", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Delete cloud data", systemImage: "icloud.slash", role: .destructive) {
                        confirmDeleteCloud = true
                    }
                    .disabled(working || deletionStatus.pending)

                    Button("Delete all Planning data", systemImage: "trash.fill", role: .destructive) {
                        confirmDeleteAllData = true
                    }
                    .disabled(working || deletionStatus.pending)
                }

                Section("Account deletion") {
                    if deletionStatus.pending {
                        Button("Restore Account", systemImage: "arrow.uturn.backward.circle.fill") {
                            Task { await restoreAccount() }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(working)

                        if let restoreUntil = deletionStatus.restoreUntil {
                            Text("Restore available until \(restoreUntil.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Delete Account", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                            confirmDeleteAccount = true
                        }
                        .disabled(working)
                    }

                    Text("Deleted accounts can be restored for 7 days. After that window, the cloud account and its stored Planning data are permanently removed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Security") {
                Label("Session tokens are stored in iOS Keychain", systemImage: "key.fill")
                Label("Cloud snapshots are protected by per-user Row Level Security", systemImage: "lock.shield.fill")
                Label("On-device planning data uses iOS file protection", systemImage: "iphone.gen3")
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Profile")
        .task(id: selectedAvatar) { await loadAvatar() }
        .task { await refreshAccountState() }
        .sheet(isPresented: $showConnection, onDismiss: {
            Task { await refreshAccountState() }
        }) {
            AccountConnectionSheet()
        }
        .confirmationDialog("Delete cloud data?", isPresented: $confirmDeleteCloud, titleVisibility: .visible) {
            Button("Delete cloud data", role: .destructive) { Task { await deleteCloudData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the cloud snapshot but keeps your account and the data currently stored on this iPhone.")
        }
        .confirmationDialog("Delete all Planning data?", isPresented: $confirmDeleteAllData, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { Task { await deleteAllData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Planning cloud snapshot and all Planning data stored on this iPhone. Your sign-in account remains active.")
        }
        .confirmationDialog("Schedule account deletion?", isPresented: $confirmDeleteAccount, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) { Task { await requestDeletion() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Planning saves your latest cloud snapshot first, then schedules permanent deletion. You can restore the account within 7 days.")
        }
        .confirmationDialog("Unlink sign-in method?", isPresented: Binding(
            get: { identityToUnlink != nil },
            set: { if !$0 { identityToUnlink = nil } }
        ), titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                guard let identity = identityToUnlink else { return }
                identityToUnlink = nil
                Task { await unlink(identity) }
            }
            Button("Cancel", role: .cancel) { identityToUnlink = nil }
        } message: {
            Text("You will no longer be able to sign in with this method unless you link it again.")
        }
    }

    private func loadAvatar() async {
        guard let selectedAvatar else { return }
        do {
            guard let raw = try await selectedAvatar.loadTransferable(type: Data.self), raw.count <= 20_000_000,
                  let source = CGImageSourceCreateWithData(raw as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 320
                  ] as CFDictionary),
                  let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) else {
                if !Task.isCancelled { message = "Choose another image under 20 MB." }
                return
            }
            guard !Task.isCancelled else { return }
            store.data.profile.avatarImageData = jpeg
            store.persist()
        } catch { if !Task.isCancelled { message = "The photo could not be loaded. Please try again." } }
    }

    @ViewBuilder
    private func providerRow(_ provider: String) -> some View {
        let identity = accountInfo?.identities.first { $0.provider == provider }
        HStack(spacing: 12) {
            ProviderBrandIcon(provider: provider, size: 20)
            Text(providerDisplayName(provider))
            Spacer()

            if let identity {
                Text("Connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button("Unlink", role: .destructive) {
                    identityToUnlink = identity
                }
                .buttonStyle(.glass)
                .disabled(working || deletionStatus.pending || (accountInfo?.identities.count ?? 0) < 2)
            } else {
                Button(linkingProvider == provider ? "Linking…" : "Link") {
                    Task { await link(provider) }
                }
                .buttonStyle(.glass)
                .disabled(working || linkingProvider != nil || deletionStatus.pending)
            }
        }
    }

    private func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "google": return "Google"
        case "apple": return "Apple"
        case "github": return "GitHub"
        default: return provider.capitalized
        }
    }

    private func categoryName(_ category: UserProfile.Category) -> String {
        switch category {
        case .study: return "Study"
        case .career: return "Career"
        case .fitness: return "Fitness"
        case .money: return "Money"
        case .custom: return "Something else"
        }
    }

    private func refreshAccountState() async {
        guard SupabaseService.shared.session != nil else {
            deletionStatus = AccountDeletionStatus()
            accountInfo = nil
            return
        }
        async let deletion = SupabaseService.shared.accountDeletionStatus()
        async let info = SupabaseService.shared.accountInfo()
        deletionStatus = await deletion
        accountInfo = await info
    }

    private func syncNow() async {
        working = true
        defer { working = false }
        await store.syncNow()
        message = store.syncMessage ?? "Your data is up to date."
        accountInfo = await SupabaseService.shared.accountInfo()
    }

    private func link(_ provider: String) async {
        guard linkingProvider == nil else { return }
        linkingProvider = provider
        message = nil
        let ok = await SupabaseService.shared.linkIdentity(provider: provider)
        linkingProvider = nil
        if ok {
            accountInfo = await SupabaseService.shared.accountInfo()
            message = "\(providerDisplayName(provider)) is now linked to your Planning account."
        } else {
            message = "\(providerDisplayName(provider)) could not be linked. Provider sign-in and manual identity linking must be enabled in the release auth setup."
        }
    }

    private func unlink(_ identity: SupabaseIdentityInfo) async {
        working = true
        defer { working = false }
        let name = providerDisplayName(identity.provider)
        let ok = await SupabaseService.shared.unlinkIdentity(identity)
        if ok {
            accountInfo = await SupabaseService.shared.accountInfo()
            message = "\(name) was unlinked."
        } else {
            message = "\(name) could not be unlinked. Keep at least one sign-in identity connected."
        }
    }

    private func saveData() async {
        working = true
        defer { working = false }
        let cloudSaved = await SupabaseService.shared.saveSnapshot(store.data)
        do {
            exportURL = try await PersistenceService.shared.exportJSON(store.data)
            message = cloudSaved
                ? "All Planning data was saved securely to cloud and an export copy is ready."
                : "An export copy is ready. Cloud save could not complete."
        } catch {
            message = cloudSaved ? "All Planning data was saved securely to cloud." : "Data could not be saved right now."
        }
    }

    private func deleteCloudData() async {
        working = true
        defer { working = false }
        let ok = await SupabaseService.shared.deleteCloudSnapshot()
        message = ok ? "Cloud data deleted. Your local data remains on this iPhone." : "Cloud data could not be deleted right now."
    }

    private func deleteAllData() async {
        working = true
        defer { working = false }
        let cloudDeleted = await SupabaseService.shared.deleteCloudSnapshot()
        await store.eraseAllLocalPlanningData()
        message = cloudDeleted ? "All Planning data was deleted. Your account is still active." : "Local data was deleted. Cloud deletion could not be confirmed."
    }

    private func requestDeletion() async {
        working = true
        defer { working = false }
        _ = await SupabaseService.shared.saveSnapshot(store.data)
        if let status = await SupabaseService.shared.requestAccountDeletion() {
            deletionStatus = status
            message = "Account deletion scheduled. Restore is available for 7 days."
        } else {
            message = "Account deletion could not be scheduled right now."
        }
    }

    private func restoreAccount() async {
        working = true
        defer { working = false }
        guard let status = await SupabaseService.shared.restoreAccount() else {
            message = "Account could not be restored right now."
            return
        }
        deletionStatus = status
        if !status.deleted, let snapshot = await SupabaseService.shared.loadSnapshot() {
            store.adoptSnapshot(snapshot)
        }
        accountInfo = await SupabaseService.shared.accountInfo()
        message = status.deleted ? "The 7-day restore window has expired." : "Account restored. Your cloud data is active again."
    }
}

private struct AccountConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var working = false
    @State private var codeSent = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Connect Planning", systemImage: "person.crop.circle.badge.plus")
                            .font(.title3.weight(.semibold))
                        Text("Keep local planning available while optionally adding cloud sync across your devices.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Sign in") {
                    Button { signIn("google") } label: {
                        ProviderButtonLabel(provider: "google", title: "Sign in with Google")
                    }
                    .disabled(working)

                    Button { signIn("apple") } label: {
                        ProviderButtonLabel(provider: "apple", title: "Sign in with Apple")
                    }
                    .disabled(working)

                    Button { signIn("github") } label: {
                        ProviderButtonLabel(provider: "github", title: "Sign in with GitHub")
                    }
                    .disabled(working)
                }

                Section("Email") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(codeSent ? "Verification code sent" : "Send verification code") {
                        sendVerificationCode()
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)

                    if codeSent {
                        TextField("6-digit verification code", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)

                        Button("Verify code") {
                            verifyCode()
                        }
                        .disabled(verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || working)
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("Planning stores the signed-in session in iOS Keychain. Local planning continues to work when the network or cloud service is unavailable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .appCanvas()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func signIn(_ provider: String) {
        guard !working else { return }
        working = true
        statusMessage = nil
        Task {
            let ok = await SupabaseService.shared.signInWithOAuth(provider: provider)
            await MainActor.run {
                working = false
                if ok {
                    dismiss()
                } else {
                    statusMessage = "Sign-in did not complete. Check the release cloud configuration and provider settings."
                }
            }
        }
    }

    private func sendVerificationCode() {
        guard !working else { return }
        working = true
        statusMessage = nil
        verificationCode = ""
        Task {
            let ok = await SupabaseService.shared.sendEmailOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            await MainActor.run {
                working = false
                codeSent = ok
                statusMessage = ok
                    ? "Verification code sent. Enter the 6-digit code from your email."
                    : "Verification code could not be sent. Check the release cloud configuration."
            }
        }
    }

    private func verifyCode() {
        guard !working else { return }
        working = true
        statusMessage = nil
        Task {
            let ok = await SupabaseService.shared.verifyEmailOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                token: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await MainActor.run {
                working = false
                if ok {
                    dismiss()
                } else {
                    statusMessage = "That verification code is invalid or expired."
                }
            }
        }
    }
}

// MARK: - Workspace

struct WorkspaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var showNewPage = false
    @State private var showNewDatabase = false
    @State private var showNewCanvas = false
    @State private var showAutopilotConfirmation = false

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                WorkspaceProfileHeader()

                NavigationLink { WorkspaceSearchView() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        Text("Search your workspace").foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 16)
                    .premiumGlassCapsule()
                }.buttonStyle(.plain)

                GlassEffectContainer(spacing: 10) {
                    PlanningAdaptiveRow {
                        Button { showNewPage = true } label: {
                            Label("New page", systemImage: "plus")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }.buttonStyle(.glassProminent)
                        Menu {
                            Button("Database", systemImage: "tablecells") { showNewDatabase = true }
                            Button("Canvas", systemImage: "rectangle.3.group") { showNewCanvas = true }
                            Button("Task, project or capture…", systemImage: "tray.and.arrow.down") { store.quickAddRequested = true }
                        } label: {
                            Label("Create", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }.buttonStyle(.glass)
                    }
                }

                if store.hasPendingCoachActions { AIActionReviewCard() }
                if store.canUndoTimelineChange {
                    HStack {
                        Text(store.timelineUndoLabel ?? "Changes applied").font(.subheadline)
                        Spacer()
                        Button("Undo") { store.undoLastTimelineChange() }.buttonStyle(.glass)
                    }
                }

                if !favoritePages.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Pinned")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(favoritePages) { page in
                                    NavigationLink { WorkspacePageEditor(page: page) } label: {
                                        Label(page.title, systemImage: page.icon)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.vertical, 8)
                                    }.buttonStyle(.glass)
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                }

                if activeProjects.isEmpty && recentPages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        PlanningEmptyState(title: "A place for your next idea", message: "Start with a page, collect your thoughts, and turn the next step into a task.", symbol: "doc.text")
                        NavigationLink { WorkspaceTemplatesView() } label: {
                            Label("Start from a template", systemImage: "sparkles.rectangle.stack")
                        }.buttonStyle(.glass)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Pick up where you left off")
                        ForEach(recentPages.prefix(3)) { page in
                            NavigationLink { WorkspacePageEditor(page: page) } label: {
                                PlanningDestinationRow(title: page.title, subtitle: page.body.replacingOccurrences(of: "\n", with: " "), symbol: page.icon)
                            }.buttonStyle(.plain)
                        }
                        ForEach(activeProjects.prefix(2)) { project in
                            NavigationLink { WorkspaceProjectDetailView(projectID: project.id) } label: {
                                PlanningDestinationRow(title: project.title, subtitle: project.outcome, symbol: "flag", detail: project.status.rawValue.capitalized)
                            }.buttonStyle(.plain)
                        }
                    }
                }

                if !todayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("On your schedule", subtitle: "Your next steps today")
                        ForEach(TaskTimelineOrder.sorted(todayTasks).prefix(3)) { task in
                            HStack(spacing: 12) {
                                NavigationLink { TaskEditorView(task: task, isNew: false) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title).font(.headline)
                                        Text(task.startTime ?? "Anytime").font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if task.source != .calendar && task.source != .reminder && task.source != .workout {
                                    Button { store.toggleTask(task.id) } label: {
                                        Image(systemName: "circle").font(.title2).frame(width: 44, height: 44)
                                    }.buttonStyle(.plain).foregroundStyle(.tint)
                                        .accessibilityLabel("Complete \(task.title)")
                                }
                            }.padding(16).premiumGlassRounded()
                        }
                        NavigationLink { WorkspaceAgendaView() } label: { Label("Full agenda", systemImage: "arrow.right") }
                            .buttonStyle(.glass)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Your spaces")
                    ForEach(WorkspaceHubSection.allCases.filter { $0 != .settings }) { section in
                        NavigationLink { WorkspaceSectionView(section: section) } label: {
                            PlanningDestinationRow(title: section.title, subtitle: section.subtitle, symbol: section.symbol, detail: sectionStatus(section))
                        }.buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Make the week easier", subtitle: "Review a change before applying it")
                    PlanningAdaptiveRow {
                        Button {
                            store.updateSettings { $0.aiAssistantMode = .workspace }
                            store.selectedTab = .coach
                        } label: {
                            Label("Ask AI", systemImage: "sparkles").frame(maxWidth: .infinity, minHeight: 36)
                        }.buttonStyle(.glass)
                        Button { showAutopilotConfirmation = true } label: {
                            Label("Weekly Autopilot", systemImage: "wand.and.stars").frame(maxWidth: .infinity, minHeight: 36)
                        }.buttonStyle(.glass)
                    }
                    NavigationLink { WorkspaceSettingsHubView() } label: {
                        PlanningDestinationRow(title: "Workspace settings", subtitle: "Behavior, reference and personalization", symbol: "slider.horizontal.3")
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .appCanvas()
        .navigationTitle("Workspace")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { WorkspaceCommandPaletteView() } label: { Image(systemName: "command") }
                    .accessibilityLabel("Workspace commands")
            }
        }
        .sheet(isPresented: $showNewPage) { NavigationStack { WorkspacePageEditor(page: WorkspacePage(title: "Untitled"), isNew: true) } }
        .sheet(isPresented: $showNewDatabase) { NavigationStack { NewWorkspaceDatabaseView() } }
        .sheet(isPresented: $showNewCanvas) { NavigationStack { NewWorkspaceCanvasView() } }
        .confirmationDialog("Run Weekly Autopilot?", isPresented: $showAutopilotConfirmation, titleVisibility: .visible) {
            Button("Apply to this week") {
                store.performTimelineTransaction(label: "Workspace Autopilot") {
                    _ = store.runWorkspaceAutopilot(containing: DateKey.date(store.selectedDate) ?? .now)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apply your configured scheduling rules to this week. Fixed commitments stay protected. You can undo the result here.")
        }
    }

    private var favoritePages: [WorkspacePage] {
        store.data.workspacePages.filter { $0.favorite && !$0.archived }.prefix(8).map { $0 }
    }

    private var activePages: [WorkspacePage] {
        store.data.workspacePages.filter { !$0.archived }
    }

    private var activeProjects: [WorkspaceProject] {
        store.data.workspaceProjects.filter { !$0.archived && $0.status != .done }
    }

    private var recentPages: [WorkspacePage] {
        activePages.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var todayTasks: [PlannerTask] {
        (store.data.plans.first(where: { $0.date == DateKey.today })?.tasks ?? [])
            .filter { $0.status == .pending || $0.status == .active }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted()).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func sectionStatus(_ section: WorkspaceHubSection) -> String {
        switch section {
        case .overview: return "\(store.data.inbox.count) inbox"
        case .knowledge: return "\(activePages.count) pages"
        case .projects: return "\(activeProjects.count) active"
        case .meetings: return "\(store.data.workspaceMeetings.count) notes"
        case .automation: return "\(store.data.workspaceAutomations.filter(\.enabled).count) on"
        case .publish: return "\(store.data.workspaceSites.filter(\.published).count) ready to share"
        case .settings: return "Personalize"
        }
    }

    private func workspaceLiveRow(title: String, subtitle: String, symbol: String, status: String, palette p: AppPalette) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(p.accent)
                .frame(width: 38, height: 38)
                .glassEffect(.regular.tint(p.accent.opacity(0.06)).interactive(), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(p.secondary).lineLimit(1)
            }
            Spacer()
            Text(status).font(.caption2.weight(.semibold)).foregroundStyle(p.accent)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(p.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .premiumGlassRounded(cornerRadius: 22, tint: p.accent.opacity(0.035), interactive: true)
    }

    private func createButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }
}

private struct WorkspaceProfileHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    private var displayName: String {
        let name = store.data.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Planning Member" : name
    }

    private var handle: String {
        if let nickname = store.data.profile.nickname, !nickname.isEmpty { return "@" + nickname }
        let name = store.data.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailName = store.data.profile.email?
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        let source = name.isEmpty ? emailName : name
        let tokens = source
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return "@" + (tokens.isEmpty ? "planning_member" : tokens.joined(separator: "_"))
    }

    private var subtitle: String {
        let goal = store.data.profile.primaryGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        return goal.isEmpty ? "Personal planning workspace" : goal
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        GlassEffectContainer(spacing: 12) {
            NavigationLink {
                UserProfileView()
            } label: {
                HStack(spacing: 14) {
                    ProfileIdentityAvatar(name: displayName, tint: p.accent, size: 62)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .font(.title3.bold())
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                        Text(handle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(p.accent)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(p.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(p.secondary)
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular.tint(p.accent.opacity(0.045)).interactive(), in: Circle())
                }
                .padding(15)
                .premiumGlassRounded(cornerRadius: 26, tint: p.accent.opacity(0.075), interactive: true)
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile for \(displayName), \(handle)")
        }
    }
}

private struct ProfileIdentityAvatar: View {
    @Environment(AppStore.self) private var store
    let name: String
    let tint: Color
    let size: CGFloat

    private var initials: String {
        let letters = name
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return letters.isEmpty ? "P" : letters
    }

    var body: some View {
        ZStack {
            Circle().fill(.clear)
            if let data = store.data.profile.avatarImageData, let photo = UIImage(data: data) {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(initials).font(.system(size: size * 0.31, weight: .bold, design: .rounded)).foregroundStyle(tint).minimumScaleFactor(0.65)
            }
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.tint(tint.opacity(0.13)).interactive(), in: Circle())
        .accessibilityHidden(true)
    }
}

private enum WorkspaceHubSection: String, CaseIterable, Identifiable {
    case overview, knowledge, projects, meetings, automation, publish, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Home"
        case .knowledge: return "Knowledge"
        case .projects: return "Projects & Data"
        case .meetings: return "Meetings & Time"
        case .automation: return "Automate & AI"
        case .publish: return "Share & History"
        case .settings: return "Workspace Settings"
        }
    }
    var subtitle: String {
        switch self {
        case .overview: return "Your agenda, daily notes and captured ideas"
        case .knowledge: return "Pages, spaces, graph and canvas"
        case .projects: return "Roadmaps, databases and forms"
        case .meetings: return "Scheduling, focus and tracking"
        case .automation: return "Workflows, agents and execution"
        case .publish: return "Sites, import, export and versions"
        case .settings: return "Built-in tools and behavior"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "rectangle.3.group.fill"
        case .knowledge: return "books.vertical.fill"
        case .projects: return "shippingbox.fill"
        case .meetings: return "calendar.badge.clock"
        case .automation: return "bolt.badge.clock.fill"
        case .publish: return "globe"
        case .settings: return "slider.horizontal.3"
        }
    }
}

private struct WorkspaceSectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let section: WorkspaceHubSection

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(spacing: 11) {
                PremiumGlassCard(tint: p.accent.opacity(0.065)) {
                    HStack(spacing: 13) {
                        Image(systemName: section.symbol)
                            .font(.title2)
                            .foregroundStyle(p.accent)
                            .frame(width: 42, height: 42)
                            .glassEffect(.regular.tint(p.accent.opacity(0.09)).interactive(), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title).font(.title3.bold())
                            Text(section.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                links
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .appCanvas()
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var links: some View {
        switch section {
        case .overview:
            destination("Dashboard", "rectangle.3.group.fill") { WorkspaceDashboardView() }
            destination("Unified Inbox", "tray.full.fill") { WorkspaceUnifiedInboxView() }
            destination("AI Agenda", "list.bullet.clipboard.fill") { WorkspaceAgendaView() }
            destination("Daily Notes", "sun.max.fill") { WorkspaceDailyNotesView() }
            destination("Universal Search", "magnifyingglass") { WorkspaceSearchView() }
            destination("Command Palette", "command.square.fill") { WorkspaceCommandPaletteView() }
        case .knowledge:
            destination("Pages & Wiki", "doc.on.doc.fill") { WorkspacePagesView() }
            destination("Spaces", "square.grid.2x2.fill") { WorkspaceSpacesView() }
            destination("Templates", "sparkles.rectangle.stack.fill") { WorkspaceTemplatesView() }
            destination("Knowledge Graph", "point.3.connected.trianglepath.dotted") { WorkspaceKnowledgeGraphView() }
            destination("Canvas", "rectangle.3.group.bubble.left") { WorkspaceCanvasesView() }
            destination("Web Clipper & Read Later", "bookmark.fill") { WorkspaceClipsView() }
        case .projects:
            destination("Projects & Roadmaps", "shippingbox.fill") { WorkspaceProjectsView() }
            destination("Databases & Views", "tablecells.fill") { WorkspaceDatabasesView() }
            destination("Forms & Intake", "list.clipboard.fill") { WorkspaceFormsView() }
        case .meetings:
            destination("Meetings & Action Notes", "person.2.wave.2.fill") { WorkspaceMeetingsView() }
            destination("Scheduling & Focus", "calendar.badge.clock") { WorkspaceSchedulingHubView() }
            destination("Time Tracking & Insights", "timer") { WorkspaceTimeTrackingView() }
        case .automation:
            destination("Automations", "bolt.badge.clock.fill") { WorkspaceAutomationsView() }
            destination("Custom Agents", "sparkles.rectangle.stack.fill") { WorkspaceCustomAgentsView() }
            destination("Notes & Inbox", "note.text") { NotesView() }
            destination("Goals", "scope") { GoalsView() }
            destination("Full Planner", "calendar.badge.clock") { TodayView() }
        case .publish:
            destination("Sites & Presentation", "globe") { WorkspaceSitesView() }
            destination("Import & Export", "arrow.up.arrow.down.square.fill") { WorkspaceImportExportView() }
            destination("Activity & Version History", "clock.arrow.circlepath") { WorkspaceActivityView() }
        case .settings:
            destination("Workspace Settings", "gearshape.2.fill") { WorkspaceSettingsHubView() }
            destination("Complete Feature Guide", "info.circle.fill") { WorkspaceFeaturesGuideView() }
        }
    }

    private func destination<Destination: View>(_ title: String, _ symbol: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            PlanningDestinationRow(title: title, subtitle: "", symbol: symbol)
        }.buttonStyle(.plain)
    }

    private var palette: AppPalette {
        AppPalette.resolve(settings: store.data.settings, scheme: scheme)
    }
}

private struct WorkspaceSettingsHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                PremiumGlassCard(tint: p.accent.opacity(0.08)) {
                    HStack(spacing: 13) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(p.accent)
                            .frame(width: 42, height: 42)
                            .glassEffect(.regular.tint(p.accent.opacity(0.09)).interactive(), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Workspace Settings").font(.title3.bold())
                            Text("Behavior, built-in capabilities and app-wide controls.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                PremiumGlassCard(tint: p.accent.opacity(0.045)) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Workspace behavior")
                        Toggle("Memory across Planner and Workspace", isOn: Binding(
                            get: { store.data.settings.globalMemoryEnabled != false },
                            set: { store.setGlobalMemoryEnabled($0) }
                        ))

                        NavigationLink { WorkspaceTimePolicyView() } label: {
                            Label("Focus & scheduling policy", systemImage: "calendar.badge.clock")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.glass)

                        NavigationLink { SettingsView() } label: {
                            Label("App settings", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.glass)
                    }
                }

                SectionLabel("Built-in capabilities", subtitle: "Kept out of the main hub, organized here for reference.")
                builtInGroup(
                    "Knowledge & databases",
                    symbol: "books.vertical.fill",
                    items: [
                        ("Backlinks, relations, aliases and graph", "link"),
                        ("Nine database views, properties, formulas and rollups", "tablecells.fill"),
                        ("Pages, wiki, canvas, forms and templates", "doc.on.doc.fill")
                    ],
                    palette: p
                )
                builtInGroup(
                    "Execution & automation",
                    symbol: "bolt.fill",
                    items: [
                        ("Projects, auto-scheduling and Timeline bridge", "shippingbox.fill"),
                        ("Automations, custom agents and Weekly Autopilot", "wand.and.stars"),
                        ("Meetings, scheduling links, focus and time tracking", "timer")
                    ],
                    palette: p
                )
                builtInGroup(
                    "Capture, sharing & safety",
                    symbol: "lock.shield.fill",
                    items: [
                        ("Web clipper, Read Later, sites and presentations", "globe"),
                        ("Comments, versions, Markdown and JSON transfer", "clock.arrow.circlepath"),
                        ("Offline-first storage and private synchronization", "lock.shield.fill")
                    ],
                    palette: p
                )
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .appCanvas()
        .navigationTitle("Workspace Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func builtInGroup(
        _ title: String,
        symbol: String,
        items: [(String, String)],
        palette p: AppPalette
    ) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Label(item.0, systemImage: item.1)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
        } label: {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(p.text)
        }
        .padding(15)
        .premiumGlassRounded(cornerRadius: 22, tint: p.accent.opacity(0.04), interactive: true)
    }
}

private struct WorkspacePagesView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var showNewPage = false
    @State private var showArchived = false

    var body: some View {
        List {
            if filteredPages.isEmpty {
                ContentUnavailableView("No pages", systemImage: "doc.text.magnifyingglass", description: Text("Create a page or use a template to start your workspace."))
            } else {
                ForEach(filteredPages) { page in
                    NavigationLink { WorkspacePageEditor(page: page) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.icon)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(page.title).font(.headline)
                                HStack(spacing: 6) {
                                    if page.favorite { Label("Favorite", systemImage: "star.fill") }
                                    if page.verified == true { Label("Verified", systemImage: "checkmark.seal.fill") }
                                    if page.locked == true { Label("Locked", systemImage: "lock.fill") }
                                    if !page.tags.isEmpty { Text(page.tags.prefix(3).joined(separator: " · ")) }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Archive", systemImage: "archivebox", role: .destructive) { store.archiveWorkspacePage(page.id) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search pages and content")
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Pages")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showArchived.toggle() } label: { Image(systemName: showArchived ? "archivebox.fill" : "archivebox") }
                Button { showNewPage = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNewPage) {
            NavigationStack { WorkspacePageEditor(page: WorkspacePage(title: "Untitled"), isNew: true) }
        }
    }

    private var filteredPages: [WorkspacePage] {
        store.data.workspacePages
            .filter { showArchived ? $0.archived : !$0.archived }
            .filter { page in
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                return q.isEmpty || page.title.localizedCaseInsensitiveContains(q) || page.body.localizedCaseInsensitiveContains(q) || page.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
            }
            .sorted { lhs, rhs in
                if lhs.favorite != rhs.favorite { return lhs.favorite && !rhs.favorite }
                return lhs.updatedAt > rhs.updatedAt
            }
    }
}

private struct WorkspacePageEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkspacePage
    @State private var tagText: String
    @State private var aliasText: String
    @State private var showRelations = false
    @State private var showHistory = false
    @State private var showComments = false
    @State private var showPresentation = false
    @State private var pageAIWorking = false
    @State private var pageAIStatus = ""
    @State private var taskDraft: PlannerTask?
    @State private var savedPage: WorkspacePage?
    @State private var showSiteSettings = false
    let isNew: Bool

    init(page: WorkspacePage, isNew: Bool = false) {
        _draft = State(initialValue: page)
        _savedPage = State(initialValue: isNew ? nil : page)
        _tagText = State(initialValue: page.tags.joined(separator: ", "))
        _aliasText = State(initialValue: (page.aliases ?? []).joined(separator: ", "))
        self.isNew = isNew
    }

    var body: some View {
        Form {
            Section("Page") {
                HStack {
                    Image(systemName: draft.icon)
                    TextField("Title", text: $draft.title)
                        .font(.title3.weight(.semibold))
                        .disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                }
            }

            Section("Content") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("Heading") { appendBlock("\n## Heading\n") }.buttonStyle(.glass).disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                        Button("Checklist") { appendBlock("\n- [ ] ") }.buttonStyle(.glass).disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                        Button("Callout") { appendBlock("\n> Note: ") }.buttonStyle(.glass).disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                        Button("Table") { appendBlock("\n| Column | Value |\n| --- | --- |\n|  |  |\n") }.buttonStyle(.glass).disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                        Button("Code") { appendBlock("\n```\n\n```\n") }.buttonStyle(.glass).disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                    }
                }
                TextEditor(text: $draft.body)
                    .frame(minHeight: 300)
                    .font(.body)
                    .disabled(draft.locked == true || pageAIWorking || store.hasPendingCoachActions)
                Text("Markdown, tables, checklists and code blocks work here. Type [[Another page]] to create a backlink-style connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Page AI") {
                Button("Improve & structure", systemImage: "wand.and.stars") { runPageAI("Improve this page for clarity and structure. Preserve all factual content, remove repetition, use useful headings/checklists, and update the page itself.") }
                    .disabled(pageAIWorking || store.hasPendingCoachActions || draft.locked == true)
                Button("Summarize page", systemImage: "text.badge.minus") { runPageAI("Replace the page body with a concise, high-signal summary that preserves key facts, decisions, dates and action items.") }
                    .disabled(pageAIWorking || store.hasPendingCoachActions || draft.locked == true)
                Button("Extract actions to Planning", systemImage: "checklist") { runPageAI("Extract genuine actionable items from this page and create the smallest useful Planning tasks or project actions. Do not invent work that is not supported by the page.") }
                    .disabled(pageAIWorking || store.hasPendingCoachActions || draft.locked == true)
                Button("Turn into execution plan", systemImage: "shippingbox.and.arrow.backward.fill") { runPageAI("Turn this page into a coherent execution system: create or update a workspace project when useful, create only necessary tasks, add dependencies where supported, and schedule only when the page gives enough timing information.") }
                    .disabled(pageAIWorking || store.hasPendingCoachActions || draft.locked == true)
                if pageAIWorking { ProgressView("Workspace AI is working…") }
                if !pageAIStatus.isEmpty { Text(pageAIStatus).font(.caption).foregroundStyle(.secondary) }
                if store.hasPendingCoachActions { AIActionReviewCard() }
                Text("AI proposes changes for you to review before applying them.").font(.caption).foregroundStyle(.secondary)
            }

            Section {
                NavigationLink { pageDetails } label: {
                    Label("Page details, links & tools", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.disabled(pageAIWorking || store.hasPendingCoachActions)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle(isNew ? "New page" : draft.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { if isNew { Button("Cancel") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(); if isNew { dismiss() } }.buttonStyle(.glassProminent).disabled(pageAIWorking || store.hasPendingCoachActions)
            }
        }
        .sheet(isPresented: $showRelations) {
            NavigationStack {
                List {
                    ForEach(store.data.workspacePages.filter { $0.id != draft.id && !$0.archived }) { page in
                        Button {
                            if draft.relatedPageIDs.contains(page.id) { draft.relatedPageIDs.removeAll { $0 == page.id } }
                            else { draft.relatedPageIDs.append(page.id) }
                        } label: {
                            HStack {
                                Label(page.title, systemImage: page.icon)
                                Spacer()
                                if draft.relatedPageIDs.contains(page.id) { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                .navigationTitle("Relations")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showRelations = false } } }
            }
        }
        .sheet(isPresented: $showHistory) { NavigationStack { WorkspacePageHistoryView(pageID: draft.id) } }
        .sheet(isPresented: $showComments) { NavigationStack { WorkspacePageCommentsView(pageID: draft.id) } }
        .fullScreenCover(isPresented: $showPresentation) { WorkspacePresentationView(page: draft) }
        .sheet(item: $taskDraft) { task in NavigationStack { TaskEditorView(task: task, isNew: true) } }
        .sheet(isPresented: $showSiteSettings) { NavigationStack { WorkspaceSitesView() } }
        .onChange(of: store.data.workspacePages.first { $0.id == draft.id }) { _, latest in
            guard let latest, let savedPage, draft == savedPage,
                  tagText == savedPage.tags.joined(separator: ", "),
                  aliasText == (savedPage.aliases ?? []).joined(separator: ", ") else { return }
            draft = latest
            self.savedPage = latest
            tagText = latest.tags.joined(separator: ", ")
            aliasText = (latest.aliases ?? []).joined(separator: ", ")
        }
    }

    private var pageDetails: some View {
                    Form {
                        Section("Page details") {
                Toggle("Favorite", isOn: $draft.favorite)
                Toggle("Wiki home", isOn: Binding(get: { draft.wikiHome ?? false }, set: { draft.wikiHome = $0 }))
                Toggle("Verified page", isOn: Binding(get: { draft.verified ?? false }, set: { value in draft.verified = value; draft.verifiedAt = value ? ISO8601DateFormatter().string(from: .now) : nil }))
                Toggle("Lock content", isOn: Binding(get: { draft.locked ?? false }, set: { draft.locked = $0 }))
                TextField("Aliases, comma separated", text: $aliasText)
                Picker("Space", selection: Binding(get: { draft.spaceID ?? "" }, set: { draft.spaceID = $0.isEmpty ? nil : $0 })) {
                    Text("None").tag("")
                    ForEach(store.data.workspaceSpaces) { space in Text(space.title).tag(space.id) }
                }
                Picker("Parent page", selection: Binding(get: { draft.parentID ?? "" }, set: { draft.parentID = $0.isEmpty ? nil : $0 })) {
                    Text("Top level").tag("")
                    ForEach(store.data.workspacePages.filter { $0.id != draft.id && !$0.archived }) { page in Text(page.title).tag(page.id) }
                }
                TextField("Tags, comma separated", text: $tagText)

                        }
            Section("Relations") {
                if relatedPages.isEmpty {
                    Text("No linked pages yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(relatedPages) { page in
                        Label(page.title, systemImage: page.icon)
                    }
                }
                Button("Edit relations", systemImage: "link.badge.plus") { showRelations = true }
            }

            Section("Backlinks") {
                if backlinks.isEmpty {
                    Text("No page links to this page yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(backlinks) { page in
                        NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: "arrowshape.turn.up.left.fill") }
                    }
                }
            }

            Section("Page power tools") {
                Button("Version history", systemImage: "clock.arrow.circlepath") { save(); showHistory = true }
                Button("Comments & mentions", systemImage: "bubble.left.and.bubble.right.fill") { save(); showComments = true }
                Button("Presentation mode", systemImage: "play.rectangle.fill") { save(); showPresentation = true }
                Button("Site export settings", systemImage: "globe") {
                    save()
                    let slug = draft.title.lowercased().replacingOccurrences(of: " ", with: "-").filter { $0.isLetter || $0.isNumber || $0 == "-" }
                    if let existing = store.data.workspaceSites.first(where: { $0.pageID == draft.id }) {
                        var site = existing; site.title = draft.title; site.slug = slug.isEmpty ? "page" : slug; store.saveWorkspaceSite(site)
                    } else {
                        store.saveWorkspaceSite(WorkspaceSite(title: draft.title, pageID: draft.id, slug: slug.isEmpty ? "page" : slug))
                    }
                    showSiteSettings = true
                }
            }

            Section("Actions") {
                Button("Turn page into a task", systemImage: "calendar.badge.plus") {
                    var task = PlanEngine.manualTask(title: draft.title.isEmpty ? "Workspace task" : draft.title, date: store.selectedDate)
                    task.note = draft.body
                    task.source = .notes
                    taskDraft = task
                }
                Button("Turn page into a project", systemImage: "shippingbox.fill") {
                    let project = WorkspaceProject(title: draft.title.isEmpty ? "Workspace project" : draft.title, status: .active, outcome: String(draft.body.prefix(500)), pageIDs: [draft.id])
                    store.saveWorkspacePage(draft)
                    store.saveWorkspaceProject(project)
                }
                Button("Send to Inbox", systemImage: "tray.and.arrow.down") {
                    store.addInbox(draft.title.isEmpty ? "Workspace item" : draft.title)
                }
                ShareLink(item: draft.body.isEmpty ? draft.title : "# \(draft.title)\n\n\(draft.body)") {
                    Label("Share page", systemImage: "square.and.arrow.up")
                }
            }
                    }.scrollContentBackground(.hidden).appCanvas().navigationTitle("Page details")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
    }

    private var relatedPages: [WorkspacePage] { store.data.workspacePages.filter { draft.relatedPageIDs.contains($0.id) } }
    private var backlinks: [WorkspacePage] {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let token = "[[\(draft.title)]]"
        return store.data.workspacePages.filter { $0.id != draft.id && $0.body.localizedCaseInsensitiveContains(token) }
    }

    private func appendBlock(_ block: String) {
        if !draft.body.isEmpty && !draft.body.hasSuffix("\n") { draft.body += "\n" }
        draft.body += block
    }

    private func runPageAI(_ instruction: String) {
        guard !pageAIWorking, !store.hasPendingCoachActions, draft.locked != true else { return }
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        draft.aliases = aliasText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        save()
        pageAIWorking = true
        pageAIStatus = ""
        Task {
            let reply = await store.runWorkspacePageAI(draft.id, instruction: instruction)
            await MainActor.run {
                if let refreshed = store.data.workspacePages.first(where: { $0.id == draft.id }) {
                    draft = refreshed
                    savedPage = refreshed
                    tagText = refreshed.tags.joined(separator: ", ")
                    aliasText = (refreshed.aliases ?? []).joined(separator: ", ")
                }
                pageAIStatus = reply
                pageAIWorking = false
            }
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        draft.aliases = aliasText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        store.saveWorkspacePage(draft)
        if let refreshed = store.data.workspacePages.first(where: { $0.id == draft.id }) {
            draft = refreshed
            savedPage = refreshed
        }
    }
}

private struct WorkspaceDatabasesView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceDatabases.isEmpty {
                ContentUnavailableView("No databases", systemImage: "tablecells", description: Text("Use databases for projects, reading lists, CRM-like lists, study trackers and anything with repeatable records."))
            }
            ForEach(store.data.workspaceDatabases) { database in
                NavigationLink { WorkspaceDatabaseDetailView(databaseID: database.id) } label: {
                    Label(database.title, systemImage: database.icon)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { store.deleteWorkspaceDatabase(database.id) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Databases")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceDatabaseView() } }
    }
}

private struct NewWorkspaceDatabaseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var view: WorkspaceDatabaseView = .table

    var body: some View {
        Form {
            TextField("Database name", text: $title)
            Picker("Default view", selection: $view) { ForEach(WorkspaceDatabaseView.allCases) { Text($0.label).tag($0) } }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("New database")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.saveWorkspaceDatabase(WorkspaceDatabase(title: name.isEmpty ? "Database" : name, view: view))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceDatabaseDetailView: View {
    @Environment(AppStore.self) private var store
    let databaseID: String
    @State private var newRecordTitle = ""
    @State private var editingRecord: WorkspaceRecord?
    @State private var showSettings = false

    private var database: WorkspaceDatabase? { store.data.workspaceDatabases.first(where: { $0.id == databaseID }) }

    var body: some View {
        Group {
            if let database {
                VStack(spacing: 10) {
                    HStack {
                        Picker("View", selection: Binding(
                            get: { database.view },
                            set: { newValue in var copy = database; copy.view = newValue; store.saveWorkspaceDatabase(copy) }
                        )) {
                            ForEach(WorkspaceDatabaseView.allCases) { view in Label(view.label, systemImage: view.symbol).tag(view) }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                        Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                            .buttonStyle(.glass)
                    }
                    .padding(.horizontal)

                    HStack {
                        TextField("New record", text: $newRecordTitle)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .premiumGlassCapsule(interactive: true)
                        Button { addRecord() } label: { Image(systemName: "plus") }.buttonStyle(.glassProminent)
                    }
                    .padding(.horizontal)

                    databaseContent(database)
                }
                .appCanvas()
                .navigationTitle(database.title)
            } else {
                ContentUnavailableView("Database not found", systemImage: "exclamationmark.triangle")
            }
        }
        .sheet(item: $editingRecord) { record in
            NavigationStack { WorkspaceRecordEditor(databaseID: databaseID, record: record) }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { WorkspaceDatabaseSettingsView(databaseID: databaseID) }
        }
    }

    @ViewBuilder
    private func databaseContent(_ database: WorkspaceDatabase) -> some View {
        switch database.view {
        case .board:
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(["Not started", "In progress", "Done"], id: \.self) { status in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(status).font(.headline)
                            ForEach(filteredRecords(database).filter { $0.status == status }) { record in
                                recordCard(database: database, record: record)
                            }
                        }
                        .frame(width: 250, alignment: .topLeading)
                        .padding(12)
                        .premiumGlassRounded(cornerRadius: 20, interactive: true)
                    }
                }
                .padding()
            }
        case .calendar:
            List(filteredRecords(database).sorted { ($0.dueDate ?? "9999") < ($1.dueDate ?? "9999") }) { record in
                recordRow(database: database, record: record, showDate: true)
            }
            .scrollContentBackground(.hidden)
        case .gallery:
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(filteredRecords(database)) { record in
                        Button { editingRecord = record } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "doc.richtext.fill").font(.title2)
                                Text(record.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                Text(record.status).font(.caption).foregroundStyle(.secondary)
                                if let due = record.dueDate { Label(due, systemImage: "calendar").font(.caption2).foregroundStyle(.secondary) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                            .padding(12)
                            .premiumGlassRounded(cornerRadius: 18, interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        case .timeline:
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredRecords(database).sorted { ($0.dueDate ?? "9999") < ($1.dueDate ?? "9999") }) { record in
                        HStack(spacing: 12) {
                            VStack(spacing: 3) {
                                Circle().fill(.secondary).frame(width: 8, height: 8)
                                Rectangle().fill(.secondary.opacity(0.25)).frame(width: 2, height: 42)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.dueDate ?? "No date").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(record.title).font(.headline)
                                ProgressView(value: Double(record.progress ?? (record.status == "Done" ? 100 : 0)), total: 100)
                            }
                            Spacer()
                            Button { editingRecord = record } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
                .padding()
            }
        case .map:
            WorkspaceDatabaseMapView(database: database) { record in editingRecord = record }
        case .form:
            WorkspaceInlineDatabaseForm(databaseID: database.id)
        case .chart:
            WorkspaceDatabaseChartView(database: database)
        case .map:
            List(filteredRecords(database)) { record in
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.title).font(.headline)
                        Text(locationValue(record, database: database)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { editingRecord = record } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .scrollContentBackground(.hidden)
        case .table, .list:
            List(filteredRecords(database)) { record in
                recordRow(database: database, record: record, showDate: database.view == .table)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func locationValue(_ record: WorkspaceRecord, database: WorkspaceDatabase) -> String {
        if let property = (database.properties ?? []).first(where: { $0.type == .location }), let value = record.properties?[property.name], !value.isEmpty { return value }
        return record.properties?["Location"] ?? "No location"
    }

    private func filteredRecords(_ database: WorkspaceDatabase) -> [WorkspaceRecord] {
        let query = (database.filterQuery ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var records = database.records.filter { record in
            query.isEmpty || record.title.localizedCaseInsensitiveContains(query) || record.status.localizedCaseInsensitiveContains(query) || record.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) || record.note.localizedCaseInsensitiveContains(query)
        }
        if let key = database.sortProperty, !key.isEmpty {
            records.sort { lhs, rhs in
                let lv = key == "Title" ? lhs.title : key == "Status" ? lhs.status : key == "Due" ? (lhs.dueDate ?? "9999") : (lhs.properties?[key] ?? "")
                let rv = key == "Title" ? rhs.title : key == "Status" ? rhs.status : key == "Due" ? (rhs.dueDate ?? "9999") : (rhs.properties?[key] ?? "")
                return database.sortAscending == false ? lv > rv : lv < rv
            }
        }
        return records
    }

    private func recordCard(database: WorkspaceDatabase, record: WorkspaceRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.title).font(.headline)
            if let due = record.dueDate { Text(due).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Edit") { editingRecord = record }.buttonStyle(.glass)
                Button("Move") { cycleStatus(databaseID: database.id, record: record) }.buttonStyle(.glass)
                Spacer()
                Button(role: .destructive) { store.deleteWorkspaceRecord(databaseID: database.id, recordID: record.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.glass)
            }
        }
        .padding(10)
        .premiumGlassRounded(cornerRadius: 16, tint: nil, interactive: true)
    }

    private func recordRow(database: WorkspaceDatabase, record: WorkspaceRecord, showDate: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                HStack(spacing: 6) {
                    Text(record.status)
                    if showDate, let due = record.dueDate { Text("· \(due)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Not started") { setStatus(database.id, record.id, "Not started") }
                Button("In progress") { setStatus(database.id, record.id, "In progress") }
                Button("Done") { setStatus(database.id, record.id, "Done") }
                Button("Edit", systemImage: "pencil") { editingRecord = record }
                Button("Turn into task", systemImage: "calendar.badge.plus") { recordToTask(record) }
                Button("Delete", role: .destructive) { store.deleteWorkspaceRecord(databaseID: database.id, recordID: record.id) }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    private func addRecord() {
        let value = newRecordTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        store.addWorkspaceRecord(databaseID: databaseID, record: WorkspaceRecord(title: value))
        newRecordTitle = ""
    }

    private func setStatus(_ databaseID: String, _ recordID: String, _ status: String) {
        store.updateWorkspaceRecord(databaseID: databaseID, recordID: recordID) { $0.status = status }
    }

    private func cycleStatus(databaseID: String, record: WorkspaceRecord) {
        let next = record.status == "Not started" ? "In progress" : record.status == "In progress" ? "Done" : "Not started"
        setStatus(databaseID, record.id, next)
    }

    private func recordToTask(_ record: WorkspaceRecord) {
        var task = PlanEngine.manualTask(title: record.title, date: record.dueDate ?? store.selectedDate)
        task.note = record.note.isEmpty ? nil : record.note
        task.source = .notes
        store.addTask(task)
    }
}

private struct WorkspaceRecordEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let databaseID: String
    @State private var draft: WorkspaceRecord
    @State private var tagText: String
    @State private var taskDraft: PlannerTask?

    private var database: WorkspaceDatabase? { store.data.workspaceDatabases.first(where: { $0.id == databaseID }) }

    init(databaseID: String, record: WorkspaceRecord) {
        self.databaseID = databaseID
        _draft = State(initialValue: record)
        _tagText = State(initialValue: record.tags.joined(separator: ", "))
    }

    var body: some View {
        Form {
            Section("Record") {
                TextField("Title", text: $draft.title)
                Picker("Status", selection: $draft.status) {
                    Text("Not started").tag("Not started")
                    Text("In progress").tag("In progress")
                    Text("Done").tag("Done")
                }
                TextField("Due date · YYYY-MM-DD", text: Binding(get: { draft.dueDate ?? "" }, set: { draft.dueDate = $0.isEmpty ? nil : $0 }))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Tags, comma separated", text: $tagText)
                TextField("Assignee", text: Binding(get: { draft.assignee ?? "" }, set: { draft.assignee = $0.isEmpty ? nil : $0 }))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progress · \(draft.progress ?? 0)%").font(.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { Double(draft.progress ?? 0) }, set: { draft.progress = Int($0.rounded()) }), in: 0...100, step: 5)
                }
                Picker("Project", selection: Binding(get: { draft.projectID ?? "" }, set: { draft.projectID = $0.isEmpty ? nil : $0 })) {
                    Text("None").tag("")
                    ForEach(store.data.workspaceProjects.filter { !$0.archived }) { project in Text(project.title).tag(project.id) }
                }
                TextField("Location name", text: Binding(get: { draft.locationName ?? "" }, set: { draft.locationName = $0.isEmpty ? nil : $0 }))
                TextField("Latitude", text: Binding(
                    get: { draft.latitude.map { String($0) } ?? "" },
                    set: { draft.latitude = Double($0.replacingOccurrences(of: ",", with: ".")) }
                ))
                .keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: Binding(
                    get: { draft.longitude.map { String($0) } ?? "" },
                    set: { draft.longitude = Double($0.replacingOccurrences(of: ",", with: ".")) }
                ))
                .keyboardType(.numbersAndPunctuation)
            }
            if let properties = database?.properties, !properties.isEmpty {
                Section("Properties") {
                    ForEach(properties) { property in
                        propertyEditor(property)
                    }
                }
            }
            Section("Notes") {
                TextEditor(text: $draft.note).frame(minHeight: 160)
            }
            Section("Action bridge") {
                Button("Turn into task", systemImage: "calendar.badge.plus") {
                    var task = PlanEngine.manualTask(title: draft.title, date: draft.dueDate.flatMap { DateKey.date($0).map(DateKey.string) } ?? store.selectedDate)
                    task.note = draft.note.isEmpty ? nil : draft.note
                    task.source = .notes
                    taskDraft = task
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Record")
        .sheet(item: $taskDraft) { task in NavigationStack { TaskEditorView(task: task, isNew: true) } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    draft.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    store.updateWorkspaceRecord(databaseID: databaseID, recordID: draft.id) { $0 = draft }
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    @ViewBuilder
    private func propertyEditor(_ property: WorkspacePropertyDefinition) -> some View {
        let binding = Binding<String>(
            get: { draft.properties?[property.name] ?? "" },
            set: { value in
                var values = draft.properties ?? [:]
                values[property.name] = value
                draft.properties = values
            }
        )
        switch property.type {
        case .checkbox:
            Toggle(property.name, isOn: Binding(get: { binding.wrappedValue == "true" }, set: { binding.wrappedValue = $0 ? "true" : "false" }))
        case .select, .status:
            let options = property.options.isEmpty ? (property.type == .status ? ["Not started", "In progress", "Blocked", "Done"] : []) : property.options
            Picker(property.name, selection: binding) {
                Text("None").tag("")
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        case .progress:
            VStack(alignment: .leading, spacing: 5) {
                Text("\(property.name) · \(Int(Double(binding.wrappedValue) ?? 0))%")
                Slider(value: Binding(get: { Double(binding.wrappedValue) ?? 0 }, set: { binding.wrappedValue = String(Int($0.rounded())) }), in: 0...100, step: 5)
            }
        case .rating:
            VStack(alignment: .leading, spacing: 5) {
                Text("\(property.name) · \(Int(Double(binding.wrappedValue) ?? 0))/5")
                Slider(value: Binding(get: { Double(binding.wrappedValue) ?? 0 }, set: { binding.wrappedValue = String(Int($0.rounded())) }), in: 0...5, step: 1)
            }
        case .createdTime:
            LabeledContent(property.name, value: draft.createdAt)
        case .lastEditedTime:
            LabeledContent(property.name, value: draft.updatedAt)
        case .url:
            TextField(property.name, text: binding).textInputAutocapitalization(.never).keyboardType(.URL)
        case .email:
            TextField(property.name, text: binding).textInputAutocapitalization(.never).keyboardType(.emailAddress)
        case .phone:
            TextField(property.name, text: binding).keyboardType(.phonePad)
        case .number:
            TextField(property.name, text: binding).keyboardType(.decimalPad)
        case .date:
            TextField("\(property.name) · YYYY-MM-DD", text: binding).textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation)
        case .multiSelect, .people, .files, .location, .relation, .rollup, .formula, .text:
            TextField(property.name, text: binding)
        }
    }
}

private struct WorkspaceCanvasesView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceCanvases.isEmpty {
                ContentUnavailableView("No canvases", systemImage: "rectangle.on.rectangle.angled", description: Text("Create a visual canvas for ideas, project maps and connected thinking."))
            }
            ForEach(store.data.workspaceCanvases) { canvas in
                NavigationLink { WorkspaceCanvasDetailView(canvasID: canvas.id) } label: {
                    Label(canvas.title, systemImage: "rectangle.on.rectangle.angled")
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { store.deleteWorkspaceCanvas(canvas.id) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Canvas")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceCanvasView() } }
    }
}

private struct NewWorkspaceCanvasView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        Form { TextField("Canvas name", text: $title) }
            .scrollContentBackground(.hidden)
            .appCanvas()
            .navigationTitle("New canvas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.saveWorkspaceCanvas(WorkspaceCanvas(title: name.isEmpty ? "Canvas" : name))
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
    }
}

private struct WorkspaceCanvasDetailView: View {
    @Environment(AppStore.self) private var store
    let canvasID: String
    @State private var showAdd = false
    @State private var nodeTitle = ""

    private var canvas: WorkspaceCanvas? { store.data.workspaceCanvases.first(where: { $0.id == canvasID }) }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.clear).frame(width: 900, height: 900)
                if let canvas {
                    ForEach(canvas.edges ?? []) { edge in
                        if let from = canvas.nodes.first(where: { $0.id == edge.fromNodeID }), let to = canvas.nodes.first(where: { $0.id == edge.toNodeID }) {
                            Path { path in
                                path.move(to: CGPoint(x: from.x, y: from.y))
                                path.addLine(to: CGPoint(x: to.x, y: to.y))
                            }
                            .stroke(.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 6]))
                        }
                    }
                    ForEach(canvas.nodes) { node in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(node.title).font(.headline)
                            if !node.note.isEmpty { Text(node.note).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                        }
                        .frame(width: 190, alignment: .leading)
                        .padding(12)
                        .premiumGlassRounded(cornerRadius: 18, interactive: true)
                        .position(x: CGFloat(node.x), y: CGFloat(node.y))
                        .gesture(DragGesture().onEnded { value in moveNode(node.id, by: value.translation) })
                    }
                }
            }
        }
        .appCanvas()
        .navigationTitle(canvas?.title ?? "Canvas")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Connect last two", systemImage: "point.topleft.down.to.point.bottomright.curvepath") { connectLastTwo() }
                    Button("Clear connections", systemImage: "eraser", role: .destructive) { clearConnections() }
                } label: { Image(systemName: "link") }
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("Add node", isPresented: $showAdd) {
            TextField("Node title", text: $nodeTitle)
            Button("Cancel", role: .cancel) { nodeTitle = "" }
            Button("Add") { addNode() }
        }
    }

    private func addNode() {
        guard let index = store.data.workspaceCanvases.firstIndex(where: { $0.id == canvasID }) else { return }
        let title = nodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.workspaceCanvases[index].nodes.append(WorkspaceCanvasNode(title: title.isEmpty ? "Idea" : title, x: 180 + Double(store.data.workspaceCanvases[index].nodes.count % 3) * 220, y: 160 + Double(store.data.workspaceCanvases[index].nodes.count / 3) * 150))
        store.persist(); nodeTitle = ""
    }

    private func moveNode(_ nodeID: String, by translation: CGSize) {
        guard let c = store.data.workspaceCanvases.firstIndex(where: { $0.id == canvasID }), let n = store.data.workspaceCanvases[c].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        store.data.workspaceCanvases[c].nodes[n].x = max(100, min(800, store.data.workspaceCanvases[c].nodes[n].x + Double(translation.width)))
        store.data.workspaceCanvases[c].nodes[n].y = max(80, min(820, store.data.workspaceCanvases[c].nodes[n].y + Double(translation.height)))
        store.persist()
    }

    private func connectLastTwo() {
        guard let c = store.data.workspaceCanvases.firstIndex(where: { $0.id == canvasID }), store.data.workspaceCanvases[c].nodes.count >= 2 else { return }
        let nodes = store.data.workspaceCanvases[c].nodes
        let from = nodes[nodes.count - 2].id
        let to = nodes[nodes.count - 1].id
        var edges = store.data.workspaceCanvases[c].edges ?? []
        guard !edges.contains(where: { ($0.fromNodeID == from && $0.toNodeID == to) || ($0.fromNodeID == to && $0.toNodeID == from) }) else { return }
        edges.append(WorkspaceCanvasEdge(fromNodeID: from, toNodeID: to))
        store.data.workspaceCanvases[c].edges = edges
        store.persist()
    }

    private func clearConnections() {
        guard let c = store.data.workspaceCanvases.firstIndex(where: { $0.id == canvasID }) else { return }
        store.data.workspaceCanvases[c].edges = []
        store.persist()
    }
}

private struct WorkspaceSearchView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var showSaveSearch = false
    @State private var savedSearchTitle = ""

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !store.data.workspaceSavedSearches.isEmpty {
                    Section("Saved searches") {
                        ForEach(store.data.workspaceSavedSearches) { search in
                            Button { query = search.query } label: {
                                HStack {
                                    Label(search.title, systemImage: "bookmark.fill")
                                    Spacer()
                                    Text(search.query).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .swipeActions { Button(role: .destructive) { store.deleteWorkspaceSavedSearch(search.id) } label: { Label("Delete", systemImage: "trash") } }
                        }
                    }
                }
                ContentUnavailableView("Search everything", systemImage: "magnifyingglass", description: Text("Search pages, projects, databases, records, meetings, notes, tasks, goals and Inbox from one place."))
            } else {
                Section("Inbox") { ForEach(store.data.inbox.filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(20)) { item in
                    NavigationLink { InboxView() } label: { Label(item.title, systemImage: "tray") }
                } }
                Section("Databases") { ForEach(store.data.workspaceDatabases.filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(20)) { database in
                    NavigationLink { WorkspaceDatabaseDetailView(databaseID: database.id) } label: { Label(database.title, systemImage: "tablecells") }
                } }
                Section("Pages") { ForEach(pageResults) { page in NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) } } }
                Section("Projects") { ForEach(projectResults) { project in NavigationLink { WorkspaceProjectDetailView(projectID: project.id) } label: { Label(project.title, systemImage: "flag.checkered") } } }
                Section("Database records") { ForEach(Array(recordResults.enumerated()), id: \.offset) { _, hit in NavigationLink { WorkspaceRecordEditor(databaseID: hit.databaseID, record: hit.record) } label: { Label("\(hit.record.title) · \(hit.databaseTitle)", systemImage: "tablecells") } } }
                Section("Meetings") { ForEach(meetingResults) { meeting in NavigationLink { WorkspaceMeetingEditor(meeting: meeting) } label: { Label("\(meeting.title) · \(meeting.date)", systemImage: "person.2") } } }
                Section("Tasks") { ForEach(taskResults) { task in NavigationLink { TaskEditorView(task: task, isNew: false) } label: { Label("\(task.title) · \(task.planDate)", systemImage: IconEngine.symbol(for: task)) } } }
                Section("Notes") { ForEach(noteResults) { note in NavigationLink { NoteEditorView(note: note) } label: { Label(note.title, systemImage: "note.text") } } }
                Section("Goals") { ForEach(goalResults) { goal in NavigationLink { GoalDetailView(goalID: goal.id) } label: { Label("\(goal.title) · \(goal.progress)%", systemImage: "scope") } } }
            }
        }
        .searchable(text: $query, prompt: "Search Planning")
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Universal Search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button { savedSearchTitle = query; showSaveSearch = true } label: { Image(systemName: "bookmark") }
                }
            }
        }
        .alert("Save search", isPresented: $showSaveSearch) {
            TextField("Name", text: $savedSearchTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let title = savedSearchTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                store.saveWorkspaceSavedSearch(WorkspaceSavedSearch(title: title.isEmpty ? query : title, query: query))
            }
        }
    }

    private var pageResults: [WorkspacePage] { store.data.workspacePages.filter { !$0.archived && ($0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)) }.prefix(20).map { $0 } }
    private var projectResults: [WorkspaceProject] { store.data.workspaceProjects.filter { !$0.archived && ($0.title.localizedCaseInsensitiveContains(query) || $0.outcome.localizedCaseInsensitiveContains(query)) }.prefix(20).map { $0 } }
    private var recordResults: [(databaseID: String, databaseTitle: String, record: WorkspaceRecord)] { store.data.workspaceDatabases.flatMap { db in db.records.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query) || ($0.assignee?.localizedCaseInsensitiveContains(query) ?? false) }.map { (db.id, db.title, $0) } }.prefix(20).map { $0 } }
    private var meetingResults: [WorkspaceMeetingNote] { store.data.workspaceMeetings.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.notes.localizedCaseInsensitiveContains(query) || $0.actionItems.contains(where: { $0.localizedCaseInsensitiveContains(query) }) }.prefix(20).map { $0 } }
    private var taskResults: [PlannerTask] { store.data.plans.flatMap(\.tasks).filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.note?.localizedCaseInsensitiveContains(query) ?? false) }.prefix(20).map { $0 } }
    private var noteResults: [AppNote] { store.data.notes.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }.prefix(20).map { $0 } }
    private var goalResults: [Goal] { store.data.goals.filter { !$0.archived && ($0.title.localizedCaseInsensitiveContains(query) || $0.why.localizedCaseInsensitiveContains(query)) }.prefix(20).map { $0 } }
}

private struct WorkspaceTemplatesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List(store.data.workspaceTemplates) { template in
            Button {
                store.saveWorkspacePage(WorkspacePage(title: template.title, body: template.body, icon: template.icon, tags: template.tags))
            } label: {
                HStack {
                    Label(template.title, systemImage: template.icon)
                    Spacer()
                    Text("Use").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Templates")
    }
}

// MARK: - Workspace power tools

private struct WorkspaceDashboardView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Workspace Home").font(.title2.bold())
                    Text("Knowledge, projects, databases, planning and scheduling in one command center.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        metric("Pages", store.data.workspacePages.filter { !$0.archived }.count)
                        metric("Projects", store.data.workspaceProjects.filter { !$0.archived }.count)
                        metric("Databases", store.data.workspaceDatabases.count)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Quick actions") {
                NavigationLink { WorkspaceAgendaView() } label: { Label("Open AI Agenda", systemImage: "list.bullet.clipboard.fill") }
                NavigationLink { WorkspaceDailyNotesView() } label: { Label("Open Daily Notes", systemImage: "sun.max.fill") }
                ConfirmedScheduleActionButton(
                    title: "Protect weekly focus",
                    systemImage: "shield.lefthalf.filled",
                    confirmationTitle: "Protect this week's focus?",
                    message: "Planning will add only the focus blocks needed to meet your configured target. You can undo the result from Today.",
                    undoLabel: "Protect weekly focus"
                ) { _ = store.protectWeeklyFocus() }
                ConfirmedScheduleActionButton(
                    title: "Run enabled manual automations",
                    systemImage: "bolt.fill",
                    confirmationTitle: "Run manual automations?",
                    message: "All enabled manual Workspace rules will run once. You can undo their combined result from Today.",
                    undoLabel: "Manual Workspace automations"
                ) {
                    for automation in store.data.workspaceAutomations where automation.enabled && automation.trigger == .manual {
                        store.runWorkspaceAutomation(automation.id)
                    }
                }
            }

            if !activeProjects.isEmpty {
                Section("Active projects") {
                    ForEach(activeProjects.prefix(6)) { project in
                        NavigationLink { WorkspaceProjectDetailView(projectID: project.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title).font(.headline)
                                ProgressView(value: Double(project.progress), total: 100)
                                Text("\(project.status.label) · \(project.progress)%")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !recentPages.isEmpty {
                Section("Recent knowledge") {
                    ForEach(recentPages.prefix(8)) { page in
                        NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) }
                    }
                }
            }

            Section("Saved searches") {
                if store.data.workspaceSavedSearches.isEmpty {
                    Text("Save searches from Universal Search to create fast knowledge views.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.data.workspaceSavedSearches) { item in
                        HStack {
                            Image(systemName: "bookmark.fill")
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text(item.query).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { store.deleteWorkspaceSavedSearch(item.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Workspace Home")
    }

    private var activeProjects: [WorkspaceProject] { store.data.workspaceProjects.filter { !$0.archived && $0.status != .done } }
    private var recentPages: [WorkspacePage] { store.data.workspacePages.filter { !$0.archived }.sorted { $0.updatedAt > $1.updatedAt } }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .premiumGlassRounded(cornerRadius: 16, interactive: true)
    }
}


private struct WorkspaceUnifiedInboxView: View {
    @Environment(AppStore.self) private var store
    @State private var agentWorking = false
    @State private var agentStatus = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Label("One inbox for everything", systemImage: "tray.full.fill")
                        .font(.headline)
                    Text("Planner captures, unread web clips, unresolved comments and at-risk projects are triaged in one place so nothing disappears between Planner and Workspace.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }

            Section("AI triage") {
                Button {
                    guard !agentWorking else { return }
                    agentWorking = true
                    agentStatus = ""
                    store.updateSettings { $0.aiAssistantMode = .workspace }
                    Task {
                        let before = store.data.messages.count
                        await store.sendCoach("Triage my Unified Inbox. Review unscheduled Inbox items, unread web clips, unresolved page comments, blocked or deadline-risk projects and overdue pending tasks. Make only clearly useful changes: schedule actionable work, connect it to projects/pages when supported, and leave ambiguous items untouched. Summarize exactly what you changed.", conversationId: "workspace-unified-inbox")
                        await MainActor.run {
                            if store.data.messages.count > before, let last = store.data.messages.last?.content {
                                agentStatus = last
                            } else {
                                agentStatus = "Triage finished with no changes."
                            }
                            agentWorking = false
                        }
                    }
                } label: {
                    Label(agentWorking ? "Triage in progress…" : "Triage with Workspace Agent", systemImage: "sparkles")
                }
                .disabled(agentWorking)
                if agentWorking { ProgressView() }
                if !agentStatus.isEmpty { Text(agentStatus).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Planner Inbox") {
                if store.data.inbox.isEmpty {
                    Text("No unscheduled Inbox items.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.data.inbox) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title).font(.headline)
                            if let note = item.note, !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
                            HStack(spacing: 8) {
                                Button("Today", systemImage: "calendar.badge.plus") {
                                    var task = PlanEngine.manualTask(title: item.title, date: DateKey.today)
                                    task.note = item.note
                                    store.addTask(task)
                                    store.deleteInbox(item.id)
                                }
                                .buttonStyle(.glass)
                                Button("Selected day", systemImage: "calendar") {
                                    var task = PlanEngine.manualTask(title: item.title, date: store.selectedDate)
                                    task.note = item.note
                                    store.addTask(task)
                                    store.deleteInbox(item.id)
                                }
                                .buttonStyle(.glass)
                                Button(role: .destructive) { store.deleteInbox(item.id) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.glass)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Unread web clips") {
                if unreadClips.isEmpty {
                    Text("Read-later is clear.").foregroundStyle(.secondary)
                } else {
                    ForEach(unreadClips) { clip in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(clip.title, systemImage: "bookmark.fill").font(.headline)
                            if !clip.url.isEmpty { Text(clip.url).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                            HStack {
                                Button("Make page", systemImage: "doc.badge.plus") { _ = store.workspaceClipToPage(clip.id) }
                                    .buttonStyle(.glass)
                                Button("Mark read", systemImage: "checkmark") {
                                    var updated = clip; updated.read = true; store.saveWorkspaceClip(updated)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
            }

            Section("Open comments") {
                if openComments.isEmpty {
                    Text("No unresolved comments.").foregroundStyle(.secondary)
                } else {
                    ForEach(openComments) { comment in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(comment.text).font(.subheadline)
                            if let page = page(for: comment.pageID) {
                                NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) }
                            }
                            Button("Resolve", systemImage: "checkmark.bubble.fill") { store.resolveWorkspaceComment(comment.id) }
                                .buttonStyle(.glass)
                        }
                    }
                }
            }

            Section("At-risk projects") {
                if atRiskProjects.isEmpty {
                    Text("No blocked or deadline-risk projects.").foregroundStyle(.secondary)
                } else {
                    ForEach(atRiskProjects) { project in
                        NavigationLink { WorkspaceProjectDetailView(projectID: project.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(project.title).font(.headline); Spacer(); Text(project.status.label).font(.caption) }
                                if let deadline = project.deadline { Label(deadline, systemImage: "calendar.badge.exclamationmark").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }

            Section("Overdue execution") {
                if overdueTasks.isEmpty {
                    Text("No overdue pending tasks.").foregroundStyle(.secondary)
                } else {
                    ForEach(overdueTasks.prefix(12)) { task in
                        Button {
                            store.selectedDate = task.planDate
                            store.selectedTab = .today
                        } label: {
                            HStack {
                                Label(task.title, systemImage: task.icon ?? IconEngine.symbol(for: task.title, category: task.category))
                                Spacer()
                                Text(task.planDate).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Unified Inbox")
    }

    private var unreadClips: [WorkspaceClip] { store.data.workspaceClips.filter { !$0.archived && !$0.read } }
    private var openComments: [WorkspaceComment] { store.data.workspaceComments.filter { !$0.resolved } }
    private var overdueTasks: [PlannerTask] {
        store.data.plans.flatMap(\.tasks).filter { ($0.status == .pending || $0.status == .active) && $0.planDate < DateKey.today }
    }
    private var atRiskProjects: [WorkspaceProject] {
        store.data.workspaceProjects.filter { project in
            guard !project.archived && project.status != .done else { return false }
            if project.status == .blocked { return true }
            if let deadline = project.deadline { return deadline <= DateKey.today && project.progress < 100 }
            return false
        }
    }
    private func page(for id: String) -> WorkspacePage? { store.data.workspacePages.first(where: { $0.id == id }) }
}

private struct WorkspaceProjectsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceProjects.filter({ !$0.archived }).isEmpty {
                ContentUnavailableView("No projects", systemImage: "shippingbox", description: Text("Projects connect outcomes, tasks, pages, milestones and deadlines."))
            }
            ForEach(store.data.workspaceProjects.filter { !$0.archived }.sorted { lhs, rhs in
                if lhs.status != rhs.status { return lhs.status.rawValue < rhs.status.rawValue }
                return (lhs.deadline ?? "9999") < (rhs.deadline ?? "9999")
            }) { project in
                NavigationLink { WorkspaceProjectDetailView(projectID: project.id) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(project.title).font(.headline); Spacer(); Text(project.status.label).font(.caption).foregroundStyle(.secondary) }
                        ProgressView(value: Double(project.progress), total: 100)
                        HStack {
                            if let deadline = project.deadline { Label(deadline, systemImage: "calendar") }
                            Spacer()
                            Text("P\(project.priority)")
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { store.deleteWorkspaceProject(project.id) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Projects")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceProjectView() } }
    }
}

private struct NewWorkspaceProjectView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var outcome = ""
    @State private var deadline = ""
    @State private var priority = 2

    var body: some View {
        Form {
            TextField("Project name", text: $title)
            TextField("Outcome", text: $outcome, axis: .vertical)
            TextField("Deadline · YYYY-MM-DD", text: $deadline)
                .textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation)
            Picker("Priority", selection: $priority) { Text("P1").tag(1); Text("P2").tag(2); Text("P3").tag(3) }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New project")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.saveWorkspaceProject(WorkspaceProject(title: name.isEmpty ? "Project" : name, status: .active, priority: priority, deadline: deadline.isEmpty ? nil : deadline, outcome: outcome))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceProjectDetailView: View {
    @Environment(AppStore.self) private var store
    let projectID: String
    @State private var taskTitle = ""
    @State private var showAddTask = false

    private var project: WorkspaceProject? { store.data.workspaceProjects.first(where: { $0.id == projectID }) }
    private var projectTasks: [PlannerTask] { store.data.plans.flatMap(\.tasks).filter { $0.projectID == projectID || (project?.taskIDs.contains($0.id) ?? false) } }

    var body: some View {
        Form {
            if let project {
                Section("Project") {
                    TextField("Title", text: binding(project, \.title))
                    Picker("Status", selection: binding(project, \.status)) { ForEach(WorkspaceProjectStatus.allCases) { Text($0.label).tag($0) } }
                    Picker("Priority", selection: binding(project, \.priority)) { Text("P1").tag(1); Text("P2").tag(2); Text("P3").tag(3) }
                    TextField("Deadline", text: Binding(get: { project.deadline ?? "" }, set: { value in update { $0.deadline = value.isEmpty ? nil : value } }))
                    TextField("Outcome", text: binding(project, \.outcome), axis: .vertical)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Progress · \(project.progress)%")
                        Slider(value: Binding(get: { Double(project.progress) }, set: { value in update { $0.progress = Int(value.rounded()) } }), in: 0...100, step: 5)
                    }
                    Toggle("Auto-schedule project work", isOn: binding(project, \.autoSchedule))
                    ConfirmedScheduleActionButton(
                        title: "Auto-schedule project now",
                        systemImage: "wand.and.stars",
                        confirmationTitle: "Schedule this project?",
                        message: "Only flexible project tasks will be placed. Fixed and imported commitments stay untouched, and the result can be undone.",
                        undoLabel: "Schedule \(project.title)"
                    ) { _ = store.autoScheduleWorkspaceProject(project.id) }
                }

                Section("Tasks") {
                    Button("Add task", systemImage: "plus") { showAddTask = true }
                    ForEach(projectTasks) { task in
                        HStack {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading) {
                                Text(task.title)
                                Text("\(task.planDate) · \(task.startTime ?? "Any time")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Knowledge") {
                    ForEach(store.data.workspacePages.filter { project.pageIDs.contains($0.id) }) { page in
                        NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) }
                    }
                    Menu("Link page", systemImage: "link.badge.plus") {
                        ForEach(store.data.workspacePages.filter { !$0.archived && !project.pageIDs.contains($0.id) }) { page in
                            Button(page.title) { update { $0.pageIDs.append(page.id) } }
                        }
                    }
                }

                Section("Milestones") {
                    ForEach(project.milestoneTitles, id: \.self) { milestone in
                        Button {
                            update {
                                if $0.completedMilestones.contains(milestone) { $0.completedMilestones.removeAll { $0 == milestone } }
                                else { $0.completedMilestones.append(milestone) }
                                if !$0.milestoneTitles.isEmpty { $0.progress = Int((Double($0.completedMilestones.count) / Double($0.milestoneTitles.count) * 100).rounded()) }
                            }
                        } label: {
                            Label(milestone, systemImage: project.completedMilestones.contains(milestone) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    Button("Add milestone", systemImage: "flag.badge.plus") { update { $0.milestoneTitles.append("Milestone \($0.milestoneTitles.count + 1)") } }
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle(project?.title ?? "Project")
        .alert("Add project task", isPresented: $showAddTask) {
            TextField("Task", text: $taskTitle)
            Button("Cancel", role: .cancel) { taskTitle = "" }
            Button("Add") { addTask() }
        }
    }

    private func binding<T>(_ project: WorkspaceProject, _ keyPath: WritableKeyPath<WorkspaceProject, T>) -> Binding<T> {
        Binding(get: { project[keyPath: keyPath] }, set: { value in update { $0[keyPath: keyPath] = value } })
    }

    private func update(_ body: (inout WorkspaceProject) -> Void) {
        guard var project = project else { return }
        body(&project)
        store.saveWorkspaceProject(project)
    }

    private func addTask() {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var task = PlanEngine.manualTask(title: title, date: project?.deadline ?? store.selectedDate)
        task.projectID = projectID
        task.category = .work
        store.addTask(task)
        update { $0.taskIDs.append(task.id) }
        taskTitle = ""
    }
}

private struct WorkspaceDatabaseSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let databaseID: String
    @State private var showNewProperty = false

    private var database: WorkspaceDatabase? { store.data.workspaceDatabases.first(where: { $0.id == databaseID }) }

    var body: some View {
        Form {
            if let database {
                Section("View rules") {
                    TextField("Description", text: Binding(get: { database.description ?? "" }, set: { value in update { $0.description = value.isEmpty ? nil : value } }))
                    TextField("Filter", text: Binding(get: { database.filterQuery ?? "" }, set: { value in update { $0.filterQuery = value.isEmpty ? nil : value } }))
                    Picker("Sort", selection: Binding(get: { database.sortProperty ?? "" }, set: { value in update { $0.sortProperty = value.isEmpty ? nil : value } })) {
                        Text("None").tag("")
                        Text("Title").tag("Title")
                        Text("Status").tag("Status")
                        Text("Due").tag("Due")
                        ForEach(database.properties ?? []) { Text($0.name).tag($0.name) }
                    }
                    Toggle("Ascending", isOn: Binding(get: { database.sortAscending != false }, set: { value in update { $0.sortAscending = value } }))
                }

                Section("Properties") {
                    Button("Add property", systemImage: "plus") { showNewProperty = true }
                    ForEach(database.properties ?? []) { property in
                        HStack {
                            Label(property.name, systemImage: property.type.symbol)
                            Spacer()
                            Text(property.type.label).font(.caption).foregroundStyle(.secondary)
                            Button(role: .destructive) { store.deleteWorkspaceProperty(databaseID: databaseID, propertyID: property.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Database settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $showNewProperty) { NavigationStack { NewWorkspacePropertyView(databaseID: databaseID) } }
    }

    private func update(_ body: (inout WorkspaceDatabase) -> Void) {
        guard var database = database else { return }
        body(&database)
        store.saveWorkspaceDatabase(database)
    }
}

private struct NewWorkspacePropertyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let databaseID: String
    @State private var name = ""
    @State private var type: WorkspacePropertyType = .text
    @State private var options = ""
    @State private var formula = ""

    var body: some View {
        Form {
            TextField("Property name", text: $name)
            Picker("Type", selection: $type) { ForEach(WorkspacePropertyType.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
            if type == .select || type == .multiSelect { TextField("Options, comma separated", text: $options) }
            if type == .formula { TextField("Formula / rule", text: $formula) }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New property")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    let opts = options.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    store.addWorkspaceProperty(databaseID: databaseID, definition: WorkspacePropertyDefinition(name: value, type: type, options: opts, formula: formula.isEmpty ? nil : formula))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceInlineDatabaseForm: View {
    @Environment(AppStore.self) private var store
    let databaseID: String
    @State private var title = ""
    @State private var note = ""
    @State private var values: [String: String] = [:]
    @State private var saved = false

    private var database: WorkspaceDatabase? { store.data.workspaceDatabases.first(where: { $0.id == databaseID }) }

    var body: some View {
        Form {
            Section("Submit") {
                TextField("Title", text: $title)
                TextField("Notes", text: $note, axis: .vertical)
                ForEach(database?.properties ?? []) { property in
                    TextField(property.name, text: Binding(get: { values[property.name] ?? "" }, set: { values[property.name] = $0 }))
                }
                Button("Submit response", systemImage: "paperplane.fill") { submit() }.buttonStyle(.glassProminent)
                if saved { Label("Saved to database", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func submit() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addWorkspaceRecord(databaseID: databaseID, record: WorkspaceRecord(title: name, note: note, properties: values))
        title = ""; note = ""; values = [:]; saved = true
    }
}

private struct WorkspaceDatabaseChartView: View {
    let database: WorkspaceDatabase

    private var groups: [(String, Int)] {
        let dictionary = Dictionary(grouping: database.records, by: { $0.status }).mapValues(\.count)
        return dictionary.keys.sorted().map { ($0, dictionary[$0] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Records by status").font(.title3.bold())
                if groups.isEmpty { Text("No records yet.").foregroundStyle(.secondary) }
                ForEach(groups, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(item.0); Spacer(); Text("\(item.1)").foregroundStyle(.secondary) }
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.18))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.65)).frame(width: proxy.size.width * CGFloat(item.1) / CGFloat(max(1, database.records.count)))
                                }
                        }
                        .frame(height: 10)
                    }
                }
            }
            .padding()
        }
    }
}

private struct WorkspaceFormsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceForms.isEmpty { Text("Create shareable-style intake forms that write directly into a Workspace database.").foregroundStyle(.secondary) }
            ForEach(store.data.workspaceForms) { form in
                NavigationLink { WorkspaceFormRunner(formID: form.id) } label: {
                    VStack(alignment: .leading) {
                        Text(form.title)
                        Text(store.data.workspaceDatabases.first(where: { $0.id == form.databaseID })?.title ?? "Missing database").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceForm(form.id) } }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Forms")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceFormView() } }
    }
}

private struct NewWorkspaceFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var databaseID = ""

    var body: some View {
        Form {
            TextField("Form title", text: $title)
            Picker("Database", selection: $databaseID) {
                Text("Choose").tag("")
                ForEach(store.data.workspaceDatabases) { Text($0.title).tag($0.id) }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New form")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    guard !databaseID.isEmpty else { return }
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.saveWorkspaceForm(WorkspaceForm(title: name.isEmpty ? "Form" : name, databaseID: databaseID))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceFormRunner: View {
    @Environment(AppStore.self) private var store
    let formID: String
    @State private var title = ""
    @State private var values: [String: String] = [:]
    @State private var message: String?

    private var form: WorkspaceForm? { store.data.workspaceForms.first(where: { $0.id == formID }) }
    private var database: WorkspaceDatabase? { form.flatMap { form in store.data.workspaceDatabases.first(where: { $0.id == form.databaseID }) } }

    var body: some View {
        Form {
            Section("Response") {
                TextField("Title", text: $title)
                ForEach(database?.properties ?? []) { property in
                    TextField(property.name, text: Binding(get: { values[property.name] ?? "" }, set: { values[property.name] = $0 }))
                }
                Button("Submit", systemImage: "paperplane.fill") { submit() }.buttonStyle(.glassProminent)
            }
            if let message { Section { Text(message).foregroundStyle(.secondary) } }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle(form?.title ?? "Form")
    }

    private func submit() {
        guard let form, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.addWorkspaceRecord(databaseID: form.databaseID, record: WorkspaceRecord(title: title, properties: values))
        title = ""; values = [:]; message = form.confirmationMessage
    }
}

private struct WorkspaceMeetingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceMeetings.isEmpty { Text("Capture meetings, decisions and action items, then turn actions directly into scheduled tasks.").foregroundStyle(.secondary) }
            ForEach(store.data.workspaceMeetings.sorted { $0.date > $1.date }) { meeting in
                NavigationLink { WorkspaceMeetingEditor(meeting: meeting) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meeting.title).font(.headline)
                        Text("\(meeting.date) · \(meeting.actionItems.count) action item(s)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceMeeting(meeting.id) } }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Meetings")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { WorkspaceMeetingEditor(meeting: WorkspaceMeetingNote(title: "Meeting"), isNew: true) } }
    }
}

private struct WorkspaceMeetingEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkspaceMeetingNote
    @State private var attendeesText: String
    @State private var actionsText: String
    @State private var decisionsText: String
    let isNew: Bool

    init(meeting: WorkspaceMeetingNote, isNew: Bool = false) {
        _draft = State(initialValue: meeting)
        _attendeesText = State(initialValue: meeting.attendees.joined(separator: ", "))
        _actionsText = State(initialValue: meeting.actionItems.joined(separator: "\n"))
        _decisionsText = State(initialValue: meeting.decisions.joined(separator: "\n"))
        self.isNew = isNew
    }

    var body: some View {
        Form {
            Section("Meeting") {
                TextField("Title", text: $draft.title)
                TextField("Date · YYYY-MM-DD", text: $draft.date)
                TextField("Attendees, comma separated", text: $attendeesText)
            }
            Section("Notes") { TextEditor(text: $draft.notes).frame(minHeight: 180) }
            Section("Decisions") { TextEditor(text: $decisionsText).frame(minHeight: 100) }
            Section("Action items · one per line") { TextEditor(text: $actionsText).frame(minHeight: 120) }
            Section("Actions") {
                Button("Create tasks from action items", systemImage: "checklist") { save(); store.turnMeetingActionsIntoTasks(draft.id) }
                Button("Create meeting page", systemImage: "doc.badge.plus") {
                    save()
                    let body = "# \(draft.title)\n\n## Notes\n\(draft.notes)\n\n## Decisions\n" + draft.decisions.map { "- \($0)" }.joined(separator: "\n") + "\n\n## Action items\n" + draft.actionItems.map { "- [ ] \($0)" }.joined(separator: "\n")
                    store.saveWorkspacePage(WorkspacePage(title: draft.title, body: body, icon: "person.2.wave.2.fill", tags: ["meeting", draft.date]))
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle(draft.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { if isNew { Button("Cancel") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); if isNew { dismiss() } }.buttonStyle(.glassProminent) }
        }
    }

    private func save() {
        draft.attendees = attendeesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        draft.actionItems = actionsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        draft.decisions = decisionsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        store.saveWorkspaceMeeting(draft)
    }
}

private struct WorkspaceAutomationsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            if store.data.workspaceAutomations.isEmpty { Text("Automations can react to records and completed tasks or run manually. Actions can create tasks, pages, Inbox items or database records.").foregroundStyle(.secondary) }
            ForEach(store.data.workspaceAutomations) { automation in
                HStack {
                    NavigationLink { WorkspaceAutomationEditor(automation: automation) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(automation.title).font(.headline)
                        Text("\(automation.trigger.label) → \(automation.action.label) · ran \(automation.runCount)x").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }
                    Toggle("Enabled", isOn: Binding(
                        get: { store.data.workspaceAutomations.first { $0.id == automation.id }?.enabled ?? false },
                        set: { enabled in
                            guard var current = store.data.workspaceAutomations.first(where: { $0.id == automation.id }) else { return }
                            current.enabled = enabled
                            store.saveWorkspaceAutomation(current)
                        }
                    )).labelsHidden().accessibilityLabel("Enable " + automation.title)
                    if automation.trigger == .manual { Button("Run") { store.runWorkspaceAutomation(automation.id) }.buttonStyle(.glass).disabled(!automation.enabled) }
                }
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceAutomation(automation.id) } }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Automations")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { WorkspaceAutomationEditor() } }
    }
}

private struct WorkspaceAutomationEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let automation: WorkspaceAutomation?
    @State private var title = ""
    @State private var trigger: WorkspaceAutomationTrigger = .manual
    @State private var action: WorkspaceAutomationAction = .createTask
    @State private var sourceDatabaseID = ""
    @State private var targetDatabaseID = ""
    @State private var matchStatus = ""
    @State private var templateTitle = "{{title}}"
    @State private var templateBody = ""

    init(automation: WorkspaceAutomation? = nil) {
        self.automation = automation
        _title = State(initialValue: automation?.title ?? "")
        _trigger = State(initialValue: automation?.trigger ?? .manual)
        _action = State(initialValue: automation?.action ?? .createTask)
        _sourceDatabaseID = State(initialValue: automation?.sourceDatabaseID ?? "")
        _targetDatabaseID = State(initialValue: automation?.targetDatabaseID ?? "")
        _matchStatus = State(initialValue: automation?.matchStatus ?? "")
        _templateTitle = State(initialValue: automation?.templateTitle ?? "{{title}}")
        _templateBody = State(initialValue: automation?.templateBody ?? "")
    }

    var body: some View {
        Form {
            TextField("Automation name", text: $title)
            Picker("When", selection: $trigger) { ForEach(WorkspaceAutomationTrigger.allCases) { Text($0.label).tag($0) } }
            Picker("Then", selection: $action) { ForEach(WorkspaceAutomationAction.allCases) { Text($0.label).tag($0) } }
            Picker("Source database", selection: $sourceDatabaseID) {
                Text("Any / none").tag("")
                ForEach(store.data.workspaceDatabases) { Text($0.title).tag($0.id) }
            }
            if action == .createRecord {
                Picker("Target database", selection: $targetDatabaseID) {
                    Text("Same source").tag("")
                    ForEach(store.data.workspaceDatabases) { Text($0.title).tag($0.id) }
                }
            }
            if trigger == .recordStatusChanged { TextField("Only when status equals…", text: $matchStatus) }
            TextField("Title template · use {{title}}", text: $templateTitle)
            TextField("Body template · use {{title}} or {{status}}", text: $templateBody, axis: .vertical)
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle(automation == nil ? "New automation" : "Edit automation")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(automation == nil ? "Create" : "Save") {
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    var draft = automation ?? WorkspaceAutomation(title: name)
                    if let current = store.data.workspaceAutomations.first(where: { $0.id == draft.id }) { draft = current }
                    draft.title = name.isEmpty ? "Automation" : name
                    draft.trigger = trigger; draft.action = action
                    draft.sourceDatabaseID = sourceDatabaseID.isEmpty ? nil : sourceDatabaseID
                    draft.targetDatabaseID = targetDatabaseID.isEmpty ? nil : targetDatabaseID
                    draft.matchStatus = matchStatus.isEmpty ? nil : matchStatus
                    draft.templateTitle = templateTitle; draft.templateBody = templateBody
                    store.saveWorkspaceAutomation(draft)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceSchedulingHubView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section("Autopilot") {
                ConfirmedScheduleActionButton(
                    title: "Optimize the whole week",
                    systemImage: "wand.and.stars.inverse",
                    confirmationTitle: "Optimize the whole week?",
                    message: "Enabled project, habit, meeting and intelligence rules will run as one undoable change. Fixed commitments stay protected.",
                    undoLabel: "Workspace Autopilot"
                ) { _ = store.runWorkspaceAutopilot() }
                Text("Schedules active projects, protects focus, time-blocks habits, places Smart Meetings, adds buffers and repairs conflicts without moving fixed commitments.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Focus") {
                LabeledContent("Weekly goal") { Text("\(store.data.workspaceTimePolicy.weeklyFocusGoalMinutes / 60)h \(store.data.workspaceTimePolicy.weeklyFocusGoalMinutes % 60)m") }
                ConfirmedScheduleActionButton(
                    title: "Protect focus across this week",
                    systemImage: "shield.lefthalf.filled",
                    confirmationTitle: "Protect focus time?",
                    message: "Planning will add only missing focus blocks and keep the operation undoable.",
                    undoLabel: "Protect weekly focus"
                ) { _ = store.protectWeeklyFocus() }
                ConfirmedScheduleActionButton(
                    title: "Time-block habits for 7 days",
                    systemImage: "repeat.circle.fill",
                    confirmationTitle: "Schedule seven days of habits?",
                    message: "Habit blocks will be created from your saved reminder times. Duplicates are skipped and the result can be undone.",
                    undoLabel: "Schedule habit blocks"
                ) { _ = store.scheduleHabitTimeBlocks(days: 7) }
                NavigationLink { WorkspaceTimePolicyView() } label: { Label("Hours & scheduling policy", systemImage: "clock.badge.checkmark") }
            }
            Section("Meetings") {
                NavigationLink { WorkspaceSmartMeetingsView() } label: { Label("Smart Meetings", systemImage: "person.2.badge.clock") }
                NavigationLink { WorkspaceSchedulingLinksView() } label: { Label("Scheduling Links", systemImage: "link.badge.plus") }
            }
            Section("Planner intelligence") {
                Label("Deadline-aware task scheduling", systemImage: "exclamationmark.triangle.fill")
                Label("Automatic timeline reflow and conflict repair", systemImage: "arrow.triangle.2.circlepath")
                Label("Focus Shield, Buffer Guard, Recovery Buffers and Auto Lock", systemImage: "shield.fill")
                Label("Week-wide Reality, Gravity and Deadline Radar", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Scheduling & Focus")
    }
}

private struct WorkspaceTimePolicyView: View {
    @Environment(AppStore.self) private var store
    private var policy: WorkspaceTimePolicy { store.data.workspaceTimePolicy }
    private func timeBinding(_ key: WritableKeyPath<WorkspaceTimePolicy, String>) -> Binding<Date> {
        Binding {
            let minute = TimeMath.minutes(policy[keyPath: key]) ?? 540
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.updateWorkspaceTimePolicy { $0[keyPath: key] = TimeMath.string((c.hour ?? 0) * 60 + (c.minute ?? 0)) }
        }
    }

    var body: some View {
        Form {
            Section("Focus") {
                Stepper("Weekly focus · \(policy.weeklyFocusGoalMinutes) min", value: Binding(get: { policy.weeklyFocusGoalMinutes }, set: { value in store.updateWorkspaceTimePolicy { $0.weeklyFocusGoalMinutes = value } }), in: 0...2400, step: 30)
                Stepper("Preferred block · \(policy.preferredFocusBlockMinutes) min", value: Binding(get: { policy.preferredFocusBlockMinutes }, set: { value in store.updateWorkspaceTimePolicy { $0.preferredFocusBlockMinutes = value } }), in: 15...240, step: 15)
                Stepper("Break · \(policy.breakMinutes) min", value: Binding(get: { policy.breakMinutes }, set: { value in store.updateWorkspaceTimePolicy { $0.breakMinutes = value } }), in: 0...60, step: 5)
            }
            Section("Hours") {
                DatePicker("Work starts", selection: timeBinding(\.workHoursStart), displayedComponents: .hourAndMinute)
                DatePicker("Work ends", selection: timeBinding(\.workHoursEnd), displayedComponents: .hourAndMinute)
                DatePicker("Meeting window starts", selection: timeBinding(\.meetingHoursStart), displayedComponents: .hourAndMinute)
                DatePicker("Meeting window ends", selection: timeBinding(\.meetingHoursEnd), displayedComponents: .hourAndMinute)
            }
            Section("Policies") {
                Toggle("Auto-schedule breaks", isOn: Binding(get: { policy.autoScheduleBreaks }, set: { value in store.updateWorkspaceTimePolicy { $0.autoScheduleBreaks = value } }))
                Toggle("Protect personal time", isOn: Binding(get: { policy.protectPersonalTime }, set: { value in store.updateWorkspaceTimePolicy { $0.protectPersonalTime = value } }))
                ForEach([(2,"Monday"),(3,"Tuesday"),(4,"Wednesday"),(5,"Thursday"),(6,"Friday")], id: \.0) { item in
                    Toggle("No-meeting \(item.1)", isOn: Binding(get: { policy.noMeetingWeekdays.contains(item.0) }, set: { enabled in store.updateWorkspaceTimePolicy { if enabled { if !$0.noMeetingWeekdays.contains(item.0) { $0.noMeetingWeekdays.append(item.0) } } else { $0.noMeetingWeekdays.removeAll { $0 == item.0 } } } }))
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Scheduling policy")
    }
}

private struct WorkspaceSchedulingLinksView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            ForEach(store.data.workspaceSchedulingLinks) { link in
                VStack(alignment: .leading, spacing: 4) {
                    Text(link.title).font(.headline)
                    Text("\(link.durationMinutes)m · \(link.windowStart)–\(link.windowEnd) · buffer \(link.bufferAfterMinutes)m").font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceSchedulingLink(link.id) } }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Scheduling Links")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceSchedulingLinkView() } }
    }
}

private struct NewWorkspaceSchedulingLinkView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = "30-minute meeting"
    @State private var duration = 30
    @State private var start = "09:00"
    @State private var end = "17:00"
    @State private var buffer = 10

    var body: some View {
        Form {
            TextField("Title", text: $title)
            Stepper("Duration · \(duration)m", value: $duration, in: 10...180, step: 5)
            TextField("Window start", text: $start)
            TextField("Window end", text: $end)
            Stepper("Buffer after · \(buffer)m", value: $buffer, in: 0...60, step: 5)
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New scheduling link")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Create") { store.saveWorkspaceSchedulingLink(WorkspaceSchedulingLink(title: title, durationMinutes: duration, windowStart: start, windowEnd: end, bufferAfterMinutes: buffer)); dismiss() }.buttonStyle(.glassProminent) }
        }
    }
}

private struct WorkspaceSmartMeetingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false

    var body: some View {
        List {
            ForEach(store.data.workspaceSmartMeetings) { meeting in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meeting.title).font(.headline)
                        Text("\(meeting.durationMinutes)m · weekday \(meeting.preferredWeekday) · \(meeting.windowStart)–\(meeting.windowEnd)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ConfirmedScheduleActionButton(
                        title: "Schedule",
                        systemImage: "calendar.badge.plus",
                        confirmationTitle: "Schedule \(meeting.title)?",
                        message: "Planning will use the preferred window and show the change in the timeline. You can undo it from Today.",
                        undoLabel: "Schedule \(meeting.title)"
                    ) { _ = store.scheduleWorkspaceSmartMeeting(meeting) }
                }
                .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceSmartMeeting(meeting.id) } }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Smart Meetings")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceSmartMeetingView() } }
    }
}

private struct NewWorkspaceSmartMeetingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var attendees = ""
    @State private var duration = 30
    @State private var weekday = 2
    @State private var start = "10:00"
    @State private var end = "16:00"
    @State private var autoReschedule = true

    var body: some View {
        Form {
            TextField("Meeting name", text: $title)
            TextField("Attendees, comma separated", text: $attendees)
            Stepper("Duration · \(duration)m", value: $duration, in: 10...180, step: 5)
            Picker("Preferred weekday", selection: $weekday) { Text("Mon").tag(2); Text("Tue").tag(3); Text("Wed").tag(4); Text("Thu").tag(5); Text("Fri").tag(6) }
            TextField("Window start", text: $start)
            TextField("Window end", text: $end)
            Toggle("Auto-reschedule when needed", isOn: $autoReschedule)
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New Smart Meeting")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let people = attendees.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    store.saveWorkspaceSmartMeeting(WorkspaceSmartMeeting(title: title.isEmpty ? "Meeting" : title, attendees: people, durationMinutes: duration, preferredWeekday: weekday, windowStart: start, windowEnd: end, autoReschedule: autoReschedule))
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct WorkspaceKnowledgeGraphView: View {
    @Environment(AppStore.self) private var store

    private var pages: [WorkspacePage] { store.data.workspacePages.filter { !$0.archived }.prefix(18).map { $0 } }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GeometryReader { proxy in
                    ZStack {
                        ForEach(graphEdges, id: \.id) { edge in
                            if let a = position(for: edge.from, in: proxy.size), let b = position(for: edge.to, in: proxy.size) {
                                Path { path in path.move(to: a); path.addLine(to: b) }
                                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
                            }
                        }
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            NavigationLink { WorkspacePageEditor(page: page) } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: page.icon)
                                    Text(page.title).font(.caption2).lineLimit(1)
                                }
                                .frame(width: 96, height: 64)
                                .premiumGlassRounded(cornerRadius: 16, interactive: true)
                            }
                            .buttonStyle(.plain)
                            .position(position(index: index, count: pages.count, size: proxy.size))
                        }
                    }
                }
                .frame(height: 420)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Connection index").font(.headline)
                    ForEach(pages) { page in
                        HStack { Label(page.title, systemImage: page.icon); Spacer(); Text("\(linkCount(page)) links").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .padding()
            }
        }
        .appCanvas().navigationTitle("Knowledge Graph")
    }

    private struct Edge { let id: String; let from: String; let to: String }
    private var graphEdges: [Edge] {
        var output: [Edge] = []
        let visibleIDs = Set(pages.map(\.id))
        for page in pages {
            for id in page.relatedPageIDs where visibleIDs.contains(id) { output.append(Edge(id: "\(page.id)-\(id)", from: page.id, to: id)) }
            for other in pages where other.id != page.id && page.body.localizedCaseInsensitiveContains("[[\(other.title)]]") {
                output.append(Edge(id: "text-\(page.id)-\(other.id)", from: page.id, to: other.id))
            }
        }
        return Array(Dictionary(grouping: output, by: \.id).compactMap { $0.value.first })
    }

    private func position(index: Int, count: Int, size: CGSize) -> CGPoint {
        guard count > 0 else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let angle = (Double(index) / Double(count)) * Double.pi * 2 - Double.pi / 2
        let radius = min(size.width, size.height) * 0.36
        return CGPoint(x: size.width / 2 + CGFloat(cos(angle)) * radius, y: size.height / 2 + CGFloat(sin(angle)) * radius)
    }

    private func position(for id: String, in size: CGSize) -> CGPoint? {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return nil }
        return position(index: index, count: pages.count, size: size)
    }

    private func linkCount(_ page: WorkspacePage) -> Int {
        page.relatedPageIDs.count + pages.filter { $0.id != page.id && ($0.body.localizedCaseInsensitiveContains("[[\(page.title)]]") || page.body.localizedCaseInsensitiveContains("[[\($0.title)]]")) }.count
    }
}

private struct WorkspaceSpacesView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false
    @State private var title = ""

    var body: some View {
        List {
            ForEach(store.data.workspaceSpaces) { space in
                Section {
                    ForEach(store.data.workspacePages.filter { !$0.archived && $0.spaceID == space.id }) { page in
                        NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) }
                    }
                } header: {
                    HStack { Label(space.title, systemImage: space.icon); Spacer(); Text("\(store.data.workspacePages.filter { !$0.archived && $0.spaceID == space.id }.count)") }
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Spaces")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .alert("New space", isPresented: $showNew) {
            TextField("Name", text: $title)
            Button("Cancel", role: .cancel) { title = "" }
            Button("Create") { let name = title.trimmingCharacters(in: .whitespacesAndNewlines); store.saveWorkspaceSpace(WorkspaceSpace(title: name.isEmpty ? "Space" : name)); title = "" }
        }
    }
}

private struct WorkspaceDailyNotesView: View {
    @Environment(AppStore.self) private var store
    @State private var createdPage: WorkspacePage?

    var body: some View {
        List {
            Section {
                Button("Open or create today's note", systemImage: "sun.max.fill") { createdPage = store.openOrCreateDailyNote() }
            }
            Section("Daily notes") {
                ForEach(dailyPages) { page in
                    NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: "calendar") }
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Daily Notes")
        .sheet(item: $createdPage) { page in NavigationStack { WorkspacePageEditor(page: page) } }
    }

    private var dailyPages: [WorkspacePage] { store.data.workspacePages.filter { !$0.archived && $0.tags.contains("daily") }.sorted { $0.title > $1.title } }
}

private struct WorkspaceAgendaView: View {
    @Environment(AppStore.self) private var store
    @State private var generated: WorkspacePage?

    private var todayTasks: [PlannerTask] { TaskTimelineOrder.sorted(store.data.plans.first(where: { $0.date == DateKey.today })?.tasks.filter { $0.status == .pending || $0.status == .active } ?? []) }
    private var overdue: [PlannerTask] { store.data.plans.flatMap(\.tasks).filter { ($0.status == .pending || $0.status == .active) && $0.planDate < DateKey.today } }

    var body: some View {
        List {
            Section("Today") {
                if todayTasks.isEmpty { Text("Nothing scheduled.").foregroundStyle(.secondary) }
                ForEach(todayTasks) { task in HStack { Text(task.startTime ?? "Any").monospacedDigit().foregroundStyle(.secondary); Text(task.title) } }
            }
            Section("Past due") {
                if overdue.isEmpty { Label("Clear", systemImage: "checkmark.circle.fill") }
                ForEach(overdue.prefix(12)) { task in Text("\(task.title) · \(task.planDate)") }
            }
            Section("Capture") {
                ForEach(store.data.inbox.prefix(12)) { item in Text(item.title) }
            }
            Section {
                Button("Generate editable Agenda page", systemImage: "doc.badge.plus") { generated = store.buildWorkspaceAgenda() }.buttonStyle(.glassProminent)
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("AI Agenda")
        .sheet(item: $generated) { page in NavigationStack { WorkspacePageEditor(page: page) } }
    }
}


// MARK: - Workspace final expansion

private struct WorkspacePageHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pageID: String

    private var versions: [WorkspacePageVersion] {
        store.data.workspacePageVersions.filter { $0.pageID == pageID }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if versions.isEmpty {
                ContentUnavailableView("No earlier versions", systemImage: "clock.arrow.circlepath", description: Text("Planning stores up to 40 previous saved versions of each page."))
            }
            ForEach(versions) { version in
                VStack(alignment: .leading, spacing: 7) {
                    Text(version.title).font(.headline)
                    Text(version.createdAt).font(.caption).foregroundStyle(.secondary)
                    Text(String(version.body.prefix(180))).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
                    Button("Restore this version", systemImage: "arrow.uturn.backward") {
                        store.restoreWorkspacePageVersion(version.id)
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Version History")
    }
}

private struct WorkspacePageCommentsView: View {
    @Environment(AppStore.self) private var store
    let pageID: String
    @State private var text = ""
    @State private var showResolved = false

    private var comments: [WorkspaceComment] {
        store.data.workspaceComments.filter { $0.pageID == pageID && (showResolved || !$0.resolved) }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Comment or @mention", text: $text)
                    Button { store.addWorkspaceComment(pageID: pageID, text: text); text = "" } label: { Image(systemName: "arrow.up.circle.fill") }
                        .buttonStyle(.glassProminent)
                }
                Toggle("Show resolved", isOn: $showResolved)
            }
            Section("Thread") {
                if comments.isEmpty { Text("No comments yet.").foregroundStyle(.secondary) }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(comment.author).font(.caption.bold()); Spacer(); Text(comment.createdAt).font(.caption2).foregroundStyle(.secondary) }
                        Text(comment.text)
                        HStack {
                            Button(comment.resolved ? "Reopen" : "Resolve") { store.resolveWorkspaceComment(comment.id, resolved: !comment.resolved) }.buttonStyle(.glass)
                            Spacer()
                            Button(role: .destructive) { store.deleteWorkspaceComment(comment.id) } label: { Image(systemName: "trash") }.buttonStyle(.glass)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Comments")
    }
}

private struct WorkspacePresentationView: View {
    @Environment(\.dismiss) private var dismiss
    let page: WorkspacePage
    @State private var index = 0

    private var slides: [String] {
        let parts = page.body.components(separatedBy: "\n## ")
        if parts.count <= 1 { return page.body.isEmpty ? [page.title] : [page.body] }
        return parts.enumerated().map { offset, value in offset == 0 ? value : "## " + value }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack { Button("Close") { dismiss() }.buttonStyle(.glass); Spacer(); Text("\(index + 1) / \(slides.count)").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                ScrollView { Text(slides[min(index, slides.count - 1)]).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding() }
                Spacer()
                HStack {
                    Button("Back") { index = max(0, index - 1) }.disabled(index == 0).buttonStyle(.glass)
                    Spacer()
                    Button("Next") { index = min(slides.count - 1, index + 1) }.disabled(index >= slides.count - 1).buttonStyle(.glassProminent)
                }
            }
            .padding()
        }
    }
}

private struct WorkspaceClipsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false
    @State private var title = ""
    @State private var url = ""
    @State private var note = ""
    @State private var tags = ""

    var body: some View {
        List {
            Section {
                Text("Save links, text or research here. Planning's Share Extension already captures shared URLs/text into Inbox; this view gives you a dedicated read-later knowledge layer.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Read later") {
                if store.data.workspaceClips.filter({ !$0.archived }).isEmpty { ContentUnavailableView("No clips", systemImage: "bookmark") }
                ForEach(store.data.workspaceClips.filter { !$0.archived }) { clip in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Image(systemName: clip.read ? "checkmark.circle.fill" : "bookmark.fill"); Text(clip.title).font(.headline); Spacer() }
                        if !clip.url.isEmpty { Text(clip.url).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        if !clip.note.isEmpty { Text(clip.note).font(.footnote).lineLimit(3) }
                        HStack {
                            Button(clip.read ? "Unread" : "Read") { var copy = clip; copy.read.toggle(); store.saveWorkspaceClip(copy) }.buttonStyle(.glass)
                            Button("To page") { _ = store.workspaceClipToPage(clip.id) }.buttonStyle(.glass)
                            Spacer()
                            Button(role: .destructive) { store.deleteWorkspaceClip(clip.id) } label: { Image(systemName: "trash") }.buttonStyle(.glass)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Web Clipper")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) {
            NavigationStack {
                Form {
                    TextField("Title", text: $title)
                    TextField("URL", text: $url).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Tags, comma separated", text: $tags)
                    TextEditor(text: $note).frame(minHeight: 160)
                }
                .scrollContentBackground(.hidden).appCanvas().navigationTitle("New clip")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNew = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        let parsedTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        store.saveWorkspaceClip(WorkspaceClip(title: title.isEmpty ? (url.isEmpty ? "Saved item" : url) : title, url: url, note: note, tags: parsedTags))
                        title = ""; url = ""; note = ""; tags = ""; showNew = false
                    }.buttonStyle(.glassProminent) }
                }
            }
        }
    }
}

private struct WorkspaceSitesView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedPageID = ""

    var body: some View {
        List {
            Section("Publish a page") {
                Picker("Page", selection: $selectedPageID) {
                    Text("Select page").tag("")
                    ForEach(store.data.workspacePages.filter { !$0.archived }) { Text($0.title).tag($0.id) }
                }
                Button("Create site", systemImage: "globe.badge.chevron.backward") {
                    guard let page = store.data.workspacePages.first(where: { $0.id == selectedPageID }) else { return }
                    let slug = page.title.lowercased().replacingOccurrences(of: " ", with: "-").filter { $0.isLetter || $0.isNumber || $0 == "-" }
                    store.saveWorkspaceSite(WorkspaceSite(title: page.title, pageID: page.id, slug: slug.isEmpty ? "page" : slug))
                }
                .disabled(selectedPageID.isEmpty)
            }
            Section("Sites") {
                if store.data.workspaceSites.isEmpty { Text("Sharing presets export page content; they do not publish a hosted website. No presets yet.").foregroundStyle(.secondary) }
                ForEach(store.data.workspaceSites) { site in
                    if let page = store.data.workspacePages.first(where: { $0.id == site.pageID }) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack { Label(site.title, systemImage: site.published ? "globe" : "globe.badge.xmark"); Spacer(); Text("/\(site.slug)").font(.caption).foregroundStyle(.secondary) }
                            Toggle("Ready to share", isOn: Binding(get: { site.published }, set: { value in var copy = site; copy.published = value; store.saveWorkspaceSite(copy) }))
                            ShareLink(item: "# \(page.title)\n\n\(page.body)") { Label("Share page content", systemImage: "square.and.arrow.up") }
                            NavigationLink { WorkspacePageEditor(page: page) } label: { Label("Edit source page", systemImage: "pencil") }
                        }
                    }
                }
                .onDelete { offsets in for i in offsets { if store.data.workspaceSites.indices.contains(i) { store.deleteWorkspaceSite(store.data.workspaceSites[i].id) } } }
            }
            Section("Presentation") {
                Text("Any page can also open as a full-screen presentation from Page → Page power tools. Headings become slides.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Sites & Presentation")
    }
}

private struct WorkspaceImportExportView: View {
    @Environment(AppStore.self) private var store
    @State private var importTitle = ""
    @State private var markdown = ""

    var body: some View {
        List {
            Section("Import") {
                TextField("Page title", text: $importTitle)
                TextEditor(text: $markdown).frame(minHeight: 180)
                Button("Import Markdown", systemImage: "square.and.arrow.down") {
                    store.importWorkspaceMarkdown(title: importTitle, markdown: markdown)
                    importTitle = ""; markdown = ""
                }
                .buttonStyle(.glassProminent).disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Paste Markdown exported from Notion, Obsidian or another notes app. Existing Planning data is never overwritten by this importer.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Export") {
                ShareLink(item: store.workspaceMarkdownExport()) { Label("Export Workspace as Markdown", systemImage: "doc.text") }
                ShareLink(item: store.workspaceJSONExport()) { Label("Export Workspace as JSON", systemImage: "curlybraces.square") }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Import & Export")
    }
}

private struct WorkspaceTimeTrackingView: View {
    @Environment(AppStore.self) private var store
    @State private var title = "Deep work"
    @State private var category: TaskCategory = .focus

    private var active: WorkspaceTimeEntry? { store.data.workspaceTimeEntries.last(where: { $0.endedAt == nil }) }
    private var completed: [WorkspaceTimeEntry] { store.data.workspaceTimeEntries.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt } }

    var body: some View {
        List {
            Section("Timer") {
                if let active {
                    Label("Tracking · \(active.title)", systemImage: "timer.circle.fill").font(.headline)
                    Button("Stop timer", systemImage: "stop.circle.fill") { store.stopWorkspaceTimer() }.buttonStyle(.glassProminent)
                } else {
                    TextField("What are you working on?", text: $title)
                    Picker("Category", selection: $category) { ForEach(TaskCategory.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    Button("Start timer", systemImage: "play.circle.fill") { store.startWorkspaceTimer(title: title.isEmpty ? "Focus" : title, category: category) }.buttonStyle(.glassProminent)
                }
            }
            Section("This data") {
                HStack { metric("Sessions", completed.count); metric("Minutes", completed.reduce(0) { $0 + $1.durationMinutes }); metric("Focus", completed.filter { $0.category == .focus }.reduce(0) { $0 + $1.durationMinutes }) }
            }
            Section("History") {
                if completed.isEmpty { Text("No tracked sessions yet.").foregroundStyle(.secondary) }
                ForEach(completed.prefix(60)) { entry in
                    HStack { VStack(alignment: .leading) { Text(entry.title); Text(entry.startedAt).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text("\(entry.durationMinutes)m").monospacedDigit() }
                    .swipeActions { Button("Delete", role: .destructive) { store.deleteWorkspaceTimeEntry(entry.id) } }
                }
            }
            Section("Schedule intelligence") {
                ConfirmedScheduleActionButton(
                    title: "Protect weekly focus target",
                    systemImage: "scope",
                    confirmationTitle: "Protect this week's focus target?",
                    message: "Missing focus blocks will be added as one undoable change.",
                    undoLabel: "Protect weekly focus"
                ) { _ = store.protectWeeklyFocus() }
                ConfirmedScheduleActionButton(
                    title: "Run scheduling autopilot",
                    systemImage: "wand.and.stars",
                    confirmationTitle: "Run scheduling autopilot?",
                    message: "Enabled scheduling rules will run only after confirmation, with one Undo point.",
                    undoLabel: "Workspace Autopilot"
                ) { _ = store.runWorkspaceAutopilot() }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Time Tracking")
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack { Text("\(value)").font(.headline.monospacedDigit()); Text(title).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}

private struct WorkspaceCustomAgentsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false
    @State private var result = ""
    @State private var runningID: String?

    var body: some View {
        List {
            Section {
                Text("Create reusable AI operators for a recurring workspace job. They can use the same safe Planning action layer as Workspace Agent; billing, login, account deletion and secrets remain outside agent control.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Agents") {
                if store.data.workspaceCustomAgents.isEmpty { ContentUnavailableView("No custom agents", systemImage: "sparkles.rectangle.stack") }
                ForEach(store.data.workspaceCustomAgents) { agent in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Label(agent.title, systemImage: "sparkles.rectangle.stack.fill"); Spacer(); Text(agent.scope.label).font(.caption).foregroundStyle(.secondary) }
                        Text(agent.instructions).font(.footnote).foregroundStyle(.secondary).lineLimit(3)
                        HStack {
                            Button(runningID == agent.id ? "Running…" : "Run now") {
                                runningID = agent.id
                                Task { let reply = await store.runWorkspaceCustomAgent(agent.id); await MainActor.run { result = reply; runningID = nil } }
                            }.disabled(runningID != nil).buttonStyle(.glassProminent)
                            Spacer()
                            Button(role: .destructive) { store.deleteWorkspaceCustomAgent(agent.id) } label: { Image(systemName: "trash") }.buttonStyle(.glass)
                        }
                    }.padding(.vertical, 4)
                }
            }
            if !result.isEmpty { Section("Last run") { Text(result) } }
            if store.hasPendingCoachActions {
                Section("Review before applying") { AIActionReviewCard() }
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Custom Agents")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew) { NavigationStack { NewWorkspaceCustomAgentView() } }
    }
}

private struct NewWorkspaceCustomAgentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var instructions = ""
    @State private var scope: WorkspaceAgentScope = .workspace
    @State private var trigger: WorkspaceAutomationTrigger = .manual

    var body: some View {
        Form {
            TextField("Agent name", text: $title)
            Picker("Scope", selection: $scope) { ForEach(WorkspaceAgentScope.allCases) { Text($0.label).tag($0) } }
            Picker("Default trigger", selection: $trigger) { ForEach(WorkspaceAutomationTrigger.allCases) { Text($0.label).tag($0) } }
            Section("Instructions") { TextEditor(text: $instructions).frame(minHeight: 220) }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("New Agent")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Create") { store.saveWorkspaceCustomAgent(WorkspaceCustomAgent(title: title.isEmpty ? "Agent" : title, instructions: instructions, scope: scope, trigger: trigger)); dismiss() }.buttonStyle(.glassProminent).disabled(instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
}

private struct WorkspaceActivityView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section("Workspace activity") {
                ForEach(store.data.events.filter { $0.type.contains("workspace") }.suffix(100).reversed()) { event in
                    VStack(alignment: .leading, spacing: 3) { Text(event.detail); Text("\(event.type) · \(event.createdAt)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            Section("Version storage") {
                Label("\(store.data.workspacePageVersions.count) saved page versions", systemImage: "clock.arrow.circlepath")
                Label("\(store.data.workspaceComments.filter { !$0.resolved }.count) open comments", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Activity")
    }
}

private struct WorkspaceCommandPaletteView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var createdPage: WorkspacePage?

    var body: some View {
        List {
            Section("Quick commands") {
                Button("New page", systemImage: "doc.badge.plus") { let page = WorkspacePage(title: "Untitled"); store.saveWorkspacePage(page); createdPage = page }
                Button("Today's daily note", systemImage: "sun.max.fill") { createdPage = store.openOrCreateDailyNote() }
                Button("Build today's agenda", systemImage: "list.bullet.clipboard.fill") { createdPage = store.buildWorkspaceAgenda() }
                ConfirmedScheduleActionButton(
                    title: "Run Workspace Autopilot",
                    systemImage: "wand.and.stars",
                    confirmationTitle: "Run Workspace Autopilot?",
                    message: "Enabled rules will update the week as one undoable change.",
                    undoLabel: "Workspace Autopilot"
                ) { _ = store.runWorkspaceAutopilot() }
                ConfirmedScheduleActionButton(
                    title: "Protect focus this week",
                    systemImage: "scope",
                    confirmationTitle: "Protect focus this week?",
                    message: "Missing focus blocks will be added only after confirmation and can be undone.",
                    undoLabel: "Protect weekly focus"
                ) { _ = store.protectWeeklyFocus() }
                ConfirmedScheduleActionButton(
                    title: "Repair today's timeline",
                    systemImage: "bandage.fill",
                    confirmationTitle: "Repair today's conflicts?",
                    message: "Only flexible tasks may move. Fixed commitments remain protected and the result can be undone.",
                    undoLabel: "Repair today's timeline"
                ) { _ = store.repairTimelineConflicts(on: store.selectedDate) }
            }
            Section("Search commands & pages") {
                ForEach(store.data.workspacePages.filter { !$0.archived && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }.prefix(20)) { page in
                    NavigationLink { WorkspacePageEditor(page: page) } label: { Label(page.title, systemImage: page.icon) }
                }
            }
        }
        .searchable(text: $query, prompt: "Command or page")
        .scrollContentBackground(.hidden).appCanvas().navigationTitle("Command Palette")
        .sheet(item: $createdPage) { page in NavigationStack { WorkspacePageEditor(page: page) } }
    }
}

private struct WorkspaceDatabaseMapView: View {
    let database: WorkspaceDatabase
    let onEdit: (WorkspaceRecord) -> Void
    @State private var position: MapCameraPosition = .automatic

    private var located: [WorkspaceRecord] { database.records.filter { $0.latitude != nil && $0.longitude != nil } }

    var body: some View {
        if located.isEmpty {
            ContentUnavailableView("No mapped records", systemImage: "map", description: Text("Open a record and add latitude/longitude to place it on the map."))
        } else {
            Map(position: $position) {
                ForEach(located) { record in
                    if let lat = record.latitude, let lon = record.longitude {
                        Annotation(record.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button { onEdit(record) } label: { Image(systemName: "mappin.circle.fill").font(.title).symbolRenderingMode(.hierarchical) }
                        }
                    }
                }
            }
        }
    }
}


private struct WorkspaceFeaturesGuideView: View {
    private let groups: [(String, [(String, String, String)])] = [
        ("Unified operating system", [
            ("Planner / Workspace", "square.grid.3x3.fill", "Switch the entire app between execution-first Planner and the complete knowledge, projects and automation Workspace."),
            ("Workspace Command Center", "square.split.2x1.fill", "Combines today's schedule, active workspace knowledge, project risk and quick cross-links in one operational dashboard."),
            ("Unified Inbox", "tray.full.fill", "Triage planner Inbox, unread clips, unresolved comments, at-risk projects and overdue work from one place, with optional AI triage."),
            ("Cross-mode Memory", "memorychip.fill", "One master switch controls learned continuity across Planner, Workspace and AI while keeping your actual saved content intact."),
            ("Verified Knowledge", "checkmark.seal.fill", "Mark trusted pages as verified so durable reference material is visibly distinct from drafts."),
            ("Locked Knowledge", "lock.fill", "Lock important pages against accidental editing; AI is instructed to respect the lock unless you explicitly request an unlock."),
            ("Aliases & Backlinks", "arrow.triangle.branch", "Give pages alternate names and connect knowledge through wiki links, relations, backlinks and graph navigation."),
            ("Page AI to Execution", "wand.and.stars", "Improve or summarize knowledge, extract actions into Planning, or turn a page into an executable plan without copying between tools.")
        ]),
        ("Knowledge", [
            ("Pages & Wiki", "doc.on.doc.fill", "Write Markdown-rich pages, organize them into spaces, verify or lock important pages, add aliases, favorite/archive content, and turn any page into a wiki home."),
            ("Backlinks & Relations", "link", "Use [[Page name]] links and explicit page relations to build a connected knowledge system."),
            ("Knowledge Graph", "point.3.connected.trianglepath.dotted", "See connections between pages and navigate the workspace as a graph rather than a folder tree."),
            ("Canvas", "rectangle.3.group.bubble.left", "Arrange movable idea nodes and connect them visually for research, projects and systems thinking."),
            ("Daily Notes", "sun.max.fill", "Create a date-linked note instantly and keep decisions, priorities and reflections beside the schedule.")
        ]),
        ("Structured data", [
            ("Databases", "tablecells.fill", "Create structured collections with custom properties, relations, formulas, rollups, filters and sorting."),
            ("9 Views", "rectangle.3.group", "Switch one database between Table, Board, Calendar, List, Gallery, Timeline, Form, Chart and Map without duplicating records."),
            ("Forms & Intake", "list.clipboard.fill", "Capture structured responses directly into a database and route them into execution workflows."),
            ("Dashboards & Charts", "chart.bar.xaxis", "Combine project, database and progress information into at-a-glance operational views."),
            ("Templates", "sparkles.rectangle.stack", "Start from reusable page and workspace structures instead of rebuilding common systems.")
        ]),
        ("Execution", [
            ("Projects & Roadmaps", "shippingbox.fill", "Connect outcomes, milestones and tasks, then auto-schedule flexible work toward deadlines."),
            ("Weekly Autopilot", "wand.and.stars", "Coordinates projects, habits, focus goals, meetings, buffers, conflicts and enabled Timeline Intelligence rules across the week."),
            ("Scheduling Links", "link.badge.plus", "Define bookable windows, durations and buffers for meeting-style scheduling."),
            ("Smart Meetings", "person.2.wave.2.fill", "Keep preferred meeting windows and automatically place or re-place flexible meetings."),
            ("Time Tracking", "timer", "Track real work sessions and compare session counts, minutes and focus time with the plan."),
            ("Meetings & Action Notes", "person.2.fill", "Store meeting notes, decisions and action items, then convert action items directly into Planning tasks."),
            ("Automations", "bolt.badge.clock.fill", "Run database- and schedule-driven workflows that create tasks, pages or other workspace records.")
        ]),
        ("Capture, sharing & history", [
            ("Web Clipper & Read Later", "bookmark.fill", "Save links with notes and tags, mark them read, and convert useful captures into full workspace pages."),
            ("Import & Export", "arrow.up.arrow.down.square.fill", "Bring Markdown into Planning and export the workspace as Markdown or JSON without overwriting unrelated data."),
            ("Version History", "clock.arrow.circlepath", "Every saved page revision creates a restorable snapshot, with recent history kept locally."),
            ("Comments", "bubble.left.and.bubble.right.fill", "Attach comments to pages, resolve them when handled, and reopen them when work returns."),
            ("Sites & Presentation", "globe", "Publish page snapshots inside Planning's sharing flow and present heading-separated content full screen.")
        ]),
        ("AI command layer", [
            ("Planning Agent", "brain.head.profile", "Can inspect represented Planning data and perform safe app actions across tasks, goals, habits, notes, workspace, allowed settings and timelines."),
            ("Workspace Agent", "sparkles", "Turns knowledge into projects, tasks and schedule changes instead of only answering questions."),
            ("Page AI", "wand.and.stars", "Improve, summarize or extract execution directly from a saved page without leaving the editor."),
            ("Custom Agents", "sparkles.rectangle.stack.fill", "Save reusable agent instructions for repeated workspace, planning, meeting, knowledge, database or scheduling jobs."),
            ("AI Agenda", "list.bullet.clipboard.fill", "Build a workspace command page from today's work, overdue items and Inbox."),
            ("Command Palette", "command.square.fill", "Jump to common workspace operations and pages with minimal navigation.")
        ])
    ]

    var body: some View {
        List {
            Section {
                Text("Workspace is designed as one system with Planning: knowledge can become execution, and schedule data can feed back into the workspace. Most features work offline-first and stay inside the existing Planning data model.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Section(group.0) {
                    ForEach(group.1, id: \.0) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.1).frame(width: 26).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0).font(.headline)
                                Text(item.2).font(.footnote).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 3)
                    }
                }
            }
            Section("Safety boundary") {
                Text("AI may operate represented user content and explicitly allowed preferences. Billing, authentication, account deletion/recovery, API keys, secrets and security-sensitive backend configuration always require direct user control.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Workspace Features")
    }
}
