//
//  NodeLogic.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class NodeLogic {
    
    static let dateFormatter = DateFormatter()
    static var dictToReturn = [String:Any]()
    static var arrayToReturn = [[String:Any]]()
    static var offchainTxids:[String] = []
    
    class func loadBalances(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        dictToReturn["unconfirmedBalance"] = "disabled"
        dictToReturn["onchainBalance"] = "disabled"
        completion((dictToReturn, nil))
    }
    
    class func loadSectionTwo(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        // Get Joinmarket tx history
    }
    
    private class func saveLocally(txid: String, date: Date) {
        let dict = [
            "txid":txid,
            "id":UUID(),
            "memo":"no transaction memo",
            "date":date,
            "label":""
        ] as [String:Any]

        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
    }
    
    class func parseTransactions(transactions: NSArray) {
        arrayToReturn.removeAll()
                
        for item in transactions {
            if let transaction = item as? [String:Any] {
                var label = String()
                var replaced_by_txid = String()
                let address = transaction["address"] as? String ?? ""
                let amount = transaction["amount"] as? Double ?? 0.0
                let amountString = amount.avoidNotation
                let confsCheck = transaction["confirmations"] as? Int ?? 0
                
                let confirmations = String(confsCheck)
                
                if let replaced_by_txid_check = transaction["replaced_by_txid"] as? String {
                    replaced_by_txid = replaced_by_txid_check
                }
                
                if let labelCheck = transaction["label"] as? String {
                    label = labelCheck
                    if labelCheck == "" || labelCheck == "," {
                        label = ""
                    }
                } else {
                    label = ""
                }
                
                let secondsSince = transaction["time"] as? Double ?? 0.0
                let rbf = transaction["bip125-replaceable"] as? String ?? ""
                let txID = transaction["txid"] as? String ?? ""
                
                let date = Date(timeIntervalSince1970: secondsSince)
                dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                let dateString = dateFormatter.string(from: date)
                
                let amountSats = amountString.btcToSats
                let amountBtc = amountString.doubleValue.btcBalanceWithSpaces
                let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double ?? 0.0
                let amountFiat = (amountString.doubleValue * fxRate).balanceText
                
                let tx = [
                    "address": address,
                    "amountBtc": amountBtc,
                    "amountSats": amountSats,
                    "amountFiat": amountFiat,
                    "confirmations": confirmations,
                    "label": label,
                    "date": dateString,
                    "rbf": rbf,
                    "txID": txID,
                    "replacedBy": replaced_by_txid,
                    "selfTransfer": false,
                    "remove": false,
                    "onchain": true,
                    "isLightning": false,
                    "sortDate": date
                ] as [String:Any]
                
                arrayToReturn.append(tx)
                                
                func saveLocally() {
                    #if DEBUG
                    print("saveLocally")
                    #endif
                    var labelToSave = "no transaction label"
                    
                    if label != "" {
                        labelToSave = label
                    }
                    
                    let dict = [
                        "txid":txID,
                        "id":UUID(),
                        "memo":"no transaction memo",
                        "date":date,
                        "label":labelToSave
                    ] as [String:Any]
                    
                    CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                }
                
                CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                    guard let txs = txs, txs.count > 0 else {
                        saveLocally()
                        return
                    }
                    
                    var alreadySaved = false
                    
                    for (i, tx) in txs.enumerated() {
                        let txStruct = TransactionStruct(dictionary: tx)
                        if txStruct.txid == txID {
                            alreadySaved = true
                        }
                        if i + 1 == txs.count {
                            if !alreadySaved {
                                saveLocally()
                            }
                        }
                    }
                }
            }
        }
    }
}
