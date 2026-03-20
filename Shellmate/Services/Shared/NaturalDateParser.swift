import Foundation

// MARK: - NaturalDateParser

/// Parses natural-language date/time expressions into concrete `Date` values.
/// Strategy: relative patterns -> colloquial time modifiers -> "at X" modifiers -> NSDataDetector -> ISO 8601 -> nil.
struct NaturalDateParser: Sendable {

    // MARK: - Result Types

    struct ParsedDate: Sendable {
        let date: Date
        let hasExplicitTime: Bool
        let source: String
    }

    struct ParsedRange: Sendable {
        let start: Date
        let end: Date
        let source: String
    }

    struct ParsedDuration: Sendable {
        let interval: TimeInterval
        let source: String
    }

    // MARK: - Public API

    func parseDate(_ text: String, relativeTo base: Date = .now) -> ParsedDate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current

        // Step 1: Try relative patterns
        if let result = parseRelative(trimmed, relativeTo: base, calendar: calendar) {
            // Step 2: Apply colloquial time modifiers
            if let modified = applyColloquialTime(trimmed, to: result.date, calendar: calendar) {
                return ParsedDate(date: modified, hasExplicitTime: true, source: text)
            }
            // Step 3: Apply "at Xpm/am" modifier
            if let modified = applyAtTime(trimmed, to: result.date, calendar: calendar) {
                return ParsedDate(date: modified, hasExplicitTime: true, source: text)
            }
            return ParsedDate(date: result.date, hasExplicitTime: result.hasExplicitTime, source: text)
        }

        // Step 4: Try ISO 8601 (use original text to preserve 'T' separator)
        let trimmedOriginal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let result = parseISO8601(trimmedOriginal) {
            return ParsedDate(date: result, hasExplicitTime: true, source: text)
        }

        // Step 5: Try NSDataDetector
        if let result = parseWithDataDetector(text, relativeTo: base) {
            return result
        }

