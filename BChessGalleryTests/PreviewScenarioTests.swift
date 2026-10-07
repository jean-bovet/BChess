import Foundation
import Testing
@testable import BChess

/// The scenario list feeds both the #Previews and the gallery renderer (`SnapshotGalleryTests`).
@MainActor
@Suite struct PreviewScenarioTests {

    @Test("every scenario has a unique file and name")
    func everyScenarioHasAUniqueFileAndName() {
        var seen = Set<String>()
        for scenario in PreviewScenarios.all {
            #expect(!scenario.name.isEmpty)
            #expect(!scenario.name.contains("/"), "\(scenario.name)")
            #expect(scenario.file.hasSuffix(".swift"), "\(scenario.file)")
            #expect(seen.insert("\(scenario.file)/\(scenario.name)").inserted, "duplicate \(scenario.file) / \(scenario.name)")
        }
        #expect(!PreviewScenarios.all.isEmpty)
    }

    @Test("the Tall and Wide fixture has a human to move, so the app starts no search")
    func contentFixtureHasAHumanToMove() {
        let session = PreviewScenarios.humanToMoveSession()
        #expect(session.mode.value == .play)
        #expect(session.isWhiteToMove)
        #expect(!session.gameState.white.computer)
    }

    @Test("the scheme passes -uiTestingFreshLibrary to the test host")
    func schemePassesTheFreshLibraryArgument() {
        #expect(ProcessInfo.processInfo.arguments.contains("-uiTestingFreshLibrary"))
    }
}
