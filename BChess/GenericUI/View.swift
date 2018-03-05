//
//  View.swift
//  BChess
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit.NSView
    public typealias View = NSView
    
    extension View {
        
        var alpha: CGFloat {
            get {
                return alphaValue
            }
            set {
                alphaValue = newValue
            }
        }
        
        var context: CGContext? {
            return NSGraphicsContext.current?.cgContext
        }
        
        func setNeedsDisplay() {
            setNeedsDisplay(bounds)
        }
    }
#else
    import UIKit.UIView
    public typealias View = UIView
    
    var context: CGContext? {
        return UIGraphicsGetCurrentContext()
    }

    
#endif

