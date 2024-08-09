//
//  ConfirmDirectSendViewController.swift
//  FullyNoded-JoinMarket
//
//  Created by Peter Denton on 8/7/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import UIKit

class ConfirmDirectSendViewController: UIViewController {
    
    var mixdepth: Int!
    var address: String!
    var amount: Double!
    var jmWallet: JMWallet!
    var totalAvailable: String!
    var isFidelity: Bool!
    
    private let spinner = ConnectingView()
    
    @IBOutlet weak private var amountOutlet: UILabel!
    @IBOutlet weak private var addressOutlet: UILabel!
    @IBOutlet weak private var mixdepthOutlet: UILabel!
    @IBOutlet weak private var headerOutlet: UILabel!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        amountOutlet.text = amount.btcBalanceWithSpaces
        mixdepthOutlet.text = "mixdepth \(mixdepth!)"
        addressOutlet.text = address.withSpaces
        if amount == 0.0 {
            amountOutlet.text = totalAvailable
        }
        if isFidelity {
            headerOutlet.text = "Fidelity Bond Deposit"
        }
    }
    
    @IBAction func confirmAction(_ sender: Any) {
        JMUtils.directSend(wallet: jmWallet, address: address, amount: amount.btcToSats, mixdepth: mixdepth) { [weak self] (jmTx, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let jmTx = jmTx, let txid = jmTx.txid else {
                showAlert(vc: self, title: "No transaction info received...", message: "Message: \(message ?? "unknown")")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "Sent ✓", message: txid, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // trigger wallet view refresh
                        NotificationCenter.default.post(name: .refreshWallet, object: nil)
                        
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
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
