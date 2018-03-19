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
    
    extension Image {
        
        public convenience init?(named: String) {
            self.init(named: NSImage.Name(named))
        }
        
    }

#else
    import UIKit
    public typealias Image = UIImage
#endif

