//
//  MetaWallet.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/01.
//

import UIKit
import web3Swift
import BigInt
import CryptoSwift
import JOSESwift
import JWTsSwift
import VerifiableSwift

public typealias TransactionRecipt = (EthereumClientError?, EthereumTransactionReceipt?) -> Void

public enum MetaTransactionType {
    case createDid
    case addWalletPublicKey
    case addServicePublicKey
    case removeKeys
    case removePublicKey
    case removeAssociatedAddress
}

public class MetaWallet: NSObject, MetaDelegatorMessenger {
    
    public enum WalletError: Error {
        case noneRegistryAddress(String)
    }
    
    public enum verifyError: Error {
        case networkError
        case noneDidDocument
        case failedVerify
        case noneKid
    }
    
    var account: EthereumAccount!
    
    var delegator: MetaDelegator!
    
    var metaID: String!

    var keyStore: EthereumKeystoreV3?
    
    var did: String! = ""
    var privateKey: String? = ""
    
    var didDocument: DiDDocument!
    
    
    func sendTxID(txID: String, type: MetaTransactionType) {
        
        let _ = self.transactionReceipt(type: type, txId: txID, complection: nil)
    }
    
    
    public init(delegator: MetaDelegator, privateKey: String? = "", did: String? = "") {
        super.init()
        
        self.delegator = delegator
        self.delegator.messenger = self
        
        self.privateKey = privateKey
        self.did = did
        
        /**
         * 로컬에 저장되어 있는 privateKey로 keystore를 가져온다.
         */
        if !privateKey!.isEmpty {
            do {
                self.keyStore = try EthereumKeystoreV3.init(privateKey: Data.init(hex: privateKey!))
                self.delegator.keyStore = self.keyStore
                self.account = try? EthereumAccount.init(keyStore: self.keyStore!)
                
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
    /**
     * 지갑 키 생성
     */
    public func createKey() -> MetadiumKey? {
        
        do {
            self.keyStore = try EthereumKeystoreV3.init()
            self.account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            self.delegator.keyStore = self.keyStore!
            
            let key = MetadiumKey()
            key.address = account?.address
            key.privateKey = account?.privateKey
            key.publicKey = account?.publicKey
            
            return key
            
        } catch  {
            print(error.localizedDescription)
        }
        
        return nil
    }
    
    
    
    /**
     * 서비스 키 생성
     */
    
    public func createServiceKey() -> MetadiumKey? {
        
        do {
            self.keyStore = try EthereumKeystoreV3.init()
            self.account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            self.delegator.keyStore = self.keyStore
            
            let key = MetadiumKey()
            key.address = account?.address
            key.privateKey = account?.privateKey
            key.publicKey = account?.publicKey
            
            return key
            
        } catch  {
            print(error.localizedDescription)
        }
        
        return nil
    }
    

    
    /**
     * @param  sign data
     */
    
    public func getSignature(data: Data) -> (Data?, String?, String?, String?) {
        
        if self.keyStore != nil {
            let account:EthereumAccount! = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            let signature = try? account.sign(data: data)
            
            let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
            let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
            let v = UInt8(signature![64]) + 27
            
            let vStr = String(format: "0x%02x", v)
            print(vStr)
            
            let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
            
            return (signData!, r, s, vStr)
        }
        
        return (nil, nil, nil, nil)
    }
    
    
    /**
     * create_identity delegate sign
     */
    public func getCreateKeySignature() throws -> (Data?, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let resolvers = self.delegator.registryAddress!.resolvers
        let providers = self.delegator.registryAddress!.providers
        let identityRegistry = self.delegator.registryAddress!.identityRegistry?.noHexPrefix
        
        let addr = self.delegator.keyStore!.addresses?.first?.address
        
        let temp = Data([0x19, 0x00])
        let identity = Data.fromHex(identityRegistry!)
        let msg = KDefine.KCreateIdentity.data(using: .utf8)
        let ass = Data.fromHex(addr!)
        
        let resolverData = NSMutableData()
        for resolver in resolvers! {
            let res = resolver
            let data = Data.fromHex("0x000000000000000000000000" + res.noHexPrefix)
            
            resolverData.append(data!)
        }
        
        
        let providerData = NSMutableData()
        for provider in providers! {
            let pro = provider
            let data = Data.fromHex("0x000000000000000000000000" + pro.noHexPrefix)
            
            providerData.append(data!)
        }
        
        let resolData = resolverData as Data
        let proviData = providerData as Data
        
        
        var timeStamp: Int!
        
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        
        let timeData = self.getInt32Byte(int: BigUInt(Int(timeStamp)))
        
        let data = (temp + identity! + msg! + ass! + ass! + proviData + resolData + timeData).keccak256
        
        self.delegator.signData = data
        
        
        let account = try? EthereumAccount.init(keyStore: self.delegator.keyStore)
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        let signature = try? account?.sign(data: prefixData! + data)
        
        let r = signature!!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature!![64]) + 27
        
        let vStr = String(format: "0x%02x", v)
        print(vStr)
        
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (signData!, r, s, vStr)
    }
    
    
    
    /**
     * add_public_key_delegated sign
     */

    public func getPublicKeySignature() throws -> (Data?, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let publicKeyResolverAddress = self.delegator.registryAddress!.publicKey

        let temp = Data([0x19, 0x00])

        let account = try? EthereumAccount.init(keyStore: self.delegator.keyStore)
        let address = account?.address
        let publicKey = account?.publicKey

        let msg = KDefine.KAdd_PublicKey.data(using: .utf8)
        let addrdata = Data.fromHex(address!)
        let publicKeyData = Data.fromHex(publicKey!)

        let pubKeyData = Data.fromHex(publicKeyResolverAddress!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }

        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))

        let data = (temp + pubKeyData! + msg! + addrdata! + publicKeyData! + timeData).keccak256

        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        let signature = try? account!.sign(data: prefixData! + data)

        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27

        let vStr = String(format: "0x%02x", v)
        print(vStr)
        
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (signData!, r, s, vStr)
    }
    
    
    
