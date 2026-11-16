import Foundation
import StoreKit

@MainActor
final class NinaPurchases {
    private var offers: [String: Product] = [:]
    private var unfinished: [String: Transaction] = [:]
    private var updates: Task<Void, Never>?

    deinit { updates?.cancel() }

    func price(for id: String) async throws -> [String: String] {
        try requireEnabled()
        let products = try await Product.products(for: [id])
        guard let product = products.first(where: { $0.id == id && $0.type == .consumable }) else {
            throw NinaIssue("Apple hasn't made this pack available.")
        }
        offers[id] = product
        return ["id": product.id, "name": product.displayName, "price": product.displayPrice]
    }

    func buy(_ id: String, owner: UUID) async throws -> [String: Any] {
        try requireEnabled()
        guard let product = offers.removeValue(forKey: id) else { throw NinaIssue("Check the Apple price first.") }
        switch try await product.purchase(options: [.appAccountToken(owner)]) {
        case .success(let verification):
            guard let transaction = remember(verification) else { return ["status": "unverified"] }
            return ["status": "purchased", "transaction": transaction]
        case .pending: return ["status": "pending"]
        case .userCancelled: return ["status": "cancelled"]
        @unknown default: return ["status": "unknown"]
        }
    }

    func start() async throws -> [[String: Any]] {
        try requireEnabled()
        if updates == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    if let payload = self?.remember(result) {
                        NotificationCenter.default.post(name: NSNotification.Name("NinaPurchase"), object: nil, userInfo: payload)
                    }
                }
            }
        }
        return await listUnfinished()
    }

    func recover() async throws -> [[String: Any]] {
        try requireEnabled()
        try await AppStore.sync()
        return await listUnfinished()
    }

    func finish(_ id: String) async {
        guard let transaction = unfinished.removeValue(forKey: id) else { return }
        await transaction.finish()
    }

    private func listUnfinished() async -> [[String: Any]] {
        var results: [[String: Any]] = []
        for await verification in Transaction.unfinished {
            if let payload = remember(verification) { results.append(payload) }
        }
        return results
    }

    private func remember(_ verification: VerificationResult<Transaction>) -> [String: Any]? {
        guard case .verified(let transaction) = verification, transaction.productType == .consumable,
              let owner = transaction.appAccountToken else { return nil }
        let id = String(transaction.id)
        unfinished[id] = transaction
        return ["id": id, "owner": owner.uuidString, "productID": transaction.productID, "revoked": transaction.revocationDate != nil]
    }

    private func requireEnabled() throws {
        guard PlatformConfiguration.purchasesEnabled else { throw NinaIssue("Grip packs are currently unavailable.") }
    }
}
