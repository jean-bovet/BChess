//
//  Color.swift
//  BChess
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit.NSColor
    public typealias Color = NSColor
#else
    import UIKit.UIColor
    public typealias Color = UIColor
#endif