    /**
     * add_key_delegated sign
     */
    
    public func getSignServiceId(serviceID: String, serviceAddress: String) throws -> (String, Data?, String, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let resolver = self.delegator.registryAddress!.serviceKey
       
        let temp = Data([0x19, 0x00])
        let resolverData = Data.fromHex(resolver!)
        let msg = KDefine.kAddKey.data(using: .utf8)
        let keyData = Data.fromHex(serviceAddress)
        let symbol = serviceID.data(using: .utf8)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
       
        let data = (temp + resolverData! + msg! + keyData! + symbol! + timeData).keccak256
        print(data.toHexString())
       
       
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
       
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        print(account?.address)
       //ecRecover
        let afterAddr = Web3Utils.personalECRecover(data, signature: signature!)
        print(afterAddr?.address as Any)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (serviceAddress, signData!, serviceID, r, s, vStr)
    }
    
    
    public func getRemoveKeySign() throws -> (Data?, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let serviceKey = self.delegator.registryAddress!.serviceKey
       
        let temp = Data([0x19, 0x00])
        let serviceKeyData = Data.fromHex(serviceKey!)
        let msg = KDefine.KRemove_allKey.data(using: .utf8)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let data = (temp + serviceKeyData! + msg! + timeData).keccak256
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (signData!, r, s, vStr)
    }
    
    
    public func getRemovePublicKeySign() throws -> (Data?, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let publicKey = self.delegator.registryAddress!.publicKey
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.KRemove_PubliKey.data(using: .utf8)
        let publickeyData = Data.fromHex(publicKey!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let associateAddrData = Data.fromHex((self.keyStore!.addresses?.first!.address)!)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let data = (temp + publickeyData! + msg! + associateAddrData! + timeData).keccak256
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (signData!, r, s, vStr)
    }
    
    
    public func getRemoveAssociatedAddressSign() throws -> (Data?, String, String, String) {
        
        if self.delegator.registryAddress == nil {
            throw WalletError.noneRegistryAddress("noneRegistryAddress")
        }
        
        let identityRegistry = self.delegator.registryAddress!.identityRegistry
       
        let temp = Data([0x19, 0x00])
        let msg = KDefine.kRemove_Address_MyIdentity.data(using: .utf8)
        let identityRegistryData = Data.fromHex(identityRegistry!)
        
        var timeStamp: Int!
        
        DispatchQueue.global().sync {
            timeStamp = self.delegator.getTimeStamp()
        }
        
        let associateAddrData = Data.fromHex((self.keyStore!.addresses?.first!.address)!)
        
        let timeData = self.getInt32Byte(int: BigUInt(timeStamp))
        
        let ein = self.getDid().replacingOccurrences(of: self.delegator.didPrefix, with: "").withHexPrefix
        let einData = self.getInt32Byte(int: BigUInt(hex: ein)!)
        
        let data = (temp + identityRegistryData! + msg! + einData + associateAddrData! + timeData).keccak256
        
        let prefixData = (KDefine.kPrefix + String(data.count)).data(using: .ascii)
        
        let account = try? EthereumAccount.init(keyStore: self.keyStore!)
        let signature = try? account!.sign(data: prefixData! + data)
       
        let r = signature!.subdata(in: 0..<32).toHexString().withHexPrefix
        let s = signature!.subdata(in: 32..<64).toHexString().withHexPrefix
        let v = UInt8(signature![64]) + 27
        let vStr = String(format: "0x%02x", v)
       
        let signData = (r.noHexPrefix + s.noHexPrefix + vStr.noHexPrefix).data(using: .utf8)
        
        return (signData!, r, s, vStr)
    }
    
    
    
    
    
    //transactionReceipt
    public func transactionReceipt(type: MetaTransactionType, txId: String, complection: TransactionRecipt?) -> Void {

        self.delegator.ethereumClient.eth_getTransactionReceipt(txHash: txId) { (error, receipt) in
            if error != nil {
                return complection!(error, nil)
            }
            
            if receipt == nil {
                return complection!(error, nil)
            }
            
            if receipt!.status.rawValue == 0 {
                return complection!(nil, receipt)
            }
        
        
            if type == .createDid {
                
                var isEin: Bool?
                DispatchQueue.global().sync {
                    self.metaID = ""
                    self.did = ""
                    
                    isEin = self.getEin(receipt: receipt!)
                }
                
                
                if isEin != nil {
                    return complection!(nil, receipt)
                }
            }
            
            return complection!(nil, receipt)
        }
    }
    
    
    
    
    private func getEin(receipt: EthereumTransactionReceipt) -> Bool {
        
        let result = MHelper.getEvent(receipt: receipt, string: "{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"initiator\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"ein\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"recoveryAddress\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"associatedAddress\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"providers\",\"type\":\"address[]\"},{\"indexed\":false,\"name\":\"resolvers\",\"type\":\"address[]\"},{\"indexed\":false,\"name\":\"delegated\",\"type\":\"bool\"}],\"name\":\"IdentityCreated\",\"type\":\"event\"}")
        
        if (result.object(forKey: "ein") as! String).count > 0 {
            let ein = BigUInt(hex: (result.object(forKey: "ein") as? String)!)
            self.metaID = self.getInt32Byte(int: ein!).toHexString().withHexPrefix
            
            self.delegator.addPublicKey()
            
            return true
        }
        
        return false
    }
    

    
    
    public func getDiDDocument(did: String) {
            
        let semaPhore = DispatchSemaphore(value: 0)
        
        self.reqDiDDocument(did: did) { (didDocument, error) in
            if error != nil {
                semaPhore.signal()
                
                return
            }
            
            self.didDocument = didDocument
            
            semaPhore.signal()
        }
        
        semaPhore.wait()
    }
    
    
    
    public func verify(jwt: JWSObject) throws -> Bool {
        
        let kid = jwt.header.kid
        
        let arr = kid?.components(separatedBy: "#")
        
        if arr!.count > 0 {
            let did = arr![0]
            
            self.getDiDDocument(did: did)
            
            if self.didDocument == nil {
                throw verifyError.noneDidDocument
            }
            
            let publicKey = self.didDocument.publicKey
            
            let publicKeyHex = (publicKey![0] as NSDictionary)["publicKeyHex"] as? String
            let pubKey = Data.fromHex(publicKeyHex!)
            
            do {
                let verified = try jwt.verify(verifier: ECDSAVerifier.init(publicKey: pubKey!))
                
                return verified
            }
            catch {
                throw verifyError.failedVerify
            }
        }
        
        throw verifyError.noneKid
    }
    
    
    /**
     * Get didDocument
     */
    public func reqDiDDocument(did: String, complection: @escaping(DiDDocument?, Error?) -> Void) {
        
        let url = self.delegator.resolverUrl
        
        DataProvider.reqDidDocument(did: did, url: url!) { (response, result, error) in
            if error != nil {
                return complection(nil, error)
            }
            
            if let dic = result as? NSDictionary {
                
                if let dicDocu = dic["didDocument"] as? Dictionary<String, Any> {
                    
                    let didDocument = DiDDocument.init(dic: dicDocu)
                    
                    return complection(didDocument, nil)
                }
            }
        }
    }
    
    

    
    /**
     * Sign verifiable credential, presntation
     */
    public func sign(verifiable: Verifiable, nonce: String, claim: JWT?) throws -> JWSObject? {
        
        if let verify = verifiable as? VerifiableCredential {
            verify.issuer = self.getDid()
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex:self.account.privateKey)!)
            
            let jwsObj = try verify.sign(kid: self.getKid(), nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
            
            return jwsObj
        }
        
        if let verify = verifiable as? VerifiablePresentation {
            verify.holder = self.getDid()
            
            let privateKey = self.getInt32Byte(int: BigUInt(hex:self.account.privateKey)!)
            
            return try verify.sign(kid: self.getKid(), nonce: nonce, signer: ECDSASigner.init(privateKey: privateKey), baseClaims: claim)
        }
        
        return nil
    }
    
    
    
