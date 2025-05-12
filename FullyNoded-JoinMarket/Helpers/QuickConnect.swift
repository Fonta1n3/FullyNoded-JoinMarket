//
//  QuickConnect.swift
//  BitSense
//
//  Created by Peter on 28/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class QuickConnect {
    
    // MARK: QuickConnect uri examples
    /// JOINMARKET http://kjwdfkjbdkcjb.onion:28183?cert=xxx
    
    
    class func addNode(url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        var newNode = [String:Any]()
        newNode["id"] = UUID()
        
        guard var host = URLComponents(string: url)?.host,
            let port = URLComponents(string: url)?.port else {
                completion((false, "invalid url"))
                return
        }
        
        host += ":" + String(port)
        
        // Encrypt credentials
        guard let torNodeHost = Crypto.encrypt(host.utf8) else {
                completion((false, "error encrypting your credentials"))
                return
        }
                    
            
            
        guard let certCheck = URL(string: url)?.value(for: "cert"),
              let certData = try? Data.decodeUrlSafeBase64(certCheck) else {
                  completion((false, "cert missing."))
                  return
              }
        
        guard let encryptedCert = Crypto.encrypt(certData) else {
                completion((false, "error encrypting your credentials"))
                return
        }
        
        newNode["cert"] = encryptedCert
        newNode["onionAddress"] = torNodeHost
        newNode["isActive"] = true
        newNode["label"] = "Join Market"
        processNode(newNode, url, completion: completion)
        return
    }
    
    private class func processNode(_ newNode: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
            guard let nodes = nodes, nodes.count > 0 else { saveNode(newNode, url, completion: completion); return }
            
            for (i, existingNode) in nodes.enumerated() {
                let existingNodeStruct = NodeStruct(dictionary: existingNode)
                    if existingNodeStruct.isActive {
                        CoreDataService.update(id: existingNodeStruct.id, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    }
                if i + 1 == nodes.count {
                    saveNode(newNode, url, completion: completion)
                }
            }
        }
    }
    
    private class func saveNode(_ node: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.saveEntity(dict: node, entityName: .newNodes) { success in
            if success {
                completion((true, nil))
            } else {
                completion((false, "error saving your node to core data"))
            }
        }
    }
    
}

extension URL {
    func value(for paramater: String) -> String? {
        let queryItems = URLComponents(string: self.absoluteString)?.queryItems
        let queryItem = queryItems?.filter({$0.name == paramater}).first
        let value = queryItem?.value
        return value
    }
}
