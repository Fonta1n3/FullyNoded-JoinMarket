//
//  Commands.swift
//  BitSense
//
//  Created by Peter on 24/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//


let rootUrl = "api/v1"

public enum JM_REST {
    case walletall
    case walletcreate
    case session
    case lockwallet(jmWallet: Wallet)
    case unlockwallet(jmWallet: Wallet)
    case walletdisplay(jmWallet: Wallet)
    case getaddress(jmWallet: Wallet, mixdepth: Int)
    case coinjoin(jmWallet: Wallet)
    case makerStart(jmWallet: Wallet)
    case makerStop(jmWallet: Wallet)
    case takerStop(jmWallet: Wallet)
    case configGet(jmWallet: Wallet)
    case configSet(jmWallet: Wallet)
    case gettimelockaddress(jmWallet: Wallet, date: String)
    case getSeed(jmWallet: Wallet)
    case unfreeze(jmWallet: Wallet)
    case listutxos(jmWallet: Wallet)
    case directSend(jmWallet: Wallet)
    
    var stringValue:String {
        switch self {
        case .walletall:
            return "\(rootUrl)/wallet/all"
        case .session:
            return "\(rootUrl)/session"
        case .walletcreate:
            return "\(rootUrl)/wallet/create"
        case .lockwallet(let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/lock"
        case .unlockwallet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/unlock"
        case .walletdisplay(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/display"
        case .getaddress(jmWallet: let wallet, mixdepth: let mixdepth):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/address/new/\(mixdepth)"
        case .coinjoin(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/coinjoin"
        case .makerStart(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/maker/start"
        case .makerStop(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/maker/stop"
        case .takerStop(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/stop"
        case .configGet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/configget"
        case .configSet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/configset"
        case .gettimelockaddress(jmWallet: let wallet, date: let date):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/address/timelock/new/\(date)"
        case .getSeed(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/getseed"
        case .unfreeze(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/freeze"
        case .listutxos(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/utxos"
        case .directSend(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/direct-send"
        }
    }
}
