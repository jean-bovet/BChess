//
//  UIActionCopyGame.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/18/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIActionCopyGame: UIAction {
    
    override init() {
        super.init()
        title = NSLocalizedString("Copy Game", comment: "")
    }
    
    override func execute(viewController: ViewController, completion: @escaping CompletionBlock) {
        UIPasteboard.general.string = viewController.interaction.engine.pgn()
        completion()
    }
}
