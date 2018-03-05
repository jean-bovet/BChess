//
//  UIAction.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

typealias CompletionBlock = () -> ()

class UIAction {
    
    var title: String?
    var color: UIColor?
    var image: UIImage?
    var accessibilityIdentifier: String?
    var destructive: Bool = false
        
    func execute(completion: @escaping CompletionBlock) {
        
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
