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
    
    class UIActionButton: UIButton {
        var action: UIAction?
    }
    
    let MaxActionsForRow = 3
    
    let actions: [UIAction]
    let viewController: ViewController

    var buttons = [UIActionButton]()

    init(actions: [UIAction], viewController: ViewController) {
        self.actions = actions
        self.viewController = viewController
        self.buttons = actionButtons()
    }
    
    func present(completion: @escaping CompletionBlock) {
        present(actions: actions, completion: completion)
    }
    
    func present(actions: [UIAction], completion: @escaping CompletionBlock) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for action in actions {
            let style = action.destructive ? UIAlertAction.Style.destructive : UIAlertAction.Style.default
            let alertAction = UIAlertAction(title: action.title, style: style, handler: { (alertAction) in
                action.execute() {
                    completion()
                }
            })
            if let enabledBlock = action.enabledBlock {
                alertAction.isEnabled = enabledBlock()
            } else {
                alertAction.isEnabled = true
            }
            if let image = action.image {
                alertAction.setValue(image, forKey: "image")
            }
            alertAction.setValue(action.selected, forKey: "checked")
            controller.addAction(alertAction)
        }
        
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
            completion()
        }))
        
        viewController.present(controller, animated: true, completion: nil)
    }
    
    private func actionButtons() -> [UIActionButton] {
        let maxActionsInRow = min(MaxActionsForRow - 1, actions.count - 1)
        
        var buttons = [UIActionButton]()
        if maxActionsInRow > 0 {
            for (index, action) in actions[0...maxActionsInRow].enumerated() {
                let button = UIActionButton(type: .roundedRect)
                button.action = action
                if let image = action.image {
                    button.setImage(image, for: .normal)
                } else {
                    button.setTitle(action.title, for: .normal)
                }
                button.addTarget(self, action: #selector(actionButtonDidTrigger(button:)), for: .touchDown)
                button.tag = index
                button.sizeToFit()
                buttons.append(button)
            }
        }
        
        if actions.count > MaxActionsForRow {
            let button = UIActionButton(type: .roundedRect)
            button.setImage(UIImage(named: "more"), for: .normal)
            button.addTarget(self, action: #selector(moreButtonDidTrigger(button:)), for: .touchDown)
            button.tag = Int.max
            buttons.append(button)
        }
        
        return buttons
    }

    func update() {
        buttons.forEach({ actionButton in
            if let action = actionButton.action {
                actionButton.isEnabled = action.enabled
            }
        })
    }
    
    @objc func actionButtonDidTrigger(button: UIButton) {
        let action = actions[button.tag]
        action.execute() {
            self.update()
        }
    }
    
    @objc func moreButtonDidTrigger(button: UIButton) {
        let moreActions = actions[self.MaxActionsForRow..<actions.count]
        present(actions: Array(moreActions)) {
            
        }
    }

}
