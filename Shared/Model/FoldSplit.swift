//
//  FoldSplit.swift
//  Shared
//
//  Where a layout steps over the fold of a folding display (the iPhone Duo's hinge): pure geometry, no views.
//

import CoreGraphics

/// A reserved region of the display, as the layout sees it: the frame in the layout's own coordinates (margins
/// included, as the OS reports it) and whether it is active (partially folded) or a flat seam (fully open).
struct FoldRegion: Equatable, Sendable {
    var frame: CGRect
    var isActive: Bool
}

/// How a layout steps over a fold along one axis.
struct FoldSplit: Equatable {
    /// The part of the length the content may use. The whole length unless the fold leaves one side under
    /// `minimum`: then the larger side alone, and the fold lies outside it (never under content).
    var usable: ClosedRange<CGFloat>
    /// With the fold inside `usable`: the extent of the first part (the board column, or the board rows), from
    /// `usable.lowerBound`, ending `gutter` before the fold; nil when there is no fold inside (today's layout runs).
    var primary: CGFloat?
    /// The distance from the end of the first part to the start of the second: the fold plus a gutter each side.
    var gap: CGFloat
}

enum FoldLayout {
    /// The fold the layout reacts to, from the regions in its coordinates: `wide` takes any region taller than wide
    /// (a vertical seam), active or not, since a flat-open Duo still has its crease; tall takes only an active region
    /// wider than tall (the tabletop pose). The range runs along the axis across the fold (x for columns, y for
    /// rows). One hinge per device: the first matching region wins.
    static func fold(in regions: [FoldRegion], wide: Bool) -> ClosedRange<CGFloat>? {
        for region in regions {
            let frame = region.frame
            if wide {
                if frame.height > frame.width { return frame.minX...frame.maxX }
            } else if region.isActive, frame.width > frame.height {
                return frame.minY...frame.maxY
            }
        }
        return nil
    }

    /// The split of `length` across `fold` (nil: the whole length, no primary). A fold that leaves a side under
    /// `minimum` (measured after the gutter) moves the content onto the larger side. When the fold covers the
    /// length, or leaves no more than the gutter on either side, nothing can step aside: the layout runs as without
    /// a fold, no worse than before the fold was known.
    static func split(length: CGFloat, fold: ClosedRange<CGFloat>?, gutter: CGFloat = 12, minimum: CGFloat = 200) -> FoldSplit {
        let whole = 0...max(0, length)
        guard let fold, fold.upperBound >= 0, fold.lowerBound <= length else {
            return FoldSplit(usable: whole, primary: nil, gap: 0)
        }
        let start = max(0, fold.lowerBound)
        let end = min(length, fold.upperBound)
        let leading = max(0, start - gutter)
        let trailing = max(0, length - end - gutter)
        if leading >= minimum, trailing >= minimum {
            return FoldSplit(usable: whole, primary: leading, gap: fold.upperBound - fold.lowerBound + 2 * gutter)
        }
        if max(leading, trailing) == 0 {
            return FoldSplit(usable: whole, primary: nil, gap: 0)
        }
        if leading >= trailing {
            return FoldSplit(usable: 0...leading, primary: nil, gap: 0)
        }
        return FoldSplit(usable: (length - trailing)...length, primary: nil, gap: 0)
    }

    /// The rectangle of `size` the content may use, before the layout is chosen: the x range is `split`'s `usable`
    /// across any vertical region, the y range across an active horizontal one (the same rules as `fold(in:wide:)`,
    /// both axes at once). The whole size without a region. Tall or wide is decided on this rectangle.
    static func usableArea(size: CGSize, regions: [FoldRegion], gutter: CGFloat = 12, minimum: CGFloat = 200) -> CGRect {
        let x = split(length: size.width, fold: fold(in: regions, wide: true), gutter: gutter, minimum: minimum).usable
        let y = split(length: size.height, fold: fold(in: regions, wide: false), gutter: gutter, minimum: minimum).usable
        return CGRect(x: x.lowerBound, y: y.lowerBound, width: x.upperBound - x.lowerBound, height: y.upperBound - y.lowerBound)
    }
}
