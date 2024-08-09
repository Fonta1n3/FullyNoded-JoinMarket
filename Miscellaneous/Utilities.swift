//
//  Utilities.swift
//  BitSense
//
//  Created by Peter on 08/08/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import UIKit

public func decryptedValue(_ encryptedValue: Data) -> String {
    guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
    
    return decrypted.utf8String ?? ""
}

/// Call this method to retrive active wallet. This method seaches the device's storage. NOT the node.
/// - Parameter completion: Active wallet
public func activeWallet(completion: @escaping ((JMWallet?)) -> Void) {
    CoreDataService.retrieveEntity(entityName: .jmWallets) { walletDictionaries in
        guard let walletDictionaries = walletDictionaries, !walletDictionaries.isEmpty else {
            completion(nil)
            return
        }
        
        var foundWallet: JMWallet?
        
        for walletDictionary in walletDictionaries where foundWallet == nil {
            let wallet = JMWallet(walletDictionary)
            
            if wallet.active {
                foundWallet = wallet
            }
        }
        
        completion(foundWallet)
    }
}

public func showAlert(vc: UIViewController?, title: String, message: String) {
    if let vc = vc {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
}

public func impact() {
    if #available(iOS 10.0, *) {
        let impact = UIImpactFeedbackGenerator()
        DispatchQueue.main.async {
            impact.impactOccurred()
        }
    } else {
        // Fallback on earlier versions
    }
}

public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0...length-1).map{ _ in letters.randomElement()! })
}

public func rounded(number: Double) -> Double {
    return Double(round(100000000*number)/100000000)
    
}

public func currentDate() -> String {
    return "NZdDCNBFTDqKPrUG9V80g0iVemSXLL0CuaWj12xqD00="
}

public var authTimeout: Int {
    return 360
}

public let currencies:[[String:String]] = [
    ["USD": "$"],
    ["GBP": "£"],
    ["EUR": "€"],
    ["AUD":"$"],
    ["BRL": "R$"],
    ["CAD": "$"],
    ["CHF": "CHF "],
    ["CLP": "$"],
    ["CNY": "¥"],
    ["DKK": "kr"],
    ["HKD": "$"],
    ["INR": "₹"],
    ["ISK": "kr"],
    ["JPY": "¥"],
    ["KRW": "₩"],
    ["NZD": "$"],
    ["PLN": "zł"],
    ["RUB": "₽"],
    ["SEK": "kr"],
    ["SGD": "$"],
    ["THB": "฿"],
    ["TRY": "₺"],
    ["TWD": "NT$"]
]

public func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
