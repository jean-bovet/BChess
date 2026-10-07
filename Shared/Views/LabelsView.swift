//
//  LabelsView.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The ranks and files, small and in the frame around the board. Lay it over a `BoardFrame`'s square:
/// it expects the frame to be `Walnut.frameFraction` of that square on every side.
struct LabelsView: View {
    let session: GameSession
    @AppStorage(AppSettings.showCoordinatesKey) private var showCoordinates = AppSettings.showCoordinatesDefault

    func actualIndex(_ index: Int) -> Int {
        if session.gameState.rotated {
            return 7 - index
        } else {
            return index
        }
    }
    
    var body: some View {
        if showCoordinates {
            labels
        }
    }

    private var labels: some View {
        GeometryReader { geometry in
            let side: CGFloat = min(geometry.size.width, geometry.size.height)
            let xOffset: CGFloat = (geometry.size.width - side) / 2
            let yOffset: CGFloat = (geometry.size.height - side) / 2
            let thickness: CGFloat = side * Walnut.frameFraction
            let squareSize: CGFloat = (side - 2 * thickness) / CGFloat(numberOfSquares)
            let font = Font.system(size: max(7, thickness * 0.7), weight: .semibold)

            ForEach(0...7, id:\.self) { index in
                let ai = actualIndex(index)
                Text("\(8 - ai)")
                    .font(font)
                    .frame(width: thickness, height: squareSize)
                    .offset(x: xOffset, y: yOffset + thickness + CGFloat(index) * squareSize)
            }
            
            ForEach(Array(["a", "b", "c", "d", "e", "f", "g", "h"].enumerated()), id:\.offset) { index, value in
                Text("\(value)")
                    .font(font)
                    .frame(width: squareSize, height: thickness)
                    .offset(x: xOffset + thickness + CGFloat(actualIndex(index)) * squareSize,
                            y: yOffset + side - thickness)
            }
        }
        .foregroundStyle(Walnut.coordinates)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("White at the bottom") {
    PreviewScenarios.labelsWhiteAtTheBottom.view()
}

#Preview("Rotated") {
    PreviewScenarios.labelsRotated.view()
}
#endif
