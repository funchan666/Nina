import Foundation

struct GripPack: Identifiable {
    let key: String
    let name: String
    let amount: Int

    var id: String { "com.funchan666.nina.placeholder.grip." + key }
    static let packs = [
        Self(key: "pocket", name: "Pocket roll", amount: 60),
        Self(key: "curb", name: "Curb pack", amount: 180),
        Self(key: "park", name: "Park pack", amount: 340),
        Self(key: "street", name: "Street pack", amount: 780),
        Self(key: "line", name: "Line pack", amount: 1700),
        Self(key: "crew", name: "Crew pack", amount: 4600),
        Self(key: "tour", name: "Tour pack", amount: 10000)
    ]
}

struct GripEntry: Identifiable, Codable {
    let id: String
    let label: String
    let amount: Int
    var date = Date()
}

struct GripReceipt: Codable {
    let owner: UUID
    let productID: String
    let credited: Bool
    var revoked: Bool
}
