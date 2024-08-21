//
//  AddSignerViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class AddSignerViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var wordView: UITextView!
    @IBOutlet weak var textView: UITextField!
    @IBOutlet weak var addSignerOutlet: UIButton!
    @IBOutlet weak var walletTypeControl: UISegmentedControl!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var walletNameField: UITextField!
    
    private let spinner = ConnectingView()
    var addedWords = [String]()
    var justWords = [String]()
    var bip39Words = [String]()
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationController?.delegate = self
        textView.delegate = self
        passwordField.delegate = self
        walletNameField.delegate = self
        addSignerOutlet.isEnabled = false
        wordView.layer.cornerRadius = 8
        wordView.layer.borderColor = UIColor.lightGray.cgColor
        wordView.layer.borderWidth = 0.5
        addSignerOutlet.clipsToBounds = true
        addSignerOutlet.layer.cornerRadius = 8
        bip39Words = Words.valid
        updatePlaceHolder(wordNumber: 1)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        textView.removeGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @IBAction func generateSignerAction(_ sender: Any) {
        guard let words = Keys.seed() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = words
            self.processTextfieldInput()
            self.validWordsAdded()
        }
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "")
        let mnemonic = justWords.joined(separator: " ")
        guard let unlockPasword = passwordField.text, unlockPasword != "" else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Unlock password field must be filled out.")
            return
        }
        
        guard let walletName = walletNameField.text, walletName != "" else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Wallet name field must be filled out.")
            return
        }
                
        var walletType = "sw-fb"
        switch walletTypeControl.selectedSegmentIndex {
        case 1: walletType = "sw"
        case 2: walletType = "sw-legacy"
        default:
            break
        }
        
        // "walletname", "password", "wallettype", "seedphrase"
        let p: [String: Any] = [
            "walletname": walletName + ".jmdat",
            "password": unlockPasword,
            "wallettype": walletType,
            "seedphrase": mnemonic
        ]
        
        JMRPC.sharedInstance.command(method: .recover, param: p) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            spinner.removeConnectingView()
            
            guard let response = response as? [String: Any] else {
                if let err = errorDesc, err.hasPrefix("Wallet already unlocked") {
                    showAlert(vc: self, title: "Wallet already unlocked.", message: "Navigate to wallets to lock the existing wallet before trying to recover a wallet.")
                } else {
                    showAlert(vc: self, title: "Wallet recover error.", message: errorDesc ?? "Unknown error.")
                }
                
                return
            }
            
            let jmWalletCreated = JMWalletCreated(response)
            
            guard let encryptedToken = Crypto.encrypt(jmWalletCreated.token.utf8) else {
                showAlert(vc: self, title: "", message: "Error encrypting jm wallet credentials.")
                return
            }
            
            guard let encryptedRefreshToken = Crypto.encrypt(jmWalletCreated.refresh_token.utf8) else {
                showAlert(vc: self, title: "", message: "Error encrypting jm wallet credentials.")
                return
            }
            
            let jmWallet: [String:Any] = [
                "id": UUID(),
                "token":encryptedToken,
                "refresh_token": encryptedRefreshToken,
                "name": jmWalletCreated.walletname,
                "active": true
            ]
            
            func saveNow() {
                CoreDataService.saveEntity(dict: jmWallet, entityName: .jmWallets) { [weak self] walletSaved in
                    guard let self = self else { return }
                    guard walletSaved else {
                        showAlert(vc: self, title: "", message: "Error saving wallet.")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil)
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
            
            CoreDataService.retrieveEntity(entityName: .jmWallets) { wallets in
                guard let wallets = wallets, wallets .count > 0 else {
                    saveNow()
                    return
                }
                
                for (i, wallet) in wallets.enumerated() {
                    let jmWallet = JMWallet(wallet)
                    if jmWallet.active {
                        CoreDataService.update(id: jmWallet.id, keyToUpdate: "active", newValue: false, entity: .jmWallets) { deactivated in
                            if !deactivated {
                                showAlert(vc: self, title: "", message: "There was an issue deactivating your existing wallet...")
                            }
                        }
                    }
                    
                    if i + 1 == wallets.count {
                        saveNow()
                    }
                }
            }
        }
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        if justWords.count > 0 {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.wordView.text = ""
                vc.addedWords.removeAll()
                vc.justWords.remove(at: vc.justWords.count - 1)
                
                for (i, word) in vc.justWords.enumerated() {
                    vc.addedWords.append("\(i + 1). \(word)\n")
                    
                    if i == 0 {
                        vc.updatePlaceHolder(wordNumber: i + 1)
                    } else {
                        vc.updatePlaceHolder(wordNumber: i + 2)
                    }
                }
                
                vc.wordView.text = vc.addedWords.joined(separator: "")
                
                if Keys.validMnemonic(vc.justWords.joined(separator: " ")) {
                    vc.validWordsAdded()
                }
            }
        }
    }
    
    private func processTextfieldInput() {
        guard textView.text != "" else {
            shakeAlert(viewToShake: textView)
            return
        }
        
        //check if user pasted more then one word
        let processed = processedCharacters(textView.text!)
        let userAddedWords = processed.split(separator: " ")
        var multipleWords = [String]()
        
        if userAddedWords.count > 1 {
            //user add multiple words
            for (i, word) in userAddedWords.enumerated() {
                var isValid = false
                
                for bip39Word in bip39Words {
                    if word == bip39Word {
                        isValid = true
                        multipleWords.append("\(word)")
                    }
                }
                
                if i + 1 == userAddedWords.count {
                    // we finished our checks
                    if isValid {
                        // they are valid bip39 words
                        addMultipleWords(words: multipleWords)
                        textView.text = ""
                    } else {
                        //they are not all valid bip39 words
                        textView.text = ""
                        showAlert(vc: self, title: "Error", message: "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                    }
                }
            }
        } else {
            //its one word
            let processedWord = textView.text!.replacingOccurrences(of: " ", with: "")
            
            for word in bip39Words {
                if processedWord == word {
                    addWord(word: processedWord)
                    textView.text = ""
                }
            }
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        hideKeyboards()
    }
    
    private func hideKeyboards() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.resignFirstResponder()
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if walletNameField.isEditing || passwordField.isEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if walletNameField.isEditing || passwordField.isEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel])
        }
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [unowned vc = self] in
            showAlert(vc: vc, title: "Error", message: error)
        }
    }

    private func formatSubstring(subString: String) -> String {
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
    }
    
    private func resetValues() {
        textView.textColor = .none
        autoCompleteCharacterCount = 0
        textView.text = ""
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textView.textColor = .none
        
        if suggestions.count > 0 {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
            })
            
        } else {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [unowned vc = self] (timer) in //7
                vc.textView.text = substring
                
                if Keys.validMnemonic(vc.processedCharacters(vc.textView.text!)) {
                    vc.processTextfieldInput()
                    vc.textView.textColor = .label
                    vc.validWordsAdded()
                } else {
                    vc.textView.textColor = .systemRed
                }
            })
            autoCompleteCharacterCount = 0
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == textView {
            var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
            subString = formatSubstring(subString: subString)
            if subString.count == 0 {
                resetValues()
            } else {
                searchAutocompleteEntriesWIthSubstring(substring: subString)
            }
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == textView {
            processTextfieldInput()
        }
        return true
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        var possibleMatches: [String] = []
        for item in bip39Words {
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            if (substringRange.location == 0) {
                possibleMatches.append(item)
            }
        }
        return possibleMatches
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.label,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        self.textView.attributedText = coloredString
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        if let newPosition = self.textView.position(from: self.textView.beginningOfDocument, offset: userQuery.count) {
            self.textView.selectedTextRange = self.textView.textRange(from: newPosition, to: newPosition)
        }
        let selectedRange: UITextRange? = textView.selectedTextRange
        textView.offset(from: textView.beginningOfDocument, to: (selectedRange?.start)!)
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
    }
    
    private func addMultipleWords(words: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.wordView.text = ""
            vc.addedWords.removeAll()
            vc.justWords = words
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
            }
            
            vc.wordView.text = vc.addedWords.joined(separator: "")
        }
    }
    
    private func addWord(word: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.wordView.text = ""
            vc.addedWords.removeAll()
            vc.justWords.append(word)
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
                
            }
            
            vc.wordView.text = vc.addedWords.joined(separator: "")
            
            if Keys.validMnemonic(vc.justWords.joined(separator: " ")) {
                vc.validWordsAdded()
            }
            
            vc.textView.becomeFirstResponder()
        }
    }
    
    private func processedCharacters(_ string: String) -> String {
        var result = string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains)
        result = result.condenseWhitespace()
        return result
    }
    
    private func validWordsAdded() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.resignFirstResponder()
            vc.addSignerOutlet.isEnabled = true
        }
        showAlert(vc: self, title: "Valid Words ✓", message: "Valid seed words added, ensure you select the correct wallet type, input a wallet name, an unlock password and an optional passphrase.")
    }
    
    private func signerAdded() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Signer successfully encrypted and saved securely to your device.", message: "Tap done", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
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
