import SwiftUI

struct BuiltInAIView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var testing = false
    @State private var connectionState: ConnectionState = .unknown

    private enum ConnectionState {
        case unknown, ready, unavailable
    }

    private var endpointHost: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AI_API_BASE_URL") as? String,
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host,
              !host.isEmpty else { return nil }
        return host
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.clear)
                            .frame(width: 46, height: 46)
                            .glassEffect(.regular.tint(p.accent.opacity(0.10)).interactive(), in: Circle())
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(p.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Built-in AI")
                            .font(.headline)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusSymbol
                }
                .padding(.vertical, 4)
            }

            Section("AI modes") {
                Label("Planning Agent · controls schedules, tasks, goals and allowed app settings", systemImage: "calendar.badge.clock")
                Label("School · level-aware interactive tutor", systemImage: "graduationcap.fill")
                Label("General · questions, ideas and comparisons", systemImage: "sparkles")
                Label("Workspace Agent · pages, databases, knowledge and action bridges", systemImage: "rectangle.3.group.bubble.left.fill")
                Text("Planning Agent can execute allowed changes across tasks, goals, habits, notes, workspace and Timeline controls. Workspace Agent focuses on knowledge and databases. Billing, authentication, account deletion, secrets and security-sensitive controls stay protected. Soft, Strict and Aggressive response styles apply across AI modes; School keeps its level-aware teaching tools.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy & security") {
                Label("Server-managed credentials", systemImage: "lock.shield.fill")
                Text("Planning sends AI requests to its protected server boundary. Provider credentials remain server-side and are never shown to the user or bundled into the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let endpointHost {
                    LabeledContent("Server") { Text(endpointHost) }
                }
            }

            Section("Connection") {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label(testing ? "Checking…" : "Check AI connection", systemImage: "network")
                        Spacer()
                        if testing { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(testing)

                switch connectionState {
                case .ready:
                    Label("Built-in AI is ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                case .unavailable:
                    Label("AI server is unavailable", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.secondary)
                    Text("Planning keeps deterministic local planning available if the AI service is temporarily offline.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .unknown:
                    EmptyView()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Built-in AI")
        .task {
            guard connectionState == .unknown else { return }
            let ready = await AIService.shared.testConnection()
            connectionState = ready ? .ready : .unavailable
        }
    }

    @ViewBuilder
    private var statusSymbol: some View {
        switch connectionState {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .unknown:
            Image(systemName: "circle.dotted")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusText: String {
        switch connectionState {
        case .ready: return "Ready"
        case .unavailable: return "Local fallback available"
        case .unknown: return "Checking connection"
        }
    }

    private func testConnection() {
        guard !testing else { return }
        testing = true
        Task {
            let ready = await AIService.shared.testConnection()
            await MainActor.run {
                connectionState = ready ? .ready : .unavailable
                testing = false
            }
        }
    }
}
