//
//  Image.swift
//  BChess
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit.NSImage
    public typealias Image = NSImage    
#else
    import UIKit
    public typealias Image = UIImage
#endif

