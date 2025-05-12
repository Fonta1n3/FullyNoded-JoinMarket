//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Denton LLC. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var isDirectSend = false
    var mixdepthToSpendFrom = 0
    var jmWallet: JMWallet?
    var fxRate: Double?
    var address: String = ""
    var amount: String = ""
    var outputs:[[String:Any]] = []
    var inputs:[[String:Any]] = []
    var txt = ""
    var utxoTotal = 0.0
    let ud = UserDefaults.standard
    var index = 0
    var invoice:[String:Any]?
    var invoiceString = ""
    let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    var isFidelity = false
    var balance = ""
    var doubleAmount = 0.0
    
    
    @IBOutlet weak private var balanceLabel: UILabel!
    @IBOutlet weak private var sweepButton: UIStackView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    @IBOutlet weak private var amountIcon: UIView!
    @IBOutlet weak private var addressIcon: UIView!
    @IBOutlet weak private var recipientBackground: UIView!
    @IBOutlet weak private var amountBackground: UIView!
    @IBOutlet weak private var amountInput: UITextField!
    @IBOutlet weak private var addressInput: UITextField!
    @IBOutlet weak private var amountLabel: UILabel!
    @IBOutlet weak private var actionOutlet: UIButton!
    @IBOutlet weak private var scanOutlet: UIButton!
    @IBOutlet weak private var receivingLabel: UILabel!
    @IBOutlet weak private var addressImageView: UIImageView!
    
    var spinner = ConnectingView()
    var spendableBalance = Double()
    //var outputArray = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        balanceLabel.text = "Available: \(balance)"
        addTapGesture()
        amountBackground.layer.cornerRadius = 8
        amountBackground.layer.borderColor = UIColor.darkGray.cgColor
        amountBackground.layer.borderWidth = 0.5
        amountBackground.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        recipientBackground.layer.cornerRadius = 8
        recipientBackground.layer.borderColor = UIColor.darkGray.cgColor
        recipientBackground.layer.borderWidth = 0.5
        recipientBackground.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        amountIcon.layer.cornerRadius = 5
        addressIcon.layer.cornerRadius = 5
        addressImageView.layer.magnificationFilter = .nearest
        amountInput.text = ""
        if address != "" {
            addAddress(address)
        }
    }
    
    @IBAction func getRemixAddress(_ sender: Any) {
        if let wallet = self.jmWallet {
            getAddressFromJm(wallet: wallet)
        }
    }        
    
    private func getAddressFromJm(wallet: JMWallet) {
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
        
        JMRPC.sharedInstance.command(method: .getaddress(jmWallet: wallet, mixdepth: mixDepth), param: nil) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            guard let response = response as? [String:Any],
            let address = response["address"] as? String else {
                showAlert(vc: self, title: "", message: errorDesc ?? "unknown error getting jm address.")
                return
            }

            self.addAdressNow(address: address, wallet: wallet)
        }
    }
    
    private func getAddressFromWallet(_ wallet: JMWallet) {
        spinner.addConnectingView(vc: self, description: "getting address...")
        getAddressFromJm(wallet: wallet)
    }
    
    private func addAdressNow(address: String, wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addAddress("\(address)")
        }
    }
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let item = UIPasteboard.general.string else { return }
        
        if item.lowercased().hasPrefix("bitcoin:") {
            processBIP21(url: item)
        } else {
            switch item {
            case _ where item.hasPrefix("1"),
                 _ where item.hasPrefix("3"),
                 _ where item.hasPrefix("tb1"),
                 _ where item.hasPrefix("bc1"),
                 _ where item.hasPrefix("2"),
                 _ where item.hasPrefix("bcrt"),
                 _ where item.hasPrefix("m"),
                 _ where item.hasPrefix("n"),
                 _ where item.hasPrefix("lntb"):
                processBIP21(url: item)
            default:
                showAlert(vc: self, title: "", message: "This button is for pasting lightning invoices, bitcoin addresses and bip21 invoices")
            }
        }
    }
    
    @IBAction func createOnchainAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.amountInput.resignFirstResponder()
            self.addressInput.resignFirstResponder()
        }
        
        guard let addressInput = addressInput.text else {
            showAlert(vc: self, title: "", message: "Enter an address or invoice.")
            return
        }
        
        guard let amount = convertedAmount() else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Enter an amount.")
            return
        }
        
        if isDirectSend {
            getRawTx(amount: amount.doubleValue, address: addressInput)
            
        } else {
            guard let jmWallet = jmWallet else { return }
            promptToCoinjoinWithJM(wallet: jmWallet, recipient: addressInput, amount: amount.doubleValue)
        }
    }
    
    private func promptToCoinjoinWithJM(wallet: JMWallet, recipient: String, amount: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.doubleAmount = amount
            self.performSegue(withIdentifier: "segueToConfirmCoinjoin", sender: self)
        }
    }
    
    private func promptToDirectSendWithJM(wallet: JMWallet, recipient: String, amount: Double, mixdepth: Int) {
        self.doubleAmount = amount
        self.mixdepthToSpendFrom = mixdepth
        
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToSendConfirmation", sender: self)
        }
    }
    
    private func directSend(mixdepth: Int) {
        guard let jmWallet = jmWallet else { print("no jm wallet."); return }
        //self.spinner.addConnectingView(vc: self, description: "direct sending with JM...")
        
        var sats = 0
        
        if amount == "0" {
            promptToDirectSendWithJM(wallet: jmWallet, recipient: self.addressInput.text!, amount: 0.0, mixdepth: mixdepth)
        } else {
            guard let amount = convertedAmount() else { print("cant convert amount"); return }
            promptToDirectSendWithJM(wallet: jmWallet, recipient: self.addressInput.text!, amount: amount.doubleValue, mixdepth: mixdepth)
        }
        
        
        
        
    }
    
    private func convertedAmount() -> String? {
        guard let amount = amountInput.text, amount != "" else { return nil }
        
        let dblAmount = amount.doubleValue
        
        guard dblAmount > 0.0 else {
            showAlert(vc: self, title: "", message: "Amount needs to be greater than 0.")
            return nil
        }

        return "\(dblAmount.avoidNotation)"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if isFidelity {
            showAlert(vc: self, title: "Fidelity Bond", message: "⚠️ This is a timelocked address.\n\nFor best privacy practices it is recommended to use the \"Send all\" button to sweep the selected utxo(s) when creating a fidelity bond.\n\n⚠️ WARNING: You should send coins to this address only once. Only single biggest value UTXO will be announced as a fidelity bond. Sending coins to this address multiple times will not increase fidelity bond value. ⚠️ WARNING: Only send coins here which are from coinjoins or otherwise not linked to your identity.")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        inputs.removeAll()
        isFidelity = false
    }
    
    private func addAddress(_ address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressInput.text = address
            self.addressImageView.alpha = 1
        }
    }
    
    @IBAction func scanNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerToGetAddress", sender: vc)
        }
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return outputs.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = view.backgroundColor
        if outputs.count > 0 {
            if outputs.count > 1 {
                tableView.separatorColor = .darkGray
                tableView.separatorStyle = .singleLine
            }
            let dict = outputs[indexPath.row]
            for (key, value) in dict {
                cell.textLabel?.text = "\n#\(indexPath.row + 1)\n\nSending: \(String(describing: value))\n\nTo: \(String(describing: key))"
                cell.textLabel?.textColor = .lightGray
            }
        } else {
           cell.textLabel?.text = ""
        }
        return cell
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: User Actions
    
    private func promptToSweep() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var title = "⚠️ Send total balance?"
            var message = "This action will send ALL the bitcoin this wallet holds to the provided address. If your fee is too low this transaction could get stuck for a long time."
            
            if self.inputs.count > 0 {
                title = "⚠️ Send total balance from the selected utxo's?"
                message = "You selected specific utxo's to sweep, this action will sweep \(self.utxoTotal) btc to the address you provide.\n\nIt is important to set a high fee as you may not use RBF if you sweep all your utxo's!"
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Send all", style: .default, handler: { action in
                self.sweep()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func sweepToMix(_ recipient: String) {
        guard let _ = jmWallet else { return }
        
        DispatchQueue.main.async {
            self.doubleAmount = 0.0
            self.performSegue(withIdentifier: "segueToConfirmCoinjoin", sender: self)
        }
    }
    
    private func handleJMResponse(_ response: [String:Any]?, _ message: String?) {
        self.spinner.removeConnectingView()

        var tit = ""
        var mess = ""

        if message == "Service already started." {
            tit = "JM Service already running."
            mess = "You need to quit the current service or restart the jmwalletd.py script."
        }

        if let response = response {
            if response.isEmpty {
                tit = "Coinjoin started ✓"
                mess = "You can monitor its status by refreshing the active wallet view. Coinjoin transactions may fail at which point you can try again by tapping the coinjoin button on the utxo."
            } else {
                tit = "JM response"
                mess = "\(response)"
            }
            
        } else if let message = message, message != "" {
            tit = "JM message:"
            mess = message

        } else {
            tit = "No response.."
            mess = "Usually after a succesful taker order JM replies with an empty response, this time we got nothing at all."
        }
        

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func sweepWallet(_ receivingAddress: String) {
        if isFidelity || isDirectSend {
            amount = "0"
            //chooseMixdepthToSpendFrom()
            self.directSend(mixdepth: mixdepthToSpendFrom)
        } else {
            sweepToMix(receivingAddress)
        }
    }
    
    private func sweep() {
        guard let receivingAddress = addressInput.text,
              receivingAddress != "" else {
                  showAlert(vc: self, title: "Add an address first", message: "")
                  return
              }
        
        spinner.addConnectingView(vc: self, description: "sweeping wallet...")
        sweepWallet(receivingAddress)
    }
    
    @IBAction func sweep(_ sender: Any) {
        promptToSweep()
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
        }
    }
    
    @objc func tryRaw() {
        spinner.addConnectingView(vc: self, description: "")
        
        if let amount = convertedAmount(), self.addressInput.text != "" {
            getRawTx(amount: amount.doubleValue, address: self.addressInput.text!)
            
        } else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "You need to fill out an amount and a recipient")
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
    }
        
    //MARK: Textfield methods
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField == amountInput, let text = textField.text else { return }
        
        if text.doubleValue > 0.0 {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 0
            }
        } else {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 1
            }
        }
        
        if text == "" {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 1
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountInput, let text = textField.text, string != "" else { return true }
        
        guard text.contains(".") else { return true }
        
        let arr = text.components(separatedBy: ".")
        
        guard arr.count > 0 else { return true }
        
        return arr[1].count < 8
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        if textField == addressInput && addressInput.text != "" {
            processBIP21(url: addressInput.text!)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    //MARK: Helpers
    
    func processBIP21(url: String) {
        let (address, amount, label, message) = AddressParser.parse(url: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressInput.resignFirstResponder()
            self.amountInput.resignFirstResponder()
            
            guard let address = address else {
                showAlert(vc: self, title: "Not compatible.", message: "FN does not support Bitpay.")
                return
            }
            
            self.addAddress(address)
            
            if amount != nil || label != nil || message != nil {
                var amountText = "not specified"
                
                if amount != nil {
                    amountText = amount!.avoidNotation
                    self.amountInput.text = amountText
                }
                
                showAlert(vc: self, title: "BIP21 Invoice\n", message: "Address: \(address)\n\nAmount: \(amountText) btc\n\nLabel: " + (label ?? "no label") + "\n\nMessage: \((message ?? "no message"))")
            }
        }
    }
    
    func getRawTx(amount: Double, address: String) {
        //self.chooseMixdepthToSpendFrom()
        if isDirectSend || isFidelity {
            self.directSend(mixdepth: mixdepthToSpendFrom)
        } else {
            promptToCoinjoinWithJM(wallet: self.jmWallet!, recipient: address, amount: amount)
        }
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == addressInput {
            if textField.text != "" {
                textField.becomeFirstResponder()
            } else {
                if let string = UIPasteboard.general.string {
                    textField.becomeFirstResponder()
                    textField.text = string
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned vc = self] in
                        textField.resignFirstResponder()
                        vc.processBIP21(url: string)
                    }
                } else {
                    textField.becomeFirstResponder()
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToScannerToGetAddress":
            guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
                        
            vc.onDoneBlock = { addrss in
                guard let addrss = addrss else { return }
                
                DispatchQueue.main.async { [unowned thisVc = self] in
                    thisVc.processBIP21(url: addrss)
                }
            }
            
        case "segueToConfirmCoinjoin":
            guard let vc = segue.destination as? ConfirmCoinjoinViewController else { fallthrough }
            
            vc.jmWallet = jmWallet!
            vc.amount = doubleAmount
            vc.mixdepth = self.mixdepthToSpendFrom
            vc.address = self.addressInput.text!
            vc.totalAvailable = self.balance
            
        case "segueToSendConfirmation":
            guard let vc = segue.destination as? ConfirmDirectSendViewController else { fallthrough }
            
            vc.jmWallet = jmWallet!
            vc.amount = doubleAmount
            vc.mixdepth = self.mixdepthToSpendFrom
            vc.address = self.addressInput.text!
            vc.totalAvailable = self.balance
            vc.isFidelity = isFidelity
            
        default:
            break
        }
    }
}
