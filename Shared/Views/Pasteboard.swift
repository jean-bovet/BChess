//
//  Pasteboard.swift
//  BChess
//
//  The system pasteboard, for the copy and paste actions.
//

import SwiftUI

enum Pasteboard {

    @MainActor
    static var string: String? {
        #if os(macOS)
        NSPasteboard.general.string(forType: .string)
        #else
        UIPasteboard.general.string
        #endif
    }

    @MainActor
    static func set(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        pb.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
