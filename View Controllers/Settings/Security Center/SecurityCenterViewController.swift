//
//  SecurityCenterViewController.swift
//  BitSense
//
//  Created by Peter on 11/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SecurityCenterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    let ud = UserDefaults.standard
    let lockView = UIView()
    let passwordInput = UITextField()
    let textInput = UITextField()
    let nextButton = UIButton()
    let alertView = UIView()
    let labelTitle = UILabel()
    var firstPassword = String()
    var secondPassword = String()
    @IBOutlet var securityTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        securityTable.delegate = self
        securityTable.dataSource = self
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            return 4
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "securityCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(2) as! UILabel
        let icon = cell.viewWithTag(1) as! UIImageView
        let background = cell.viewWithTag(3)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        switch indexPath.section {
        case 0:
            icon.image = UIImage(systemName: "lock.shield")
            label.text = "V3 Authentication Key"
            background.backgroundColor = .systemGreen
            
        case 1:
            if KeyChain.getData("UnlockPassword") != nil {
                label.text = "Reset"
                icon.image = UIImage(systemName: "arrow.clockwise")
            } else {
                label.text = "Set"
                icon.image = UIImage(systemName: "plus")
            }
            
            background.backgroundColor = .systemBlue
            
        case 2:
            switch indexPath.row {
            case 0: label.text = "Set Passphrase"; icon.image = UIImage(systemName: "plus"); background.backgroundColor = .systemPink
            case 1: label.text = "Change Passphrase"; icon.image = UIImage(systemName: "arrow.clockwise") ; background.backgroundColor = .systemGreen
            case 2: label.text = "Encrypt"; icon.image = UIImage(systemName: "lock.shield"); background.backgroundColor = .systemOrange
            case 3: label.text = "Decrypt"; icon.image = UIImage(systemName: "lock.open"); background.backgroundColor = .systemIndigo
            default: break}
                        
        case 3:
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                label.text = "Disabled"
                label.textColor = .darkGray
                icon.image = UIImage(systemName: "eye.slash")
            } else {
                label.text = "Enabled"
                label.textColor = .lightGray
                icon.image = UIImage(systemName: "eye")
            }
            
            background.backgroundColor = .systemPurple
            
        case 4:
            if ud.object(forKey: "passphrasePrompt") != nil {
                label.text = "On"
                label.textColor = .lightGray
                icon.image = UIImage(systemName: "checkmark.circle")
                background.backgroundColor = .systemGreen
            } else {
                label.text = "Off"
                label.textColor = .darkGray
                icon.image = UIImage(systemName: "xmark.circle")
                background.backgroundColor = .systemRed
            }
                        
        default:
            break
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        switch section {
        case 0:
            textLabel.text = "Tor Authentication"
            
        case 1:
            textLabel.text = "App Password"
            
        case 2:
            textLabel.text = "Wallet Encryption"
            
        case 3:
            textLabel.text = "Biometrics"
            
        case 4:
            textLabel.text = "Passphrase Prompt"
                        
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
        
        case 0:
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToTorAuth", sender: vc)
            }
            
        case 1:
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "addPasswordSegue", sender: vc)
            }
            
        case 2:
           print("section 2 tapped")
            
        case 3:
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                ud.removeObject(forKey: "bioMetricsDisabled")
            } else {
                ud.set(true, forKey: "bioMetricsDisabled")
            }
            DispatchQueue.main.async {
                tableView.reloadSections([3], with: .fade)
            }
            
        case 4:
            if ud.object(forKey: "passphrasePrompt") != nil {
                ud.removeObject(forKey: "passphrasePrompt")
            } else {
                ud.set(true, forKey: "passphrasePrompt")
            }
            DispatchQueue.main.async {
                tableView.reloadSections([4], with: .fade)
            }
            
        default:
            break
        }
    }
    
    private func exisitingPassword() -> Data? {
        return KeyChain.getData("UnlockPassword")
    }
    
//    private func hash(_ text: String) -> Data? {
//       // return Data(hexString: Crypto.sha256hash(text))
//        return Crypto.sha
//    }
        
}
