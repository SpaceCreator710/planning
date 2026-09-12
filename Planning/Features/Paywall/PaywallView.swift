import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppStore.self) private var store
    @State private var products: [Product] = []
    @State private var purchasing: String?
    @State private var restoring = false
    @State private var loading = false
    @State private var statusMessage: String?

    private let freeFeatures = [
        "Unlimited tasks, subtasks, Notes and Inbox",
        "Workspace pages/wiki, spaces, projects, 9 database views including Map, forms, charts, backlinks, Canvas/Graph and templates",
        "Web Clipper, Read Later, comments, version history, sites/presentation, Markdown/JSON import-export, command palette and time tracking",
        "Confirmed Workspace automations, meeting action notes, scheduling links, Smart Meetings, Focus Time and Weekly Autopilot",
        "Manual Planning Intelligence tools with status, results and one-step Undo",
        "Horizontal Day + Week timelines, exact drag confirmation, Day Path, smart task icons, widgets and Live Activities",
        "Basic reminders, themes and iCloud/local-first data",
        "Planning AI Agent + Custom Agent runs · up to 12 AI requests per day"
    ]

    private let proFeatures = [
        "Everything in Free",
        "Vertical Day and Vertical Week timelines",
        "Time Machine and Magnetic Compress",
        "Workspace Agent with app-wide safe actions + School AI + General AI + unlimited AI/custom-agent runs",
        "Recurring tasks and multiple/custom alerts",
        "Calendar + Health integrations",
        "Reality Replan + Horizon Planner",
        "Premium appearance, HSL colors and alternate app icons"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                    Text("Planning Pro")
                        .font(.largeTitle.bold())
                    Text("Keep the essentials generous. Unlock the full timeline, deeper automation and every AI mode when you want more.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 18)

                featureCard(
                    title: "Free",
                    badge: store.data.subscription.isPro ? "Included" : "Current",
                    features: freeFeatures
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pro")
                        .font(.title2.bold())
                    Text("Same Pro access with monthly or yearly billing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    purchaseRow(kind: .monthly)
                    purchaseRow(kind: .yearly)
                }
                .padding(16)
                .premiumGlassRounded(cornerRadius: 24, tint: .accentColor.opacity(0.08), interactive: true)

                featureCard(title: "Everything in Pro", badge: nil, features: proFeatures)

                Button(restoring ? "Restoring…" : "Restore purchases") {
                    guard !restoring, purchasing == nil else { return }
                    restoring = true
                    Task {
                        do {
                            try await StoreKit.AppStore.sync()
                            await refreshTier()
                            statusMessage = store.data.subscription.isPro ? "Your Pro access is restored." : "No active Planning Pro subscription was found for this Apple Account."
                        } catch {
                            statusMessage = "Purchases could not be restored. Please try again."
                        }
                        restoring = false
                    }
                }.buttonStyle(.glass).disabled(restoring || purchasing != nil)

                if products.isEmpty {
                    Button(loading ? "Checking App Store…" : "Reload available plans") { Task { await loadProducts() } }
                        .buttonStyle(.glass).disabled(loading)
                }
                Text("The App Store displays your local price and confirms the billing period before you subscribe. You can manage or cancel your subscription in your Apple Account settings.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .appCanvas()
        .navigationTitle("Subscription")
        .task { await loadProducts() }
    }

    private func purchaseRow(kind: PlanningProductKind) -> some View {
        let product = products.first(where: { $0.id == kind.productID })
        return Button {
            guard let product, purchasing == nil, !restoring else { return }
            purchasing = product.id
            Task {
                let ok = await SubscriptionService.shared.purchase(product)
                await refreshTier()
                purchasing = nil
                statusMessage = ok ? "Planning Pro unlocked." : "The purchase was not completed or is awaiting approval."
            }
        } label: {
            PlanningAdaptiveRow(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(kind.title).font(.headline).foregroundStyle(.primary)
                    Text(product.map { $0.displayPrice + (kind == .monthly ? " / month" : " / year") } ?? "Price unavailable")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if purchasing == product?.id && purchasing != nil { ProgressView() }
                else { Image(systemName: product == nil ? "appstore" : "arrow.up.right").foregroundStyle(.tint) }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 68).contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .disabled(product == nil || purchasing != nil || restoring)
        .accessibilityHint(product == nil ? "This plan is not available from the App Store yet" : "Opens Apple's purchase confirmation")
    }

    private func loadProducts() async {
        guard !loading else { return }
        loading = true
        await SubscriptionService.shared.loadProducts()
        products = SubscriptionService.shared.products
        await refreshTier()
        loading = false
    }

    private func featureCard(title: String, badge: String?, features: [String]) -> some View {
        MatteCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.title2.bold())
                    Spacer()
                    if let badge { Text(badge).font(.headline).foregroundStyle(.secondary) }
                }
                DisclosureGroup("\(features.count) included features") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(features, id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func refreshTier() async {
        await store.refreshSubscriptionTier()
    }
}
