//
//  ActiveWalletViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletViewController: UIViewController {
    
    private var spinny: UIActivityIndicatorView = .init(style: .medium)
    private var onchainBalanceBtc = ""
    private var onchainBalanceFiat = ""
    private var sectionZeroLoaded = Bool()
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel: String!
    private var wallet: JMWallet?
    private var fxRate: Double?
    private var alertStyle = UIAlertController.Style.alert
    private let barSpinner = UIActivityIndicatorView(style: .medium)
    private let ud = UserDefaults.standard
    private let spinner = ConnectingView()
    private var dateFormatter = DateFormatter()
    private var initialLoad = true
    private var fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    private var utxos: [JMUtxo] = []
    private var isFidelity = false
    private var jmActive = false
    private var makerRunning = false
    private var takerRunning = false
    private var isDirectSend = false
    private var mixdepth = 0
    private var amountTotal = 0.0
    private var depositAddress: String?
    private var mixDepth0Balance = 0.0
    private var mixDepth1Balance = 0.0
    private var mixDepth2Balance = 0.0
    private var mixDepth3Balance = 0.0
    private var mixDepth4Balance = 0.0
    private var isLocalHost = false
    
    
    @IBOutlet weak private var coinjoinButtonOutlet: UIButton!
    @IBOutlet weak private var sendView: UIView!
    @IBOutlet weak private var jmMixView: UIView!
    @IBOutlet weak private var fidelityBondOutlet: UIButton!
    @IBOutlet weak private var jmActionOutlet: UIButton!
    @IBOutlet weak private var earnOutlet: UIButton!
    @IBOutlet weak private var jmStatusImage: UIImageView!
    @IBOutlet weak private var jmStatusLabel: UILabel!
    @IBOutlet weak private var jmVersionLabel: UILabel!
    @IBOutlet weak private var backgroundView: UIVisualEffectView!
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var invoiceView: UIView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    @IBOutlet weak private var blurView: UIVisualEffectView!
    @IBOutlet weak private var torProgressLabel: UILabel!
    @IBOutlet weak private var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshWallet), name: .refreshNode, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshWallet), name: .refreshWallet, object: nil)
        jmVersionLabel.text = ""
        UserDefaults.standard.setValue(false, forKey: "hasPromptedToRescan")
        walletTable.delegate = self
        walletTable.dataSource = self
        walletTable.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        configureUi()
        setNotifications()
        sectionZeroLoaded = false
        jmStatusImage.alpha = 0
        coinjoinButtonOutlet.isEnabled = false
        fidelityBondOutlet.alpha = 0
        jmStatusLabel.alpha = 0
        jmActionOutlet.alpha = 0
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = 8
        blurView.layer.zPosition = 1
        blurView.alpha = 0
        torProgressLabel.layer.zPosition = 1
        progressView.layer.zPosition = 1
        progressView.setNeedsFocusUpdate()
        addNavBarSpinner()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        if initialLoad {
            initialLoad = false
            if TorClient.sharedInstance.state != .connected && TorClient.sharedInstance.state != .started {
                TorClient.sharedInstance.start(delegate: self)
                checkIfHostIsLocal()
            } else {
                getFxRate()
            }
        }
    }
    
    private func checkIfHostIsLocal() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes else { return }
            for node in nodes {
                let n = NodeStruct(dictionary: node)
                guard let decryptedAddress = Crypto.decrypt(n.onionAddress), let address = String(data: decryptedAddress, encoding: .utf8) else { return }
                if n.isActive {
                    if address.hasPrefix("127.0.0.1") || address.hasPrefix("localhost") {
                        DispatchQueue.main.async { [weak self] in
                            self?.isLocalHost = true
                            self?.torProgressLabel.isHidden = true
                            self?.progressView.isHidden = true
                            self?.blurView.isHidden = true
                            self?.loadTable()
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func jmAction(_ sender: Any) {
        if makerRunning {
            stopMaker()
        } else if takerRunning {
            stopTaker()
        } else {
            startMaker()
        }
    }
    
    private func hideJmSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            spinny.stopAnimating()
            spinny.alpha = 0
            self.jmStatusImage.alpha = 1
            self.earnOutlet.tintColor = .systemTeal
            //self.jmMixView.alpha = 1
            coinjoinButtonOutlet.isEnabled = true
            self.earnOutlet.isEnabled = true
        }
    }
    
    private func setMakerStoppedUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmMixView.tintColor = .systemTeal
            self.earnOutlet.tintColor = .systemTeal
            //self.jmMixView.alpha = 1
            coinjoinButtonOutlet.isEnabled = true
            self.earnOutlet.isEnabled = true
            self.jmStatusImage.tintColor = .systemRed
            self.jmStatusLabel.text = "Maker stopped"
            self.jmActionOutlet.setTitle("Start", for: .normal)
            self.makerRunning = false
            self.jmActionOutlet.alpha = 1
            //jmMixView.alpha = 1
            //jmMixView.tintColor = .systemTeal
        }
    }
    
    private func setMakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabel.text = "Maker running"
            self.jmActionOutlet.alpha = 1
            self.jmActionOutlet.setTitle("Stop", for: .normal)
            self.makerRunning = true
            jmStatusImage.tintColor = .green
            //self.jmMixView.tintColor = .clear
            self.earnOutlet.tintColor = .clear
            coinjoinButtonOutlet.isEnabled = false
            //self.jmMixView.alpha = 0
            self.earnOutlet.isEnabled = false
        }
    }
    
    private func setTakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabel.text = "Coinjoin started"
            self.jmActionOutlet.setTitle("Stop", for: .normal)
            self.jmActionOutlet.alpha = 1
            self.jmActionOutlet.isEnabled = true
            self.takerRunning = true
            jmStatusImage.tintColor = .green
            //self.jmMixView.tintColor = .clear
            self.earnOutlet.tintColor = .clear
            //self.jmMixView.alpha = 1
            coinjoinButtonOutlet.isEnabled = false
            self.earnOutlet.isEnabled = false
        }
    }
        
    private func stopTaker() {
        addSpinny()
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
                hideJmSpinner()
                showAlert(vc: self, title: "", message: message)
                return
            }
            
            guard let _ = response else {
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
        
        //spinner.addConnectingView(vc: self, description: "Stopping maker...")
        addSpinny()
        
        JMUtils.stopMaker(wallet: wallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            hideJmSpinner()
            
            guard let response = response else {
                if let message = message, message != "" {
                    
                    if message.contains("Service cannot be stopped as it is not running.") {
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            jmStatusImage.tintColor = .systemRed
                            jmStatusLabel.text = "Maker stopped"
                            jmActionOutlet.setTitle("Start", for: .normal)
                            makerRunning = false
                            earnOutlet.tintColor = .systemTeal
                            earnOutlet.isEnabled = true
                            coinjoinButtonOutlet.isEnabled = true
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
                    
                    jmStatusImage.tintColor = .systemRed
                    jmStatusLabel.text = "Maker stopped"
                    jmActionOutlet.setTitle("Start", for: .normal)
                    makerRunning = false
                    earnOutlet.tintColor = .systemTeal
                    earnOutlet.isEnabled = true
                    coinjoinButtonOutlet.isEnabled = true
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
    
    @IBAction func coinjoinAction(_ sender: Any) {
        guard utxos.count > 0 else {
            showAlert(vc: self, title: "", message: "No utxos to coinjoin...")
            return
        }
        
        guard !makerRunning else {
            showAlert(vc: self, title: "Maker running.", message: "You need to stop the maker before creating a transaction.")
            return
        }
        
        guard !takerRunning else {
            showAlert(vc: self, title: "Taker running.", message: "You need to stop the taker before creating a transaction.")
            return
        }
        
        isDirectSend = false
        joinNow()
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
            self.jmStatusLabel.text = "Checking join market status..."
            self.jmStatusLabel.alpha = 1

            JMUtils.session { [weak self] (response, message) in
                guard let self = self else { return }
                guard let status = response else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.jmStatusLabel.text = "Join Market inactive"
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
    
    private func directSendNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Direct Send"
            let mess = "Select a mixdepth to spend from."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            
            if mixDepth0Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.directSend(mixdepth: 0)
                }))
            }
            
            if mixDepth1Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.directSend(mixdepth: 1)
                }))
            }
            
            if mixDepth2Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.directSend(mixdepth: 2)
                }))
            }
            
            if mixDepth3Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.directSend(mixdepth: 3)
                }))
            }
            
            if mixDepth4Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.directSend(mixdepth: 4)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func directSend(mixdepth: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            isDirectSend = true
            self.mixdepth = mixdepth
            performSegue(withIdentifier: "spendFromWallet", sender: self)
        }
    }
    
    private func joinNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Coinjoin"
            let mess = "This action will create a coinjoin transaction to the address of your choice.\n\nSpecify the mixdepth (account) you want to join from.\n\nOn the next screen you can select a recipient address and amount as normal. The fees will be determined as per your Join Market config."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            
            if mixDepth0Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.joinMixdepthNow(0)
                }))
            }
            
            if mixDepth1Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.joinMixdepthNow(1)
                }))
            }
            
            if mixDepth2Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.joinMixdepthNow(2)
                }))
            }
            
            if mixDepth3Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    self.joinMixdepthNow(3)
                }))
            }
            
            if mixDepth4Balance > 0.0 {
                alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.joinMixdepthNow(4)
                }))
            }
            

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
    
    
    private func hideData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onchainBalanceBtc = ""
            self.onchainBalanceFiat = ""
            self.sectionZeroLoaded = false
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
        configureButton(jmMixView)
        
        fxRateLabel.text = ""
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
    }
    
    private func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshWallet), name: .refreshWallet, object: nil)
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
        guard !makerRunning else {
            showAlert(vc: self, title: "Maker running.", message: "You need to stop the maker before creating a transaction.")
            return
        }
        
        guard !takerRunning else {
            showAlert(vc: self, title: "Taker running.", message: "You need to stop the taker before creating a transaction.")
            return
        }
        
        directSendNow()
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
                        promptToAddNode()
                        return
                    }
                                        
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
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
            self.removeSpinner()
        }
    }
    
    private func onchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OnBalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let iconImageView = cell.viewWithTag(67) as! UIImageView
        iconImageView.image = .init(systemName: "link")
        
        let onchainFiatLabel = cell.viewWithTag(2) as! UILabel
        onchainFiatLabel.text = onchainBalanceFiat
        
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0.00 000 000"
        }
                
        onchainBalanceLabel.text = onchainBalanceBtc
                
        return cell
    }
            
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
        
    @objc func refreshWallet() {
        refreshAll()
    }
    
    private func getFxRate() {
        FiatConverter.sharedInstance.getFxRate { [weak self] rate in
            guard let self = self else { return }
            
            guard let rate = rate else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.fxRateLabel.text = "no fx rate data"
                }
                if !isLocalHost {
                    loadTable()
                }
                return
            }
            
            self.fxRate = rate
            UserDefaults.standard.setValue(rate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRateLabel.text = rate.exchangeRate
                if !isLocalHost {
                    utxos.removeAll()
                    loadTable()
                }
            }
        }
    }
    
    private func dateFromStr(date: String) -> Date? {
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.date(from: date)
    }
    
    private func getWalletBalance() {
        utxos.removeAll()
        
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
            
            if utxos.count > 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.fidelityBondOutlet.alpha = 1
                }
            }
            
            
            var totalBalance = 0.0
            self.utxos.removeAll()
            for (i, utxo) in utxos.enumerated() {
                let utxo = JMUtxo(utxo)
                self.utxos.append(utxo)
                
                let amountBtc = utxo.value.satsToBtcDouble
                totalBalance += amountBtc
                
                if !utxo.frozen {
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
                
                if let _ = utxo.locktime {
                    DispatchQueue.main.async { [weak self] in
                        self?.fidelityBondOutlet.alpha = 0
                    }
                }
                
                if i + 1 == utxos.count {
                    self.utxos = self.utxos.sorted {
                        $0.confirmations < $1.confirmations
                    }
                    
                    if let rate = self.fxRate {
                        self.onchainBalanceFiat = (totalBalance * rate).fiatString
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
            
            let alert = UIAlertController(title: "\(wallet!.name) locked, unlock it?", message: "", preferredStyle: .alert)

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
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Create a wallet?", message: "Or do it later by tapping the + button in the top left.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "createFullyNodedWallet", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToChooseWallet() {
        removeSpinner()
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToImport", sender: self)
        }
    }
    
    private func goChooseWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToWallets", sender: vc)
        }
    }
    
    func reloadWalletData() {
        sectionZeroLoaded = false
        getWalletBalance()
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
        utxos.removeAll()
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
        }
        
        addNavBarSpinner()
        if isLocalHost {
            loadTable()
        }
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
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "segueToImport":
            guard let vc = segue.destination as? CreateFullyNodedWalletViewController else { fallthrough }
            
            vc.isImporting = true
            
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
            
            vc.jmWallet = wallet!
            
        case "segueToFidelity":
            guard let vc = segue.destination as? FidelityBondViewController else { fallthrough }
            
            vc.wallet = wallet!
                    
        default:
            break
        }
    }
}

