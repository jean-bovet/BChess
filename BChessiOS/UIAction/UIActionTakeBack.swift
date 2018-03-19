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
        
    override init() {
        super.init()        
        title = NSLocalizedString("Take Back", comment: "")
    }
    
    override func execute(viewController: ViewController, completion: @escaping CompletionBlock) {
        viewController.interaction.takeBack()
        completion()
    }
}
