//
//  WalletUnlock.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
/*
 {
     "expires_in" = 1800;
     "refresh_token" = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MjI2MTYyMTgsInNjb3BlIjoiZEdWemRDNXFiV1JoZEE9PSB3YWxsZXRycGMifQ.FJV94HaX-bSJuvtM7_HzKAkPuTAeiQKccxWcun9lzkg";
     scope = "dGVzdC5qbWRhdA== walletrpc";
     token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MjI2MDM2MTgsInNjb3BlIjoiZEdWemRDNXFiV1JoZEE9PSB3YWxsZXRycGMifQ.rtJEEpLze8BP0xXLTEjhT56h2PxPb7zU0BiV5ELrIOk";
     "token_type" = bearer;
     walletname = "test.jmdat";
 }
 */

public struct WalletUnlock: CustomStringConvertible {
    let token: String
    let walletname: String
    let refresh_token: String
    
    init(_ dictionary: [String: Any]) {
        token = dictionary["token"] as! String
        walletname = dictionary["walletname"] as! String
        refresh_token = dictionary["refresh_token"] as! String
    }
    
    public var description: String {
        return ""
    }
}
