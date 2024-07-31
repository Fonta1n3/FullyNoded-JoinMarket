//
//  JMWallet.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct JMWallet: CustomStringConvertible {
    let id: UUID
    let name: String
    var token: Data
    let active: Bool
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        name = dictionary["name"] as! String
        token = dictionary["token"] as! Data
        active = dictionary["active"] as! Bool
    }
    
    public var description: String {
        return ""
    }
    
}
