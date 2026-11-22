//
//  FrameProbe.swift
//  BChess
//
//  Lets a view name its layout frame, so the gallery's oracle tests measure what a view lays out to (its boundary,
//  not the pixels it paints). The gallery hosts Debug builds: in Release `probeFrame` does nothing and the key is
//  not compiled in.
//

import SwiftUI

#if DEBUG
/// The named frames of the views below, as anchors the reader resolves in its own space.
struct FrameProbeKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}
#endif

extension View {
    /// Names this view's frame for `FrameProbeKey` (Debug builds only).
    @ViewBuilder
    func probeFrame(_ name: String) -> some View {
        #if DEBUG
        // Added to what the views below named (anchorPreference would replace it)
        transformAnchorPreference(key: FrameProbeKey.self, value: .bounds) { frames, anchor in
            frames[name] = anchor
        }
        #else
        self
        #endif
    }
}
