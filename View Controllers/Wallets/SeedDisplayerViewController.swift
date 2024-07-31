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
    @IBOutlet weak var textView: UITextView!
    
    var jmWallet: JMWallet!
    var words: String!
    var password: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.textColor = .systemGreen
        savedOutlet.layer.cornerRadius = 8
        load()
    }
    
    
    @IBAction func savedAction(_ sender: Any) {
        textView.text = ""
        navigationController?.popToRootViewController(animated: true)
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = ""
            showAlert(vc: self, title: "Error", message: error)
        }
    }
    
    private func load() {
        let message = """
        Wallet created ✓
        
        It is extremely important to save the following information offline! Please write these seed words and password down somewhere safe!
        
        Fully Noded does not remember your seed words or password! You can always recover the wallet with the seed words, in order to use the wallet you will need the password.
        
        \(words!)
        
        Encryption password:
        
        \(password!)
        """
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            textView.text = message
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
