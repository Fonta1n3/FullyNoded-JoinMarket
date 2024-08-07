//
//  ActiveWalletViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletViewController: UIViewController, UTXOCellDelegate {
    func didTapToUnfreeze(_ utxo: JMUtxo) {
        promptToUnfreeze(utxoString: utxo.utxoString)
    }
    
    
    func didTapToFreeze(_ utxo: JMUtxo) {
        spinner.addConnectingView(vc: self, description: "freezing utxo...")
        let p: [String: Any] = ["utxo-string": utxo.utxoString, "freeze": true]
        JMRPC.sharedInstance.command(method: .unfreeze(jmWallet: wallet!), param: p) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let _ = response else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: errorDesc ?? "Unknown issue unfreezing utxo...")
                return
            }
            
            loadTable()
        }
    }
    
    
    private var spinny: UIActivityIndicatorView = .init(style: .medium)
    private var pickerView: UIPickerView!
    private var datePickerView: UIVisualEffectView!
    private var onchainBalanceBtc = ""
    private var onchainBalanceFiat = ""
    private var sectionZeroLoaded = Bool()
    private var transactionArray = [[String:Any]]()
    private var tx = String()
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel:String!
    private var wallet: JMWallet?
    private var fxRate:Double?
    private var alertStyle = UIAlertController.Style.alert
    private let barSpinner = UIActivityIndicatorView(style: .medium)
    private let ud = UserDefaults.standard
    private let spinner = ConnectingView()
    private var hex = ""
    private var confs = 0
    private var txToEdit = ""
    private var memoToEdit = ""
    private var labelToEdit = ""
    private var psbt = ""
    private var rawTx = ""
    private var dateFormatter = DateFormatter()
    private var isFiat = false
    private var isBtc = true
    private var initialLoad = true
    private var isRecovering = false
    private var fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    private var utxos: [JMUtxo] = []
    private var selectedUTXOs: [JMUtxo] = []
    private var isFidelity = false
    private var jmActive = false
    private var makerRunning = false
    private var takerRunning = false
    private var isDirectSend = false
    private var mixdepth = 0
    private var amountTotal = 0.0
    private var inputArray:[[String:Any]] = []
    private var depositAddress: String?
    private var mixDepth0Balance = 0.0
    private var mixDepth1Balance = 0.0
    private var mixDepth2Balance = 0.0
    private var mixDepth3Balance = 0.0
    private var mixDepth4Balance = 0.0
    
    private let months = [
        ["January":"01"],
        ["February":"02"],
        ["March":"03"],
        ["April":"04"],
        ["May":"05"],
        ["June":"06"],
        ["July":"07"],
        ["August":"08"],
        ["September":"09"],
        ["October":"10"],
        ["November":"11"],
        ["December":"12"]
    ]
    
    private let years = [
        "2024",
        "2025",
        "2026",
        "2027"
    ]
    
    private var month = ""
    private var year = "2024"
    
    @IBOutlet weak private var jmActionOutlet: UIButton!
    @IBOutlet weak private var earnOutlet: UIButton!
    @IBOutlet weak private var jmMixOutlet: UIButton!
    @IBOutlet weak private var jmStatusImage: UIImageView!
    @IBOutlet weak private var jmStatusLabel: UILabel!
    @IBOutlet weak private var jmVersionLabel: UILabel!
    @IBOutlet weak private var backgroundView: UIVisualEffectView!
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var sendView: UIView!
    @IBOutlet weak private var invoiceView: UIView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        jmVersionLabel.text = ""
        UserDefaults.standard.setValue(false, forKey: "hasPromptedToRescan")
        walletTable.delegate = self
        walletTable.dataSource = self
        walletTable.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        configureUi()
        setNotifications()
        sectionZeroLoaded = false
        jmStatusImage.alpha = 0
        jmStatusLabel.alpha = 0
        jmActionOutlet.alpha = 0
        addNavBarSpinner()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        if initialLoad {
            initialLoad = false
            getFxRate()
        }
    }
    
    @IBAction func jmAction(_ sender: Any) {
        if makerRunning {
            stopMaker()
        } else if takerRunning {
            stopTaker()
        } else {
            //spinner.addConnectingView(vc: self, description: "starting maker bot...")
            startMaker()
        }
    }
    
    private func hideJmSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            spinny.stopAnimating()
            spinny.alpha = 0
            self.jmStatusImage.alpha = 1
            
            //self.jm.tintColor = .systemTeal
            self.earnOutlet.tintColor = .systemTeal
            self.jmMixOutlet.isEnabled = true
            self.earnOutlet.isEnabled = true
        }
    }
    
    private func setMakerStoppedUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmMixOutlet.tintColor = .systemTeal
            self.earnOutlet.tintColor = .systemTeal
            self.jmMixOutlet.isEnabled = true
            self.earnOutlet.isEnabled = true
            self.jmStatusImage.tintColor = .systemRed
            self.jmStatusLabel.text = "maker stopped"
            self.jmActionOutlet.setTitle("start", for: .normal)
            self.makerRunning = false
            self.jmActionOutlet.alpha = 1
        }
    }
    
    private func setMakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabel.text = "maker running"
            self.jmActionOutlet.alpha = 1
            self.makerRunning = true
            self.jmMixOutlet.tintColor = .clear
            self.earnOutlet.tintColor = .clear
            self.jmMixOutlet.isEnabled = false
            self.earnOutlet.isEnabled = false
        }
    }
    
    private func setTakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabel.text = "taker running"
            self.jmActionOutlet.setTitle("stop", for: .normal)
            self.jmActionOutlet.alpha = 1
            self.jmActionOutlet.isEnabled = true
            self.takerRunning = true
            self.jmMixOutlet.tintColor = .clear
            self.earnOutlet.tintColor = .clear
            self.jmMixOutlet.isEnabled = false
            self.earnOutlet.isEnabled = false
        }
    }
        
    private func stopTaker() {
        guard let wallet = wallet else { return }
        
        JMUtils.stopTaker(wallet: wallet) { (response, message) in
            guard message == nil else {
                if message!.contains("Service cannot be stopped as it is not running") {
                    self.getStatus(wallet)
                } else {
                    showAlert(vc: self, title: "There was an issue stopping the taker.", message: message ?? "Unknown.")
                }
                
                return
            }
            
            self.getStatus(wallet)
        }
    }
    
    private func startMaker() {
        addSpinny()
        guard let wallet = self.wallet else { return }
        
        JMUtils.startMaker(wallet: wallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            if let message = message {
                showAlert(vc: self, title: "", message: message)
                return
            }
            
            guard let response = response else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                
                getStatus(wallet)
            }
        }
    }
    
    private func stopMaker() {
        guard let wallet = self.wallet else { return }
        
        spinner.addConnectingView(vc: self, description: "stopping maker bot...")
        
        JMUtils.stopMaker(wallet: wallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
                if let message = message, message != "" {
                    
                    if message.contains("Service cannot be stopped as it is not running.") {
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.jmStatusImage.tintColor = .systemRed
                            self.jmStatusLabel.text = "maker stopped"
                            self.jmActionOutlet.setTitle("start", for: .normal)
                            self.makerRunning = false
                            self.earnOutlet.tintColor = .systemTeal
                            self.jmMixOutlet.tintColor = .systemTeal
                            self.earnOutlet.isEnabled = true
                            self.jmMixOutlet.isEnabled = true
                        }
                        
                        showAlert(vc: self, title: "Unable to stop maker...", message: "Looks like your maker never actually started, this can happen for a number of reasons.")
                        
                    } else {
                        showAlert(vc: self, title: "", message: message)
                    }
                }
                return
            }
            
            if response.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.jmStatusImage.tintColor = .systemRed
                    self.jmStatusLabel.text = "maker stopped"
                    self.jmActionOutlet.setTitle("start", for: .normal)
                    self.makerRunning = false
                    self.earnOutlet.tintColor = .systemTeal
                    self.jmMixOutlet.tintColor = .systemTeal
                    self.earnOutlet.isEnabled = true
                    self.jmMixOutlet.isEnabled = true
                }
            }
            
            if let message = message, message != "" {
                showAlert(vc: self, title: "", message: message)
            }
        }
    }
    
    
    @IBAction func allWalletsAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "segueToAllWallets", sender: self)
        }
    }
    
    @IBAction func mixAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "checking JM session status...")
        
        JMUtils.session { (response, message) in
            self.spinner.removeConnectingView()
            
            guard let session = response else {
                showAlert(vc: self, title: "Unable to fetch sesssion...", message: message ?? "Unknown error.")
                return
            }
            
            guard !session.coinjoin_in_process else {
                showAlert(vc: self, title: "Coinjoin already in process...", message: "Only one coinjoin session can be active at a time.")
                return
            }
                        
            if self.utxos.count > 1 {
                if self.selectedUTXOs.count > 0 {
                    showAlert(vc: self, title: "Coin control not yet supported for JM.", message: "You need to manually freeze your utxos using the JM wallet tool scripts.")
                } else {
                    self.joinNow()
                }
                
            } else {
                self.joinNow()
            }
        }
    }
    
    private func addSpinny() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusImage.alpha = 0
            spinny.frame = self.jmStatusImage.frame
            spinny.alpha = 1
            self.view.addSubview(spinny)
            spinny.startAnimating()
        }
    }
    
    private func getStatus(_ wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.addSpinny()
            self.jmStatusLabel.text = "checking join market status..."
            self.jmStatusLabel.alpha = 1

            JMUtils.session { [weak self] (response, message) in
                guard let self = self else { return }
                guard let status = response else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.jmStatusLabel.text = "join market inactive"
                        self.jmStatusImage.tintColor = .systemRed
                        self.hideJmSpinner()
                        showAlert(vc: self, title: "", message: "Join Market server doesn't seem to be responding, are you sure it is on?")
                    }
                    return
                }

                self.jmActive = true
                self.makerRunning = false
                self.takerRunning = false

                if status.coinjoin_in_process {
                    self.setTakerRunningUi()
                } else if status.maker_running {
                    self.setMakerRunningUi()
                 } else if !status.maker_running {
                    self.setMakerStoppedUi()
                }
                
                self.hideJmSpinner()
            }
        }
    }
    
    private func joinNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Join?"
            let mess = "This action will create a coinjoin transaction to the address of your choice.\n\nSpecify the mixdepth (account) you want to join from.\n\nOn the next screen you can select a recipient address and amount as normal. The fees will be determined as per your Join Market config."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(0)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(1)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(2)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(3)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.joinMixdepthNow(4)
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func joinMixdepthNow(_ mixdepth: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mixdepth = mixdepth
            self.performSegue(withIdentifier: "spendFromWallet", sender: self)
        }
    }
    
    @IBAction func createFidelityBondAction(_ sender: Any) {
        if let wallet = wallet {
            spinner.addConnectingView(vc: self, description: "checking fidelity bond status...")
            isFidelity = true
            JMUtils.fidelityStatus(wallet: wallet) { [weak self] (exists, message) in
                guard let self = self else { return }
                            
                guard let exists = exists, exists else {
                    guard self.selectedUTXOs.isEmpty else {
                        self.spinner.removeConnectingView()
                        showAlert(
                            vc: self,
                            title: "Fidelity Bond",
                            message: "This button is for Fidelity Bonds, deselect the utxos and try again."
                        )
                        return
                    }
                    self.promptToSelectTimelockDate()
                    return
                }
                self.showFidelityBondOptions(wallet)
            }
        }
    }
    
    private func showFidelityBondOptions(_ wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond"
            let mess = ""

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Unfreeze fb", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.unfreezeFb(wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                self.removeSpinner()
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func unfreezeFb(_ wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = "unfreezing fb utxo..."
            
            JMUtils.unfreezeFb(wallet: wallet) { (response, message) in
                self.spinner.removeConnectingView()
                
                guard let _ = response else {
                    showAlert(vc: self, title: "There was an issue...", message: message ?? "Unknown issue unfreezing utxo.")
                    return
                }
                
                guard let message = message else {
                    showAlert(vc: self, title: "Utxo unfrozen", message: "You should be able to join or earn with your expired fidelity bond funds now.")
                    return
                }
                
                showAlert(vc: self, title: "Message from JM:", message: message)
            }
        }
    }
    
    private func promptToUnfreeze(utxoString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Unfreeze?"
            let mess = "This utxo is frozen, would you like to unfreeze it?"

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Unfreeze", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                spinner.addConnectingView(vc: self, description: "unfreezing utxo...")
                let p: [String: Any] = ["utxo-string": utxoString, "freeze": false]
                JMRPC.sharedInstance.command(method: .unfreeze(jmWallet: self.wallet!), param: p) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    
                    guard let _ = response else {
                        spinner.removeConnectingView()
                        showAlert(vc: self, title: "", message: errorDesc ?? "Unknown issue unfreezing utxo...")
                        return
                    }
                    
                    loadTable()
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.removeSpinner()
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToSelectTimelockDate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond"
            let mess = "A fidelity bond is a timelocked bitcoin address.\n\nCreating a fidelity bond increases your earning potential. The higher the amount/duration of the bond, the higher the earning potential.\n\nYou will be prompted to select an expiry date for the bond, you will NOT be able to spend these funds until that date."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.selectTimelockDate()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.removeSpinner()
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func selectTimelockDate() {
        datePickerView = blurView()
        view.addSubview(datePickerView)
    }
    
    private func blurView() -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(frame: view.frame)
        blurView.effect = effect
        
        pickerView = UIPickerView(frame: .init(x: 0, y: 200, width: self.view.frame.width, height: 300))
        pickerView.delegate = self
        pickerView.dataSource = self
        blurView.contentView.addSubview(pickerView)
        
        let cal = Calendar.current
        var monthInt = cal.component(.month, from: Date())
        if monthInt == 12 {
            monthInt = 1
        } else {
            monthInt += 1
        }
        
        month = String(format: "%02d", monthInt)
        
        pickerView.selectRow(monthInt - 1, inComponent: 0, animated: true)
        
        let label = UILabel()
        label.textColor = .lightGray
        label.frame = CGRect(x: 16, y: pickerView.frame.minY - 40, width: pickerView.frame.width - 32, height: 40)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = "⚠️ Select the fidelity bond expiry date. Funds sent to the fidelity bond address will not be spendable until midnight (UTC) on the 1st day of the selected month/year."
        label.sizeToFit()
        blurView.contentView.addSubview(label)
        
        let button = UIButton()
        button.frame = CGRect(x: 0, y: pickerView.frame.maxY + 20, width: view.frame.width, height: 40)
        button.setTitle("Next", for: .normal)
        button.addTarget(self, action: #selector(closeDatePicker), for: .touchUpInside)
        button.setTitleColor(.systemTeal, for: .normal)
        blurView.contentView.addSubview(button)
        
        let cancel = UIButton()
        cancel.frame = CGRect(x: 0, y: button.frame.maxY + 20, width: view.frame.width, height: 40)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(cancelDatePicker), for: .touchUpInside)
        cancel.setTitleColor(.systemTeal, for: .normal)
        blurView.contentView.addSubview(cancel)
        
        return blurView
    }
    
    @objc func closeDatePicker() {
        datePickerView.removeFromSuperview()
        getFidelityAddress()
    }
    
    @objc func cancelDatePicker() {
        datePickerView.removeFromSuperview()
    }
    
    private func getFidelityAddress() {
        guard let wallet = wallet else {
            return
        }
        
        spinner.addConnectingView(vc: self, description: "getting timelocked address...")

        let date = "\(year)-\(month)"
        
        JMUtils.fidelityAddress(wallet: wallet, date: date) { [weak self] (address, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let address = address else {
                showAlert(vc: self, title: "Unable to fetch timelocked address...", message: message ?? "Unknown.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let tit = "Fidelity Bond"
                let mess = "This is a timelocked bitcoin address which prevents you from spending the funds until midnight on the 1st of \(date) (UTC).\n\nYou will be presented with the transaction creator as normal with the fidelity bond address automatically entered."

                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.isFidelity = true
                        self.depositAddress = address
                        self.performSegue(withIdentifier: "spendFromWallet", sender: self)
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func hideData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onchainBalanceBtc = ""
            self.onchainBalanceFiat = ""
            self.sectionZeroLoaded = false
            self.transactionArray.removeAll()
            self.walletTable.reloadData()
        }
    }
        
    
    
    private func configureButton(_ button: UIView) {
        button.layer.borderColor = UIColor.darkGray.cgColor
        button.layer.borderWidth = 0.5
        button.layer.cornerRadius = 5
    }
    
    private func configureUi() {
        configureButton(sendView)
        configureButton(invoiceView)
        
        fxRateLabel.text = ""
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
    }
    
    private func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshWallet), name: .refreshWallet, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLabel), name: .updateWalletLabel, object: nil)
    }
    
    @objc func updateLabel() {
        activeWallet { [weak self] wallet in
            guard let self = self, let wallet = wallet else { return }
                        
            self.walletLabel = wallet.name
            
            DispatchQueue.main.async {
                self.walletTable.reloadData()
            }
        }
    }
    
    @IBAction func getDetails(_ sender: Any) {
        guard let wallet = wallet else {
            showAlert(vc: self, title: "", message: "That button only works for \"Fully Noded Wallets\" which can be created by tapping the plus button, you can see your Fully Noded Wallets by tapping the squares button. Fully Noded allows you to access, use and create wallets with ultimate flexibility using your node but it comes with some limitations. In order to get a better user experience we recommend creating a Fully Noded Wallet.")
            return
        }
        
        walletLabel = wallet.name
        goToDetail()
    }
    
    @IBAction func goToFullyNodedWallets(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToWallets", sender: vc)
        }
    }
    
    @IBAction func createWallet(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "createFullyNodedWallet", sender: vc)
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            isDirectSend = true
            performSegue(withIdentifier: "spendFromWallet", sender: self)
        }
    }
    
    @IBAction func invoiceAction(_ sender: Any) {
        guard let _ = wallet else { return }
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToInvoice", sender: vc)
        }
    }
    
    @IBAction func goToUtxos(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToUtxos", sender: vc)
        }
    }
    
    private func loadTable() {
        isDirectSend = false
        isFidelity = false
        mixdepth = 0
        depositAddress = ""
        mixDepth0Balance = 0.0
        mixDepth1Balance = 0.0
        mixDepth2Balance = 0.0
        mixDepth3Balance = 0.0
        mixDepth4Balance = 0.0
        amountTotal = 0.0
        sectionZeroLoaded = false
        walletLabel = ""
        utxos.removeAll()
        
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            walletTable.reloadData()
        }
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
                    guard let self = self, let nodes = nodes else { return }
                    
                    guard nodes.count > 0 else {
                        finishedLoading()
                        promptToAddNode()
                        return
                    }
                    
                    // MARK: TODO!! Check for wallets here and prompt accordingly.
                    JMUtils.wallets { [weak self] (response, message) in
                        guard let self = self else { return }
                        
                        guard let wallets = response, wallets.count > 0 else {
                            if let message = message {
                                removeSpinner()
                                showAlert(vc: self, title: "Getting wallets failed.", message: message)
                            } else {
                                promptToCreateWallet()
                            }
                            return
                        }
                        promptToChooseWallet()
                    }
                }
                return
            }
            
            self.wallet = wallet
            self.walletLabel = wallet.name
            self.getWalletBalance()
        }
    }
    
    private func promptToAddNode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            
            let tit = "Connect to Join Market"
            
            let mess = "You need to connect to your Join Market node in order to use wallet features."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Connect", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "segueToAddNode", sender: self)
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToChooseJmWallet(jmWallets: [String]) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            self.spinner.removeConnectingView()
//            
//            let tit = "Join Market wallet"
//            
//            let mess = "Please select which wallet you'd like to use."
//            
//            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
//            for jmWallet in jmWallets {
//                alert.addAction(UIAlertAction(title: jmWallet, style: .default, handler: { [weak self] action in
//                    guard let self = self else { return }
//                    
//                    CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
//                        guard let wallets = wallets else { return }
//                        
//                        guard wallets.count > 0 else {
//                            showAlert(vc: self, title: "", message: "No existing wallets, tap the + button to create a wallet.")
//                            return
//                        }
//                        
//                        for wallet in wallets {
//                            if wallet["id"] != nil {
//                                let wStr = JMWallet(wallet)
//                                if wStr.isJm && wStr.jmWalletName == jmWallet {
//                                    UserDefaults.standard.set(wStr.name, forKey: "walletName")
//                                    self.wallet = wStr
//                                    self.walletLabel = wStr.label
//                                    self.loadBalances()
//                                }
//                            }
//                        }
//                    }
//                    
//                }))
//            }
//            
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
            self.removeSpinner()
        }
    }
    
    private func updateTransactionArray() {
       CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0, self.transactionArray.count > 0 else {
                self.finishedLoading()
                return
            }
            
            let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"

            for (i, transaction) in transactions.enumerated() {
                
               let localTransactionStruct = TransactionStruct(dictionary: transaction)
                
                for (t, tx) in self.transactionArray.enumerated() {
                    if (tx["txID"] as! String) == localTransactionStruct.txid {
                        self.transactionArray[t]["memo"] = localTransactionStruct.memo
                        self.transactionArray[t]["transactionLabel"] = localTransactionStruct.label
                        if let originRate = localTransactionStruct.fxRate, originRate > 0 {
                            if localTransactionStruct.fiatCurrency == currency {
                                self.transactionArray[t]["originRate"] = originRate
                            }
                        }
                    }

                    if i + 1 == transactions.count && t + 1 == self.transactionArray.count {
                        self.finishedLoading()
                    }
                }
            }
        }
    }
    
    
    @objc func goToDetail(_ sender: UIButton) {
        spinner.addConnectingView(vc: self, description: "getting raw transaction...")
        
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        let tx = transactionArray[int]
//        let id = tx["txID"] as! String
//        let param:Get_Tx = .init(["txid":id, "verbose": true])
//        Reducer.sharedInstance.makeCommand(command: .gettransaction(param)) { [weak self] (response, errorMessage) in
//            guard let self = self else { return }
//            self.spinner.removeConnectingView()
//            guard let dict = response as? NSDictionary, let hex = dict["hex"] as? String else {
//                showAlert(vc: self, title: "There was an issue getting the transaction.", message: errorMessage ?? "unknown error")
//                return
//            }
//            DispatchQueue.main.async {
//                self.confs = Int(tx["confirmations"] as! String)!
//                self.hex = hex
//                self.performSegue(withIdentifier: "segueToTxDetail", sender: self)
//            }
//        }
    }
    
    
    private func onchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OnBalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let iconImageView = cell.viewWithTag(67) as! UIImageView
        iconImageView.image = .init(systemName: "link")
        
        if let offchainBalanceLabel = cell.viewWithTag(2) as? UILabel, let offchainBalanceView = cell.viewWithTag(66) {
            offchainBalanceLabel.removeFromSuperview()
            offchainBalanceView.removeFromSuperview()
        }
        
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0.00 000 000"
        }
                
        if isBtc {
            onchainBalanceLabel.text = onchainBalanceBtc
        }
        
        if isFiat {
            onchainBalanceLabel.text = onchainBalanceFiat
        }
                
        return cell
    }
    
    private func transactionsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let categoryImage = cell.viewWithTag(1) as! UIImageView
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let confirmationsLabel = cell.viewWithTag(3) as! UILabel
        let dateLabel = cell.viewWithTag(5) as! UILabel
        let onchainImage = cell.viewWithTag(8) as! UIImageView
        let currentFiatValueLabel = cell.viewWithTag(9) as! UILabel
        let memoLabel = cell.viewWithTag(10) as! UILabel
        let transactionLabel = cell.viewWithTag(11) as! UILabel
        let seeDetailButton = cell.viewWithTag(14) as! UIButton
        let editLabelButton = cell.viewWithTag(15) as! UIButton
        
        amountLabel.alpha = 1
        confirmationsLabel.alpha = 1
        dateLabel.alpha = 1
        
        let index = indexPath.section - 1
                
        seeDetailButton.addTarget(self, action: #selector(goToDetail(_:)), for: .touchUpInside)
        seeDetailButton.restorationIdentifier = "\(index)"
        
        editLabelButton.addTarget(self, action: #selector(editTx(_:)), for: .touchUpInside)
        editLabelButton.restorationIdentifier = "\(index)"
        
        var dict = self.transactionArray[index]
        seeDetailButton.alpha = 1
        onchainImage.alpha = 1
        let confs = dict["confirmations"] as! String
        confirmationsLabel.text = confs + " " + "confs"
        dateLabel.text = dict["date"] as? String
        
        if dict["abandoned"] as? Bool == true {
            cell.backgroundColor = .red
        }
        
        let amountBtc = dict["amountBtc"] as! String
        let amountSats = dict["amountSats"] as! String
        let amountFiat = dict["amountFiat"] as! String
        editLabelButton.alpha = 1
        
        var gainText = ""
        
        if let originRate = dict["originRate"] as? Double {
            var btcAmount = 0.0
            
            btcAmount = amountBtc.doubleValue
            
            if btcAmount < 0.0 {
                btcAmount = btcAmount * -1.0
            }
            
            var originValueFiat = 0.0
            
            originValueFiat = btcAmount * originRate
            
            if originValueFiat < 0.0 {
                originValueFiat = originValueFiat * -1.0
            }
            
            if let exchangeRate = fxRate {
                var gain = round((btcAmount * exchangeRate) - originValueFiat)
                
                if Int(gain) > 0 {
                    gainText = " / gain of \(gain.fiatString) / \(Int((gain / originValueFiat) * 100.0))%"
                } else if Int(gain) < 0 {
                    gain = gain * -1.0
                    gainText = " / loss of \(gain.fiatString) / \(Int((gain / originValueFiat) * 100.0))%"
                }
            }
        }
        
        if let _ = fxRate {
            currentFiatValueLabel.text = amountFiat + gainText
        } else {
            currentFiatValueLabel.text = "current exchange rate missing"
        }
        
        memoLabel.text = dict["memo"] as? String ?? "no transaction memo"
        transactionLabel.text = dict["transactionLabel"] as? String ?? "no transaction label"
        
        if memoLabel.text == "" {
            memoLabel.text = "no transaction memo"
        }
        
        if transactionLabel.text == "" {
            transactionLabel.text = "no transaction label"
        }
        
        if amountBtc.hasPrefix("-") || amountSats.hasPrefix("-") {
            categoryImage.image = UIImage(systemName: "arrow.up.right")
            categoryImage.tintColor = .systemRed
            
            amountLabel.textColor = UIColor.darkGray
            
            var amountText = ""
            
            if isBtc {
                amountText = amountBtc
            } else {
                amountText = amountFiat
            }
            
            amountText = amountText.replacingOccurrences(of: "-", with: "")
            amountLabel.text = amountText
            
        } else {
            categoryImage.image = UIImage(systemName: "arrow.down.left")
            categoryImage.tintColor = .systemGreen
            amountLabel.textColor = .white
            
            var amountText = ""
            
            if isBtc {
                amountText = "+" + amountBtc
            } else {
                amountText = "+" + amountFiat
            }
            
            amountText = amountText.replacingOccurrences(of: "+", with: "")
            amountLabel.text = amountText
        }
        
        return cell
    }
        
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
        
    private func updateMemo(txid: String, memo: String) {
        addNavBarSpinner()
        
        CoreDataService.retrieveEntity(entityName: .transactions) { savedTxs in
            guard let savedTxs = savedTxs, savedTxs.count > 0 else {
                self.removeSpinner()
                return
            }
                        
            for savedTx in savedTxs {
                let txStruct = TransactionStruct(dictionary: savedTx)
                if txStruct.txid == txid {
                    CoreDataService.update(id: txStruct.id!, keyToUpdate: "memo", newValue: memo, entity: .transactions) { [weak self] updated in
                        guard let self = self else { return }
                        
                        if updated {
                            self.spinner.label.text = "reloading..."
                            self.addNavBarSpinner()
                            self.loadTable()
                            showAlert(vc: self, title: "Memo updated ✓", message: "")
                        } else {
                            self.removeSpinner()
                            showAlert(vc: self, title: "Error", message: "There was an issue updatinng your memo.")
                        }
                    }
                }
            }
        }
    }
    
    @objc func editTx(_ sender: UIButton) {
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        
        let tx = transactionArray[int]
        let id = tx["txID"] as! String
        
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                return
            }
            
            for transaction in transactions {
                let txStruct = TransactionStruct(dictionary: transaction)
                if txStruct.txid == id {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.txToEdit = id
                        self.memoToEdit = txStruct.memo
                        self.labelToEdit = txStruct.label
                        self.performSegue(withIdentifier: "segueToEditTx", sender: self)
                    }
                }
            }
        }
    }
    
    @objc func refreshWallet() {
        refreshAll()
    }
    
    
    private func loadBalances() {
        print("loadBalances")
    }
    
    private func chooseWallet() {
        print("chooseWallet")
    }
    
    
    private func getFxRate() {
        FiatConverter.sharedInstance.getFxRate { [weak self] rate in
            guard let self = self else { return }
            
            guard let rate = rate else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.fxRateLabel.text = "no fx rate data"
                }
                loadTable()
                return
            }
            
            self.fxRate = rate
            UserDefaults.standard.setValue(rate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRateLabel.text = rate.exchangeRate
                self.onchainBalanceFiat = (self.onchainBalanceBtc.doubleValue * Double(rate)).fiatString
                loadTable()
            }
        }
    }
    
    private func dateFromStr(date: String) -> Date? {
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.date(from: date)
    }
    
    private func getWalletBalance() {
        guard let wallet = wallet else {
            removeSpinner()
            
            CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
                guard let self = self else { return }
                
                guard let nodes = nodes, nodes.count > 0 else {
                    promptToAddNode()
                    return
                }
                
                CoreDataService.retrieveEntity(entityName: .jmWallets) { [weak self] jmWallets in
                    guard let self = self else { return }
                    
                    guard let jmWallets = jmWallets, jmWallets.count > 0 else {
                        promptToCreateWallet()
                        return
                    }
                    
                    promptToChooseWallet()
                }
            }
            
            
            return
        }
        
        JMRPC.sharedInstance.command(method: .listutxos(jmWallet: wallet), param: nil) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            removeSpinner()
            
            guard let response = response as? [String:Any] else {
                if errorDesc == "No nodes added." {
                    promptToAddNode()
                } else if errorDesc!.hasPrefix("Unauthorized") {
                    promptToUnlock()
                } else {
                    showAlert(vc: self, title: "", message: errorDesc ?? "Unknown issue getting jm utxos.")
                }
                
                return
            }
            
            guard let utxos = response["utxos"] as? [[String:Any]] else {
                return
            }
            
            var totalBalance = 0.0
            
            for (i, utxo) in utxos.enumerated() {
                let utxo = JMUtxo(utxo)
                self.utxos.append(utxo)
                
                if !utxo.frozen {
                    let amountBtc = utxo.value.satsToBtcDouble
                    totalBalance += amountBtc
                    
                    switch utxo.mixdepth {
                    case 0: mixDepth0Balance += utxo.value.satsToBtcDouble
                    case 1: mixDepth1Balance += utxo.value.satsToBtcDouble
                    case 2: mixDepth2Balance += utxo.value.satsToBtcDouble
                    case 3: mixDepth3Balance += utxo.value.satsToBtcDouble
                    case 4: mixDepth4Balance += utxo.value.satsToBtcDouble
                    default:
                        break
                    }
                }
                
                if i + 1 == utxos.count {
                    self.utxos = self.utxos.sorted {
                        $0.confirmations < $1.confirmations
                    }
                    self.finishedLoading()
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                totalBalance = Double(round(100000000 * totalBalance) / 100000000)
                self.onchainBalanceBtc = totalBalance.btcBalanceWithSpaces
                self.sectionZeroLoaded = true
                self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
            
                JMRPC.sharedInstance.command(method: .getinfo, param: nil) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    
                    guard let response = response as? [String: Any] else { return }
                    
                    guard let version = response["version"] as? String else { return }
                    
                    DispatchQueue.main.async {
                        self.jmVersionLabel.text = "Join Market v" + version
                    }
                    
                    getStatus(wallet)
                }
            }
        }
    }
    
    
    private func promptToUnlock() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Wallet locked, unlock it?", message: "", preferredStyle: .alert)

            alert.addTextField { passwordField1 in
                passwordField1.placeholder = "Password"
                passwordField1.isSecureTextEntry = true
            }

            alert.addAction(UIAlertAction(title: "Unlock \(wallet!.name)", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                
                let password = alert.textFields![0].text
                
                if let password = password {
                    spinner.addConnectingView(vc: self, description: "")
                    
                    JMUtils.unlockWallet(password: password, wallet: wallet!) { [weak self] (unlockedWallet, message) in
                        guard let self = self else { return }
                        
                        spinner.removeConnectingView()
                        
                        guard let _ = unlockedWallet else {
                            showAlert(vc: self, title: "Error unlocking your wallet...", message: message ?? "Unknown.")
                            return
                        }
                        
                        showAlert(vc: self, title: "", message: "\(wallet!.name.capitalized) unlocked ✓")
                        
                        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
                            guard let jmWallets = jmWallets else { return }
                            
                            for jmWallet in jmWallets {
                                let w = JMWallet(jmWallet)
                                
                                if w.active {
                                    self.wallet = w
                                    self.getWalletBalance()
                                }
                            }
                        }
                    }
                    
                } else {
                    showAlert(vc: self, title: "Passwords don't match...", message: "Try again.")
                }
                
            }))

            self.present(alert, animated: true, completion: nil)
        }
    }
    
   
    
    private func promptToRescan() {
        let hasPrompted = UserDefaults.standard.value(forKey: "hasPromptedToRescan") as? Bool ?? false
//        if !hasPrompted {
//            UserDefaults.standard.setValue(true, forKey: "hasPromptedToRescan")
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//                
//                let alert = UIAlertController(title: "No transactions found.", message: "Would you like to rescan the blockchain to search for transaction history and balances? Input the year you'd like to rescan from.", preferredStyle: self.alertStyle)
//                
//                let rescan = UIAlertAction(title: "Rescan", style: .default) { [weak self] (alertAction) in
//                    guard let self = self else { return }
//                    let textField = (alert.textFields![0] as UITextField)
//                    var blockheight = 0
//                    let currentYear = Int(Calendar.current.component(.year, from: .now))
//                    if let text = textField.text {
//                        var yearToScanFrom = Int(text) ?? 2009
//                        
//                        if yearToScanFrom <= currentYear {
//                            if yearToScanFrom < 2010 {
//                                yearToScanFrom = 2010
//                            }
//                            let yearsToScan = (currentYear - yearToScanFrom) + 1
//                            let blocksToScan = yearsToScan * 55000
//                            
//                            spinner.addConnectingView(vc: self, description: "rescanning...")
//                            
//                            OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
//                                guard let self = self else { return }
//                                
//                                guard let blockchainInfo = blockchainInfo else {
//                                    spinner.removeConnectingView()
//                                    showAlert(vc: self, title: "", message: message ?? "Unknown issue getblockchaininfo.")
//                                    return
//                                }
//                                
//                                if !blockchainInfo.initialblockdownload {
//                                    blockheight = blockchainInfo.blockheight - blocksToScan
//                                    
//                                    if blockchainInfo.pruned {
//                                        if blockheight < blockchainInfo.pruneheight {
//                                            blockheight = blockchainInfo.pruneheight
//                                        }
//                                    }
//                                    
//                                    OnchainUtils.rescanNow(from: blockheight) { [weak self] (started, message) in
//                                        guard let self = self else { return }
//                                        
//                                        guard started else {
//                                            spinner.removeConnectingView()
//                                            showAlert(vc: self, title: "", message: message ?? "Unknown issue from rescan.")
//                                            return
//                                        }
//                                        
//                                        self.spinner.removeConnectingView()
//                                        showAlert(vc: self, title: "", message: "Rescanning, you can refresh this page to see completion status.")
//                                    }
//                                } else {
//                                    spinner.removeConnectingView()
//                                    showAlert(vc: self, title: "", message: "Wait till your node is done syncing before attempting to rescan or use wallets.")
//                                }
//                            }
//                        }
//                    }
//                }
//                
//                alert.addTextField { (textField) in
//                    textField.placeholder = "From year"
//                    textField.keyboardAppearance = .dark
//                    textField.keyboardType = .numberPad
//                    textField.text = "2009"
//                }
//                
//                alert.addAction(rescan)
//                
//                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//                alert.popoverPresentationController?.sourceView = self.view
//                self.present(alert, animated: true, completion: nil)
//            }
//        }
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Create a wallet.", message: "Or do it later by tapping the + button in the top left.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tabBarController?.selectedIndex = 1
                    self.performSegue(withIdentifier: "createFullyNodedWallet", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToChooseWallet() {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            self.removeSpinner()
//            
//            let alert = UIAlertController(title: "None of your wallets seem to be toggled on, please choose which wallet you want to use.", message: "", preferredStyle: self.alertStyle)
//            
//            alert.addAction(UIAlertAction(title: "Activate a Fully Noded wallet", style: .default, handler: { action in
//                DispatchQueue.main.async { [weak self] in
//                    guard let self = self else { return }
//                    
//                    self.tabBarController?.selectedIndex = 1
//                    self.goChooseWallet()
//                }
//            }))
//            
//            CoreDataService.retrieveEntity(entityName: .wallets) { potentialJmWallets in
//                guard let potentialJmWallets = potentialJmWallets else { return }
//                
//                var showJMOption = false
//                
//                for (i, potentialJmWallet) in potentialJmWallets.enumerated() {
//                    if potentialJmWallet["id"] != nil {
//                        let wStr = JMWallet(potentialJmWallet)
//                        showJMOption = true
//                        
//                        if i + 1 == potentialJmWallets.count && showJMOption {
//                            alert.addAction(UIAlertAction(title: "Activate a Join Market wallet", style: .default, handler: { action in
//                                DispatchQueue.main.async { [weak self] in
//                                    guard let self = self else { return }
//                                    
//                                    JMUtils.wallets { (response, message) in
//                                        guard let jmwallets = response else {
//                                            self.finishedLoading()
//                                            showAlert(vc: self, title: "", message: message ?? "Unknown issue getting your JM wallets.")
//                                            return
//                                        }
//                                        
//                                        if jmwallets.count > 0 {
//                                            self.promptToChooseJmWallet(jmWallets: jmwallets)
//                                        }
//                                    }
//                                }
//                            }))
//                        }
//                    }
//                }
//            }
//            
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
    }
    
    private func goChooseWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToWallets", sender: vc)
        }
    }
    
    func reloadWalletData() {
        transactionArray.removeAll()
        sectionZeroLoaded = false
        self.getWalletBalance()
    }
    
    private func loadTransactions() {
        transactionArray.removeAll()
        
        NodeLogic.loadSectionTwo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeSpinner()
                
                guard let errorMessage = errorMessage else {
                    return
                }
                showAlert(vc: self, title: "", message: errorMessage)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.transactionArray = response
                
                if transactionArray.count == 0 {
                    promptToRescan()
                }
                
                self.updateTransactionArray()
                self.isRecovering = false
            }
        }
    }
    
    private func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.barSpinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.barSpinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.barSpinner.startAnimating()
            self.barSpinner.alpha = 1
        }
    }
    
    private func removeSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            self.barSpinner.stopAnimating()
            self.barSpinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            self.refreshButton.tintColor = UIColor.lightGray.withAlphaComponent(1)
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    private func refreshAll() {
        sectionZeroLoaded = false
        wallet = nil
        walletLabel = nil
        onchainBalanceFiat = ""
        onchainBalanceBtc = ""
        transactionArray.removeAll()
        utxos.removeAll()
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
        }
        
        addNavBarSpinner()
        getFxRate()
    }
    
    @objc func refreshData(_ sender: Any) {
        refreshAll()
    }
    
    private func goToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToActiveWalletDetail", sender: vc)
        }
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
        }
    }
    
    @objc func filterTxs(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("filterTxs")
//            for (i, tx) in self.transactionArray.enumerated() {
//                if let isOnchain = tx["onchain"] as? Bool, isOnchain, let isLightning = tx["isLightning"] as? Bool, !isLightning {
//                    self.onchainTxArray.append(tx)
//                }
//                
//                if i + 1 == self.transactionArray.count, self.onchainTxArray.count > 0 {
//                    self.showOnchainOnly = true
//                    self.showOffchain = false
//                    self.reloadTable()
//                }
//            }
        }
    }
    
    @objc func sortTxs(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Sort by", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Amount", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.transactionArray = self.transactionArray.sorted{ ($0["amountBtc"] as! String).doubleValue > ($1["amountBtc"] as! String).doubleValue }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Newest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.transactionArray = self.transactionArray.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                
                self.reloadTable()
                
            }))
            
            alert.addAction(UIAlertAction(title: "Oldest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.transactionArray = self.transactionArray.sorted{ ($0["sortDate"] as? Date ?? Date()) < ($1["sortDate"] as? Date ?? Date()) }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func updateSelectedUtxos() {
        selectedUTXOs.removeAll()
        
        for utxo in utxos {
            if utxo.isSelected {
                selectedUTXOs.append(utxo)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "spendFromWallet":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            vc.isFidelity = isFidelity
            vc.isDirectSend = isDirectSend
            vc.mixdepthToSpendFrom = mixdepth
            vc.jmWallet = wallet
            vc.utxoTotal = amountTotal
            vc.address = depositAddress ?? ""
            
            switch mixdepth {
            case 0: vc.balance = mixDepth0Balance.btcBalanceWithSpaces
            case 1: vc.balance = mixDepth1Balance.btcBalanceWithSpaces
            case 2: vc.balance = mixDepth2Balance.btcBalanceWithSpaces
            case 3: vc.balance = mixDepth3Balance.btcBalanceWithSpaces
            case 4: vc.balance = mixDepth4Balance.btcBalanceWithSpaces
                
            default:
                vc.balance = onchainBalanceBtc
            }
                        
        case "segueToAddNode":
            guard let vc = segue.destination as? NodeDetailViewController else { fallthrough }
        
            vc.createNew = true
        
        case "segueToInvoice":
            guard let vc = segue.destination as? InvoiceViewController else { fallthrough }
            
            vc.isBtc = isBtc
            vc.isFiat = isFiat
            vc.jmWallet = wallet!
        
        case "segueToSignPsbt":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.unsignedPsbt = self.psbt.condenseWhitespace()
            vc.signedRawTx = self.rawTx.condenseWhitespace()
            
        case "segueToEditTx":
            guard let vc = segue.destination as? TransactionLabelMemoViewController else { fallthrough }
            
            vc.memoText = memoToEdit
            vc.labelText = labelToEdit
            vc.txid = txToEdit
            vc.doneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                showAlert(vc: self, title: "", message: "Transaction updated ✓")
                self.spinner.addConnectingView(vc: self, description: "refreshing transactions...")
                self.loadTransactions()
            }
            
        case "segueToTxDetail":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.alreadyBroadcast = true
            vc.signedRawTx = hex
            vc.confs = confs
            
        case "segueToUtxos":
            guard let vc = segue.destination as? UTXOViewController else { fallthrough }
            
            vc.fxRate = fxRate
            vc.isBtc = isBtc
            vc.isFiat = isFiat
            
        case "segueToActiveWalletDetail":
            guard let vc = segue.destination as? WalletDetailViewController else { fallthrough }
            
            guard let idDetail = self.wallet?.id else {
                showAlert(vc: self, title: "", message: "Fully Noded can only show wallet details for wallets created with Fully Noded.")
                return
            }
                        
            vc.walletId = idDetail
            
        case "chooseAWallet":
            print("segueToChooseWallet")
//            guard let vc = segue.destination as? ChooseWalletViewController else { fallthrough }
//            
//            vc.wallets = wallets
//            
//            vc.doneBlock = { result in
//                self.loadTable()
//            }
            
//        case "segueToAccountMap":
//            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
//            
//            if let json = CreateAccountMap.create(wallet: wallet!) {
//                vc.text = json
//            }
            
        case "createFullyNodedWallet":
            guard let vc = segue.destination as? CreateFullyNodedWalletViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.refreshWallet()
                    
                    guard let uncleJim = UserDefaults.standard.object(forKey: "UncleJim") as? Bool, uncleJim else {
                        //showAlert(vc: self, title: "Wallet imported ✓", message: "Your node is now rescanning the blockchain you can monitor rescan status by refreshing this page, balances and historic transactions will not display until the rescan completes.\n\n⚠️ Always verify the addresses match what you expect them to. Just tap the info button above and scroll down till you see the address explorer.")
                        
                        return
                    }
                    
                    showAlert(vc: self, title: "Wallet imported ✓", message: "")
                }
            }
                    
        default:
            break
        }
    }
}

