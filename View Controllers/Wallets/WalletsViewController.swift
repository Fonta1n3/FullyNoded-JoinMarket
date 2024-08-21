//
//  WalletsViewController.swift
//  FullyNoded-JoinMarket
//
//  Created by Peter Denton on 8/2/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import UIKit

class WalletsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {    
    
    @IBOutlet var walletsTable: UITableView!
    private var editButton = UIBarButtonItem()
    private var wallets: [JMWallet] = []
    private var activeWallet = ""
    private let spinner = ConnectingView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        walletsTable.delegate = self
        walletsTable.dataSource = self
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editWallets))
        editButton.tintColor = .systemTeal
        self.navigationItem.setRightBarButtonItems([editButton], animated: true)
        load()
    }
    
    func load() {
        spinner.addConnectingView(vc: self, description: "")
        wallets.removeAll()
        activeWallet = ""
        
        JMUtils.wallets { [weak self] (response, message) in
            guard let self = self else { return }
            
            spinner.removeConnectingView()
            
            guard let response = response, response.count > 0 else {
                showAlert(vc: self, title: "", message: "No wallets yet.")
                return
            }
            
            CoreDataService.retrieveEntity(entityName: .jmWallets) { [weak self] jmWallets in
                guard let self = self else { return }
                
                guard let jmWallets = jmWallets else { return }
                
                for jmWallet in jmWallets {
                    let w = JMWallet(jmWallet)
                    if response.contains(w.name) {
                        wallets.append(w)
                    }
                }
                
                JMUtils.session { (response, message) in
                    guard let session = response else { return }
                    
                    if let activeWallet = session.wallet_name {
                        self.activeWallet = activeWallet
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        walletsTable.reloadData()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedWallet = wallets[indexPath.row]
        if selectedWallet.name == activeWallet {
            promptToLock(wallet: selectedWallet)
        } else {
            for (i, wallet) in wallets.enumerated() {
                if wallet.active && wallet.id != selectedWallet.id {
                    CoreDataService.update(id: wallet.id, keyToUpdate: "active", newValue: false, entity: .jmWallets) { _ in }
                }
                if wallet.id == selectedWallet.id {
                    CoreDataService.update(id: wallet.id, keyToUpdate: "active", newValue: true, entity: .jmWallets) { [weak self] activated in
                        guard let self = self else { return }
                        if activated {
                            load()                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil)
                            }
                        } else {
                            showAlert(vc: self, title: "", message: "There was an issue activating your wallet.")
                        }
                    }
                }
            }
        }
    }
    
    func promptToLock(wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Lock \(wallet.name)?", message: "", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Lock \(wallet.name)", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                spinner.addConnectingView(vc: self, description: "")
                
                JMUtils.lockWallet(wallet: wallet) { [weak self] (locked, message) in
                    guard let self = self else { return }
                    spinner.removeConnectingView()
                    
                    if locked {
                        showAlert(vc: self, title: "", message: "\(wallet.name) locked ✓")
                        load()
                    } else {
                        showAlert(vc: self, title: "Not locked...", message: message ?? "Unknown issue locking \(wallet.name).")
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        let wallet = wallets[indexPath.row]
        let label = cell.viewWithTag(1) as! UILabel
        let tapToLock = cell.viewWithTag(2) as! UILabel
        label.text = wallet.name
        
        if wallet.name == activeWallet {
            tapToLock.alpha = 1
        } else {
            tapToLock.alpha = 0
        }
        
        cell.isSelected = wallet.active
        
        if wallet.active {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
        
    }
    
    @objc func editWallets() {
        walletsTable.setEditing(!walletsTable.isEditing, animated: true)
        
        if walletsTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editWallets))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editWallets))
        }
        
        editButton.tintColor = .systemTeal
        
        self.navigationItem.setRightBarButtonItems([editButton], animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            deleteWallet(id: wallets[indexPath.row].id, indexPath: indexPath)
        }
    }
    
    private func deleteWallet(id: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: id, entityName: .jmWallets) { [weak self]
            success in
            guard let self = self else { return }
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    wallets.remove(at: indexPath.row)
                    walletsTable.deleteRows(at: [indexPath], with: .fade)
                }
            } else {
                showAlert(vc: self, title: "", message: "We had an error trying to delete that wallet.")
            }
        }
    }
    
    
    private func reloadTable() {
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            walletsTable.reloadData()
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
