//
//  UIAction.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIAction {

    typealias ActionExecuteBlock = (UIAction, CompletionBlock) -> Void
    typealias ActionEnabledBlock = () -> Bool

    var title: String?
    var color: UIColor?
    var image: UIImage?
    var accessibilityIdentifier: String?
    var destructive = false
    var enabled: Bool {
        if let block = enabledBlock {
            return block()
        } else {
            return true
        }
    }
    var executeBlock: ActionExecuteBlock?
    var enabledBlock: ActionEnabledBlock?

    convenience init(title: String, executeBlock: @escaping ActionExecuteBlock) {
        self.init()
        self.title = title
        self.executeBlock = executeBlock
    }

    convenience init(title: String, executeBlock: @escaping ActionExecuteBlock, enabledBlock: @escaping ActionEnabledBlock) {
        self.init()
        self.title = title
        self.executeBlock = executeBlock
        self.enabledBlock = enabledBlock
    }

    func execute(completion: @escaping CompletionBlock) {
        guard let block = executeBlock else {
            return
        }
        block(self, completion)
    }
    
    static func confirmDestructiveAction(viewController: UIViewController, message: String, completion: @escaping (_ doIt: Bool) -> ()) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { action in
            completion(false)
        }
        alertController.addAction(cancelAction)
        
        let destroyAction = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { action in
            completion(true)
        }
        alertController.addAction(destroyAction)
        
        viewController.present(alertController, animated: true)
    }
    
}
