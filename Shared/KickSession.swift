import Foundation

struct KickSession: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var targetDuration: TimeInterval
    var duplicateInterval: TimeInterval
    var duplicateFilteringEnabled: Bool
    var events: [KickEvent]
    var note: String
    var tags: [KickTag]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        targetDuration: TimeInterval = 60 * 60,
        duplicateInterval: TimeInterval = 2 * 60,
        duplicateFilteringEnabled: Bool = true,
        events: [KickEvent] = [],
        note: String = "",
        tags: [KickTag] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetDuration = targetDuration
        self.duplicateInterval = duplicateInterval
        self.duplicateFilteringEnabled = duplicateFilteringEnabled
        self.events = events
        self.note = note
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case kickCount
        case targetDuration
        case duplicateInterval
        case duplicateFilteringEnabled
        case events
        case note
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        targetDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .targetDuration) ?? 60 * 60
        duplicateInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .duplicateInterval) ?? 2 * 60
        duplicateFilteringEnabled = try container.decodeIfPresent(Bool.self, forKey: .duplicateFilteringEnabled) ?? true
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try container.decodeIfPresent([KickTag].self, forKey: .tags) ?? []

        if let storedEvents = try container.decodeIfPresent([KickEvent].self, forKey: .events) {
            events = storedEvents
        } else {
            let legacyCount = try container.decodeIfPresent(Int.self, forKey: .kickCount) ?? 0
            var legacyEvents: [KickEvent] = []
            for index in 0..<legacyCount {
                legacyEvents.append(KickEvent(timestamp: startedAt.addingTimeInterval(TimeInterval(index)), isEffective: true))
            }
            events = legacyEvents
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(targetDuration, forKey: .targetDuration)
        try container.encode(duplicateInterval, forKey: .duplicateInterval)
        try container.encode(duplicateFilteringEnabled, forKey: .duplicateFilteringEnabled)
        try container.encode(events, forKey: .events)
        try container.encode(note, forKey: .note)
        try container.encode(tags, forKey: .tags)
    }

    var isActive: Bool {
        endedAt == nil
    }

    var duration: TimeInterval {
        duration(at: .now)
    }

    func duration(at date: Date) -> TimeInterval {
        max((endedAt ?? date).timeIntervalSince(startedAt), 0)
    }

    var actualDuration: TimeInterval {
        duration
    }

    var effectiveCount: Int {
        events.filter(\.isEffective).count
    }

    var rawTapCount: Int {
        events.count
    }

    var duplicateCount: Int {
        events.filter { !$0.isEffective }.count
    }

    var lastEffectiveEvent: KickEvent? {
        events.last { $0.isEffective }
    }

    var progress: Double {
        progress(at: .now)
    }

    func progress(at date: Date) -> Double {
        guard targetDuration > 0 else { return 0 }
        let ratio = duration(at: date) / targetDuration
        guard ratio.isFinite else { return 0 }
        return min(max(ratio, 0), 1)
    }
}

struct KickEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var timestamp: Date
    var isEffective: Bool

    init(id: UUID = UUID(), timestamp: Date = .now, isEffective: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.isEffective = isEffective
    }
}

enum KickTag: String, CaseIterable, Codable, Identifiable, Hashable {
    case afterMeal
    case bedtime
    case afterWalk
    case leftSide

    var id: String { rawValue }
}

enum KickRecordResult: Equatable {
    case counted
    case duplicate
}

struct KickSyncPayload: Codable {
    var sessions: [KickSession]
    var activeSession: KickSession?
    var updatedAt: Date
}
