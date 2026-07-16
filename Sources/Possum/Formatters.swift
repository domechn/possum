import Foundation

enum ClockFormatter {
    static func timeString(from date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func dateString(from date: Date,
                           locale: Locale = .current,
                           timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEEMMMd", options: 0, locale: locale)
        return f.string(from: date)
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