        return nil
    }

    func parseRange(_ text: String, relativeTo base: Date = .now) -> ParsedRange? {
        // Split on common range separators
        let separators = [" to ", " through ", " until ", " - ", "–", "—"]
        for sep in separators {
            let parts = text.lowercased().components(separatedBy: sep)
            if parts.count == 2 {
                let startText = parts[0].trimmingCharacters(in: .whitespaces)
                let endText = parts[1].trimmingCharacters(in: .whitespaces)
                if let start = parseDate(startText, relativeTo: base),
                   let end = parseDate(endText, relativeTo: base),
                   start.date < end.date {
                    return ParsedRange(start: start.date, end: end.date, source: text)
                }
            }
        }
        return nil
    }

    func parseDuration(_ text: String) -> ParsedDuration? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Match patterns like "30 minutes", "1 hour", "2 hours 30 minutes", "1.5 hours"
        let patterns: [(String, TimeInterval)] = [
            ("second", 1),
            ("minute", 60),
            ("hour", 3600),
            ("day", 86400),
            ("week", 604800),
        ]

        var total: TimeInterval = 0
        var matched = false

        for (unit, multiplier) in patterns {
            // Match "N unit(s)" patterns
            let pattern = #"(\d+(?:\.\d+)?)\s*"# + unit + #"s?"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let numRange = Range(match.range(at: 1), in: trimmed) {
                if let value = Double(trimmed[numRange]) {
                    total += value * multiplier
                    matched = true
                }
            }
        }

        return matched ? ParsedDuration(interval: total, source: text) : nil
    }

    // MARK: - Private Helpers

    private struct RelativeResult {
        let date: Date
        let hasExplicitTime: Bool
    }

    private func parseRelative(_ text: String, relativeTo base: Date, calendar: Calendar) -> RelativeResult? {
        // "today"
        if text.hasPrefix("today") {
            return RelativeResult(date: calendar.startOfDay(for: base), hasExplicitTime: false)
        }

        // "tomorrow"
        if text.hasPrefix("tomorrow") {
            if let date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: base)) {
                return RelativeResult(date: date, hasExplicitTime: false)
            }
        }

        // "yesterday"
        if text.hasPrefix("yesterday") {
            if let date = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: base)) {
                return RelativeResult(date: date, hasExplicitTime: false)
            }
        }

        // "in N days/hours/minutes/weeks"
        let inPattern = #"^in\s+(\d+)\s+(day|hour|minute|week|month)s?"#
        if let regex = try? NSRegularExpression(pattern: inPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let numRange = Range(match.range(at: 1), in: text),
           let unitRange = Range(match.range(at: 2), in: text),
           let num = Int(text[numRange]) {
            let unit = String(text[unitRange])
            let component: Calendar.Component = switch unit {
            case "day": .day
            case "hour": .hour
            case "minute": .minute
            case "week": .weekOfYear
            case "month": .month
            default: .day
            }
            let hasTime = (unit == "hour" || unit == "minute")
            if let date = calendar.date(byAdding: component, value: num, to: hasTime ? base : calendar.startOfDay(for: base)) {
                return RelativeResult(date: date, hasExplicitTime: hasTime)
            }
        }

        // "next Tuesday", "next Monday", etc.
        let nextDayPattern = #"^next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        if let regex = try? NSRegularExpression(pattern: nextDayPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let dayRange = Range(match.range(at: 1), in: text) {
            let dayName = String(text[dayRange])
            let targetWeekday = weekdayNumber(for: dayName)
            let currentWeekday = calendar.component(.weekday, from: base)
            var daysAhead = targetWeekday - currentWeekday
            if daysAhead <= 0 { daysAhead += 7 }
            if let date = calendar.date(byAdding: .day, value: daysAhead, to: calendar.startOfDay(for: base)) {
                return RelativeResult(date: date, hasExplicitTime: false)
            }
        }

        return nil
    }

    private func applyColloquialTime(_ text: String, to date: Date, calendar: Calendar) -> Date? {
        // Order matters: "afternoon" must come before "noon" to avoid partial match
        let timeModifiers: [(String, Int)] = [
            ("morning", 9),
            ("afternoon", 13),
            ("evening", 18),
            ("night", 21),
            ("noon", 12),
        ]
        for (keyword, hour) in timeModifiers {
            if text.contains(keyword) {
                return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)
            }
        }
        return nil
    }

    private func applyAtTime(_ text: String, to date: Date, calendar: Calendar) -> Date? {
        // Match "at 3pm", "at 3:30pm", "at 15:00", "at 3 pm"
        let atPattern = #"at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        guard let regex = try? NSRegularExpression(pattern: atPattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]) else {
            return nil
        }

        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minRange = Range(match.range(at: 2), in: text) {
            minute = Int(text[minRange]) ?? 0
        }

        if match.range(at: 3).location != NSNotFound,
           let periodRange = Range(match.range(at: 3), in: text) {
            let period = String(text[periodRange])
            if period == "pm" && hour < 12 { hour += 12 }
            if period == "am" && hour == 12 { hour = 0 }
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    private func parseWithDataDetector(_ text: String, relativeTo base: Date) -> ParsedDate? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector.firstMatch(in: text, range: range), let date = match.date {
            let hasTime = match.duration == 0 && match.timeZone != nil
            return ParsedDate(date: date, hasExplicitTime: hasTime, source: text)
        }
        return nil
    }

    private func parseISO8601(_ text: String) -> Date? {
        // Try local time first (no timezone suffix, e.g. 2026-03-25T14:00:00)
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localFormatter.timeZone = TimeZone.current
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = localFormatter.date(from: text) { return date }

        // Full internet date-time with timezone (e.g. 2026-03-25T14:00:00Z)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: text) { return date }

        // Date-only (e.g. 2026-03-25)
        isoFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return isoFormatter.date(from: text)
    }

    private func weekdayNumber(for name: String) -> Int {
        switch name {
        case "sunday": 1
        case "monday": 2
        case "tuesday": 3
        case "wednesday": 4
        case "thursday": 5
        case "friday": 6
        case "saturday": 7
        default: 1
        }
    }
}
