//
//  FaceToFace.swift
//  BChess
//
//  Two boards against a friend (APP-15): the rules that tell the game screen which half is which. No state.
//

import Foundation
#if os(iOS)
import UIKit
#endif

nonisolated enum FaceToFace {
    /// A game set up as "A friend" (the saved flag, both players still human): the iOS game screen shows two boards.
    static func isOn(_ state: GameState) -> Bool {
        state.faceToFace && canSwitch(state)
    }

    /// The two-boards choice is offered whenever both players are human, whatever the flag: an opened or pasted game
    /// can opt in, and a friend game can go back to the single board.
    static func canSwitch(_ state: GameState) -> Bool {
        !state.white.computer && !state.black.computer
    }

    /// The engine readout and its analysis run only on the single board. `hasTwoBoards` is the platform: true on
    /// iOS (the call site passes `FaceToFace.platformHasTwoBoards`); the Mac always has the single board and its
    /// engine controls, so there it is `setting` whatever the flag.
    static func showsEngine(setting: Bool, state: GameState, hasTwoBoards: Bool) -> Bool {
        setting && !(hasTwoBoards && isOn(state))
    }

    static var platformHasTwoBoards: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    /// The colour at the bottom of a half: the near half is the first player's (today's board).
    static func bottomIsWhite(near: Bool, rotated: Bool) -> Bool {
        near ? !rotated : rotated
    }

    /// The board takes taps only for the side to move.
    static func acceptsMoves(bottomIsWhite: Bool, isWhiteToMove: Bool) -> Bool {
        bottomIsWhite == isWhiteToMove
    }

    /// The turn of a half, in degrees clockwise: tall 0 (near) / 180 (far); wide 90 (near, left half, its bottom
    /// toward the left edge) / -90 (far, right half).
    static func turn(near: Bool, wide: Bool) -> Double {
        switch (near, wide) {
        case (true, false): 0
        case (false, false): 180
        case (true, true): 90
        case (false, true): -90
        }
    }

    /// The orientations a screen allows: iPad every one, iPhone portrait plus landscape while a friend game is open.
    enum Orientations: Equatable { case portrait, allButUpsideDown, all }

    static func orientations(isPad: Bool, faceToFace: Bool) -> Orientations {
        if isPad {
            return .all
        }
        return faceToFace ? .allButUpsideDown : .portrait
    }
}

#if os(iOS)
/// The mask the app delegate answers; the game screen updates it from the open game.
@MainActor enum OrientationLock {
    /// An iPad starts with every orientation, an iPhone in portrait until a friend game opens.
    static private(set) var mask: UIInterfaceOrientationMask =
        FaceToFace.orientations(isPad: UIDevice.current.userInterfaceIdiom == .pad, faceToFace: false).mask

    /// Sets the mask from the game and, when it changed, tells UIKit.
    static func update(for state: GameState, isPad: Bool) {
        let new = FaceToFace.orientations(isPad: isPad, faceToFace: FaceToFace.isOn(state)).mask
        guard new != mask else {
            return
        }
        mask = new
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            // A sideways phone whose mask no longer allows it goes back to portrait
            if !new.contains(scene.effectiveGeometry.interfaceOrientation.mask) {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }
}

private extension FaceToFace.Orientations {
    var mask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: .portrait
        case .allButUpsideDown: .allButUpsideDown
        case .all: .all
        }
    }
}

private extension UIInterfaceOrientation {
    var mask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: .portrait
        }
    }
}
#endif
