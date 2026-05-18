import Foundation

struct CSVExporter {
    static func makeFileURL(from sessions: [KickSession]) throws -> URL {
        let formatter = ISO8601DateFormatter()
        var rows = ["started_at,ended_at,target_duration_seconds,actual_duration_seconds,effective_count,raw_tap_count,duplicate_count,tags,note"]

        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let started = formatter.string(from: session.startedAt)
            let ended = session.endedAt.map { formatter.string(from: $0) } ?? ""
            let tags = escape(session.tags.map(\.rawValue).joined(separator: "|"))
            let note = escape(session.note)
            rows.append("\(started),\(ended),\(Int(session.targetDuration)),\(Int(session.actualDuration)),\(session.effectiveCount),\(session.rawTapCount),\(session.duplicateCount),\(tags),\(note)")
        }

        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appending(path: "GangBaoKicks.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\n") || value.contains("\"") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
