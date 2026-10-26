//
//  FoldSplitTests.swift
//  BChessTests
//
//  How a layout steps over the fold of a folding display, on the Mac, with no view.
//

import CoreGraphics
import Testing

struct FoldSplitTests {

    @Test("no fold leaves the layout alone")
    func noFoldLeavesTheLayoutAlone() {
        let split = FoldLayout.split(length: 919, fold: nil)
        #expect(split == FoldSplit(usable: 0...919, primary: nil, gap: 0))
    }

    @Test("a centred fold splits the length around it")
    func centredFoldSplitsAroundIt() {
        let split = FoldLayout.split(length: 919, fold: 439.5...479.5)
        #expect(split == FoldSplit(usable: 0...919, primary: 427.5, gap: 64))
        let rest = 919 - (split.primary ?? 0) - split.gap
        #expect(rest == 427.5)
    }

    @Test("a fold off centre, as the side bars make it, is only another range")
    func offCentreFoldFromTheSideBars() {
        let split = FoldLayout.split(length: 857, fold: 377.5...417.5)
        #expect(split == FoldSplit(usable: 0...857, primary: 365.5, gap: 64))
    }

    @Test("a fold near an edge moves the layout onto the larger side", arguments: [
        (CGFloat(919), CGFloat(10)...CGFloat(50), CGFloat(62)...CGFloat(919)),
        (CGFloat(919), CGFloat(880)...CGFloat(919), CGFloat(0)...CGFloat(868)),
        (CGFloat(300), CGFloat(140)...CGFloat(180), CGFloat(0)...CGFloat(128)),
        (CGFloat(300), CGFloat(120)...CGFloat(160), CGFloat(172)...CGFloat(300)),
        (CGFloat(300), CGFloat(144)...CGFloat(156), CGFloat(0)...CGFloat(132)),
    ])
    func edgeFoldMovesTheLayoutOntoTheLargerSide(length: CGFloat, fold: ClosedRange<CGFloat>, usable: ClosedRange<CGFloat>) {
        let split = FoldLayout.split(length: length, fold: fold)
        #expect(split == FoldSplit(usable: usable, primary: nil, gap: 0))
        #expect(!split.usable.overlaps(fold))
    }

    @Test("a tie between two small sides goes to the leading one")
    func tieGoesLeading() {
        // 300 long, fold 144...156: both sides are 132 after the gutter
        let split = FoldLayout.split(length: 300, fold: 144...156)
        #expect(split.usable == 0...132)
    }

    @Test("a fold outside or covering the length", arguments: [
        (CGFloat(919), CGFloat(1000)...CGFloat(1040), CGFloat(0)...CGFloat(919)),
        (CGFloat(300), CGFloat(-10)...CGFloat(310), CGFloat(0)...CGFloat(300)),
        (CGFloat(300), CGFloat(280)...CGFloat(400), CGFloat(0)...CGFloat(268)),
        (CGFloat(300), CGFloat(-20)...CGFloat(30), CGFloat(42)...CGFloat(300)),
    ])
    func foldOutsideOrCoveringTheLength(length: CGFloat, fold: ClosedRange<CGFloat>, usable: ClosedRange<CGFloat>) {
        let split = FoldLayout.split(length: length, fold: fold)
        #expect(split == FoldSplit(usable: usable, primary: nil, gap: 0))
        #expect(split.usable.lowerBound >= 0 && split.usable.upperBound <= length)
    }

    private let vertical = FoldRegion(frame: CGRect(x: 439.5, y: 0, width: 40, height: 637), isActive: true)
    private let verticalFlat = FoldRegion(frame: CGRect(x: 439.5, y: 0, width: 40, height: 637), isActive: false)
    private let horizontal = FoldRegion(frame: CGRect(x: 0, y: 439.5, width: 637, height: 40), isActive: true)
    private let horizontalFlat = FoldRegion(frame: CGRect(x: 0, y: 439.5, width: 637, height: 40), isActive: false)

    @Test("the wide layout takes a vertical region, active or not, and ignores a horizontal one")
    func wideTakesVerticalRegions() {
        #expect(FoldLayout.fold(in: [vertical], wide: true) == 439.5...479.5)
        #expect(FoldLayout.fold(in: [verticalFlat], wide: true) == 439.5...479.5)
        #expect(FoldLayout.fold(in: [horizontal], wide: true) == nil)
        #expect(FoldLayout.fold(in: [], wide: true) == nil)
    }

    @Test("the tall layout takes only an active horizontal region")
    func tallTakesActiveHorizontalRegions() {
        #expect(FoldLayout.fold(in: [horizontal], wide: false) == 439.5...479.5)
        #expect(FoldLayout.fold(in: [horizontalFlat], wide: false) == nil)
        #expect(FoldLayout.fold(in: [vertical], wide: false) == nil)
        #expect(FoldLayout.fold(in: [], wide: false) == nil)
    }

    @Test("two regions: the first matching one wins")
    func firstMatchingRegionWins() {
        let other = FoldRegion(frame: CGRect(x: 100, y: 0, width: 10, height: 600), isActive: true)
        #expect(FoldLayout.fold(in: [horizontal, vertical, other], wide: true) == 439.5...479.5)
    }

    @Test("the usable area is the whole size unless a fold leaves a side too small")
    func usableAreaOfTheSize() {
        #expect(FoldLayout.usableArea(size: CGSize(width: 300, height: 240), regions: [])
                == CGRect(x: 0, y: 0, width: 300, height: 240))
        let narrow = FoldRegion(frame: CGRect(x: 140, y: 0, width: 40, height: 240), isActive: true)
        let area = FoldLayout.usableArea(size: CGSize(width: 300, height: 240), regions: [narrow])
        #expect(area == CGRect(x: 0, y: 0, width: 128, height: 240))
        #expect(area.width < area.height)

        #expect(FoldLayout.usableArea(size: CGSize(width: 951, height: 669), regions: [vertical])
                == CGRect(x: 0, y: 0, width: 951, height: 669))
        #expect(FoldLayout.usableArea(size: CGSize(width: 669, height: 951), regions: [horizontalFlat])
                == CGRect(x: 0, y: 0, width: 669, height: 951))
        let edge = FoldRegion(frame: CGRect(x: 0, y: 10, width: 669, height: 40), isActive: true)
        #expect(FoldLayout.usableArea(size: CGSize(width: 669, height: 951), regions: [edge])
                == CGRect(x: 0, y: 62, width: 669, height: 889))
    }
}
