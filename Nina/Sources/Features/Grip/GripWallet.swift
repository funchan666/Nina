import StoreKit
import SwiftUI

struct GripWallet: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @EnvironmentObject private var store: GripStore
    @Environment(\.ninaRouteVisible) private var visible
    @State private var priceRequest: Task<Void, Never>?

    var body: some View {
        NinaPage("Wallet", ground: "CrewGround") {
            balance
            if NinaConfiguration.purchasesEnabled {
                if let offer = store.offer, store.offerOwner == library.activeID {
                    quote(offer)
                } else {
                    packs
                }
            } else {
                NinaNotice(text: "Grip packs are currently unavailable.")
            }
            if !store.status.isEmpty { NinaNotice(text: store.status) }
            NinaHeading(text: "Grip history")
            let entries = Array((library.me?.grip ?? []).reversed())
            if entries.isEmpty { NinaNotice(text: "Your Grip changes will appear here.") }
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.label).font(NinaTheme.label)
                        Text(entry.date, style: .date).font(NinaTheme.caption).foregroundColor(NinaTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Text(entry.amount > 0 ? "+\(entry.amount)" : "\(entry.amount)").font(NinaTheme.label).monospacedDigit()
                }
                .padding(10)
                .background(NinaTheme.paper)
            }
        }
        .onChange(of: visible) { current in
            if !current { clearQuote() }
        }
        .onDisappear(perform: clearQuote)
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 4) {
            InkGlyph(ink: .grip, size: 46, color: NinaTheme.grip)
            Text("\(library.me?.balance ?? 0) Grip").font(NinaTheme.title)
            Text("Unlock a cover for your skate journal.")
            NinaButton("See journal covers", icon: .sessions, kind: .paper) { flow.open(.covers) }
        }
        .foregroundColor(NinaTheme.paper)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NinaTheme.ink)
    }

    private var packs: some View {
        VStack(alignment: .leading, spacing: 7) {
            NinaHeading(text: "Grip packs")
            if store.working { NinaNotice(text: "Checking with Apple…") }
            ForEach(GripPack.packs) { pack in
                NinaRow(title: pack.name, detail: "\(pack.amount) Grip · View Apple price", icon: .grip) {
                    guard let owner = library.activeID, !store.working else { return }
                    priceRequest?.cancel()
                    priceRequest = Task { await store.quote(pack, owner: owner) }
                }
                .disabled(store.working)
            }
            NinaButton("Check Apple purchases", icon: .load, kind: .paper) {
                Task { await store.recover(using: library) }
            }
            .disabled(store.working)
            Text("Apple can finish pending deliveries. Used Grip doesn’t restore.")
                .font(NinaTheme.caption).foregroundColor(NinaTheme.muted)
        }
    }

    private func clearQuote() {
        priceRequest?.cancel()
        priceRequest = nil
        store.dismissOffer()
    }

    private func quote(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            NinaHeading(text: product.displayName)
            if let pack = GripPack.packs.first(where: { $0.id == product.id }) {
                Text("\(pack.amount) Grip")
            }
            Text(product.displayPrice).font(NinaTheme.card)
            NinaButton(store.working ? "Waiting for Apple…" : "Buy for \(product.displayPrice)", icon: .grip) {
                Task { await store.buy(using: library) }
            }
            .disabled(store.working)
            NinaButton("Cancel", kind: .paper) { store.dismissOffer() }.disabled(store.working)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NinaTheme.paper)
    }
}

struct JournalCoverShop: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var confirming: JournalCover?

    var body: some View {
        NinaPage("Journal covers", ground: "SessionsGround") {
            NinaNotice(text: "\(library.me?.balance ?? 0) Grip available")
            ForEach(JournalCover.allCases) { cover in
                let owned = library.me?.covers.contains(cover) == true
                let selected = library.me?.selectedCover == cover
                HStack(alignment: .center, spacing: 12) {
                    Image(cover.image)
                        .resizable().scaledToFill()
                        .frame(width: 76, height: 108).clipped()
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cover.title).font(NinaTheme.card)
                        if selected {
                            Text("Applied").font(NinaTheme.caption)
                        } else if owned {
                            NinaButton("Apply cover", icon: .check, kind: .paper) { apply(cover) }
                        } else if confirming == cover {
                            NinaButton("Spend \(cover.cost) Grip", icon: .grip) {
                                apply(cover)
                                confirming = nil
                            }
                            NinaButton("Cancel", kind: .text) { confirming = nil }
                        } else {
                            NinaButton("Unlock · \(cover.cost) Grip", icon: .grip) { confirming = cover }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(9)
                .background(NinaTheme.paper)
            }
            if library.me?.selectedCover != nil {
                NinaButton("Use standard cover", icon: .deck, kind: .paper) { flow.run { try library.clearCover() } }
            }
            NinaButton("Open wallet", icon: .grip, kind: .paper) { flow.open(.wallet) }
        }
    }

    private func apply(_ cover: JournalCover) {
        flow.run {
            try library.selectCover(cover)
            flow.notice = "Journal cover applied."
        }
    }
}