extension ActiveWalletViewController: UTXOCellDelegate {
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
        
        switch section {
        case 0:
            if let w = self.wallet {
                textLabel.text = w.name
            }
            
        case 1:
            if self.utxos.count > 0 {
                textLabel.text = "Utxos"
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
                return 92
            } else {
                return 47
            }
        default:
            if sectionZeroLoaded, utxos.count > 0 {
                let utxo = utxos[indexPath.section - 1]
                if let _ = utxo.locktime {
                    return 300
                } else {
                    return 280
                }
//                
                //UITableView.automaticDimension
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
}



extension ActiveWalletViewController: OnionManagerDelegate {
    func torConnProgress(_ progress: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.text = "Tor bootstrapping \(progress)% complete"
            self?.progressView.setProgress(Float(Double(progress) / 100.0), animated: true)
            self?.blurView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
            self?.blurView.alpha = 1
        }
    }
    
    func torConnFinished() {
        // hide it and get fxRate
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.isHidden = true
            self?.progressView.isHidden = true
            self?.blurView.isHidden = true
        }
        
        getFxRate()
    }
    
    func torConnDifficulties() {
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.isHidden = true
            self?.progressView.isHidden = true
            self?.blurView.isHidden = true
        }
        
        // hide it with alert
    }
    
    
}
