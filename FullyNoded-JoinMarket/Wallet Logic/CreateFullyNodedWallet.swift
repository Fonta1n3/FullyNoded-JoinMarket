//
//  CreateFullyNodedWallet.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import LibWally

enum Keys {
    
    static func validMnemonic(_ words: String) -> Bool {
        guard let _ = try? BIP39Mnemonic(words: words) else { return false }
        
        return true
    }
    
    static func validPath(_ path: String) -> Bool {
        guard let _ = try? BIP32Path(string: path) else { return false }
        
        return true
    }
    
    static func dataToSigner(_ data: Data) -> String? {
        return try? BIP39Mnemonic(entropy: BIP39Mnemonic.Entropy(data)).words.joined(separator: " ")
    }
    
    static func wordsToEntropy(_ words: String) -> BIP39Mnemonic.Entropy? {
        return try? BIP39Mnemonic(words: words).entropy
    }
    
    
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<100)
        
        guard let hdKey = try? HDKey(base58: "xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"),
            let path = try? BIP32Path(string: "0/\(randomInt)"),
              let address = try? hdKey.derive(using: path).address(type: .payToWitnessPubKeyHash) else { return nil }
        
        return address.description
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 32
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            var data = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(randomBytes))))
            data = data.subdata(in: Range(0...15))
            let entropy = BIP39Mnemonic.Entropy(data)
            if let mnemonic = try? BIP39Mnemonic(entropy: entropy) {
                words = mnemonic.description
            }
        }
        
        return words
    }
    
    
        
    
    
   
    
    
    
    
    
    
    
   
    
    
    
    
}
