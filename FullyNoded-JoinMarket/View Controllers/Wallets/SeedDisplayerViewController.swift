//
//  SeedDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SeedDisplayerViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var savedOutlet: UIButton!
    @IBOutlet var seedWordsLabel: UILabel!
    @IBOutlet var passwordLabel: UILabel!
    
    var jmWallet: JMWallet!
    var words: String!
    var password: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        savedOutlet.layer.cornerRadius = 8
        load()
    }
    
    
    @IBAction func savedAction(_ sender: Any) {
        seedWordsLabel.text = ""
        passwordLabel.text = ""
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(name: .refreshWallet, object: nil)
            navigationController?.popToRootViewController(animated: true)
            tabBarController?.selectedIndex = 0
        }
    }
    
    
    private func load() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            seedWordsLabel.text = words.formatted
            passwordLabel.text = password
            seedWordsLabel.translatesAutoresizingMaskIntoConstraints = false
            seedWordsLabel.sizeToFit()
            passwordLabel.translatesAutoresizingMaskIntoConstraints = false
            passwordLabel.sizeToFit()
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
