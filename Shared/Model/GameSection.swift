//
//  GameSection.swift
//  BChess
//
//  The games list groups games by the day they were last played.
//

import Foundation

/// A run of the games list: the games of one day-group, in the order they were given.
struct GameSection: Identifiable {
    enum Group: Int, CaseIterable {
        case today
        case yesterday
        case earlier

        /// In title case: the header shows it with `.textCase(.uppercase)`, which Hebrew and Arabic ignore.
        var title: LocalizedStringResource {
            switch self {
            case .today: return "Today"
            case .yesterday: return "Yesterday"
            case .earlier: return "Earlier"
            }
        }
    }

    let group: Group
    let games: [GameFile]

    var id: Group { group }

    /// Groups `games` (newest first, as the library lists them) by calendar day relative to `now`.
    /// A game dated after `now` (a clock that moved) counts as today. Empty groups are left out.
    static func sections(of games: [GameFile], now: Date, calendar: Calendar) -> [GameSection] {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        return Group.allCases.compactMap { group in
            let members = games.filter { Self.group(of: $0.modified, startOfToday, startOfYesterday) == group }
            return members.isEmpty ? nil : GameSection(group: group, games: members)
        }
    }

    private static func group(of date: Date, _ startOfToday: Date, _ startOfYesterday: Date) -> Group {
        if date >= startOfToday { return .today }
        if date >= startOfYesterday { return .yesterday }
        return .earlier
    }
}
