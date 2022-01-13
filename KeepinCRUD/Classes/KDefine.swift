//
//  KDefine.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/11/27.
//

import Foundation


class KDefine: NSObject {
    static let kEntropy_Length: Int = 16
    static let kBip44PrefixPath: String = "m/44'/916'/0'/0"
    static let kAes128CBC: String = "aes-128-cbc"
    
    static let kMetadium_Real_EndPoind: String = "https://api.metadium.com/prod"
    static let kMetadium_Test_EndPoind: String = "https://delegator.metadium.com"
    
    static let kResolver_Identifiers: String = "https://resolver.metadium.com/1.0/identifiers/"
    
    static let kPrefix: String = "\u{19}Ethereum Signed Message:\n"
    
    static let KCreateIdentity: String = "I authorize the creation of an Identity on my behalf."
    static let kAddKey: String = "I authorize the addition of a service key on my behalf."
    static let kRmovekey: String = "I authorize the removal of a service key on my behalf."
    static let KRemove_allKey: String = "I authorize the removal of all service keys on my behalf."
    static let KAdd_PublicKey: String = "I authorize the addition of a public key on my behalf."
    static let KRemove_PubliKey: String = "I authorize the removal of a public key on my behalf."
    static let kRemove_Address_MyIdentity: String = "I authorize removing this address from my Identity."
}

