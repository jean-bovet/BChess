//
//  LocalizationCatalogTests.swift
//  BChessTests
//
//  The String Catalog (`Shared/Localizable.xcstrings`) read as data: every string is translated in every
//  language the app ships, nothing is stale, and no number or notation sneaks into a key.
//

import Foundation
import Testing

struct LocalizationCatalogTests {

    /// The languages the catalog must be complete in (the source language, English, is not listed).
    static let languages = ["fr", "de", "it", "he", "ar"]

    /// Keys that may interpolate an `Int` directly: counts in a plural, never notation (the digits rule).
    static let integerKeyAllowlist: Set<String> = ["%lld games exported to “%@”"]

    private typealias Entry = [String: Any]

    private func catalog() throws -> [String: Entry] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["sourceLanguage"] as? String == "en")
        return try #require(root["strings"] as? [String: Entry])
    }

    /// The plural categories CLDR gives each language: a plural key needs every one of them, translated.
    static let pluralCategories: [String: Set<String>] = [
        "en": ["one", "other"], "fr": ["one", "other"], "de": ["one", "other"], "it": ["one", "other"],
        "he": ["one", "two", "many", "other"], "ar": ["zero", "one", "two", "few", "many", "other"],
    ]

    /// The units of a language: category -> state for a plural (`plural == true`), `[""]: state` for a plain string.
    private func units(of entry: Entry, in language: String) -> (plural: Bool, states: [String: String]) {
        guard let localization = (entry["localizations"] as? [String: Any])?[language] as? [String: Any] else {
            return (false, [:])
        }
        if let unit = localization["stringUnit"] as? [String: Any] {
            return (false, ["": unit["state"] as? String ?? ""])
        }
        if let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] {
            return (true, plural.mapValues { form in
                ((form as? [String: Any])?["stringUnit"] as? [String: Any])?["state"] as? String ?? ""
            })
        }
        return (false, [:])
    }

    @Test func catalogHasStrings() throws {
        #expect(try catalog().count > 100)
    }

    @Test func everyKeyIsTranslatedInEveryLanguage() throws {
        let strings = try catalog()
        for (key, entry) in strings where entry["shouldTranslate"] as? Bool != false {
            for language in Self.languages {
                let unit = units(of: entry, in: language)
                #expect(!unit.states.isEmpty && unit.states.values.allSatisfy { $0 == "translated" },
                        "\(key) has no \(language) translation")
            }
        }
    }

    /// Removing one form of a plural must fail: every language has its full category set (and the source language too).
    @Test func pluralKeysHaveEveryCategoryOfEveryLanguage() throws {
        var plurals = 0
        for (key, entry) in try catalog() where key.contains("%lld") {
            plurals += 1
            for language in ["en"] + Self.languages {
                let unit = units(of: entry, in: language)
                let expected = try #require(Self.pluralCategories[language], "no categories for \(language)")
                #expect(unit.plural && Set(unit.states.keys) == expected,
                        "\(key) has the forms \(unit.states.keys.sorted()) in \(language), needs \(expected.sorted())")
            }
        }
        #expect(plurals == Self.integerKeyAllowlist.count)
    }

    /// German is Swiss-spelled: Switzerland writes "ss" where Germany writes "ß" (Weiss, Schliessen, ausserhalb).
    @Test func germanHasNoEsszett() throws {
        for (key, entry) in try catalog() {
            let german = units(of: entry, in: "de")
            #expect(german.states.count > 0)
            let text = String(decoding: try JSONSerialization.data(withJSONObject: (entry["localizations"] as? [String: Any])?["de"] ?? [:]), as: UTF8.self)
            #expect(!text.contains("ß"), "\(key) has an ß in German")
        }
    }

    @Test func noKeyIsStale() throws {
        for (key, entry) in try catalog() {
            #expect(entry["extractionState"] as? String != "stale", "\(key) is stale")
        }
    }

    /// A number in a composed sentence is a `%@` argument that code formatted (Western digits, D1); `%lld` and `%d`
    /// would take the locale's digits.
    @Test func integersAreInterpolatedOnlyWhereAllowed() throws {
        for key in try catalog().keys where key.contains("%lld") || key.contains("%d") {
            #expect(Self.integerKeyAllowlist.contains(key), "\(key) interpolates an integer")
        }
    }

    /// The direction isolates are added by code, never typed into a key or a translation.
    @Test func noDirectionIsolateInTheCatalog() throws {
        let isolates = ["\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"]
        let strings = try catalog()
        for (key, entry) in strings {
            #expect(!isolates.contains { key.contains($0) }, "\(key) holds an isolate")
            let text = String(decoding: try JSONSerialization.data(withJSONObject: entry), as: UTF8.self)
            #expect(!isolates.contains { text.contains($0) }, "\(key) holds an isolate in a translation")
        }
    }
}