    /**
     * Issue verifiable credentail
     */
    public func issueCredential(types: [String], id: String?, nonce: String, issuanceDate: Date?, expirationDate: Date?, ownerDid: String, subjects: [String: Any]) throws -> JWSObject? {
        
        let vc = try? VerifiableCredential.init()
        vc!.addTypes(types: types)
        
        if id != nil {
            vc!.id = id
        }
        
        if issuanceDate != nil {
            vc?.issuanceDate = issuanceDate
        }
        
        if expirationDate != nil {
            vc?.expirationDate = expirationDate
        }
        
        let credentialSubject = NSMutableDictionary.init(dictionary: subjects)
        credentialSubject.setValue(ownerDid, forKey: "id")
        
        vc?.credentialSubject = credentialSubject
        
        return try self.sign(verifiable: vc!, nonce: nonce, claim: nil)
    }
    
    
    /**
     * Issue verifiable presentation
     */
    public func issuePresentation(types: [String], id: String?, nonce: String, issuanceDate: Date?, expirationDate: Date?, vcList: [String]) throws -> JWSObject? {
        let vp = try? VerifiablePresentation.init()
        vp?.addTypes(types: types)
        
        if id != nil {
            vp?.id = id
        }
        
        for vc in vcList {
            vp?.addVerifiableCredential(verifiableCredential: vc)
        }
        
        let claims = JWT()
        
        if issuanceDate != nil {
            claims.notBeforeTime = issuanceDate
            claims.issuedAt = issuanceDate
        }
        
        if expirationDate != nil {
            claims.expirationTime = expirationDate
        }
        
        return try self.sign(verifiable: vp!, nonce: nonce, claim: claims)
    }
    
    
    
