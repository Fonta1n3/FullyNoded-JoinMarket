//
//  FidelityBondViewController.swift
//  FullyNoded-JoinMarket
//
//  Created by Peter Denton on 12/30/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import UIKit

class FidelityBondViewController: UIViewController {
    
    private var pickerView: UIPickerView!
    private var datePickerView: UIVisualEffectView!
    private let spinner = ConnectingView()
    var wallet: JMWallet?
    private var fidelityBondAddress: String?
    
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
    
    private var years: [String] = []
    private var month = ""
    private var monthString = ""
    private var currentYearInt = Calendar.current.component(.year, from: Date())
    private var year = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        year = "\(currentYearInt + 1)"
        monthString = "January"
        month = "01"
        for i in 1...4 {
            years.append("\(currentYearInt + i)")
        }        
        //createFidelityBondAction()
    }
    
    @IBAction func createNow(_ sender: Any) {
        year = "\(currentYearInt + 1)"
        monthString = "January"
        month = "01"
        years.removeAll()
        for i in 1...4 {
            years.append("\(currentYearInt + i)")
        }
        createFidelityBondAction()
    }
    
    
    func createFidelityBondAction() {
        if let wallet = wallet {
            spinner.addConnectingView(vc: self, description: "checking fidelity bond status...")
            JMUtils.fidelityStatus(wallet: wallet) { [weak self] (exists, message) in
                guard let self = self else { return }
                            
                guard let exists = exists, exists else {
                    //self.promptToSelectTimelockDate()
                    selectTimelockDate()
                    return
                }
                showAlert(vc: self, title: "Fidelity Bond exists.", message: "You can only create one fidelity bond at a time.")
            }
        }
    }
    
    private func fbBlurView() -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(frame: .init(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
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
    

    
    private func promptToSelectTimelockDate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond"
            let mess = "A fidelity bond is a timelocked bitcoin address.\n\nCreating a fidelity bond increases your earning potential. The higher the amount/duration of the bond, the higher the earning potential.\n\nYou will be prompted to select an expiry date for the bond, you will NOT be able to spend these funds until that date. You must wait until your current fidelity bond expires before making a new one."

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
        datePickerView = fbBlurView()
        view.addSubview(datePickerView)
    }
    
    @objc func closeDatePicker() {
        datePickerView.removeFromSuperview()
        getFidelityAddress()
    }
    
    @objc func cancelDatePicker() {
        spinner.removeConnectingView()
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
                let mess = "This is a timelocked bitcoin address which prevents you from spending the funds until midnight (UTC) on the 1st of \(monthString), \(year).\n\nTap OK to display the Fidelty Bond address."

                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.fidelityBondAddress = address
                        self.performSegue(withIdentifier: "segueToShowFBInvoice", sender: self)
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    
    private func removeSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
        }
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToShowFBInvoice":
            guard let vc = segue.destination as? InvoiceViewController else { fallthrough }
            
            vc.fidelityBondAddress = self.fidelityBondAddress
            vc.jmWallet = wallet
            vc.expiration = "Fidelity Bond expires at midnight UTC on the 1st of \(monthString), \(year)."
        default:
            break
        }
    }
}

extension FidelityBondViewController: UIPickerViewDelegate, UIPickerViewDataSource {
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
            for (key, value) in dict {
                month = value
                monthString = key
            }
        case 1:
            year = years[row]
        default:
            break
        }
    }
}
