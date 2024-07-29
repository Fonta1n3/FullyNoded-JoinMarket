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
        onionAddressField.placeholder = "localhost:28183"
        nodeLabel.text = "Join Market"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
        
        if scanNow {
            segueToScanNow()
        }
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
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
            
            if onionAddressField != nil,
                let onionAddressText = onionAddressField.text {
               guard let encryptedOnionAddress = encryptedValue(onionAddressText.utf8)  else {
                    showAlert(vc: self, title: "", message: "Error encrypting the address.")
                    return }
                newNode["onionAddress"] = encryptedOnionAddress
            }
                    
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
            }

            
            guard let encryptedCert = encryptCert(certField.text!) else {
                return
            }
            
            newNode["cert"] = encryptedCert
            
            func save() {
                CoreDataService.saveEntity(dict: self.newNode, entityName: .newNodes) { [unowned vc = self] success in
                     if success {
                         vc.nodeAddedSuccess()
                     } else {
                         displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                     }
                 }
            }
            
            guard certField.text != "" || onionAddressField.text != "" else {
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                return
            }
            save()
        } else {
            //updating
            let id = selectedNode!["id"] as! UUID
            
            CoreDataService.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                if !success {
                    displayAlert(viewController: self, isError: true, message: "error updating label")
                }
            }
            
            if onionAddressField != nil, let addressText = onionAddressField.text {
                let decryptedAddress = addressText.dataUsingUTF8StringEncoding
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
                        displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                    }
                }
            }
                        
            guard let encryptedCert = encryptCert(certField.text!) else { return }
            
            CoreDataService.update(id: id, keyToUpdate: "cert", newValue: encryptedCert, entity: .newNodes) { success in
                if !success {
                    displayAlert(viewController: self, isError: true, message: "error updating cert")
                }
            }
            
            nodeAddedSuccess()
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
        
        func decryptedNostr(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.hexString
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
    
    func addBtcRpcQr(url: String) {
        QuickConnect.addNode(uncleJim: false, url: url) { [weak self] (success, errorMessage) in
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.navigationController?.popViewController(animated: true)
                    NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScanNodeCreds" {
            if #available(macCatalyst 14.0, *) {
                if let vc = segue.destination as? QRScannerViewController {
                    vc.isQuickConnect = true
                    vc.onDoneBlock = { [unowned thisVc = self] url in
                        if url != nil {
                            thisVc.addBtcRpcQr(url: url!)
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
}
