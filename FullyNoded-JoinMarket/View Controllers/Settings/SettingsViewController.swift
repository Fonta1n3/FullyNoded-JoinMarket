//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import Foundation

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource  {
    
    var isApi = false
    var isCurrency = false
    let ud = UserDefaults.standard
    let spinner = ConnectingView()
    @IBOutlet var settingsTable: UITableView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        settingsTable.reloadData()
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
    }
    
    private func settingsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let settingsCell = settingsTable.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        configureCell(settingsCell)
        
        let label = settingsCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = settingsCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let icon = settingsCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        switch indexPath.section {
        case 0:
            label.text = "Node manager"
            icon.image = UIImage(systemName: "desktopcomputer")
            background.backgroundColor = .systemBlue
            
        case 1:
            if useBlockchainInfo {
                label.text = "Blockchain.info"
            } else {
                label.text = "Coindesk"
            }
            
            icon.image = UIImage(systemName: "server.rack")
            background.backgroundColor = .systemGreen
            
        case 2:
            let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
            label.text = currencyToUse
            background.backgroundColor = .systemGray
                
            for dict in Currencies.currenciesWithCircle {
                for (key, value) in dict {
                    if currencyToUse == key {
                        label.text = key
                        icon.image = UIImage(systemName: value)
                    }
                }
            }
            
        default:
            break
        }
        
        return settingsCell
    }
    
    
//    func blockchainInfoCell(_ indexPath: IndexPath) -> UITableViewCell {
//        let blockchainInfoCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleFxrateCell", for: indexPath)
//        configureCell(blockchainInfoCell)
//        
//        let label = blockchainInfoCell.viewWithTag(1) as! UILabel
//        label.textColor = .lightGray
//        label.adjustsFontSizeToFitWidth = true
//        
//        let background = blockchainInfoCell.viewWithTag(2)!
//        background.clipsToBounds = true
//        background.layer.cornerRadius = 8
//        
//        let icon = blockchainInfoCell.viewWithTag(3) as! UIImageView
//        icon.tintColor = .white
//        
//        let toggle = blockchainInfoCell.viewWithTag(4) as! UISwitch
//        toggle.addTarget(self, action: #selector(toggleBlockchainInfo(_:)), for: .valueChanged)
//        
//        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
//        
//        toggle.setOn(useBlockchainInfo, animated: true)
//        label.text = "Blockchain.info"
//        icon.image = UIImage(systemName: "dollarsign.circle")
//        
//        if useBlockchainInfo {
//            background.backgroundColor = .systemBlue
//        } else {
//            background.backgroundColor = .systemGray
//        }
//        
//        return blockchainInfoCell
//    }
    
    
//    func coinDeskCell(_ indexPath: IndexPath) -> UITableViewCell {
//        let coinDeskCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleFxrateCell", for: indexPath)
//        configureCell(coinDeskCell)
//        
//        let label = coinDeskCell.viewWithTag(1) as! UILabel
//        label.textColor = .lightGray
//        label.adjustsFontSizeToFitWidth = true
//        
//        let background = coinDeskCell.viewWithTag(2)!
//        background.clipsToBounds = true
//        background.layer.cornerRadius = 8
//        
//        let icon = coinDeskCell.viewWithTag(3) as! UIImageView
//        icon.tintColor = .white
//        
//        let toggle = coinDeskCell.viewWithTag(4) as! UISwitch
//        toggle.addTarget(self, action: #selector(toggleCoindesk(_:)), for: .valueChanged)
//        
//        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
//        
//        toggle.setOn(!useBlockchainInfo, animated: true)
//        label.text = "Coindesk"
//        icon.image = UIImage(systemName: "dollarsign.circle")
//        
//        if useBlockchainInfo {
//            background.backgroundColor = .systemGray
//        } else {
//            background.backgroundColor = .systemBlue
//        }
//        
//        return coinDeskCell
//    }
    
    
//    func currencyCell(_ indexPath: IndexPath, _ currency: [String:String]) -> UITableViewCell {
//        let currencyCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCurrencyCell", for: indexPath)
//        configureCell(currencyCell)
//        
//        let label = currencyCell.viewWithTag(1) as! UILabel
//        label.textColor = .lightGray
//        label.adjustsFontSizeToFitWidth = true
//        
//        let background = currencyCell.viewWithTag(2)!
//        background.clipsToBounds = true
//        background.layer.cornerRadius = 8
//                
//        let icon = currencyCell.viewWithTag(3) as! UIImageView
//        icon.tintColor = .white
//        
//        let toggle = currencyCell.viewWithTag(4) as! UISwitch
//        let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
//        
//        for (key, value) in currency {
//            if currencyToUse == key {
//                background.backgroundColor = .systemGreen
//            } else {
//                background.backgroundColor = .systemGray
//            }
//            
//            toggle.restorationIdentifier = key
//            toggle.setOn(currencyToUse == key, animated: true)
//            
//            label.text = key
//            icon.image = UIImage(systemName: value)
//        }
//        
//        toggle.addTarget(self, action: #selector(toggleCurrency(_:)), for: .valueChanged)
//        
//        return currencyCell
//    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        switch indexPath.section {
//        case 0:
//            return settingsCell(indexPath)
//            
//        case 1:
//            if indexPath.row == 0 {
//                return blockchainInfoCell(indexPath)
//            } else {
//                return coinDeskCell(indexPath)
//            }
//            
//        case 2:
//            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
//            
//            var currencies:[[String:String]] = blockchainInfoCurrencies
//            
//            if !useBlockchainInfo {
//                currencies = coindeskCurrencies
//            }
//            
//            return currencyCell(indexPath, currencies[indexPath.row])
//            
//        default:
//            return UITableViewCell()
//        }
        
        return settingsCell(indexPath)
    }
    
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        switch section {
        case 0:
            textLabel.text = "Nodes"
                        
        case 1:
            textLabel.text = "Exchange Rate API"
            
        case 2:
            textLabel.text = "Fiat Currency"
            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        impact()
        
        switch indexPath.section {
        case 0:
            isApi = false
            isCurrency = false
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "goToNodes", sender: self)
            }
            
        case 1:
            isApi = true
            isCurrency = false
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "segueToSettingsDetail", sender: self)
            }
        
            
        default:
            isApi = false
            isCurrency = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "segueToSettingsDetail", sender: self)
            }
            
        }
    }
    
    
