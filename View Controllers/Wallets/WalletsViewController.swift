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
    private var wallets: [JMWallet] = []
    private var editButton = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        walletsTable.delegate = self
        walletsTable.dataSource = self
        
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editWallets))
        editButton.tintColor = .systemTeal
        self.navigationItem.setRightBarButtonItems([editButton], animated: true)
        
        CoreDataService.retrieveEntity(entityName: .jmWallets) { [weak self] jmWallets in
            guard let self = self else { return }
            
            guard let jmWallets = jmWallets else { return }
            
            for jmWallet in jmWallets {
                let w = JMWallet(jmWallet)
                wallets.append(w)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                walletsTable.reloadData()
            }
        }
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
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        label.text = wallets[indexPath.row].name
        let toggle = cell.viewWithTag(2) as! UISwitch
        toggle.isOn = wallets[indexPath.row].active
        toggle.restorationIdentifier = "\(indexPath.row)"
        toggle.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            deleteWallet(id: wallets[indexPath.row].id, indexPath: indexPath)
        }
    }
    
    private func deleteWallet(id: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: id, entityName: .jmWallets) { [unowned vc = self] success in
            if success {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.wallets.remove(at: indexPath.section)
                    vc.walletsTable.deleteSections(IndexSet.init(arrayLiteral: indexPath.section), with: .fade)
                }
            } else {
                displayAlert(viewController: vc,
                             isError: true,
                             message: "We had an error trying to delete that wallet.")
            }
        }
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {
        guard let restId = sender.restorationIdentifier, let index = Int(restId) else { return }
        
        guard let selectedCell = walletsTable.cellForRow(at: IndexPath.init(row: index, section: 0)) else {
            return
        }
        
        let toggle = selectedCell.viewWithTag(2) as! UISwitch
        
        CoreDataService.update(id: wallets[index].id, keyToUpdate: "active", newValue: toggle.isOn, entity: .jmWallets) { [weak self] success in
            guard let self = self else { return }
            
            guard success else { return }
            
            if wallets.count == 1 {
                reloadTable()
                
            } else {
                CoreDataService.retrieveEntity(entityName: .jmWallets) { [weak self] jmWallets in
                    guard let self = self else { return }
                    
                    guard let jmWallets = jmWallets else { return }
                    
                    //wallets.removeAll()
                    
                    for (i, jmWallet) in jmWallets.enumerated() {
                        if i != index {
                            let w = JMWallet(jmWallet)
                            
                            if w.id != wallets[index].id {
                                CoreDataService.update(id: w.id, keyToUpdate: "active", newValue: false, entity: .jmWallets) { deactivated in
                                    guard deactivated else {
                                        showAlert(vc: self, title: "", message: "There was an issue deactivating that wallet...")
                                        return
                                    }
                                }
                            }
                        }
                        
                        if i + 1 == jmWallets.count {
                            CoreDataService.retrieveEntity(entityName: .jmWallets) { wallets in
                                guard let wallets = wallets else { return }
                                
                                self.wallets.removeAll()
                                
                                for wallet in wallets {
                                    let jmw = JMWallet(wallet)
                                    self.wallets.append(jmw)
                                }
                            }
                        }
                        
                    }
                    reloadTable()
                }
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
