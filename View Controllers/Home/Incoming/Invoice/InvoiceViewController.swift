//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class InvoiceViewController: UIViewController, UITextFieldDelegate {
    
    var textToShareViaQRCode = String()
    var addressString = String()
    var qrCode = UIImage()
    let spinner = ConnectingView()
    let qrGenerator = QRGenerator()
    var descriptor = ""
    var jmWallet: JMWallet!
    let ud = UserDefaults.standard
    var isBtc = false
    var isSats = false
    var isFiat = false
    
    @IBOutlet weak var invoiceHeader: UILabel!
    @IBOutlet weak var addressImageView: UIImageView!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var labelField: UITextField!
    @IBOutlet var qrView: UIImageView!
    @IBOutlet var addressOutlet: UILabel!
    @IBOutlet private weak var invoiceText: UITextView!
    @IBOutlet private weak var messageField: UITextField!
    @IBOutlet weak var fieldsBackground: UIView!
    @IBOutlet weak var addressBackground: UIView!
    @IBOutlet weak var invoiceBackground: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setDelegates()
        configureView(fieldsBackground)
        configureView(addressBackground)
        configureView(invoiceBackground)
        addressImageView.layer.magnificationFilter = .nearest
        confirgureFields()
        configureTap()
        addDoneButtonOnKeyboard()
        addressOutlet.text = ""
        invoiceText.text = ""
        qrView.image = generateQrCode(key: "bitcoin:")
        generateOnchainInvoice()
        getReceiveAddressJm(wallet: jmWallet)
    }
    
    
    @IBAction func switchDenominationsAction(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.isBtc = true
            self.isSats = false
            self.isFiat = false
        default:
            self.isBtc = false
            self.isSats = true
            self.isFiat = false
        }
        
        updateQRImage()
    }
    
    
    private func setDelegates() {
        messageField.delegate = self
        amountField.delegate = self
        labelField.delegate = self
    }
    
    
    private func confirgureFields() {
        amountField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        labelField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        messageField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    
    
    private func configureTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        amountField.removeGestureRecognizer(tap)
        labelField.removeGestureRecognizer(tap)
        messageField.removeGestureRecognizer(tap)
    }
    
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.borderColor = UIColor.darkGray.cgColor
        view.layer.borderWidth = 0.5
    }
    
    
    
    
    
    @IBAction func shareAddressAction(_ sender: Any) {
        shareText(addressString)
    }
    
    
    @IBAction func copyAddressAction(_ sender: Any) {
        UIPasteboard.general.string = addressString
        showAlert(vc: self, title: "", message: "Address text copied ✓")
    }
    
    
    @IBAction func shareQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityController = UIActivityViewController(activityItems: [self.qrView.image as Any], applicationActivities: nil)
            activityController.popoverPresentationController?.sourceView = self.view
            activityController.popoverPresentationController?.sourceRect = self.view.bounds
            self.present(activityController, animated: true) {}
        }
    }
    
    @IBAction func copyQrAction(_ sender: Any) {
        UIPasteboard.general.image = self.qrView.image
        showAlert(vc: self, title: "", message: "QR copied ✓")
    }
    
    @IBAction func shareInvoiceTextAction(_ sender: Any) {
        shareText(invoiceText.text)
    }
    
    @IBAction func copyInvoiceTextAction(_ sender: Any) {
        UIPasteboard.general.string = invoiceText.text
        showAlert(vc: self, title: "", message: "Invoice text copied ✓")
    }
    
        
    @IBAction func generateOnchainAction(_ sender: Any) {
        generateOnchainInvoice()
    }
    
    func generateOnchainInvoice() {
        spinner.addConnectingView(vc: self, description: "fetching address...")
        
        print("generate address")
    }
    
    private func getReceiveAddressJm(wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            let title = "Select a mixdepth to deposit to."
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 0, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 1, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 2, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 3, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.getJmAddressFromMixDepth(mixDepth: 4, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getJmAddressFromMixDepth(mixDepth: Int, wallet: JMWallet) {
        spinner.addConnectingView(vc: self, description: "getting address from jm...")
        var w = wallet
        JMRPC.sharedInstance.command(method: .getaddress(jmWallet: w, mixdepth: mixDepth), param: nil) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            if errorDesc == "Invalid credentials." {
                // Prompt to unlock
                
//                JMUtils.unlockWallet(wallet: w) { [weak self] (unlockedWallet, message) in
//                    guard let self = self else { return }
//                    guard let unlockedWallet = unlockedWallet else { return }
//
//                    guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
//                        self.spinner.removeConnectingView()
//                        showAlert(vc: self, title: "", message: "Unable to decrypt your jm auth token.")
//                        return
//                    }
//
//                    w.token = encryptedToken
//                    self.getJmAddressFromMixDepth(mixDepth: mixDepth, wallet: w)
//                }
                
            } else {
                guard let response = response as? [String:Any],
                      let address = response["address"] as? String else {
                    showAlert(vc: self, title: "", message: errorDesc ?? "unknown error getting jm address.")
                    return
                }
                self.spinner.removeConnectingView()
                self.showAddress(address: address)
            }
        }
    }
    
    
    func showAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressOutlet.alpha = 1
            self.addressOutlet.text = address
            self.addressString = address
            self.updateQRImage()
            self.addressImageView.image = LifeHash.image(address)
            self.spinner.removeConnectingView()
        }
    }
    
    
    private func shareText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let textToShare = [text]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            activityViewController.popoverPresentationController?.sourceRect = self.view.bounds
            self.present(activityViewController, animated: true) {}
        }
    }
    
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        updateQRImage()
    }
    
    func generateQrCode(key: String) -> UIImage {
        qrGenerator.textInput = key
        let qr = qrGenerator.getQRCode()
        return qr
    }
    
    func updateQRImage() {
        var newImage = UIImage()
        var amount = self.amountField.text ?? ""
        
        if isSats {
            if amount != "" {
                if let dbl = Double(amount) {
                    amount = (dbl / 100000000.0).avoidNotation
                }
            }
        }
        
        let label = self.labelField.text?.replacingOccurrences(of: " ", with: "%20") ?? ""
        let message = self.messageField.text?.replacingOccurrences(of: " ", with: "%20") ?? ""
        textToShareViaQRCode = "bitcoin:\(self.addressString)"
        let dict = ["amount": amount, "label": label, "message": message]
        
        if amount != "" || label != "" || message != "" {
            textToShareViaQRCode += "?"
        }
        
        for (key, value) in dict {
            if textToShareViaQRCode.contains("amount=") || textToShareViaQRCode.contains("label=") || textToShareViaQRCode.contains("message=") {
                if value != "" {
                    textToShareViaQRCode += "&\(key)=\(value)"
                }
            } else {
                if value != "" {
                    textToShareViaQRCode += "\(key)=\(value)"
                }
            }
        }
        
        newImage = self.generateQrCode(key:textToShareViaQRCode)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIView.transition(with: self.qrView,
                              duration: 0.75,
                              options: .transitionCrossDissolve,
                              animations: { self.qrView.image = newImage },
                              completion: nil)
            
            self.invoiceText.text = self.textToShareViaQRCode
        }
    }
    
    @objc func doneButtonAction() {
        self.amountField.resignFirstResponder()
        self.labelField.resignFirstResponder()
        self.messageField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateQRImage()
    }
    
    func addDoneButtonOnKeyboard() {
        let doneToolbar = UIToolbar()
        doneToolbar.frame = CGRect(x: 0, y: 0, width: 320, height: 50)
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonAction))
        
        let items = NSMutableArray()
        items.add(flexSpace)
        items.add(done)
        
        doneToolbar.items = (items as! [UIBarButtonItem])
        doneToolbar.sizeToFit()
        
        self.amountField.inputAccessoryView = doneToolbar
        self.labelField.inputAccessoryView = doneToolbar
        self.messageField.inputAccessoryView = doneToolbar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
