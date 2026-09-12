import Foundation
import StoreKit

enum PlanningProductKind: String, CaseIterable {
    case monthly, yearly

    var productID: String {
        switch self {
        case .monthly: return "com.aiplanyourday.pro.monthly"
        case .yearly: return "com.aiplanyourday.pro.yearly"
        }
    }

    var title: String {
        switch self {
        case .monthly: return "Pro Monthly"
        case .yearly: return "Pro Yearly"
        }
    }

    // Reference US prices used on the in-app fallback before App Store products resolve.
    // App Store Connect remains the authority for localized storefront pricing.
    var referencePrice: String {
        switch self {
        case .monthly: return "$4.99 / month"
        case .yearly: return "$24.99 / year"
        }
    }
}

@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()
    static let freePlanningAIDailyLimit = 12

    private let productIDs = PlanningProductKind.allCases.map(\.productID)
    private let legacyProductIDs = ["com.aiplanyourday.plus.monthly"]

    var products: [Product] = []

    var enabled: Bool {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUBSCRIPTIONS_ENABLED") as? String else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on": return true
        default: return false
        }
    }

    func loadProducts() async {
        guard enabled else {
            products = []
            return
        }
        let loaded = (try? await Product.products(for: productIDs)) ?? []
        products = loaded.sorted { productRank($0.id) < productRank($1.id) }
    }

    func purchase(_ product: Product) async -> Bool {
        guard enabled, let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            return true
        default:
            return false
        }
    }

    func currentTier() async -> SubscriptionTier {
        guard enabled else { return .free }
        let recognized = Set(productIDs + legacyProductIDs)
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  recognized.contains(transaction.productID), transaction.revocationDate == nil, !transaction.isUpgraded,
                  transaction.expirationDate.map({ $0 > .now }) != false else { continue }
            return .pro
        }
        return .free
    }

    func kind(for product: Product) -> PlanningProductKind? {
        PlanningProductKind.allCases.first { $0.productID == product.id }
    }

    func remainingFreePlanningAIRequests() -> Int {
        let defaults = UserDefaults.standard
        let dayKey = DateKey.today
        let storedDay = defaults.string(forKey: "planning.free-ai.day")
        if storedDay != dayKey {
            defaults.set(dayKey, forKey: "planning.free-ai.day")
            defaults.set(0, forKey: "planning.free-ai.count")
            return Self.freePlanningAIDailyLimit
        }
        return max(0, Self.freePlanningAIDailyLimit - defaults.integer(forKey: "planning.free-ai.count"))
    }

    @discardableResult
    func consumeFreePlanningAIRequest() -> Bool {
        let remaining = remainingFreePlanningAIRequests()
        guard remaining > 0 else { return false }
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: "planning.free-ai.count") + 1,
            forKey: "planning.free-ai.count"
        )
        return true
    }

    private func productRank(_ id: String) -> Int {
        if id == PlanningProductKind.monthly.productID { return 0 }
        if id == PlanningProductKind.yearly.productID { return 1 }
        return 99
    }
}