    /**
     * did, privatekey의 json String
     */
    public func toJson() -> String? {
        
        if self.keyStore != nil {
            
            let account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            let dic = ["did": self.getDid(), "private_key": account!.privateKey]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
                
                let jsonStr = String(data: jsonData, encoding: .utf8)
                
                return jsonStr
            }
            catch {
                return nil
            }
        }
        
        return nil
    }
    
    
    
    
    public func getKey() -> MetadiumKey? {
        if self.keyStore != nil {
            let account = try? EthereumAccount.init(keyStore: self.keyStore!)
            
            let key = MetadiumKey()
            key.address = account?.address
            key.privateKey = account?.privateKey
            key.publicKey = account?.publicKey
            
            return key
        }
        
        return nil
    }
    
    
    public func getDid() -> String {
        
//        self.did = ""
        
        if !self.did.isEmpty {
            return self.did
        }
        
        if self.metaID != nil && !self.metaID.isEmpty {
            
            self.did = self.delegator.didPrefix + self.metaID.noHexPrefix
            
            print(self.did)
            
            return self.did
        }
        
        return self.did
    }
    
    
    public func getKid() -> String {
        
        var kid = ""
        let did = getDid()
        
        if !did.isEmpty {
            kid = did + "#MetaManagementKey#" + self.getAddress().lowercased().noHexPrefix
        }
        
        return kid
    }
    
    
    public func getAddress() -> String {
        
        var address: String = ""
        
        
        if self.keyStore != nil  {
            address = (self.keyStore?.addresses?.first!.address)!
        }
        
        return address
    }
    
    
    
    private func getInt32Byte(int: BigUInt) -> Data {
        let bytes = int.bytes // should be <= 32 bytes
        let byte = [UInt8](repeating: 0x00, count: 32 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
    
    func getInt16Byte(int: BigUInt) -> Data {
        let bytes = int.bytes // should be <= 20 bytes
        let byte = [UInt8](repeating: 0x00, count: 16 - bytes.count) + bytes
        let data = Data(bytes: byte)
        
        return data
    }
    
}
