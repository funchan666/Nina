import Foundation

enum SkateTerrain: String, CaseIterable, Codable, Identifiable {
    case street, park, flat

    var id: Self { self }
    var title: String {
        switch self {
        case .street: return "Street"
        case .park: return "Park"
        case .flat: return "Flatground"
        }
    }
}

enum SurfaceCondition: String, CaseIterable, Codable, Identifiable {
    case smooth, rough, waxed, damp

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum SkateStance: String, CaseIterable, Codable, Identifiable {
    case regular, goofy, switchStance = "switch", fakie

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct SkateSpot: Codable, Identifiable {
    var id = UUID()
    var name: String
    var terrain: SkateTerrain
    var obstacle: String
    var condition: SurfaceCondition
    var accessNotes: String
    var referenceID: String?
    var createdAt = Date()

    var crewKey: String {
        terrain.rawValue + ":" + name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
    }
}

enum TrickProgress: String {
    case planned = "Planned"
    case working = "In progress"
    case goalMet = "Goal landed"
}

struct TrickAttempt: Codable, Identifiable {
    var id = UUID()
    var spotID: UUID
    var trick: String
    var stance: SkateStance
    var attempts: Int
    var landings: Int
    var goal: Int
    var minutes: Int
    var notes: String
    var referenceID: String?
    var shareWithCrew: Bool
    var date = Date()

    var progress: TrickProgress {
        if attempts == 0 { return .planned }
        return landings >= goal ? .goalMet : .working
    }
}

enum JournalCover: String, CaseIterable, Codable, Identifiable {
    case bowl, wax, night
    var id: Self { self }
    var cost: Int { 60 }

    var title: String {
        switch self {
        case .bowl: return "Bowl Print"
        case .wax: return "Curb Print"
        case .night: return "After Hours"
        }
    }

    var image: String {
        switch self {
        case .bowl: return "CoverBowl"
        case .wax: return "CoverWax"
        case .night: return "CoverNight"
        }
    }
}
