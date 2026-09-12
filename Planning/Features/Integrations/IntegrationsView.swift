import SwiftUI

struct IntegrationsView: View {
    @Environment(AppStore.self) private var store
    @State private var calendarWorking = false
    @State private var healthWorking = false
    @State private var integrationError: String?

    var body: some View {
        List {
            if store.hasAccess(.appleIntegrations) {
                Section("Apple") {
                    integration("Calendar", "calendar", store.data.settings.calendarSyncEnabled, working: calendarWorking) {
                        connectCalendar()
                    }
                    integration("Health", "heart.fill", store.data.settings.healthSyncEnabled, working: healthWorking) {
                        connectHealth()
                    }
                }

                Section("Automation") {
                    Toggle("Calendar conflict suggestions", isOn: Binding(
                        get: { store.data.settings.timelineSuggestionsEnabled != false },
                        set: { value in store.updateSettings { $0.timelineSuggestionsEnabled = value } }
                    ))
                    Toggle("Use Health summaries with AI", isOn: Binding(
                        get: { store.data.settings.healthPlanningEnabled },
                        set: { value in store.updateSettings { $0.healthPlanningEnabled = value } }
                    ))
                    Text("Calendar sync never moves your tasks automatically. Health AI context is optional and sends only a current read-only summary. Planning shows schedule previews and waits for confirmation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Apple integrations") {
                    Label("Calendar and Health planning are included with Pro.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                    NavigationLink { PaywallView() } label: {
                        Label("See Pro", systemImage: "sparkles")
                    }
                }
            }

            Section {
                Text("Add Planning widgets from the Home Screen. A running focus session can appear on the Lock Screen and Dynamic Island. Control Center and Siri shortcuts provide quick access to your plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Integrations")
        .alert("Integration couldn't connect", isPresented: Binding(
            get: { integrationError != nil },
            set: { if !$0 { integrationError = nil } }
        )) {
            Button("OK", role: .cancel) { integrationError = nil }
        } message: {
            Text(integrationError ?? "Try again later.")
        }
    }

    @ViewBuilder
    private func integration(
        _ title: String,
        _ icon: String,
        _ connected: Bool,
        working: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if working {
                    ProgressView().controlSize(.small).accessibilityLabel("Refreshing " + title)
                } else if connected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if working {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Connecting \(title)")
                } else {
                    Text("Connect")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    private func connectCalendar() {
        guard !calendarWorking else { return }
        calendarWorking = true
        integrationError = nil

        Task {
            let ok = await CalendarService.shared.requestCalendarAccess()
            await MainActor.run {
                store.updateSettings { $0.calendarSyncEnabled = ok }
            }

            if ok {
                await store.refreshExternalSources()
                await MainActor.run {
                    calendarWorking = false
                }
            } else {
                await MainActor.run {
                    calendarWorking = false
                    integrationError = "Calendar access was not granted. You can change access later in iOS Settings."
                }
            }
        }
    }

    private func connectHealth() {
        guard !healthWorking else { return }
        healthWorking = true
        integrationError = nil

        Task {
            let ok = await HealthService.shared.requestReadAccess()
            await MainActor.run {
                store.updateSettings {
                    $0.healthSyncEnabled = ok
                    if !ok { $0.healthPlanningEnabled = false }
                }
                healthWorking = false
                if !ok {
                    integrationError = "Health access was not granted. You can change access later in iOS Settings."
                }
            }
            if ok { await store.refreshHealthIfNeeded() }
        }
    }
}
