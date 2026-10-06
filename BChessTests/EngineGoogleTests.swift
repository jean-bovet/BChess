//
//  EngineGoogleTests.swift
//  BChessTests
//
//  Runs every C++ GoogleTest case of the engine as its own Swift Testing case.
//

import Foundation
import Testing

// GoogleTest's UnitTest singleton, flags and listeners are not thread-safe, so the cases run one
// after the other and no other suite touches GoogleTest.
@Suite(.serialized)
struct EngineGoogleTests {

    @Test(arguments: GTestRunner.testNames())
    func gtest(_ name: String) {
        for failure in GTestRunner.run(name) {
            let file = (failure.file as NSString).lastPathComponent
            Issue.record(Comment(rawValue: failure.message),
                         sourceLocation: SourceLocation(fileID: "BChessTests/\(file)",
                                                        filePath: failure.file,
                                                        line: max(1, failure.line),
                                                        column: 1))
        }
    }

    /// The floor that turns "zero GoogleTest cases ran" into a failure.
    @Test func registersAllCases() {
        #expect(GTestRunner.testNames().count >= 147)
    }
}
