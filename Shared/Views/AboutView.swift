//
//  AboutView.swift
//  BChess
//
//  The About screen of both apps: the version, the copyright and license of BChess, and the notices of the
//  third-party material it includes (`ThirdPartyNotices.txt`). A pushed screen of Settings on iPhone, the About
//  window on the Mac. The legal text is English and never translated; it stays left to right in every language.
//

import SwiftUI

struct AboutView: View {
    /// "1.0 (12)": the marketing version and the build, in the digits of the notation (Western, left to right).
    private var version: String {
        let info = Bundle(for: GameSession.self).infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return GameText.notation(build.isEmpty ? short : "\(short) (\(build))")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "BChess")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Walnut.textPrimary)
                Text("Version \(version)")
                    .font(.callout)
                    .foregroundStyle(Walnut.textSecondary)
                Text(verbatim: "Copyright © 2017–2026 Jean Bovet")
                    .font(.callout)
                    .foregroundStyle(Walnut.textSecondary)
                Text(verbatim: "https://github.com/jean-bovet/BChess")
                    .font(.callout)
                    .foregroundStyle(Walnut.textSecondary)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Text("Free and open source under the MIT License.")
                .font(.callout)
                .foregroundStyle(Walnut.textPrimary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Acknowledgments and licenses")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Walnut.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                Text("The licenses below are in English.")
                    .font(.caption)
                    .foregroundStyle(Walnut.textSecondary)
            }
            Text(verbatim: ThirdPartyNotices.text)
                .font(.caption)
                .foregroundStyle(Walnut.textPrimary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityIdentifier("about-notices")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        #if os(iOS)
        ScrollView {
            content
        }
        .background(Walnut.background.ignoresSafeArea())
        .navigationTitle("About BChess")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Walnut.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About BChess")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Walnut.textPrimary)
            }
        }
        #else
        ScrollView {
            content
        }
        .frame(width: 460, height: 560)
        .background(Walnut.background)
        #endif
    }
}
