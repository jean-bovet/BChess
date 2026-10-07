//
//  GameSectionsTests.swift
//  BChessTests
//
//  How the games list groups games by the day they were last played.
//

import Foundation
import Testing

struct GameSectionsTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: string)!
    }

    private func file(_ name: String, _ modified: String) -> GameFile {
        GameFile(url: URL(fileURLWithPath: "/games/\(name).bchess"), modified: date(modified))
    }

    private func titles(_ sections: [GameSection]) -> [String] {
        sections.map { "\($0.group.title): " + $0.games.map(\.title).joined(separator: ",") }
    }

    @Test func groupsByDayAndKeepsTheOrder() {
        let now = date("2026-10-07T10:42:00-07:00")
        let games = [file("a", "2026-10-07T08:15:00-07:00"),
                     file("b", "2026-10-06T22:00:00-07:00"),
                     file("c", "2026-10-05T12:00:00-07:00"),
                     file("d", "2026-09-28T12:00:00-07:00")]
        let sections = GameSection.sections(of: games, now: now, calendar: calendar)
        #expect(titles(sections) == ["TODAY: a", "YESTERDAY: b", "EARLIER: c,d"])
    }

    @Test func midnightStartsANewDay() {
        let now = date("2026-10-07T10:00:00-07:00")
        let games = [file("justAfter", "2026-10-07T00:00:00-07:00"),
                     file("justBefore", "2026-10-06T23:59:59-07:00"),
                     file("yesterdayStart", "2026-10-06T00:00:00-07:00"),
                     file("beforeYesterday", "2026-10-05T23:59:59-07:00")]
        let sections = GameSection.sections(of: games, now: now, calendar: calendar)
        #expect(titles(sections) == ["TODAY: justAfter", "YESTERDAY: justBefore,yesterdayStart", "EARLIER: beforeYesterday"])
    }

    @Test func nowJustAfterMidnightPushesTheEveningToYesterday() {
        let now = date("2026-10-07T00:00:01-07:00")
        let sections = GameSection.sections(of: [file("evening", "2026-10-06T23:30:00-07:00")], now: now, calendar: calendar)
        #expect(titles(sections) == ["YESTERDAY: evening"])
    }

    @Test func emptyGroupsAreLeftOut() {
        let now = date("2026-10-07T10:00:00-07:00")
        #expect(GameSection.sections(of: [], now: now, calendar: calendar).isEmpty)
        let onlyEarlier = GameSection.sections(of: [file("old", "2025-01-01T12:00:00-08:00")], now: now, calendar: calendar)
        #expect(titles(onlyEarlier) == ["EARLIER: old"])
    }

    @Test func aFileFromTheFutureCountsAsToday() {
        let now = date("2026-10-07T10:00:00-07:00")
        let sections = GameSection.sections(of: [file("skewed", "2026-10-09T10:00:00-07:00")], now: now, calendar: calendar)
        #expect(titles(sections) == ["TODAY: skewed"])
    }

    @Test func daysAreCountedInTheCalendarsTimeZoneAcrossDaylightSaving() {
        // The clocks go back on 2026-11-01: that day has 25 hours, and "yesterday" is still the day before
        let now = date("2026-11-02T00:30:00-08:00")
        let sections = GameSection.sections(of: [file("sunday", "2026-11-01T00:30:00-07:00")], now: now, calendar: calendar)
        #expect(titles(sections) == ["YESTERDAY: sunday"])
    }
}
