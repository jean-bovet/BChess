import SwiftUI
import UIKit
import Foundation
import Testing
@testable import BChess

/// Renders every `PreviewScenarios.all` entry in light and dark into
/// `$BCHESS_SNAPSHOT_DIR/<light|dark>/<file stem>/<name>.png`, the tree `scripts/preview-gallery.py`
/// imports. Skipped when the variable is absent, so a normal test run writes nothing. Run it with
/// `scripts/snapshot-gallery.sh`.
@MainActor
@Suite struct SnapshotGalleryTests {
    private static let phone = CGSize(width: 402, height: 874)

    private static let snapshotDirectory = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"].flatMap { $0.isEmpty ? nil : $0 }

    @Test("render every scenario in light and dark",
          .enabled(if: ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"]?.isEmpty == false,
                   "set BCHESS_SNAPSHOT_DIR (TEST_RUNNER_BCHESS_SNAPSHOT_DIR on the xcodebuild command line) to render the gallery"))
    func renderEveryScenarioInLightAndDark() async throws {
        let root = URL(fileURLWithPath: try #require(Self.snapshotDirectory))

        for scenario in PreviewScenarios.all where scenario.gallery {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let png = try await render(scenario, style: style)
                let directory = root
                    .appendingPathComponent(style == .dark ? "dark" : "light", isDirectory: true)
                    .appendingPathComponent((scenario.file as NSString).deletingPathExtension, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try png.write(to: directory.appendingPathComponent("\(scenario.name).png"))
            }
        }
    }

    private func render(_ scenario: PreviewScenario, style: UIUserInterfaceStyle) async throws -> Data {
        let size = scenario.size ?? Self.phone
        let host = UIHostingController(rootView: scenario.view())
        host.overrideUserInterfaceStyle = style
        host.view.backgroundColor = .systemBackground
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "needs the app's window scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        defer { window.isHidden = true }
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // Let onAppear / task / List layout settle.
        try await Task.sleep(for: .milliseconds(400))
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        var drawn = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            drawn = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        try #require(drawn, "\(scenario.file) / \(scenario.name) did not draw")
        return try #require(image.pngData())
    }
}
