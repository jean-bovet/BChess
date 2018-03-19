//
//  UIActionPasteGame.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/18/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIActionPasteGame: UIAction {
    
    override init() {
        super.init()
        title = NSLocalizedString("Paste Game", comment: "")
    }
    
    override func execute(viewController: ViewController, completion: @escaping CompletionBlock) {
        if UIPasteboard.general.hasStrings, let pgn = UIPasteboard.general.string {
            viewController.interaction.setPGN(pgn: pgn)
        }
        completion()
    }
}
