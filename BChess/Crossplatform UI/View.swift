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
    public typealias AnimateCallback = (View) -> Void

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
        
        var backgroundColor: NSColor? {
            get {
                if let color = layer?.backgroundColor {
                    return NSColor(cgColor: color)
                } else {
                    return nil
                }
            }
            set {
                wantsLayer = true
                layer?.backgroundColor = newValue?.cgColor
            }
        }
        
        func setNeedsDisplay() {
            setNeedsDisplay(bounds)
        }
        
        func animate(animated: Bool, callback: @escaping AnimateCallback) {
            if animated {
                callback(animator())
            } else {
                callback(self)
            }
        }

    }
#else
    import UIKit.UIView
    public typealias View = UIView
    public typealias AnimateCallback = (View) -> Void

    var context: CGContext? {
        return UIGraphicsGetCurrentContext()
    }
    
    extension View {

        func animate(animated: Bool, callback: @escaping AnimateCallback) {
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    callback(self)
                })
            } else {
                callback(self)
            }
        }
        
    }
    
#endif

