//
//  ImageView.swift
//  BChess
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit.NSImageView
    public typealias ImageView = NSImageView
#else
    import UIKit.UIImageView
    public typealias ImageView = UIImageView
#endif

