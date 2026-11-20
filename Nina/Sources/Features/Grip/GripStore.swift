import Combine
import Foundation
import StoreKit

@MainActor
final class GripStore: ObservableObject {
    @Published private(set) var working = false
    @Published private(set) var offer: Product?
    @Published private(set) var offerOwner: UUID?
    @Published private(set) var status = ""
    private var updates: Task<Void, Never>?

    deinit { updates?.cancel() }

    func listen(to library: NinaLibrary) {
        guard updates == nil, NinaConfiguration.purchasesEnabled else { return }
        updates = Task { [weak self, weak library] in
            for await verification in Transaction.updates {
                guard let self, let library else { return }
                await self.receive(verification, library: library, initiatedBy: nil)
            }
        }
        Task { [weak self, weak library] in
            guard let self, let library else { return }
            await self.processUnfinished(library)
        }
    }

    func quote(_ pack: GripPack, owner: UUID) async {
        guard !working, NinaConfiguration.purchasesEnabled else { return }
        working = true
        status = ""
        offer = nil
        offerOwner = nil
        defer { working = false }
        do {
            let products = try await Product.products(for: [pack.id])
            try Task.checkCancellation()
            guard let product = products.first(where: { $0.id == pack.id }), product.type == .consumable else {
                throw NinaIssue("Apple hasn't made this pack available.")
            }
            offer = product
            offerOwner = owner
        } catch is CancellationError {
            return
        } catch {
            status = (error as? NinaIssue)?.text ?? "Couldn't load the price from Apple. Try again."
        }
    }

    func dismissOffer() {
        guard !working else { return }
        offer = nil
        offerOwner = nil
    }

    func buy(using library: NinaLibrary) async {
        guard !working, NinaConfiguration.purchasesEnabled, let offer,
              let owner = offerOwner, owner == library.activeID else { return }
        working = true
        status = ""
        defer {
            working = false
            self.offer = nil
            offerOwner = nil
        }
        do {
            let result = try await offer.purchase(options: [.appAccountToken(owner)])
            switch result {
            case .success(let verification): await receive(verification, library: library, initiatedBy: owner)
            case .pending: status = "Waiting for Apple's approval."
            case .userCancelled: status = "Purchase canceled."
            @unknown default: status = "Apple returned an unknown result. Check again before purchasing."
            }
        } catch {
            status = "Apple couldn't complete the purchase. Check your connection and try again."
        }
    }

    func recover(using library: NinaLibrary) async {
        guard !working, NinaConfiguration.purchasesEnabled else { return }
        working = true
        status = ""
        defer { working = false }
        do {
            try await AppStore.sync()
            await processUnfinished(library)
            if status.isEmpty { status = "Apple purchase check complete." }
        } catch {
            status = "Apple couldn't check purchases. Try again."
        }
    }

    private func processUnfinished(_ library: NinaLibrary) async {
        for await verification in Transaction.unfinished {
            await receive(verification, library: library, initiatedBy: nil)
        }
    }

    private func receive(_ verification: VerificationResult<Transaction>, library: NinaLibrary, initiatedBy: UUID?) async {
        guard case .verified(let transaction) = verification else {
            if initiatedBy != nil { status = "Apple couldn't verify this purchase." }
            return
        }
        guard let pack = GripPack.packs.first(where: { $0.id == transaction.productID }),
              let owner = transaction.appAccountToken else {
            if initiatedBy != nil { status = "This purchase couldn't be assigned to your profile." }
            return
        }
        do {
            let delivered = try library.recordGrip(transaction, pack: pack, owner: owner)
            guard delivered else {
                if initiatedBy != nil { status = "This purchase belongs to a different profile." }
                return
            }
            await transaction.finish()
            if library.activeID == owner {
                status = transaction.revocationDate == nil ? "Purchase verified." : "Grip adjusted for Apple's refund."
            }
        } catch {
            if library.activeID == owner { status = "Grip is waiting to be recorded. Check purchases again." }
        }
    }
}

extension NinaLibrary {
    func recordGrip(_ transaction: Transaction, pack: GripPack, owner: UUID) throws -> Bool {
        let id = String(transaction.id)
        let revoked = transaction.revocationDate != nil
        let entry = archive.receipts[id]
        if let entry {
            guard entry.owner == owner, entry.productID == pack.id else { return false }
            if entry.revoked == revoked { return true }
        }
        guard archive.accounts[owner] != nil else { return archive.retiredAccounts.contains(owner) }
        try commit { next in
            if var previous = entry {
                if previous.credited {
                    next.accounts[owner]?.grip.append(
                        GripEntry(id: UUID().uuidString, label: revoked ? "Apple refund" : "Refund reversed",
                                  amount: revoked ? -pack.amount : pack.amount)
                    )
                } else if !revoked {
                    next.accounts[owner]?.grip.append(GripEntry(id: "purchase-" + id, label: pack.name, amount: pack.amount))
                }
                previous = GripReceipt(owner: owner, productID: pack.id, credited: previous.credited || !revoked, revoked: revoked)
                next.receipts[id] = previous
            } else {
                if !revoked {
                    next.accounts[owner]?.grip.append(GripEntry(id: "purchase-" + id, label: pack.name, amount: pack.amount))
                }
                next.receipts[id] = GripReceipt(owner: owner, productID: pack.id, credited: !revoked, revoked: revoked)
            }
        }
        return true
    }
}
