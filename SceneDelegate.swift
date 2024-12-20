//
//  SceneDelegate.swift
//  BitSense
//
//  Created by Peter on 03/02/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    weak var mgr = TorClient.sharedInstance
    var window: UIWindow?
    private var isBooting = true
    private var blacked = UIView()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.blacked.removeFromSuperview()
        guard !isBooting else { isBooting = !isBooting; return }
        
        if !self.isBooting && self.mgr?.state != .started && self.mgr?.state != .connected  {
            self.mgr?.start(delegate: nil)
        } else {
            self.isBooting = false
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        
        
        if mgr?.state != .stopped && mgr?.state != TorClient.TorState.none  {
            if #available(iOS 14.0, *) {
                if !ProcessInfo.processInfo.isiOSAppOnMac {
                    mgr?.state = .refreshing
                    mgr?.resign()
                } else {
                    print("running on mac, not quitting tor.")
                }
            }
        }
        
        if let window = self.window {
            blacked.frame = window.frame
            blacked.backgroundColor = .black
            self.window?.addSubview(blacked)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let urlcontexts = URLContexts.first
        guard let url = urlcontexts?.url else { return }
        
        addNode(url: "\(url)")
    }
    
    private func addNode(url: String) {
        QuickConnect.addNode(url: url) { (success, _) in
            guard success else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
            }
        }
    }
    
}
