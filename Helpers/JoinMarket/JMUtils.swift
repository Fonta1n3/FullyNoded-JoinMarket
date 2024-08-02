//
//  JMUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMUtils {
    static func getDescriptors(wallet: JMWallet, completion: @escaping ((descriptors: [String]?,  message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .getSeed(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
                  let words = dict["seedphrase"] as? String else {
                completion((nil, errorDesc))
                return
            }
            
            let chain = UserDefaults.standard.string(forKey: "chain")
            var coinType = "0"
            if chain != "main" {
                coinType = "1"
            }
            
            guard let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: ""),
                  let xfp = Keys.fingerprint(masterKey: mk) else {
                completion((nil, "error deriving mk/xfp."))
                return
            }
            
            JoinMarket.descriptors(mk, xfp, completion: { descriptors in
                guard let descriptors = descriptors else { completion((nil, "error deriving descriptors")); return }
                
                completion((descriptors, nil))
            })
        }
    }
    
    // Get user to provide encryption password.
    static func createWallet(label: String,
                             password: String,
                             completion: @escaping ((response: JMWallet?, words: String?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "walletname": label + ".jmdat",
            "password": password,
            "wallettype":"sw-fb"
        ]
        
        JMRPC.sharedInstance.command(method: .walletcreate, param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, nil, errorDesc ?? "Unknown."))
                return
            }
            
            let jmWalletCreated = JMWalletCreated(response)
            
            guard let encryptedToken = Crypto.encrypt(jmWalletCreated.token.utf8) else {
                completion((nil, nil, "Error encrypting jm wallet credentials."))
                return
            }
            
            guard let encryptedRefreshToken = Crypto.encrypt(jmWalletCreated.refresh_token.utf8) else {
                completion((nil, nil, "Error encrypting jm wallet credentials."))
                return
            }
            
            let jmWallet: [String:Any] = [
                "id": UUID(),
                "token":encryptedToken,
                "refresh_token": encryptedRefreshToken,
                "name": label + ".jmdat",
                "active": true
            ]
            
            CoreDataService.saveEntity(dict: jmWallet, entityName: .jmWallets) { walletSaved in
                guard walletSaved else {
                    completion((nil, nil, "Error saving wallet."))
                    return
                }
                
                completion((JMWallet(jmWallet), jmWalletCreated.seedphrase, nil))
            }
        }
    }
    
    static func getMkXfpBlock(signer: String) -> (mk: String?, xfp: String?, block: Int?) {
        var cointType = "0"
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            cointType = "1"
        }
        let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int ?? 0
        
        guard let mk = Keys.masterKey(words: signer, coinType: cointType, passphrase: ""),
              let xfp = Keys.fingerprint(masterKey: mk) else {
                  return (nil, nil, nil)
              }
        
        return (mk, xfp, blockheight)
    }
    
    static func lockWallet(wallet: JMWallet, completion: @escaping ((locked: Bool, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .lockwallet(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((false, errorDesc ?? "Unknown."))
                return
            }
            
            let walletLocked = WalletLocked(response)
            completion((!walletLocked.already_locked, nil))
        }
    }
    
    static func unlockWallet(password: String, wallet: JMWallet, completion: @escaping ((unlockedWallet: WalletUnlock?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .unlockwallet(jmWallet: wallet, password: password), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
                        
            let walletUnlock = WalletUnlock(response)
            
            guard let updatedToken = Crypto.encrypt(walletUnlock.token.utf8) else {
                completion((nil, "Unable to encrypt new token."))
                return
            }
            
            guard let refreshToken = Crypto.encrypt(walletUnlock.refresh_token.utf8) else {
                completion((nil, "Unable to encrypt refresh token."))
                return
            }
            
            CoreDataService.update(id: wallet.id, keyToUpdate: "token", newValue: updatedToken, entity: .jmWallets) { tokenUpdated
                in
                guard tokenUpdated else { return }
                
                CoreDataService.update(id: wallet.id, keyToUpdate: "refresh_token", newValue: refreshToken, entity: .jmWallets) { refreshUpdated in
                    guard refreshUpdated else { return }
                    
                    completion((walletUnlock, nil))
                }
            }
        }
    }

    
    static func display(wallet: JMWallet, completion: @escaping ((detail: WalletDetail?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletdisplay(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            completion((WalletDetail(response), nil))
        }
    }
    
    static func getAddress(wallet: JMWallet, mixdepth: Int, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .getaddress(jmWallet: wallet, mixdepth: mixdepth), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any],
                  let address = response["address"] as? String else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            completion((address, "message"))
        }
    }
    
    static func coinjoin(wallet: JMWallet,
                         amount_sats: Int,
                         mixdepth: Int,
                         counterparties: Int,
                         address: String,
                         completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "amount_sats":amount_sats,
            "mixdepth":mixdepth,
            "counterparties":counterparties,
            "destination": address
        ]
        
        JMRPC.sharedInstance.command(method: .coinjoin(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func stopTaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .takerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func configGet(wallet: JMWallet,
                          section: String,
                          field: String,
                          completion: @escaping ((response: String?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "section":section,
            "field":field
        ]
        
        JMRPC.sharedInstance.command(method: .configGet(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any],
                  let value = response["configvalue"] as? String else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((value, errorDesc))
        }
    }
    
    static func configSet(wallet: JMWallet,
                          section: String,
                          field: String,
                          value: String,
                          completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "section":section,
            "field":field,
            "value":value
        ]
        
        JMRPC.sharedInstance.command(method: .configSet(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((response, errorDesc))
        }
    }
    
    static func session(completion: @escaping ((response: JMSession?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .session, param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return }
            
            completion((JMSession(response), nil))
        }
    }
    
    static func startMaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        let txfee = 0
        let cjfee_a = Int.random(in: 5000...10000)
        let cjfee_r = Double.random(in: 0.00002...0.000025)
        let minsize = Int.random(in: 99999...299999)
        let orderType = "sw0reloffer"
        
        let param:[String:Any] = [
            "txfee": txfee,
            "cjfee_a": cjfee_a,
            "cjfee_r": cjfee_r.avoidNotation,
            "ordertype": orderType,
            "minsize": minsize
        ]
                
        JMRPC.sharedInstance.command(method: .makerStart(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((response, errorDesc))
        }
    }
    
    static func stopMaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .makerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func fidelityStatus(wallet: JMWallet, completion: @escaping ((exists: Bool?, message: String?)) -> Void) {
        JMUtils.display(wallet: wallet) { (detail, message) in
            guard let detail = detail else {
                completion((nil, message))
                return
            }
            
            var exists = false
            
            for account in detail.accounts {
                if account.accountNumber == 0 {
                    for branch in account.branches {
                        if branch.balance > 0.0 {
                            for entry in branch.entries {
                                if entry.hd_path.contains(":") {
                                    print("funded timelocked address exists")
                                    exists = true
                                }
                            }
                        }
                    }
                }
            }
            completion((exists, nil))
        }
    }
    
    static func fidelityAddress(wallet: JMWallet, date: String, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .gettimelockaddress(jmWallet: wallet, date: date), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
            let address = dict["address"] as? String else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            completion((address, errorDesc))
        }
    }
    
    static func wallets(completion: @escaping ((response: [String]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletall, param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any], let wallets = response["wallets"] as? [String] else {
                completion((nil, errorDesc))
                return }
            
            completion((wallets, nil))
        }
    }
    
    static func unfreezeFb(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .listutxos(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any],
                    !response.isEmpty,
                    let utxos = response["utxos"] as? [[String:Any]],
                    !utxos.isEmpty else { return }
            
            var fbUtxo:JMUtxo?
            
            for (i, utxo) in utxos.enumerated() {
                let jmUtxo = JMUtxo(utxo)
                                
                if jmUtxo.frozen, let locktime = jmUtxo.locktime, locktime < Date() {
                    fbUtxo = jmUtxo
                }
                
                if i + 1 == utxos.count {
                    guard let fbUtxo = fbUtxo else {
                        print("no utxo")
                        completion((nil, "No frozen expired timelocked utxo."))
                        return
                    }
                    
                    let param:[String:Any] = [
                        "utxo-string":fbUtxo.utxoString,
                        "freeze": false
                    ]
                    
                    JMRPC.sharedInstance.command(method: .unfreeze(jmWallet: wallet), param: param) { (response, errorDesc) in
                        guard let response = response as? [String:Any] else {
                            completion((nil, errorDesc))
                            return
                        }
                        
                        completion((response, errorDesc))
                    }
                }
            }
        }
    }
    
    static func directSend(wallet: JMWallet, address: String, amount: Int, mixdepth: Int, completion: @escaping ((jmTx: JMTx?, message: String?)) -> Void) {
        let param:[String:Any] = [
            "mixdepth":mixdepth,
            "amount_sats":amount,
            "destination": address
        ]
        
        JMRPC.sharedInstance.command(method: .directSend(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return
            }
            
            completion((JMTx(response), errorDesc))
        }
    }
}
