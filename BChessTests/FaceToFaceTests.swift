//
//  FaceToFaceTests.swift
//  BChessTests
//
//  The rules of two boards against a friend (APP-15): when the mode is on, which colour each half has at its
//  bottom, which half takes taps, how each half is turned, and which orientations the app allows.
//

import Testing

@Suite struct FaceToFaceTests {

    private func state(flag: Bool, white: GamePlayer, black: GamePlayer, rotated: Bool = false) -> GameState {
        GameState(pgn: "*", rotated: rotated, white: white, black: black, faceToFace: flag)
    }

    @Test(arguments: [
        (true, GamePlayer.human, GamePlayer.human, true),
        (false, GamePlayer.human, GamePlayer.human, false),
        (true, GamePlayer.computer(.club), GamePlayer.human, false),
        (true, GamePlayer.human, GamePlayer.computer(.club), false),
        (true, GamePlayer.computer(.club), GamePlayer.computer(.club), false),
    ])
    func isOnOnlyForAFriendGame(flag: Bool, white: GamePlayer, black: GamePlayer, expected: Bool) {
        #expect(FaceToFace.isOn(state(flag: flag, white: white, black: black)) == expected)
    }

    @Test(arguments: [
        (true, GamePlayer.human, GamePlayer.human, true),
        (false, GamePlayer.human, GamePlayer.human, true),
        (true, GamePlayer.computer(.club), GamePlayer.human, false),
        (false, GamePlayer.human, GamePlayer.computer(.club), false),
        (false, GamePlayer.computer(.club), GamePlayer.computer(.club), false),
    ])
    func canSwitchOnlyWhenBothPlayersAreHuman(flag: Bool, white: GamePlayer, black: GamePlayer, expected: Bool) {
        #expect(FaceToFace.canSwitch(state(flag: flag, white: white, black: black)) == expected)
    }

    @Test(arguments: [(true, true), (true, false), (false, true), (false, false)])
    func showsEngineOnlyOnTheSingleBoard(setting: Bool, friend: Bool) {
        let game = state(flag: friend, white: .human, black: .human)
        #expect(FaceToFace.showsEngine(setting: setting, state: game, hasTwoBoards: true) == (setting && !friend))
    }

    /// The production value: the Mac has one board, iOS two.
    @Test func platformHasTwoBoardsOnlyOnIOS() {
        #if os(macOS)
        #expect(!FaceToFace.platformHasTwoBoards)
        #else
        #expect(FaceToFace.platformHasTwoBoards)
        #endif
    }

    @Test func macKeepsTheEngineInAFriendGame() {
        let game = state(flag: true, white: .human, black: .human)
        #expect(FaceToFace.showsEngine(setting: true, state: game, hasTwoBoards: false))
        #expect(!FaceToFace.showsEngine(setting: false, state: game, hasTwoBoards: false))
    }

    @Test func bottomColourOfEachHalf() {
        #expect(FaceToFace.bottomIsWhite(near: true, rotated: false))
        #expect(!FaceToFace.bottomIsWhite(near: true, rotated: true))
        #expect(!FaceToFace.bottomIsWhite(near: false, rotated: false))
        #expect(FaceToFace.bottomIsWhite(near: false, rotated: true))
    }

    @Test func onlyTheSideToMoveAcceptsMoves() {
        #expect(FaceToFace.acceptsMoves(bottomIsWhite: true, isWhiteToMove: true))
        #expect(!FaceToFace.acceptsMoves(bottomIsWhite: true, isWhiteToMove: false))
        #expect(!FaceToFace.acceptsMoves(bottomIsWhite: false, isWhiteToMove: true))
        #expect(FaceToFace.acceptsMoves(bottomIsWhite: false, isWhiteToMove: false))
    }

    @Test func turnsFaceEachPlayer() {
        #expect(FaceToFace.turn(near: true, wide: false) == 0)
        #expect(FaceToFace.turn(near: false, wide: false) == 180)
        #expect(FaceToFace.turn(near: true, wide: true) == 90)
        #expect(FaceToFace.turn(near: false, wide: true) == -90)
    }

    @Test func iPhoneUnlocksLandscapeOnlyFaceToFace() {
        #expect(FaceToFace.orientations(isPad: false, faceToFace: false) == .portrait)
        #expect(FaceToFace.orientations(isPad: false, faceToFace: true) == .allButUpsideDown)
    }

    @Test func iPadAllowsEveryOrientation() {
        #expect(FaceToFace.orientations(isPad: true, faceToFace: false) == .all)
        #expect(FaceToFace.orientations(isPad: true, faceToFace: true) == .all)
    }
}
