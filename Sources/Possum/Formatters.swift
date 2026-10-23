import Foundation

enum ClockFormatter {
    // Cached: the clock redraws every second. POSIX locale keeps "HH:mm" 24h regardless of user settings.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return f
    }()

    static func timeString(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

enum DurationFormatter {
    static func string(from interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) 小时 \(m) 分钟" }
        if m > 0 { return "\(m) 分钟" }
        return "不到 1 分钟"
    }
}
