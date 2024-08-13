//
//  ConfirmCoinjoinTableViewController.swift
//  FullyNoded-JoinMarket
//
//  Created by Peter Denton on 8/12/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import UIKit

class SettingsDetailTableViewController: UITableViewController {
    
    var isApi: Bool!
    var isCurrency: Bool!
    
    let ud = UserDefaults.standard

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if isApi {
            navigationItem.title = "Exchange Rate API"
        } else {
            navigationItem.title = "Currency"
        }
        
        if UserDefaults.standard.object(forKey: "useBlockchainInfo") == nil {
            UserDefaults.standard.set(true, forKey: "useBlockchainInfo")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        if isCurrency {
            if useBlockchainInfo {
                return Currencies.currenciesWithCircle.count
            } else {
                return Currencies.coindeskCurrencies.count
            }
        } else if isApi {
            return 2
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isApi {
            switch indexPath.row {
            case 0: UserDefaults.standard.setValue(true, forKey: "useBlockchainInfo")
            case 1: UserDefaults.standard.setValue(false, forKey: "useBlockchainInfo")
            default:
                break
            }
            
            DispatchQueue.main.async {
                tableView.reloadData()
            }
        } else if isCurrency {
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            var currencies:[[String:String]] = []
            UserDefaults.standard.removeObject(forKey: "fxRate")
            if useBlockchainInfo {
                currencies = Currencies.currenciesWithCircle
            } else {
                currencies = Currencies.coindeskCurrencies
            }
            let currencyDict = currencies[indexPath.row]
            for (key, _) in currencyDict {
                UserDefaults.standard.setValue(key, forKey: "currency")
                DispatchQueue.main.async {
                    tableView.reloadData()
                    NotificationCenter.default.post(name: .refreshWallet, object: nil)
                }
            }
        }
        
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
    }
    
    func exchangeRateApiCell(_ indexPath: IndexPath) -> UITableViewCell {
        let exchangeRateApiCell = tableView.dequeueReusableCell(withIdentifier: "checkmarkCell", for: indexPath)
        configureCell(exchangeRateApiCell)
        
        let label = exchangeRateApiCell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        let icon = exchangeRateApiCell.viewWithTag(3) as! UIImageView
        
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        icon.image = UIImage(systemName: "server.rack")
        
        switch indexPath.row {
        case 0:
            label.text = "Blockchain.info"
            if useBlockchainInfo {
                //background.backgroundColor = .systemBlue
                exchangeRateApiCell.isSelected = true
                exchangeRateApiCell.accessoryType = .checkmark
            } else {
                //background.backgroundColor = .systemGray
                exchangeRateApiCell.isSelected = false
                exchangeRateApiCell.accessoryType = .none
            }
        case 1:
            label.text = "Coindesk"
            if !useBlockchainInfo {
                exchangeRateApiCell.isSelected = true
                exchangeRateApiCell.accessoryType = .checkmark
            } else {
                exchangeRateApiCell.isSelected = false
                exchangeRateApiCell.accessoryType = .none
            }
        default:
            break
        }
        
        return exchangeRateApiCell
    }
    
    func currencyCell(_ indexPath: IndexPath, _ currency: [String:String]) -> UITableViewCell {
        let currencyCell = tableView.dequeueReusableCell(withIdentifier: "checkmarkCell", for: indexPath)
        configureCell(currencyCell)
        
        let label = currencyCell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
                
        let icon = currencyCell.viewWithTag(3) as! UIImageView
        
        let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        for (key, value) in currency {
            if currencyToUse == key {
                currencyCell.accessoryType = .checkmark
                currencyCell.isSelected = true
            } else {
                currencyCell.accessoryType = .none
                currencyCell.isSelected = false
            }
            label.text = key
            icon.image = UIImage(systemName: value)
        }
        
        return currencyCell
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isApi {
            return exchangeRateApiCell(indexPath)
        } else if isCurrency {
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            
            var currencies:[[String:String]] = Currencies.currenciesWithCircle
            
            if !useBlockchainInfo {
                currencies = Currencies.coindeskCurrencies
            }
            
            return currencyCell(indexPath, currencies[indexPath.row])
        } else {
            return UITableViewCell()
        }
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
