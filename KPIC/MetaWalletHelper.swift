//
//  File.swift
//  KeepinCRUD_Example
//
//  Created by 주식회사두위더스 on 2022/01/12.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation
import Security

enum KeychainError: Error {
    // Attempted read for an item that does not exist.
    case itemNotFound
    
    // Attempted save to override an existing item.
    // Use update instead of save to update existing items
    case duplicateItem
    
    // A read of an item in any format other than Data
    case invalidItemFormat
    
    // Any operation result status than errSecSuccess
    case unexpectedStatus(OSStatus)
}

class MetaWalletHelper {
    
    static func save(data: String, service: String, account: String) throws {

        let query: [CFString: Any] = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            // kSecValueData is the item value to save
            kSecValueData: data.data(using: .utf8, allowLossyConversion: false)!
        ]
        
        // SecItemAdd attempts to add the item identified by
        // the query to keychain
        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        // errSecDuplicateItem is a special case where the
        // item identified by the query already exists. Throw
        // duplicateItem so the client can determine whether
        // or not to handle this as an error
        if status == errSecDuplicateItem {
            throw KeychainError.duplicateItem
        }

        // Any status other than errSecSuccess indicates the
        // save operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        print("")
        print("[MetaWalletHelper >> storeWalletParam() : Success Status : \(status)]")
        print("")
    }
    
    static func update(data: String, service: String, account: String) throws {
        let query: [CFString: Any] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to update in Keychain
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ]
        
        // attributes is passed to SecItemUpdate with
        // kSecValueData as the updated item value
        let attributes: [CFString: Any] = [
            kSecValueData: data.data(using: .utf8, allowLossyConversion: false)!
        ]
        
        // SecItemUpdate attempts to update the item identified
        // by query, overriding the previous value
        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        // errSecItemNotFound is a special status indicating the
        // item to update does not exist. Throw itemNotFound so
        // the client can determine whether or not to handle
        // this as an error
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        // Any status other than errSecSuccess indicates the
        // update operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        print("")
        print("[MetaWalletHelper >> update() : Success Status : \(status)]")
        print("")
    }
    
    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to delete in Keychain
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword
        ]

        // SecItemDelete attempts to perform a delete operation
        // for the item identified by query. The status indicates
        // if the operation succeeded or failed.
        let status = SecItemDelete(query as CFDictionary)

        // Any status other than errSecSuccess indicates the
        // delete operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func read(service: String, account: String) throws -> String {
        let query: [CFString: Any] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to read in Keychain
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            // kSecMatchLimitOne indicates keychain should read
            // only the most recent item matching this query
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnAttributes: true,
            // kSecReturnData is set to kCFBooleanTrue in order
            // to retrieve the data for the item
            kSecReturnData: true
        ]
        
//        let query:[CFString: Any]=[kSecClass: kSecClassGenericPassword, // 보안 데이터 저장
//                                   kSecAttrService: service, // 키 체인에서 해당 앱을 식별하는 값 (앱만의 고유한 값)
//                                   kSecAttrAccount : account, // 앱 내에서 데이터를 식별하기 위한 키에 해당하는 값 (사용자 계정)
//                                   kSecReturnData : true, // kSecReturnData에 true를 리턴시켜 값을 불러옵니다
//                                   kSecReturnAttributes: true, // kSecReturnAttributes에 true를 리턴시켜 값을 불러옵니다
//                                   kSecMatchLimit : kSecMatchLimitOne] // 값이 일치하는 것을 찾습니다

        // SecItemCopyMatching will attempt to copy the item
        // identified by query to the reference itemCopy
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &itemCopy
        )

        // errSecItemNotFound is a special status indicating the
        // read item does not exist. Throw itemNotFound so the
        // client can determine whether or not to handle
        // this case
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        // Any status other than errSecSuccess indicates the
        // read operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        // This implementation of KeychainInterface requires all
        // items to be saved and read as Data. Otherwise,
        // invalidItemFormat is thrown
        guard let result = itemCopy as? [String: Any] else {
            throw KeychainError.invalidItemFormat
        }
        
        let value = result[kSecValueData as String] as? Data
        let data = String(data: value!, encoding: .utf8)!
        
        return data
    }
    
    
    
    
}
