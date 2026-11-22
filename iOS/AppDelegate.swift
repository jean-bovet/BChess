//
//  AppDelegate.swift
//  BChess
//
//  Answers which orientations the app allows right now: the open game decides (`OrientationLock`), since an iPhone
//  turns sideways only in a friend game (APP-15).
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
