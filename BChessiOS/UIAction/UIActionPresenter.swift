//
//  ViewControllerActions.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class UIActionPresenter {
    
    func present(parentViewController: UIViewController, actions: [UIAction], completion: @escaping CompletionBlock) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for action in actions {
            let style = action.destructive ? UIAlertActionStyle.destructive : UIAlertActionStyle.default
            let alertAction = UIAlertAction(title: action.title, style: style, handler: { (alertAction) in
                action.execute() {
                    completion()
                }
            })
            if let image = action.image {
                alertAction.setValue(image, forKey: "image")
            }
            controller.addAction(alertAction)
        }
        
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
            completion()
        }))
        
        parentViewController.present(controller, animated: true, completion: nil)
    }
}