//    @objc func toggleCurrency(_ sender: UISwitch) {
//        let currency = sender.restorationIdentifier!
//        
//        if sender.isOn {
//            UserDefaults.standard.setValue(currency, forKey: "currency")
//        } else {
//            UserDefaults.standard.setValue("USD", forKey: "currency")
//        }
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 2), with: .fade)
//        }
//    }

    
//    private func saveFile(_ file: [String:Any]) {
//        let fileManager = FileManager.default
//        let fileURL = fileManager.temporaryDirectory.appendingPathComponent("wallets.fullynoded")
//        
//        guard let json = file.json() else { showAlert(vc: self, title: "", message: "Unable to convert your backup data into json..."); return }
//        
//        try? json.utf8.write(to: fileURL)
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            var controller:UIDocumentPickerViewController!
//            
//            if #available(iOS 14, *) {
//                controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
//            } else {
//                controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
//            }
//            
//            self.present(controller, animated: true)
//        }
//    }
    
    
//    @objc func toggleBlockchainInfo(_ sender: UISwitch) {
//        UserDefaults.standard.setValue(sender.isOn, forKey: "useBlockchainInfo")
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1, 2), with: .fade)
//        }
//    }
    
    
//    @objc func toggleCoindesk(_ sender: UISwitch) {
//        UserDefaults.standard.setValue(!sender.isOn, forKey: "useBlockchainInfo")
//        
//        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
//        
//        if sender.isOn {
//            switch currency {
//            case "USD", "GBP", "EUR":
//                fallthrough
//            default:
//                UserDefaults.standard.setValue("USD", forKey: "currency")
//            }
//        }
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1, 2), with: .fade)
//        }
//    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToSettingsDetail":
            guard let vc = segue.destination as? SettingsDetailTableViewController else { fallthrough }
            
            vc.isApi = isApi
            vc.isCurrency = isCurrency
            
        default:
            break
        }
    }
        
}



