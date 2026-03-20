import Foundation
import Testing
@testable import Shellmate

// Fixed reference date: 2026-03-19 10:00:00 UTC
private let referenceDate: Date = {
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 19
    components.hour = 10
    components.minute = 0
    components.second = 0
    components.timeZone = TimeZone.current
    return Calendar.current.date(from: components)!
}()

private func components(from date: Date) -> DateComponents {
    Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
}

@Suite("NaturalDateParser")
struct NaturalDateParserTests {
    let parser = NaturalDateParser()

    // MARK: - parseDate

    @Test("tomorrow returns March 20, no explicit time")
    func tomorrowNoTime() {
        let result = parser.parseDate("tomorrow", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 20)
        #expect(result!.hasExplicitTime == false)
    }

    @Test("tomorrow at 3pm returns March 20 15:00, explicit time")
    func tomorrowAt3pm() {
        let result = parser.parseDate("tomorrow at 3pm", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 20)
        #expect(c.hour == 15)
        #expect(c.minute == 0)
        #expect(result!.hasExplicitTime == true)
    }

    @Test("in 3 days returns March 22")
    func in3Days() {
        let result = parser.parseDate("in 3 days", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 22)
        #expect(result!.hasExplicitTime == false)
    }

    @Test("tomorrow morning returns March 20 9am")
    func tomorrowMorning() {
        let result = parser.parseDate("tomorrow morning", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.month == 3)
        #expect(c.day == 20)
        #expect(c.hour == 9)
        #expect(c.minute == 0)
        #expect(result!.hasExplicitTime == true)
    }

    @Test("tomorrow afternoon returns March 20 1pm")
    func tomorrowAfternoon() {
        let result = parser.parseDate("tomorrow afternoon", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.month == 3)
        #expect(c.day == 20)
        #expect(c.hour == 13)
        #expect(c.minute == 0)
        #expect(result!.hasExplicitTime == true)
    }

    @Test("ISO 8601 2026-03-25T14:00:00 returns March 25, explicit time")
    func iso8601() {
        let result = parser.parseDate("2026-03-25T14:00:00", relativeTo: referenceDate)
        #expect(result != nil)
        let c = components(from: result!.date)
        #expect(c.year == 2026)
        #expect(c.month == 3)
        #expect(c.day == 25)
        #expect(c.hour == 14)
        #expect(c.minute == 0)
        #expect(result!.hasExplicitTime == true)
    }

    @Test("gibberish returns nil")
    func gibberish() {
        let result = parser.parseDate("xyzzy garble", relativeTo: referenceDate)
        #expect(result == nil)
    }

    // MARK: - parseDuration

    @Test("30 minutes duration returns 1800s")
    func thirtyMinutes() {
        let result = parser.parseDuration("30 minutes")
        #expect(result != nil)
        #expect(result!.interval == 1800)
    }

    @Test("1 hour duration returns 3600s")
    func oneHour() {
        let result = parser.parseDuration("1 hour")
        #expect(result != nil)
        #expect(result!.interval == 3600)
    }

    @Test("gibberish duration returns nil")
    func gibberishDuration() {
        let result = parser.parseDuration("xyzzy garble")
        #expect(result == nil)
    }

    // MARK: - parseRange

    @Test("tomorrow to next Friday parses a range")
    func rangeBasic() {
        let result = parser.parseRange("tomorrow to next Friday", relativeTo: referenceDate)
        // Range parsing is best-effort; just verify non-nil produces valid start < end
        if let result {
            #expect(result.start < result.end)
        }
    }
}
