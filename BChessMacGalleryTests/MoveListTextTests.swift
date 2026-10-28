//
//  MoveListTextTests.swift
//  BChessMacGalleryTests
//
//  The view-side pure functions that keep notation and comments in their own direction (display only, nothing is
//  written to a file). Views are not compiled into the unhosted `BChessTests`, so they are tested here, in the app.
//

import Foundation
import Testing
@testable import BChess

@MainActor
struct MoveListTextTests {

    /// The depth is notation: "9/12" in an isolate, so the slash stays between the numbers in a right-to-left line.
    @Test func statisticsIsolateTheDepth() {
        let text = EngineView.statistics(depth: 9, quiescenceDepth: 12, nodes: 1_234_567, speed: 410_000)
        #expect(text.contains("\u{2066}9/12\u{2069}"))
        let plain = EngineView.statistics(depth: 9, quiescenceDepth: 0, nodes: 10, speed: 20)
        #expect(plain.contains("\u{2066}9\u{2069}"))
        // The counts are not notation: no isolate around them
        #expect(!text.contains("\u{2066}1"))
    }

    private func characters(_ text: AttributedString) -> String {
        String(text.characters)
    }

    /// A variation line is a left-to-right sequence whatever the window's direction, and a comment reads in its own
    /// direction inside it: today's spacing (no space after "(" or before ")", one space before every other piece).
    @Test func variationLineIsolatesTheSequenceAndEachComment() {
        let tokens: [MoveToken] = [.open, .move("8\u{2026}O-O", uuid: 3), .comment("הערה"), .move("9. d4", uuid: 4), .close]
        let text = MoveRowView.variationText(tokens, current: 0)
        #expect(characters(text) == "\u{2066}(8\u{2026}O-O \u{2068}הערה\u{2069} 9. d4)\u{2069}")
        // The tokens themselves are untouched (the isolates are added to the display only)
        #expect(tokens[2] == .comment("הערה"))
    }

    @Test func aLineWithoutACommentHasOneIsolatePair() {
        let text = characters(MoveRowView.variationText([.open, .move("8\u{2026}O-O", uuid: 3), .move("9. d4", uuid: 4), .close], current: 0))
        #expect(text == "\u{2066}(8\u{2026}O-O 9. d4)\u{2069}")
        #expect(text.unicodeScalars.filter { $0.value == 0x2066 || $0.value == 0x2068 || $0.value == 0x2069 }.count == 2)
    }

    @Test func eachCommentGetsItsOwnIsolate() {
        let tokens: [MoveToken] = [.open, .move("1\u{2026}c5", uuid: 1), .comment("Sicilian"), .move("2. Nf3", uuid: 2), .comment("سامي"), .close]
        let text = characters(MoveRowView.variationText(tokens, current: 0))
        #expect(text.components(separatedBy: "\u{2068}").count - 1 == 2)
        #expect(text.contains("\u{2068}Sicilian\u{2069}"))
        #expect(text.contains("\u{2068}سامي\u{2069}"))
    }

    @Test func theCurrentMoveStaysALink() {
        let text = MoveRowView.variationText([.open, .move("9. d4", uuid: 4), .close], current: 4)
        let linked = text.runs.filter { $0.link != nil }
        #expect(linked.count == 1)
        #expect(linked.first.map { String(text[$0.range].characters) } == "9. d4")
    }
}
