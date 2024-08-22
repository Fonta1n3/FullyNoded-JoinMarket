//
//  Extensions.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/9/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation


public extension Date {
    var displayDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.string(from: self)
    }
    
    var secondsSince: Int {
        return Int(Date().timeIntervalSince(self))
    }
    
}


public extension String {
    var btc: String {
        return self + " btc"
    }
    
    var sats: String {
        var sats = self
        sats = sats.replacingOccurrences(of: "-", with: "")
        
        guard let dbl = Double(sats) else {
            return self + " sats"
        }
        
        if dbl < 1.0 {
            return dbl.avoidNotation + " sat"
        } else if dbl == 1.0 {
            return "1 sat"
        } else {
            if self.contains(".") || self.contains(",") {
                return "\(sats) sats"
            } else {
                return "\(sats.withCommas) sats"
            }
        }
    }
    
    var withCommas: String {
        let dbl = Double(self)!
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(from: NSNumber(value:dbl))!
    }
    
    var utf8: Data {
        return data(using: .utf8)!
    }
    
    func condenseWhitespace() -> String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
    static let numberFormatter = NumberFormatter()
    
    var doubleValue: Double {
        String.numberFormatter.decimalSeparator = "."

        if let result =  String.numberFormatter.number(from: self) {
            return result.doubleValue
        } else {
            String.numberFormatter.decimalSeparator = ","

            if let result = String.numberFormatter.number(from: self) {
                return result.doubleValue
            }
        }

        return 0
    }
    
    var satsToBtc: Double {
        var processed = "\(self)".replacingOccurrences(of: ",", with: "")
        processed = processed.replacingOccurrences(of: ".", with: "")
        processed = processed.replacingOccurrences(of: "-", with: "")
        processed = processed.replacingOccurrences(of: "+", with: "")
        processed = processed.replacingOccurrences(of: "sats", with: "").condenseWhitespace()
        let btc = Double(processed)! / 100000000.0
        return btc
    }
    
    var sha256Hash: String {
        return Crypto.sha256hash(self)
    }
    
    var btcToSats: String {
        return (Int(self.doubleValue * 100000000.0)).avoidNotation
    }
    
    var formatted: String {
        var formatted = ""
        for (i, word) in self.description.split(separator: " ").enumerated() {
            formatted += "   \(i + 1).  \(word)   "
        }
        return formatted
    }
    
    var withSpaces: String {
        var addressToDisplay = ""
        for (i, c) in self.enumerated() {
            addressToDisplay += "\(c)"
            if i > 0 && i < self.count - 2 {
                if i.isMultiple(of: 4) {
                    addressToDisplay += " - "
                }
            }
        }
        return addressToDisplay
    }
}


public extension Notification.Name {
    static let refreshNode = Notification.Name(rawValue: "refreshNode")
    static let refreshWallet = Notification.Name(rawValue: "refreshWallet")
}

public extension Data {
    var utf8String:String? {
        return String(bytes: self, encoding: .utf8)
    }
    
    /// A hexadecimal string representation of the bytes.
    var hexString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(count * 2)
        
        for byte in self {
            let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
        
        return String(utf16CodeUnits: hexChars, count: hexChars.count)
        
    }
    
    static func decodeUrlSafeBase64(_ value: String) throws -> Data {
        var stringtoDecode = value.condenseWhitespace()
        
        stringtoDecode = value.replacingOccurrences(of: "-", with: "+")
        stringtoDecode = stringtoDecode.replacingOccurrences(of: "_", with: "/")
        
        switch (stringtoDecode.utf8.count % 4) {
            case 2:
                stringtoDecode += "=="
            case 3:
                stringtoDecode += "="
            default:
                break
        }
        
        guard let data = Data(base64Encoded: stringtoDecode, options: [.ignoreUnknownCharacters]) else {
            
            throw NSError(domain: "decodeUrlSafeBase64", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Can't decode base64 string"])
        }
        
        return data
    }
    
    static func random(_ len: Int) -> Data {
        let values = (0 ..< len).map { _ in UInt8.random(in: 0 ... 255) }
        return Data(values)
    }

    var bytes: [UInt8] {
        var b: [UInt8] = []
        b.append(contentsOf: self)
        return b
    }
    
    var urlSafeB64String: String {
        return self.base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-")
    }
         
}

public extension Double {
    var btcToSats: Int {
        return Int(self * 100000000.0)
    }
    
