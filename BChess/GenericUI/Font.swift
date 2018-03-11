//
//  Font.swift
//  BChess
//
//  Created by Jean Bovet on 3/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit.NSFont
    public typealias Font = NSFont
#else
    import UIKit.UIFont
    public typealias Font = UIFont
#endif

