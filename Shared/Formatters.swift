import Foundation

extension KickSession {
    var durationText: String {
        duration.formattedDuration
    }

    var targetDurationText: String {
        targetDuration.formattedMinutes
    }

    var dateText: String {
        startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var timeRangeText: String {
        guard let endedAt else {
            return startedAt.formatted(date: .omitted, time: .shortened)
        }
        return "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = max(Int(self), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedMinutes: String {
        let minutes = max(Int((self / 60).rounded()), 0)
        return String(format: NSLocalizedString("time.minutes", comment: "Minutes format"), minutes)
    }
}

extension KickTag {
    var localizedName: String {
        NSLocalizedString("tag.\(rawValue)", comment: "Kick tag")
    }
}
