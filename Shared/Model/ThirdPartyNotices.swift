//
//  ThirdPartyNotices.swift
//  BChess
//
//  The licenses and credits of what BChess includes, as the About screen shows them.
//

import Foundation

enum ThirdPartyNotices {
    /// The text of `ThirdPartyNotices.txt`; empty when the bundle lacks the file.
    static let text: String = {
        let bundle = Bundle(for: GameSession.self)
        guard let url = bundle.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()
}
