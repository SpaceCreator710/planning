import SwiftUI

struct ProviderBrandIcon: View {
    let provider: String
    var size: CGFloat = 19

    var body: some View {
        Group {
            switch provider {
            case "google":
                Image("GoogleBrandIcon")
                    .resizable()
                    .scaledToFit()
            case "apple":
                Image(systemName: "apple.logo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            case "github":
                Image("GitHubBrandIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            default:
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ProviderButtonLabel: View {
    let provider: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ProviderBrandIcon(provider: provider)
            Text(title)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showOnboarding = false
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
    @State private var working = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 42)

                    Image("PlanningMark")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .frame(width: 64, height: 64)

                    VStack(spacing: 8) {
                        Text("Planning")
                            .font(.largeTitle.bold())
                        Text("Your day, alive on one timeline.")
                            .font(.title3.weight(.medium))
                        Text("Plan, adapt, focus and see what happens next without turning your day into a spreadsheet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Picker("Appearance", selection: Binding(
                        get: { store.data.settings.theme },
                        set: { value in store.updateSettings { $0.theme = value } }
                    )) {
                        Label("Light", systemImage: "sun.max.fill").tag(ThemeMode.light)
                        Label("Dark", systemImage: "moon.fill").tag(ThemeMode.dark)
                        Label("System", systemImage: "iphone").tag(ThemeMode.system)
                    }
                    .pickerStyle(.segmented)

                    if SupabaseService.shared.configured {
                        accountOptions

                        Button("Continue without an account") {
                            showOnboarding = true
                        }
                        .font(.subheadline)
                    } else {
                        Button {
                            showOnboarding = true
                        } label: {
                            Label("Start Planning", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)

                        HStack(spacing: 8) {
                            Label("Local-first", systemImage: "iphone")
                            Text("•")
                            Label("Built-in AI", systemImage: "sparkles")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("Your plan stays usable even if the network is temporarily unavailable.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .appCanvas()
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .onOpenURL { url in
                if SupabaseService.shared.handle(url: url) {
                    showOnboarding = true
                }
            }
        }
    }

    @ViewBuilder
    private var accountOptions: some View {
        VStack(spacing: 12) {
            Button { signIn("google") } label: {
                ProviderButtonLabel(provider: "google", title: "Sign in with Google")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(working)

            Button { signIn("apple") } label: {
                ProviderButtonLabel(provider: "apple", title: "Sign in with Apple")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(working)

            Button { signIn("github") } label: {
                ProviderButtonLabel(provider: "github", title: "Sign in with GitHub")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(working)

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .premiumGlassRounded(cornerRadius: 18, interactive: true)

                Button(codeSent ? "Verification code sent" : "Send verification code") {
                    sendVerificationCode()
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
                .buttonStyle(.glass)

                if codeSent {
                    TextField("6-digit verification code", text: $verificationCode)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .premiumGlassRounded(cornerRadius: 18, interactive: true)

                    Button("Verify code") {
                        verifyCode()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || working)
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
                    showOnboarding = true
                } else {
                    statusMessage = "Sign-in did not complete. You can continue without an account."
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
                codeSent = ok
                working = false
                statusMessage = ok
                    ? "Verification code sent. Enter the 6-digit code from your email."
                    : "Verification code could not be sent. You can continue without an account."
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
                    statusMessage = "Email verified."
                    showOnboarding = true
                } else {
                    statusMessage = "That verification code is invalid or expired."
                }
            }
        }
    }
}
