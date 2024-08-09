//
//  CreateFullyNodedWalletViewController.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit


class CreateFullyNodedWalletViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {
        
    var onDoneBlock:(((Bool)) -> Void)?
    var spinner = ConnectingView()
    var jmMessage = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "", message: "Looks like you do not have valid text on your clipboard.")
                return
            }
            
            processPastedString(string)
        } else if let string = UIPasteboard.general.string {
           processPastedString(string)
        } else {
            showAlert(vc: self, title: "", message: "Not a supported import item. Please let us know about it so we can add it.")
        }
    }
    
    
    
    private func processPastedString(_ string: String) {
        processImportedString(string)
    }
    
    @IBAction func automaticAction(_ sender: Any) {
        
    }
    
    
    private func segueToSingleSigCreator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSeedWords", sender: self)
        }
    }
    
    @IBAction func manualAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "seguToManualCreation", sender: self)
        }
    }

    
    @IBAction func createJmWalletAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "checking for existing jm wallets on your server...")
//        JMUtils.wallets { [weak self] (jmWallets, message) in
//            guard let self = self else { return }
//            guard let jmWallets = jmWallets else {
//                self.spinner.removeConnectingView()
//                showAlert(vc: self, title: "JM Server issue", message: message ?? "unknown")
//                return
//            }
//            
//            if jmWallets.count > 0 {
//                // select a wallet to use
//                self.promptToChooseJmWallet(jmWallets: jmWallets)
//            } else {
//                DispatchQueue.main.async {
//                    self.spinner.label.text = "creating new wallet (can take some time)..."
//                }
//                
//                JMUtils.createWallet { (wallet, words, passphrase, message) in
//                    self.spinner.removeConnectingView()
//                    
//                    guard let jmWallet = wallet, let words = words, let passphrase = passphrase else {
//                        if let mess = message, mess.contains("Wallet already unlocked.") {
//                            self.promptToLockWallets()
//                        } else {
//                            showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
//                        }
//                        
//                        return
//                    }
//                    UserDefaults.standard.setValue(jmWallet.name, forKey: "walletName")
//                    var formattedWords = ""
//                    for (i, word) in words.description.split(separator: " ").enumerated() {
//                        formattedWords += "\(i + 1). \(word) "
//                    }
//                    self.jmMessage = """
//                    In order to avoid lost funds back up the following information:
//                    
//                    Join Market Seed Words:
//                    \(formattedWords)
//                    
//                    Join Market wallet encryption passphrase:
//                    \(passphrase)
//                    
//                    Join Market wallet file:
//                    \(jmWallet.jmWalletName)
//                    """
//                    self.segueToSingleSigCreator()
//                }
//            }
//        }
    }
    
    private func promptToChooseJmWallet(jmWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            
            let tit = "Join Market wallet"
            
            let mess = "Please select which wallet you'd like to use."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            for jmWallet in jmWallets {
                alert.addAction(UIAlertAction(title: jmWallet, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    self.recoverJm(jmWallet: jmWallet)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recoverJm(jmWallet: String) {
        var walletToSave:[String:Any] = [
            "id": UUID(),
            "active": true,
            "name": jmWallet
            //"refresh_token": ,
            //"token":
        ]
        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            let title = "Unlock \(jmWallet)"
//            
//            let alert = UIAlertController(title: title, message: "Input your JM wallet encryption passphrase to unlock the wallet.", preferredStyle: .alert)
//            
////            let recover = UIAlertAction(title: "Unlock", style: .default) { [weak self] alertAction in
////                guard let self = self else { return }
////                self.spinner.addConnectingView(vc: self, description: "attempting to unlock the jm wallet...")
////                let jmWalletPassphrase = (alert.textFields![0] as UITextField).text
////                let jmWalletPassphraseConfirm = (alert.textFields![1] as UITextField).text
////                
////                guard let jmWalletPassphrase = jmWalletPassphrase,
////                      let jmWalletPassphraseConfirm = jmWalletPassphraseConfirm,
////                      jmWalletPassphraseConfirm == jmWalletPassphrase else {
////                    self.spinner.removeConnectingView()
////                    showAlert(vc: self, title: "", message: "Passphrases do not match, try again.")
////                    return
////                }
////                
////                guard let encryptedPassword = Crypto.encrypt(jmWalletPassphrase.utf8) else { showAlert(vc: self, title: "", message: "error encrypting passphrase"); return }
////                
////                walletToSave["password"] = encryptedPassword
////                var w:JMWallet = .init(walletToSave)
////                
////                JMUtils.unlockWallet(wallet: w) { [weak self] (unlockedWallet, message) in
////                    guard let self = self else { return }
////                    guard let unlockedWallet = unlockedWallet else {
////                        self.spinner.removeConnectingView()
////                        showAlert(vc: self, title: "", message: message ?? "unknown error when attempting to unlock \(w.name)")
////                        return
////                    }
////                    
////                    walletToSave["token"] = Crypto.encrypt(unlockedWallet.token.utf8)!
////                    w = .init(dictionary: walletToSave)
////                    
////                    JMUtils.getDescriptors(wallet: w) { (descriptors, message) in
////                        guard let descriptors = descriptors else {
////                            showAlert(vc: self, title: "", message: "")
////                            return
////                        }
////                        
////                        walletToSave["watching"] = Array(descriptors[2...descriptors.count - 1])
////                        walletToSave["receiveDescriptor"] = descriptors[0]
////                        walletToSave["changeDescriptor"] = descriptors[1]
////                        w = .init(dictionary: walletToSave)
////                        
////                        JMUtils.configGet(wallet: w, section: "BLOCKCHAIN", field: "rpc_wallet_file") { (jm_rpc_wallet, message) in
////                            guard let jm_rpc_wallet = jm_rpc_wallet else {
////                                self.spinner.removeConnectingView()
////                                showAlert(vc: self, title: "", message: message ?? "error fetching Bitcoin Core rpc wallet name in jm config.")
////                                return
////                            }
////                            walletToSave["name"] = jm_rpc_wallet
////                            print("walletToSave: \(walletToSave)")
////                            
////                            CoreDataService.saveEntity(dict: walletToSave, entityName: .wallets) { saved in
////                                self.spinner.removeConnectingView()
////                                if saved {
////                                    w = .init(dictionary: walletToSave)
////                                    UserDefaults.standard.set(w.name, forKey: "walletName")
////                                    self.spinner.removeConnectingView()
////                                    showAlert(vc: self, title: "", message: "Join Market Wallet created, it should load automatically.")
////                                    DispatchQueue.main.async { [weak self] in
////                                        guard let self = self else { return }
////                                        NotificationCenter.default.post(name: .refreshWallet, object: nil)
////                                        self.navigationController?.popToRootViewController(animated: true)
////                                    }
////                                } else {
////                                    showAlert(vc: self, title: "", message: message ?? "error saving wallet")
////                                }
////                            }
////                        }
////                    }
////                }
////            }
//            
//            alert.addTextField { jmWalletPassphrase in
//                jmWalletPassphrase.placeholder = "join market wallet passphrase"
//                jmWalletPassphrase.isSecureTextEntry = true
//                jmWalletPassphrase.keyboardAppearance = .dark
//            }
//            
//            alert.addTextField { jmWalletPassphraseConfirm in
//                jmWalletPassphraseConfirm.placeholder = "confirm encryption passphrase"
//                jmWalletPassphraseConfirm.keyboardAppearance = .dark
//                jmWalletPassphraseConfirm.isSecureTextEntry = true
//            }
//            
//            alert.addAction(recover)
//            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
//            alert.addAction(cancel)
//            self.present(alert, animated:true, completion: nil)
//        }
    }
    
    private func promptToLockWallets() {
        CoreDataService.retrieveEntity(entityName: .jmWallets) { wallets in
            guard let wallets = wallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "You have an existing Join Market wallet which is unlocked, you need to lock it before we can create a new one."
                
                let mess = ""
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
                
                JMUtils.wallets { (server_wallets, message) in
                    guard let server_wallets = server_wallets else { return }
                    for server_wallet in server_wallets {
                        DispatchQueue.main.async {
                            alert.addAction(UIAlertAction(title: server_wallet, style: .default, handler: { [weak self] action in
                                guard let self = self else { return }
                                
                                self.spinner.addConnectingView(vc: self, description: "locking wallet...")
                                
                                for fnwallet in wallets {
//                                    if fnwallet["id"] != nil {
//                                        let str = Wallet(dictionary: fnwallet)
//                                        if str.jmWalletName == server_wallet {
//                                            JMUtils.lockWallet(wallet: str) { [weak self] (locked, message) in
//                                                guard let self = self else { return }
//                                                self.spinner.removeConnectingView()
//                                                if locked {
//                                                    showAlert(vc: self, title: "Wallet locked ✓", message: "Try joining the utxo again.")
//                                                } else {
//                                                    showAlert(vc: self, title: message ?? "Unknown issue locking that wallet...", message: "FN can only work with one JM wallet at a time, it looks like you need to restart your JM daemon in order to create a new wallet. Restart JM daemon and try again.")
//                                                }
//                                            }
//                                        }
//                                    }
                                }
                            }))
                        }
                    }
                }
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func processImportedString(_ item: String) {
        if Keys.validMnemonic(item) {
            
        } else {
            showAlert(vc: self, title: "Unsupported import.", message: item + " is not a supported import option, please let us know about this so we can add support.")
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
            
//            vc.isSegwit = isSegwit
//            vc.isTaproot = isTaproot
//            vc.jmMessage = jmMessage
            
        case "segueToScanner":
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
                
                vc.onDoneBlock = { [weak self] item in
                    guard let self = self else { return }
                    
                    guard let item = item else {
                        return
                    }
                    
                    #if(DEBUG)
                    print("item: \(item)")
                    #endif
                    
                    self.processImportedString(item)
                }
            }
            
        default:
            break
        }
    }
}
