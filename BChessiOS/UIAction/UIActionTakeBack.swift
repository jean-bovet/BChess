//
//  UIActionTakeBack.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/17/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIActionTakeBack: UIAction {
    
    let viewController: ViewController
    
    init(viewController: ViewController) {
        self.viewController = viewController
        
        super.init()
        
        title = NSLocalizedString("Take Back", comment: "")
        accessibilityIdentifier = "take-back"
        color = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        //        image = UIImage(named: "action-deposit")
    }
    
    override func execute(completion: @escaping CompletionBlock) {
        viewController.interaction.takeBack()
        completion()
    }
}
