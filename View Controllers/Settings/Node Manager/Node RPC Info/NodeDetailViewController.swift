//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
//import AVFoundation

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    let spinner = ConnectingView()
    var selectedNode:[String:Any]?
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    //let imagePicker = UIImagePickerController()
    //var scanNow = false
//    var jmWallet: JMWallet?
//    var words: String?
//    var password: String?
    
    
    @IBOutlet weak var portField: UITextField!
    @IBOutlet weak var masterStackView: UIStackView!
    @IBOutlet weak var certField: UITextField!
    //@IBOutlet weak var scanQROutlet: UIBarButtonItem!
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet weak var onionAddressField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        masterStackView.alpha = 0
        navigationController?.delegate = self
        portField.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        onionAddressField.delegate = self
        certField.delegate = self
        onionAddressField.isSecureTextEntry = false
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
        navigationController?.delegate = self
        onionAddressField.placeholder = "ugouyfiytfd.onion"
        nodeLabel.text = "Join Market"
        portField.text = "28183"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
//        if scanNow {
//            segueToScanNow()
//        }
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
        spinner.addConnectingView(vc: self, description: "checking node connectivity...")
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        if createNew || selectedNode == nil {
            newNode["id"] = UUID()
            
            guard let onionAddressText = onionAddressField.text else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "Add a node address first. If JM is running locally use localhost:28183.")
                return
            }
            
            guard let port = portField.text else {
                showAlert(vc: self, title: "", message: "Port is required.")
                return
            }
            
            let address = onionAddressText + ":" + port
            
            guard let encryptedOnionAddress = encryptedValue(address.utf8) else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "Error encrypting the address.")
                return
            }
            
            newNode["onionAddress"] = encryptedOnionAddress
            newNode["label"] = nodeLabel.text ?? "Join Market"
            
            guard let certText = certField.text?.condenseWhitespace(), certText != "" else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "Paste in the SSL cert text first.")
                return
            }
            
            guard let encryptedCert = encryptCert(certText) else {
                spinner.removeConnectingView()
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
                                 
                                 spinner.removeConnectingView()
                                 
                                 guard let _ = response else {
                                     showAlert(vc: self, title: "There was an issue testing your connection..", message: message ?? "Unknown issue.")
                                     
                                     let n = NodeStruct(dictionary: newNode)
                                     CoreDataService.deleteEntity(id: n.id, entityName: .newNodes) { _ in }
                                     
                                     return
                                 }
                                 
                                 promptToCreateWallet()
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
                        CoreDataService.update(id: node.id, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { updated in
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
            
            if let host = onionAddressField.text, let port = portField.text {
                let address = host + ":" + port
                let decryptedAddress = address.utf8
                
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
            
            let mess = "In order to use the app you need to create or import a Join Market wallet."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Create a wallet", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    performSegue(withIdentifier: "segueToCreateWallet", sender: self)
                }
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
        
        if let selectedNode = selectedNode {
            let node = NodeStruct(dictionary: selectedNode)
            nodeLabel.text = node.label
            let decrypted = decryptedValue(node.onionAddress)
            let arr = decrypted.components(separatedBy: ":")
            onionAddressField.text = "\(arr[0])"
            portField.text = "\(arr[1])"
            if let decryptedCert = Crypto.decrypt(node.cert) {
                certField.text = decryptedCert.utf8String ?? ""
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.masterStackView.alpha = 1
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            onionAddressField.resignFirstResponder()
            nodeLabel.resignFirstResponder()
            certField.resignFirstResponder()
            portField.resignFirstResponder()
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
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        switch segue.identifier {
//        case "segueToBackUpInfo":
//            guard let vc = segue.destination as? SeedDisplayerViewController else { fallthrough }
//            
//            vc.jmWallet = self.jmWallet
//            vc.password = self.password
//            vc.words = self.words
//            
//        default:
//            break
//        }
//        
//    }
    
}
