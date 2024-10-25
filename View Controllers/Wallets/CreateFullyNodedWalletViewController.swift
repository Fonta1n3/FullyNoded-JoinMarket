//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit


class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
        
    //var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var jmMessage = ""
    var password = ""
    var words = ""
    var jmWallet: JMWallet?
    var isImporting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        
        if isImporting {
            importNow()
        }
    }
    
    @IBAction func createJmWalletAction(_ sender: Any) {
        promptToCreateWallet()
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Create a new wallet?"
                        
            let alert = UIAlertController(title: tit, message: "You will be shown seed words and an unlock password, this information must be saved by you, without it you may lose access to your funds!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Create a new wallet", style: .default, handler: { [weak self] action in
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
        
        func createNow() {
            JMUtils.createWallet(label: label, password: password) { [weak self] (response, words, message) in
                guard let self = self else { return }
                
                self.spinner.removeConnectingView()
                
                guard let jmWallet = response, let words = words else {
                    
                    if let message = message, message.contains("Wallet already unlocked") {
                        showAlert(vc: self, title: "Wallet already unlocked.", message: "You need to lock the existing wallet in order to create a new wallet. Go to the wallets view and tap the lock button to lock the wallet and try again.")
                    } else {
                        showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
                    }
                    
                    return
                }
                
                self.password = password
                self.words = words
                self.jmWallet = jmWallet
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToSeedWords", sender: self)
                }
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
            guard let jmWallets = jmWallets, jmWallets.count > 0 else {
                createNow()
                return
            }
            
            for (i, jmWallet) in jmWallets.enumerated() {
                let w = JMWallet(jmWallet)
                if w.active {
                    CoreDataService.update(id: w.id, keyToUpdate: "active", newValue: false, entity: .jmWallets) { _ in  }
                }
                
                if i + 1 == jmWallets.count {
                    createNow()
                }
            }
        }
    }
    
    @IBAction func importAction(_ sender: Any) {
        importNow()
    }
    
    private func importNow() {
        spinner.addConnectingView(vc: self, description: "checking for existing wallets...")
        
        JMUtils.wallets { [weak self] (remoteJmWallets, message) in
            guard let self = self else { return }
            spinner.removeConnectingView()
            
            guard let remoteJmWallets = remoteJmWallets else {
                showAlert(vc: self, title: "Server issue", message: message ?? "unknown")
                return
            }
            
            if remoteJmWallets.count > 0 {
                CoreDataService.retrieveEntity(entityName: .jmWallets) { localJmWallets in
                    
                    guard let localJmWallets = localJmWallets, localJmWallets.count > 0 else {
                        self.promptToChooseJmWallet(jmWallets: remoteJmWallets)
                        return
                    }
                                        
                    var newWallets: [String] = []
                    
                    for remoteJmWallet in remoteJmWallets {
                        var exists = false
                        
                        for (i, localJmWallet) in localJmWallets.enumerated() {
                            let localWallet = JMWallet(localJmWallet)
                            if localWallet.name == remoteJmWallet {
                                exists = true
                            }
                            
                            if i + 1 == localJmWallets.count {
                                if !exists {
                                    newWallets.append(remoteJmWallet)
                                }
                            }
                        }
                    }
                    
                    if newWallets.count > 0 {
                        self.promptToChooseJmWallet(jmWallets: newWallets)
                    } else {
                        showAlert(vc: self, title: "No new wallets found.", message: "Looks like no new wallets exist on your server. In order to import a wallet it must already exist on your server.")
                    }
                }
            } else {
                showAlert(vc: self, title: "No wallets exist.", message: "In order to import a wallet it must already exist on your server.")
            }
        }
    }
    
    @IBAction func recoverAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToRecover", sender: self)
        }
    }
    
    private func promptToChooseJmWallet(jmWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            
            let tit = "Wallet import"
            
            let mess = "Please select which wallet you'd like to use."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            
            for jmWallet in jmWallets {
                alert.addAction(UIAlertAction(title: jmWallet, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    self.importJm(jmWallet: jmWallet)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importJm(jmWallet: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Unlock \(jmWallet)"
            
            let alert = UIAlertController(title: title, message: "Input your Join Market wallet encryption password to unlock the wallet.", preferredStyle: .alert)
            
            let recover = UIAlertAction(title: "Unlock", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                self.spinner.addConnectingView(vc: self, description: "attempting to unlock the wallet...")
                
                let jmWalletPassphrase = (alert.textFields![0] as UITextField).text
                
                guard let jmWalletPassphrase = jmWalletPassphrase else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "Enter the password, try again.")
                    return
                }
                                
                let w = JMWallet([
                    "name": jmWallet,
                    "id": UUID(),
                    "token": "".utf8,
                    "refresh_token": "".utf8,
                    "active": true
                ])
                
                JMRPC.sharedInstance.command(method: .unlockwallet(jmWallet: w, password: jmWalletPassphrase), param: nil) { (response, errorDesc) in
                    guard let response = response as? [String: Any] else {
                        showAlert(vc: self, title: "", message: errorDesc ?? "Unknown error.")
                        return
                    }
                    
                    let unlockedWallet = WalletUnlock(response)
                                        
                    guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                        //completion((nil, nil, "Error encrypting jm wallet credentials."))
                        return
                    }
                    
                    guard let encryptedRefreshToken = Crypto.encrypt(unlockedWallet.refresh_token.utf8) else {
                        //completion((nil, nil, "Error encrypting jm wallet credentials."))
                        return
                    }
                    
                    let jmWalletToSave: [String:Any] = [
                        "id": UUID(),
                        "token":encryptedToken,
                        "refresh_token": encryptedRefreshToken,
                        "name": unlockedWallet.walletname,
                        "active": true
                    ]
                    
                    func saveNow() {
                        CoreDataService.saveEntity(dict: jmWalletToSave, entityName: .jmWallets) { walletSaved in
                            guard walletSaved else {
                                //completion((nil, nil, "Error saving wallet."))
                                return
                            }
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil)
                                self.navigationController?.popToRootViewController(animated: true)
                            }
                        }
                    }
                    
                    // check if any existing wallets and deactivate
                    CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
                        guard let jmWallets = jmWallets, jmWallets.count > 0 else {
                            saveNow()
                            return
                        }
                        
                        for (i, jmWallet) in jmWallets.enumerated() {
                            let w = JMWallet(jmWallet)
                            if w.active {
                                CoreDataService.update(id: w.id, keyToUpdate: "active", newValue: false, entity: .jmWallets) { deactivated in
                                    print(deactivated)
                                }
                            }
                            
                            if i + 1 == jmWallets.count {
                                saveNow()
                            }
                        }
                    }
                }
            }
            
            alert.addTextField { jmWalletPassphrase in
                jmWalletPassphrase.placeholder = "password"
                jmWalletPassphrase.isSecureTextEntry = true
                jmWalletPassphrase.keyboardAppearance = .dark
            }
            
            alert.addAction(recover)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToSeedWords":
            guard let vc = segue.destination as? SeedDisplayerViewController else { fallthrough }

            vc.password = password
            vc.words = words
            vc.jmWallet = jmWallet
            
//        case "segueToScanner":
//            if #available(macCatalyst 14.0, *) {
//                guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
//                
//                vc.onDoneBlock = { [weak self] item in
//                    guard let self = self else { return }
//                    
//                    guard let item = item else {
//                        return
//                    }
//                    
//                    #if(DEBUG)
//                    print("item: \(item)")
//                    #endif
//                    
//                    self.processImportedString(item)
//                }
//            }
            
        default:
            break
        }
    }
}
