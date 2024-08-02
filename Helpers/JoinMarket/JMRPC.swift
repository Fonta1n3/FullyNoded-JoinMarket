//
//  JMRPC.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/20/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMRPC {
    
    static let sharedInstance = JMRPC()
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    private var token:String?
    private var isNostr = false
    
    private init() {}
    
    func command(method: JM_REST, param: [String:Any]?, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        var paramToUse:[String:Any] = [:]
        if let param = param {
            paramToUse = param
        }
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                completion((nil, "Error getting nodes from core data"))
                return
            }
            
            guard nodes.count > 0 else {
                completion((nil, "No nodes added."))
                return
            }
            
            var activeNode: NodeStruct?
            
            for node in nodes {
                let n = NodeStruct(dictionary: node)
                if n.isActive {
                    activeNode = n
                }
            }
            
            guard let node = activeNode else {
                completion((nil, "no active nodes!"))
                return
            }
            
            var onionAddress:String?
            
            if let encAddress = node.onionAddress {
                onionAddress = decryptedValue(encAddress)
            }
            
            if let encryptedCert = node.cert {
                guard let decryptedCert = Crypto.decrypt(encryptedCert) else {
                    completion((nil, "Error getting decrypting cert."))
                    return
                }
                
                self.torClient.cert = decryptedCert.base64EncodedData()
            }
            
            let walletUrl = "https://\(onionAddress ?? "localhost:28183")/\(method.stringValue)"
            
            guard let url = URL(string: walletUrl) else {
                completion((nil, "url error"))
                return
            }
            
            var request = URLRequest(url: url)
            var timeout = 10.0
            var httpMethod:String!
            
            switch method {
            case .walletall,
                    .session,
                    .getinfo:
                httpMethod = "GET"
                
            case .lockwallet(let wallet),
                    .walletdisplay(let wallet),
                    .getaddress(jmWallet: let wallet, mixdepth: _),
                    .makerStop(jmWallet: let wallet),
                    .takerStop(jmWallet: let wallet),
                    .getSeed(jmWallet: let wallet),
                    .listutxos(jmWallet: let wallet):
                httpMethod = "GET"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                    completion((nil, "Unable to decrypt token."))
                    return
                }
                self.token = token
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .unlockwallet(jmWallet: _, let password):
                httpMethod = "POST"
                timeout = 1000
                paramToUse = ["password": password]
                
            case .walletcreate:
                httpMethod = "POST"
                timeout = 1000
                
            case .coinjoin(jmWallet: let wallet),
                    .makerStart(jmWallet: let wallet),
                    .configGet(jmWallet: let wallet),
                    .configSet(jmWallet: let wallet),
                    .unfreeze(jmWallet: let wallet),
                    .directSend(jmWallet: let wallet):
                
                httpMethod = "POST"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                    completion((nil, "Unable to decrypt token."))
                    return
                }
                self.token = token
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .token(jmWallet: let wallet):
                httpMethod = "POST"
                
                guard let decryptedToken = Crypto.decrypt(wallet.refresh_token),
                      let token = decryptedToken.utf8String else {
                    completion((nil, "Unable to decrypt token."))
                    return
                }
                self.token = token
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .gettimelockaddress(jmWallet: let wallet, date: _):
                httpMethod = "GET"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                    completion((nil, "Unable to decrypt token."))
                    return
                }
                self.token = token
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            if !paramToUse.isEmpty {
                guard let jsonData = try? JSONSerialization.data(withJSONObject: paramToUse) else {
                    completion((nil, "Unable to encode your params into json data."))
                    return
                }
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
            }
            
            request.timeoutInterval = timeout
            request.httpMethod = httpMethod
            request.url = url
            
#if DEBUG
            print("url = \(url)")
            print("httpMethod = \(String(describing: httpMethod))")
            print("self.token = \(String(describing: self.token))")
            print("httpBody = \(paramToUse)")
#endif
            
            
            let task = torClient.session.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
                guard let self = self else { return }
                
                guard let urlContent = data else {
                    
                    guard let error = error else {
                        if self.attempts < 20 {
                            self.command(method: method, param: param, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, "Unknown error, ran out of attempts"))
                        }
                        
                        return
                    }
                    
                    if self.attempts < 20 {
                        self.command(method: method, param: param, completion: completion)
                    } else {
                        self.attempts = 0
#if DEBUG
                        print("error: \(error.localizedDescription)")
#endif
                        completion((nil, error.localizedDescription))
                    }
                    
                    return
                }
                
                self.attempts = 0
                
                guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
                    if let httpResponse = response as? HTTPURLResponse {
                        print("httpResponse.statusCode: \(httpResponse.statusCode)")
                        switch httpResponse.statusCode {
                        case 401:
                            completion((nil, "Unauthorized. Go to settings to request a new token."))
                            
                        case 403:
                            completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                        default:
                            completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                        }
                    } else {
                        completion((nil, "Unable to decode the response from your node..."))
                    }
                    return
                }
                
#if DEBUG
                print("json: \(json)")
#endif
                
                guard let message = json["message"] as? String else {
                    completion((json, nil))
                    return
                }
                
                completion((nil, message))
            }
            
            task.resume()
        }
    }
}
