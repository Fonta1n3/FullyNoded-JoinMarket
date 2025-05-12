//
//  NodeStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct NodeStruct: CustomStringConvertible {
    
    let id: UUID
    let label: String
    let isActive: Bool
    let onionAddress: Data
    let cert: Data
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        isActive = dictionary["isActive"] as! Bool
        onionAddress = dictionary["onionAddress"] as! Data
        cert = dictionary["cert"] as! Data
    }
    
    public var description: String {
        return ""
    }
    
}