extension ActiveWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if sectionZeroLoaded {
                return onchainBalancesCell(indexPath)
            } else {
                return blankCell()
            }
        default:
            
            
            if utxos.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
                let utxo = utxos[indexPath.section - 1]
                
                cell.configure(
                    utxo: utxo,
                    fxRate: fxRate,
                    delegate: self
                )
                return cell
            } else {
               return blankCell()
            }
            
            
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 400, height: 50)
        
        let filterButton = UIButton()
        let filterImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: UIImage.SymbolConfiguration.init(scale: .large))
        filterButton.setImage(filterImage, for: .normal)
        filterButton.frame = CGRect(x: header.frame.size.width - 50, y: 0, width: 50, height: 50)
        filterButton.tintColor = .systemTeal
        filterButton.center.y = textLabel.center.y
        //filterButton.showsTouchWhenHighlighted = true
        filterButton.addTarget(self, action: #selector(filterTxs(_:)), for: .touchUpInside)
        
        let sortButton = UIButton()
        let sortImage = UIImage(systemName: "arrow.up.arrow.down.circle", withConfiguration: UIImage.SymbolConfiguration.init(scale: .large))
        sortButton.setImage(sortImage, for: .normal)
        sortButton.frame = CGRect(x: filterButton.frame.minX - 60, y: 0, width: 50, height: 50)
        sortButton.tintColor = .systemTeal
        sortButton.center.y = textLabel.center.y
        //sortButton.showsTouchWhenHighlighted = true
        sortButton.addTarget(self, action: #selector(sortTxs(_:)), for: .touchUpInside)
        
        switch section {
        case 0:
            if let w = self.wallet {
                textLabel.text = w.name
            }
            
        case 1:
            if self.transactionArray.count > 0 {
                textLabel.text = "Transactions"
                header.addSubview(filterButton)
                header.addSubview(sortButton)
            } else {
                textLabel.text = ""
            }
            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 || section == 1 {
            return 50
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            if sectionZeroLoaded {
                return 80
            } else {
                return 47
            }
        default:
            if sectionZeroLoaded {
                return 256
            } else {
                return 47
            }
        }
    }
}

extension ActiveWalletViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if utxos.count > 0 {
            return 1 + utxos.count

        } else {
            return 2
        }
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let cell = tableView.cellForRow(at: indexPath) as! UTXOCell
//        let utxo = utxos[indexPath.section - 1]
//        let isSelected = utxo.isSelected
//        
//        if isSelected {
//            cell.deselectedAnimation()
//        } else {
//            cell.selectedAnimation()
//        }
//        
//        utxos[indexPath.section - 1].isSelected = !isSelected
//        
//        updateSelectedUtxos()
//        
//        tableView.deselectRow(at: indexPath, animated: false)
//    }
}

extension ActiveWalletViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0:
            return months.count
        case 1:
            return years.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        var toReturn:String?
        switch component {
        case 0:
            let dict = months[row]
            for (key, _) in dict {
                toReturn = key
            }
        case 1:
            toReturn = years[row]
        default:
            break
        }
        
        return toReturn
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            let dict = months[row]
            for (_, value) in dict {
                month = value
            }
        case 1:
            year = years[row]
        default:
            break
        }
    }
}
