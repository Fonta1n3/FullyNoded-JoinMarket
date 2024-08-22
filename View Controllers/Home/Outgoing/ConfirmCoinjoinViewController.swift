//
//  ConfirmCoinjoinViewController.swift
//  FullyNoded-JoinMarket
//
//  Created by Peter Denton on 8/8/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import UIKit

class ConfirmCoinjoinViewController: UIViewController {
    
    var mixdepth: Int!
    var address: String!
    var amount: Double!
    var jmWallet: JMWallet!
    var totalAvailable: String!
    
    private let spinner = ConnectingView()

    @IBOutlet weak private var amountOutlet: UILabel!
    @IBOutlet weak private var recipientOutlet: UILabel!
    @IBOutlet weak private var mixdepthOutlet: UILabel!
    @IBOutlet weak private var counterpartiesControl: UISegmentedControl!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        amountOutlet.text = amount.btcBalanceWithSpaces
        mixdepthOutlet.text = "mixdepth \(mixdepth!)"
        recipientOutlet.text = address.withSpaces
        if amount == 0.0 {
            amountOutlet.text = totalAvailable
        }
    }
    

    @IBAction func confirmAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "starting taker")
        
        JMUtils.coinjoin(wallet: jmWallet,
                         amount_sats: amount.btcToSats,
                         mixdepth: mixdepth,
                         counterparties: counterpartiesControl.selectedSegmentIndex + 2,
                         address: address) { [weak self] (response, message) in
            
            guard let self = self else { return }
            spinner.removeConnectingView()
            
            self.handleJMResponse(response, message)
        }
    }
    
    private func handleJMResponse(_ response: [String:Any]?, _ message: String?) {
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
                    
                    NotificationCenter.default.post(name: .refreshWallet, object: nil)
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
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
