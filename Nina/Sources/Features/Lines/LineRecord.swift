import Foundation

enum LineCollection: String, CaseIterable, Codable, Identifiable {
    case street, park, flat, offboard

    var id: Self { self }
    var title: String {
        if self == .offboard { return "Off the Board" }
        return terrain?.title ?? ""
    }
    var terrain: SkateTerrain? { SkateTerrain(rawValue: rawValue) }
}

enum LineFormat: String, Codable {
    case photo, video
}

struct LineMedia: Identifiable, Decodable {
    let id: String
    let title: String
    let type: LineFormat
    let collection: LineCollection
    let path: String
    let poster: String?
    let width: Int
    let height: Int
    let duration: Double?

    var aspectRatio: CGFloat { CGFloat(max(1, width)) / CGFloat(max(1, height)) }
    var stillPath: String { poster ?? path }
}

struct LineComment: Identifiable, Codable {
    var id = UUID()
    let lineID: String
    let authorID: UUID
    var body: String
    let date: Date
}

enum PublicationStatus: String, Codable {
    case pending = "Awaiting review"
}

struct LineSubmission: Identifiable, Codable {
    var id = UUID()
    var title: String
    var caption: String
    var attachment: SkateAttachment
    var status: PublicationStatus = .pending
    var createdAt = Date()
}

struct SkateAttachment: Codable, Equatable {
    let type: LineFormat
    let file: String
    let posterFile: String?
}
