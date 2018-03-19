//
//  UIActionNewGame.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIActionNewGame: UIAction {
    
    override init() {
        super.init()        
        title = NSLocalizedString("New Game", comment: "")
    }
    
    override func execute(viewController: ViewController, completion: @escaping CompletionBlock) {
        viewController.interaction.newGame()
        completion()
    }
}
