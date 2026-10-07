//
//  Arrow.swift
//  BChess
//
//  Created by Jean Bovet on 5/17/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct Arrow {
        
    var path = Path()

    init(start a: CGPoint, end b: CGPoint, length: CGFloat) {
        let arrowLength = sqrt(pow(b.x-a.x, 2)+pow(b.y-a.y, 2))
        
        let x = -(b.x - a.x)/arrowLength * length
        let y = -(b.y - a.y)/arrowLength * length

        let alpha = CGFloat(deg2rad(25))
        
        let c1x = b.x + (x*cos(alpha)-y*sin(alpha))
        let c1y = b.y + (x*sin(alpha)+y*cos(alpha))

        let c2x = b.x + (x*cos(-alpha)-y*sin(-alpha))
        let c2y = b.y + (x*sin(-alpha)+y*cos(-alpha))

        path.move(to: b)
        path.addLine(to: CGPoint(x: c1x, y: c1y))
        path.addLine(to: CGPoint(x: c2x, y: c2y))
        path.addLine(to: b)
        path.closeSubpath()
        path.move(to: a)
        path.addLine(to: b)
    }
    
    private func deg2rad(_ number: Double) -> Double {
        return number * .pi / 180
    }

}

#if DEBUG
#Preview("Arrow") {
    PreviewScenarios.arrow.view()
}
#endif
