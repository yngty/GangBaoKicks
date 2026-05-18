import Foundation

@MainActor
final class KickStore: ObservableObject {
    @Published private(set) var sessions: [KickSession] = []
    @Published private(set) var activeSession: KickSession?
    @Published var targetDuration: TimeInterval {
        didSet {
            if targetDuration < 5 * 60 { targetDuration = 5 * 60 }
            defaults.set(targetDuration, forKey: targetDurationKey)
            updateActiveSessionSettings()
        }
    }

    @Published var duplicateInterval: TimeInterval {
        didSet {
            if duplicateInterval < 0 { duplicateInterval = 0 }
            defaults.set(duplicateInterval, forKey: duplicateIntervalKey)
            updateActiveSessionSettings()
        }
    }

    @Published var duplicateFilteringEnabled: Bool {
        didSet {
            defaults.set(duplicateFilteringEnabled, forKey: duplicateFilteringKey)
            updateActiveSessionSettings()
        }
    }

    @Published var autoStopWhenTargetReached: Bool {
        didSet {
            defaults.set(autoStopWhenTargetReached, forKey: autoStopWhenTargetReachedKey)
        }
    }

    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            defaults.set(hapticFeedbackEnabled, forKey: hapticFeedbackEnabledKey)
        }
    }

    private let defaults: UserDefaults
    private let sessionsKey = "gangbao.sessions"
    private let activeSessionKey = "gangbao.activeSession"
    private let targetDurationKey = "gangbao.targetDuration"
    private let duplicateIntervalKey = "gangbao.duplicateInterval"
    private let duplicateFilteringKey = "gangbao.duplicateFilteringEnabled"
    private let autoStopWhenTargetReachedKey = "gangbao.autoStopWhenTargetReached"
    private let hapticFeedbackEnabledKey = "gangbao.hapticFeedbackEnabled"
    private var latestSyncUpdate = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        targetDuration = defaults.object(forKey: targetDurationKey) as? TimeInterval ?? 60 * 60
        duplicateInterval = defaults.object(forKey: duplicateIntervalKey) as? TimeInterval ?? 2 * 60
        duplicateFilteringEnabled = defaults.object(forKey: duplicateFilteringKey) as? Bool ?? true
        autoStopWhenTargetReached = defaults.object(forKey: autoStopWhenTargetReachedKey) as? Bool ?? true
        hapticFeedbackEnabled = defaults.object(forKey: hapticFeedbackEnabledKey) as? Bool ?? false
        load()
    }

    var sortedSessions: [KickSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var syncPayload: KickSyncPayload {
        KickSyncPayload(sessions: sessions, activeSession: activeSession, updatedAt: .now)
    }

    func startSession() {
        activeSession = KickSession(
            targetDuration: targetDuration,
            duplicateInterval: duplicateInterval,
            duplicateFilteringEnabled: duplicateFilteringEnabled
        )
        save()
    }

    @discardableResult
    func addKick(at date: Date = .now) -> KickRecordResult {
        if activeSession == nil {
            startSession()
        }

        guard var session = activeSession else { return .counted }
        let isDuplicate = session.duplicateFilteringEnabled
            && session.duplicateInterval > 0
            && session.lastEffectiveEvent.map { date.timeIntervalSince($0.timestamp) < session.duplicateInterval } == true

        session.events.append(KickEvent(timestamp: date, isEffective: !isDuplicate))
        activeSession = session
        save()
        return isDuplicate ? .duplicate : .counted
    }

    func undoLastTap() {
        guard var session = activeSession, !session.events.isEmpty else { return }
        session.events.removeLast()
        activeSession = session
        save()
    }

    func endSession(at date: Date = .now) {
        guard var session = activeSession else { return }
        session.endedAt = date
        sessions.append(session)
        activeSession = nil
        save()
    }

    func updateActiveSession(note: String, tags: [KickTag]) {
        guard var session = activeSession else { return }
        session.note = note
        session.tags = tags
        activeSession = session
        save()
    }

    func updateSession(_ session: KickSession, note: String, tags: [KickTag]) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index].note = note
        sessions[index].tags = tags
        save()
    }

    func discardActiveSession() {
        activeSession = nil
        save()
    }

    func replace(with payload: KickSyncPayload) {
        guard payload.updatedAt >= latestSyncUpdate else { return }
        latestSyncUpdate = payload.updatedAt
        sessions = payload.sessions
        activeSession = payload.activeSession
        save()
    }

    private func updateActiveSessionSettings() {
        guard var session = activeSession else { return }
        session.targetDuration = targetDuration
        session.duplicateInterval = duplicateInterval
        session.duplicateFilteringEnabled = duplicateFilteringEnabled
        activeSession = session
        save()
    }

    private func load() {
        let decoder = JSONDecoder()

        if let data = defaults.data(forKey: sessionsKey),
           let storedSessions = try? decoder.decode([KickSession].self, from: data) {
            sessions = storedSessions
        }

        if let data = defaults.data(forKey: activeSessionKey),
           let storedActiveSession = try? decoder.decode(KickSession.self, from: data) {
            activeSession = storedActiveSession
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(sessions), forKey: sessionsKey)
        defaults.set(try? encoder.encode(activeSession), forKey: activeSessionKey)
    }
}