    func rounded(toPlaces places:Int) -> Double {
        let divisor = Darwin.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var withCommas: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
    func withCommasNotRounded() -> String {
        let arr = "\(self)".split(separator: ".")
        let satoshis = "\(arr[1])"
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        let arr1 = (numberFormatter.string(from: NSNumber(value:self))!).split(separator: ".")
        let numberWithCommas = "\(arr1[0])"
        return numberWithCommas + "." + satoshis
    }
    
    var avoidNotation: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(for: self) ?? ""
    }
    
    var satsToBtc: String {
        var processed = "\(self)".replacingOccurrences(of: ",", with: "")
        processed = processed.replacingOccurrences(of: "-", with: "")
        processed = processed.replacingOccurrences(of: "+", with: "")
        processed = processed.replacingOccurrences(of: "sats", with: "").condenseWhitespace()
        let btc = processed.doubleValue / 100000000.0
        return btc.avoidNotation
    }
    
    var sats: String {
        let sats = self * 100000000.0
        
        if sats < 1.0 {
            return sats.avoidNotation + " sats"
        } else if sats == 1.0 {
            return "1 sat"
        } else {
            return "\(Int(sats).withCommas) sats"
        }
    }
    
    var btc: String {
        if self > 1.0 {
            return self.withCommasNotRounded() + " btc"
        } else {
            return self.avoidNotation + " btc"
        }
    }
    
    var balanceText: String {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        var symbol = "$"
        
        for curr in currencies {
            for (key, value) in curr {
                if key == currency {
                    symbol = value
                }
            }
        }
        
        var dbl = self
        
        if dbl < 0 {
            dbl = dbl * -1.0
        }
        
        if dbl < 1.0 {
            return "\(symbol)\(dbl.avoidNotation)"
        } else {
            return "\(symbol)\(dbl.rounded(toPlaces: 2).withCommas)"
        }
    }
    
    var exchangeRate: String {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        var symbol = "$"
        
        for curr in currencies {
            for (key, value) in curr {
                if key == currency {
                    symbol = value
                }
            }
        }
        
        return "\(symbol)\(self.withCommas) / btc"
    }
    
    var fiatString: String {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        var symbol = "$"
        
        for curr in currencies {
            for (key, value) in curr {
                if key == currency {
                    symbol = value
                }
            }
        }
        
        if self < 1.0 {
            return "\(symbol)\(self.avoidNotation)"
        } else {
            return "\(symbol)\(Int(self).withCommas)"
        }
    }
    
    var satsToBtcDouble: Double {
        return self / 100000000.0
    }
    
    var btcBalanceWithSpaces: String {
        var btcBalance = Swift.abs(self.rounded(toPlaces: 8)).avoidNotation
        btcBalance = btcBalance.replacingOccurrences(of: ",", with: "")
        
        if !btcBalance.contains(".") {
            btcBalance += ".0"
        }
        
        if self == 0.0 {
            btcBalance = "0.00 000 000"
        } else {
            var decimalLocation = 0
            var btcBalanceArray:[String] = []
            var digitsPastDecimal = 0
                        
            for (i, c) in btcBalance.enumerated() {
                btcBalanceArray.append("\(c)")
                if c == "." {
                    decimalLocation = i
                }
                if i > decimalLocation {
                    digitsPastDecimal += 1
                }
            }
            
            if digitsPastDecimal <= 7 {
                let numberOfTrailingZerosNeeded = 7 - digitsPastDecimal

                for _ in 0...numberOfTrailingZerosNeeded {
                    btcBalanceArray.append("0")
                }
            }
            
            btcBalanceArray.insert(" ", at: decimalLocation + 3)
            btcBalanceArray.insert(" ", at: decimalLocation + 7)
            btcBalance = btcBalanceArray.joined()
        }
        
        return btcBalance
    }
}

public extension Int {
    
    var avoidNotation: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(for: self) ?? ""
    }
    
    var satsToBtcDouble: Double {
        return Double(self) / 100000000.0
    }
    
    var withCommas: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
}
