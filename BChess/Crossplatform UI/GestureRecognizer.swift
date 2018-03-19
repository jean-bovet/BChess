//
//  GestureRecognizer.swift
//  BChess
//
//  Created by Jean Bovet on 3/17/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit
    public typealias TapGestureRecognizer = NSClickGestureRecognizer
#else
    import UIKit
    public typealias TapGestureRecognizer = UIGestureRecognizer
#endif

