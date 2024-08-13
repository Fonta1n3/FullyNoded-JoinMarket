//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    let spinner = ConnectingView()
    var selectedNode:[String:Any]?
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    let imagePicker = UIImagePickerController()
    var scanNow = false
    var jmWallet: JMWallet?
    var words: String?
    var password: String?
    
    
    @IBOutlet weak var masterStackView: UIStackView!
    @IBOutlet weak var addressHeader: UILabel!
    @IBOutlet weak var certHeader: UILabel!
    @IBOutlet weak var certField: UITextField!
    @IBOutlet weak var scanQROutlet: UIBarButtonItem!
    @IBOutlet weak var header: UILabel!
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet weak var onionAddressField: UITextField!
    @IBOutlet weak var addressHeaderOutlet: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        masterStackView.alpha = 0
        navigationController?.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        onionAddressField.delegate = self
        certField.delegate = self
        onionAddressField.isSecureTextEntry = false
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
        header.text = "Node Credentials"
        navigationController?.delegate = self
        onionAddressField.text = "localhost:28183"
        nodeLabel.text = "Join Market"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
        }
    }
    
    @IBAction func scanQuickConnect(_ sender: Any) {
        segueToScanNow()
    }
    
    private func segueToScanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanNodeCreds", sender: self)
        }
    }
    
    private func encryptCert(_ certText: String) -> Data? {
        let certData = Data(certText.utf8)
        
        guard let encryptedCert = Crypto.encrypt(certData) else {
            showAlert(vc: self, title: "Error", message: "Unable to encrypt your cert data.")
            return nil
        }
        
        return encryptedCert
    }
    
    @IBAction func save(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        if createNew || selectedNode == nil {
            newNode["id"] = UUID()
            
            guard let onionAddressText = onionAddressField.text else {
                showAlert(vc: self, title: "", message: "Add a node address first. If JM is running locally use localhost:28183.")
                return
            }
            
            guard let encryptedOnionAddress = encryptedValue(onionAddressText.utf8)  else {
                showAlert(vc: self, title: "", message: "Error encrypting the address.")
                return
            }
            
            newNode["onionAddress"] = encryptedOnionAddress
            newNode["label"] = nodeLabel.text ?? "Join Market"
            
            guard let certText = certField.text?.condenseWhitespace(), certText != "" else {
                showAlert(vc: self, title: "", message: "Paste in the SSL cert text first.")
                return
            }
            
            guard let encryptedCert = encryptCert(certText) else {
                showAlert(vc: self, title: "", message: "Unable to encrypt your cert.")
                return
            }
            
            newNode["cert"] = encryptedCert
            newNode["isActive"] = true
            
            func save() {
                
                func saveNow() {
                    CoreDataService.saveEntity(dict: self.newNode, entityName: .newNodes) { [weak self] success in
                        guard let self = self else { return }
                        
                         if success {
                             JMUtils.wallets { [weak self] (response, message) in
                                 guard let self = self else { return }
                                 
                                 guard let response = response else {
                                     showAlert(vc: self, title: "There was an issue testing your connection..", message: message ?? "Unknown issue.")
                                     
                                     return
                                 }
                                 
                                 if response.count == 0 {
                                     promptToCreateWallet()
                                 } else {
                                     showAlert(vc: self, title: "Connected to Join Market ✓", message: "You have exisiting wallets, would you like to connect to one?")
                                 }
                             }
                         } else {
                             showAlert(vc: self, title: "Node not added...", message: "There was an issue adding your node, please let us know about it.")
                         }
                     }
                }
                
                CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                    guard let nodes = nodes, nodes.count > 0 else {
                        saveNow()
                        return
                    }
                    
                    for (i, node) in nodes.enumerated() {
                        let node = NodeStruct(dictionary: node)
                        CoreDataService.update(id: node.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { updated in
                            if updated, i + 1 == nodes.count {
                                saveNow()
                            }
                        }
                    }
                }
            }
            
            guard certField.text != "" || onionAddressField.text != "" else {
                showAlert(vc: self, title: "", message: "Fill out all fields first")
                return
            }
            save()
        } else {
            //updating
            let id = selectedNode!["id"] as! UUID
            
            CoreDataService.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                if !success {
                    showAlert(vc: self, title: "", message: "Error updating label.")
                }
            }
            
            if onionAddressField != nil, let addressText = onionAddressField.text {
                let decryptedAddress = addressText.utf8
                let arr = addressText.split(separator: ":")
                guard arr.count == 2 else {
                    showAlert(vc: self, title: "Not updated, port missing...", message: "Please make sure you add the port at the end of your onion hostname, such as xjshdu.onion:28183")
                    return
                }
                
                guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
                
                CoreDataService.update(id: id, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                    if success {
                        vc.nodeAddedSuccess()
                    } else {
                        showAlert(vc: self, title: "", message: "Error updating node!")
                    }
                }
            }
                        
            guard let encryptedCert = encryptCert(certField.text!) else { return }
            
            CoreDataService.update(id: id, keyToUpdate: "cert", newValue: encryptedCert, entity: .newNodes) { success in
                if !success {
                    showAlert(vc: self, title: "", message: "Error updating cert.")
                }
            }
            
            nodeAddedSuccess()
        }
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Join Market connected ✓"
            
            let mess = "In order to use the app you need to create a Join Market wallet."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Create a wallet", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                getLabelAndPasswordForWallet()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getLabelAndPasswordForWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "To create a wallet provide a label and a password.", message: "The label will be used as a filename for the wallet.\n\nThe password will be used to encrypt and decrypt the wallet.\n\nYou MUST remember the password to use the wallet! Fully Noded does not save it!", preferredStyle: .alert)

            alert.addTextField { textFieldLabel in
                textFieldLabel.placeholder = "Label / filename."
            }
            
            alert.addTextField { passwordField1 in
                passwordField1.placeholder = "A password you won't forget."
                passwordField1.isSecureTextEntry = true
            }
            
            alert.addTextField { passwordField2 in
                passwordField2.placeholder = "Confirm password."
                passwordField2.isSecureTextEntry = true
            }

            alert.addAction(UIAlertAction(title: "Create Wallet", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                
                let fileName = alert.textFields![0].text // Force unwrapping because we know it exists.
                let password1 = alert.textFields![1].text
                let password2 = alert.textFields![2].text
                
                if let fileName = fileName, 
                    fileName != "" {
                    if let password1 = password1,
                        let password2 = password2,
                        password1 == password2 {
                        self.createWallet(label: fileName, password: password1)
                    } else {
                        showAlert(vc: self, title: "Passwords don't match...", message: "Navigate to the Active Wallet view to try again.")
                    }
                } else {
                    showAlert(vc: self, title: "Empty label", message: "Please add a label / filename in order to create a wallet. Navigate to the Active Wallet view to try again.")
                }
            }))

            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func createWallet(label: String, password: String) {
        spinner.addConnectingView(vc: self, description: "Creating your wallet...")
        JMUtils.createWallet(label: label, password: password) { [weak self] (response, words, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let jmWallet = response, let words = words else {
                showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
                
                return
            }
            
            self.password = password
            self.words = words
            self.jmWallet = jmWallet
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToBackUpInfo", sender: self)
            }
        }
    }
    
    private func promptToImportWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Join Market connected ✓"
            
            let mess = "You have existing Join Market wallets, connect to one?"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Connect a wallet", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                
                
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    func loadValues() {
        func decryptedValue(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.utf8String ?? ""
        }
        
        if selectedNode != nil {
            let node = NodeStruct(dictionary: selectedNode!)
            if node.id != nil {
                if node.label != "" {
                    nodeLabel.text = node.label
                }
                                                
                if let enc = node.onionAddress {
                    let decrypted = decryptedValue(enc)
                    if onionAddressField != nil {
                        onionAddressField.text = decrypted
                    }
                }
                
                if node.cert != nil, certField != nil {
                    if let decryptedCert = Crypto.decrypt(node.cert!) {
                        certField.text = decryptedCert.utf8String ?? ""
                    }
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.masterStackView.alpha = 1
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.onionAddressField != nil {
                self.onionAddressField.resignFirstResponder()
            }
            if self.nodeLabel != nil {
                self.nodeLabel.resignFirstResponder()
            }
            if self.certField != nil {
                self.certField.resignFirstResponder()
            }
        }
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    private func nodeAddedSuccess() {
        if selectedNode == nil || createNew {
            selectedNode = newNode
            createNew = false
            showAlert(vc: self, title: "Node saved ✓", message: "")
        } else {
            showAlert(vc: self, title: "Node updated ✓", message: "")
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToBackUpInfo":
            guard let vc = segue.destination as? SeedDisplayerViewController else { fallthrough }
            
            vc.jmWallet = self.jmWallet
            vc.password = self.password
            vc.words = self.words
            
        default:
            break
        }
        
    }
    
}
