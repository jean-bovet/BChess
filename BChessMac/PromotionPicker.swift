//
//  PromotionPicker.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/28/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class PromotionPicker {
    
    let pieces : [String]
        
    init(isWhite: Bool) {
        pieces = isWhite ? [ "Q", "R", "B", "N" ] : [ "q", "r", "b", "n" ]
    }

    func choosePromotionPiece(callback: @escaping (_ piece: String?) -> Void) {
        let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let monitorcontroler = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "PromotionSheet")) as! NSWindowController
        let pickerView = monitorcontroler.contentViewController!.view.viewWithTag(1) as! PromotionPickerView
        pickerView.pieces = pieces
        NSApp.mainWindow!.beginSheet(monitorcontroler.window!, completionHandler: { (response) in
            callback(self.pieces[response.rawValue])
        })
    }

}
