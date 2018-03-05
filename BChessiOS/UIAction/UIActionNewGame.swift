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
    
    let viewController: ViewController
    
    init(viewController: ViewController) {
        self.viewController = viewController

        super.init()
        
        title = NSLocalizedString("New Game", comment: "")
        accessibilityIdentifier = "new-game"
        color = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
//        image = UIImage(named: "action-deposit")
    }
    
    override func execute(completion: @escaping CompletionBlock) {
        viewController.newGame()
        completion()
    }
}
