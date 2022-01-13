//
//  ViewController.swift
//  Sample
//
//  Created by 주식회사두위더스 on 2022/01/11.
//

import UIKit
import WebKit
import AVFoundation
import web3Swift
import KeepinCRUD
import JWTsSwift

/*
 웹뷰 JS 호출 코드 모음
 */
enum DISPATCH_CODE : String{
    case CLOSE_APP = "CLOSE_APP" // 앱종료
    case START_PERMISSION = "START_PERMISSION" // 권한 요청
    case QR_READER = "QR_READER" // QR스캔 호출
    case REG_PASSCODE = "REG_PASSCODE" // 제로페이 호출
    case REG_FINGER_PRINT = "REG_FINGER_PRINT" // 전화걸기 호출
    case GET_DID = "GET_DID" // 쿠키 저장
    case CREATE_DID = "CREATE_DID" // 쿠키 삭제
    case DELETE_DID = "DELETE_DID" // 로케이션 정보 호출
    case GET_APP_VERSION = "GET_APP_VERSION" // 공유하기 호출
    case CHECK_AUTH = "CHECK_AUTH" // 공유하기 호출
    case HP_CERT = "HP_CERT" // 공유하기 호출
    case UPDATE_FIDO_USAGE = "UPDATE_FIDO_USAGE"
}

class ViewController: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler {

    var webview : WKWebView!
    var windowPopUpWebView: WKWebView? //window.open()으로 열리는 새창
    var scriptCallbackFn: String = ""
    
    let BASE_URL = "http://211.188.64.221:2500/post/"
    
    let account = "KpicKeyPair"
    let service = Bundle.main.bundleIdentifier!

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        var webview : WKWebView!
        // Do any additional setup after loading the view.
        
        setupWebView()
        let urlString = BASE_URL
        let url = URL(string: urlString)
        
        self.webview.load(URLRequest(url: url!))
        
        // QR 스캔 정보 노티피케이션 등록
        NotificationCenter.default.addObserver(self,selector: #selector(receiveQRNotification(_:)),name: NSNotification.Name("receiveQRNotification"),object: nil)
    }
    
    /**
     웹뷰 설정
     */
    func setupWebView() {
        
        
        let preferences = WKPreferences()
//        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
//        configuration.websiteDataStore = WKWebsiteDataStore
        
        let userController : WKUserContentController = WKUserContentController()
        userController.add(self, name: "dispatch")
        
        configuration.userContentController = userController
        
        webview = WKWebView(frame: view.bounds, configuration: configuration)
        webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webview.uiDelegate = self
        webview.navigationDelegate = self
        
        view.addSubview(webview)
        
        let paddingConstant:CGFloat = 0
        let guide = self.view.safeAreaLayoutGuide
        
        webview.translatesAutoresizingMaskIntoConstraints = false
        
        webview.topAnchor.constraint(equalTo: guide.topAnchor, constant: paddingConstant).isActive = true
        webview.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -paddingConstant).isActive = true
        webview.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: paddingConstant).isActive = true
        webview.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -paddingConstant).isActive = true
        
//        webview.addGestureRecognizer(self.rightSwipe)
    }
    
    func dispatchCallback(scriptCallbackFn: String, resultCode: String, jsonData: String){
        let script = String(format: "javascript: %@({RESULT: '%@', DATA: %@})",scriptCallbackFn,resultCode,jsonData)
        print("dispatchCallback: \(script)")
        self.webview.evaluateJavaScript(script, completionHandler: {(result, error) in
            if let result = result {
                print(result)
            }
        })
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        
        if(message.name == "dispatch"){
            
            print("userContentController didReceive dispatch data \(message.body)")
            
            let jsonString:String = message.body as! String
            
            let dic = jsonString.jsonStringToDictionary
            
        
            
            if(dic?["scriptFn"] == nil){
                scriptCallbackFn = "callback_HP_CERT";
            }else {
                scriptCallbackFn = dic?["scriptFn"] as! String
            }
            scriptCallbackFn = dic?["scriptFn"] as! String
            let code = (dic?["code"])! as! String
            let data = (dic?["data"])!
            
            
            print("code: \(code)")
            print("data: \(data)")
            
            
            if(code == DISPATCH_CODE.CLOSE_APP.rawValue){ // 알림 권한 요청
                
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                
            }else if(code == DISPATCH_CODE.START_PERMISSION.rawValue){ // 공유하기
                
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { (didAllow, error) in
                    
                    DispatchQueue.main.async {
                        
                        self.dispatchCallback(scriptCallbackFn: self.scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                    }
                })
                
            }else if(code == DISPATCH_CODE.QR_READER.rawValue){ // 앱투앱 결제 요청
                
                AVCaptureDevice.authorizeVideo(completion: { (status) in
                    if(status == AVCaptureDevice.AuthorizationStatus.alreadyAuthorized || status == AVCaptureDevice.AuthorizationStatus.justAuthorized){
                        DispatchQueue.main.async {
                            guard let qsv = self.storyboard?.instantiateViewController(withIdentifier: "QSV") as? QRScannerViewController else{ return }
                            qsv.modalPresentationStyle = .fullScreen
                            self.present(qsv, animated: true)
                        }
                    }else{
                        let alertController = UIAlertController (title: "알림", message: "카메라 권한이 없습니다. 설정 화면에서 카메라 권한에 동의하여 주십시오.", preferredStyle: .alert)
                        
                        let settingsAction = UIAlertAction(title: "설정화면가기", style: .default) { (_) -> Void in
                            
                            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                                return
                            }
                            
                            if UIApplication.shared.canOpenURL(settingsUrl) {
                                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                    print("Settings opened: \(success)") // Prints true
                                })
                            }
                        }
                        alertController.addAction(settingsAction)
                        let cancelAction = UIAlertAction(title: "취소", style: .default, handler: nil)
                        alertController.addAction(cancelAction)
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
                })
                
            }else if(code == DISPATCH_CODE.REG_PASSCODE.rawValue){ // QR 스캔 요청
                
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                
            }else if(code == DISPATCH_CODE.REG_FINGER_PRINT.rawValue){ // 전화걸기 화면 호출
                
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                
            }else if(code == DISPATCH_CODE.GET_DID.rawValue){ // 전화걸기 화면 호출
                
                let did = getDID();
                if(did .isEmpty){
                    self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "NO", jsonData: "{}")
                }else{
                    self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{DID: '\(did)'}")
                }
                
                
            }else if(code == DISPATCH_CODE.CREATE_DID.rawValue){ // 전화걸기 화면 호출
                createDID()
                
                
            }else if(code == DISPATCH_CODE.DELETE_DID.rawValue){ // 전화걸기 화면 호출
                
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                
            }else if(code == DISPATCH_CODE.GET_APP_VERSION.rawValue){ // 전화걸기 화면 호출
                let version = currentAppVersion()
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{appVersion:'\(version)'}")
                
            }else if(code == DISPATCH_CODE.CHECK_AUTH.rawValue){ // 전화걸기 화면 호출
                
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
                
            }else if(code == DISPATCH_CODE.HP_CERT.rawValue){ // 전화걸기 화면 호출
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: (dic?["data"])!, options: [])
                    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                    self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: jsonString)
                } catch {
                    
                }
            }else if(code == DISPATCH_CODE.UPDATE_FIDO_USAGE.rawValue){
                self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
            }
        }
    }
    
    /*
     QR 스캔 정보 노티피케이션 콜백함수
     */
    @objc
    func receiveQRNotification(_ notification: Notification?) {
        
        guard let qrCode: String = notification?.userInfo?["qrCode"] as? String else { return }
        
        print("qrCode :", qrCode)
        
        self.dispatchCallback(scriptCallbackFn: scriptCallbackFn, resultCode: "OK", jsonData: "{}")
        
        
        
//        let url = URL(string: qrCode)
//
//        guard let host: String = url?.host else { return }
        
        
        
//        if (host == "sdl.kisvan.co.kr" || host == "orderdev.kisvan.co.kr"){
//            let data : Dictionary = url!.queryDictionary!
//            let strId = data["strId"]!
//            let storeCd = data["storeCd"]!
//            print(data["strId"]!)
//
//            let script = String(format : "window.dispatchEvent(new CustomEvent('SDL_dispatchInternalQR',{detail : {type : 'QRCODE' , data : { strId : '%@' , storeCd : '%@'}} }))", strId,storeCd)
//
//            print("receiveQRNotification SDL_dispatchInternalQR  \(script)")
//
//            self.webview.evaluateJavaScript(script, completionHandler: {(result, error) in
//                if let result = result {
//                    print(result)
//                }
//            })
//        }
    }
    
    //WKUIDelegate 3가지 필수 Callback 함수
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: {(action) in
            completionHandler()
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in
            completionHandler(false)
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: "", message: prompt, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let request = navigationAction.request
        let optUrl = request.url
        let optUrlScheme = optUrl?.scheme
        
        guard let url = optUrl, let scheme = optUrlScheme else { return decisionHandler(WKNavigationActionPolicy.cancel)}
        
        // 나이스 PG 설정
        if( scheme != "http" && scheme != "https" ) {
            if( scheme == "ispmobile" && !UIApplication.shared.canOpenURL(url) ) {  //ISP 미설치 시
                UIApplication.shared.openURL(URL(string: "http://itunes.apple.com/kr/app/id369125087?mt=8")!)
            } else if( scheme == "kftc-bankpay" && !UIApplication.shared.canOpenURL(url) ) {    //BANKPAY 미설치 시
                UIApplication.shared.openURL(URL(string: "http://itunes.apple.com/us/app/id398456030?mt=8")!)
            } else {
                if( UIApplication.shared.canOpenURL(url) ) {
                    UIApplication.shared.openURL(url)
                }
            }
        }
        
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    /*
     웹뷰에서 window.open 시 호출되는 함수
     */
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        //뷰를 생성하는 경우
        let frame = UIScreen.main.bounds
        
        //파라미터로 받은 configuration
        windowPopUpWebView = WKWebView(frame: frame, configuration: configuration)
        
        //오토레이아웃 처리
        windowPopUpWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        windowPopUpWebView!.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        windowPopUpWebView!.navigationDelegate = self
        windowPopUpWebView!.uiDelegate = self
        
        view.addSubview(windowPopUpWebView!)
        
//        windowPopUpWebView!.addGestureRecognizer(self.rightSwipe)
        
        return windowPopUpWebView!
        
    }
    
    // WKNavigationDelegate 중복적으로 리로드 방지 (iOS 9 이후지원)
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
    
    /*
     웹뷰에서 window.close 시 호출되는 함수
     */
    public func webViewDidClose(_ webView: WKWebView) {
        if webView == windowPopUpWebView {
            windowPopUpWebView!.removeFromSuperview()
            windowPopUpWebView = nil
        }
    }
    
    func currentAppVersion() -> String {
      if let info: [String: Any] = Bundle.main.infoDictionary,
          let currentVersion: String
            = info["CFBundleShortVersionString"] as? String {
            return currentVersion
      }
      return "nil"
    }
    
    func getMetaDelegator() -> MetaDelegator {
//        return MetaDelegator.init(delegatorUrl: "http://211.188.64.200:8545",
//                                  nodeUrl: "http://211.188.64.200:8588",
//                                  resolverUrl: "http://211.188.64.200:3006/1.0/",
//                                  didPrefix: "did:koreapost:testnet",
//                                  api_key: "abcd1234efgzPiefqeq3l1ba344gg")
        return MetaDelegator.init(delegatorUrl: "https://testdelegator.metadium.com",
                                  nodeUrl: "https://api.metadium.com/dev",
                                  resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                  didPrefix: "did:meta:testnet:",
                                  api_key: "abcd1234efgzPiefqeq3l1ba344gg")
    }
    
    func getDID() -> String{

        var data: String = ""
        
        do{
            data = try MetaWalletHelper.read(service: service, account: account)
        }catch{
            print(error)
        }
        
        if(!data .isEmpty){
            let delegator:MetaDelegator = getMetaDelegator()
            let dic = data.jsonStringToDictionary
            let didParam = dic?["did"] as! String
            let keyParam = dic?["private_key"] as! String
            
            let wallet: MetaWallet = MetaWallet.init(delegator: delegator, privateKey: keyParam, did: didParam)
            
            var result:Bool = false

            let semaPhore = DispatchSemaphore(value: 0)
            wallet.reqDiDDocument(did: didParam) { (didDocument, error) in
                if error != nil {
                    semaPhore.signal()
                    return
                }

                result = true
                semaPhore.signal()
            }
            semaPhore.wait()
            
            if(result){
                return didParam
            }
            
            return ""
            
        }else{
            // DID 없다
            return ""
        }
        return ""
    }
    
    func createDID() {
        
        let delegator:MetaDelegator = getMetaDelegator()

        let wallet: MetaWallet = MetaWallet.init(delegator: delegator)
        wallet.createKey()
        
        do {
            let (signData, r, s, v) = try wallet.getCreateKeySignature()

            delegator.createIdentityDelegated(signData: signData!, r: r, s: s, v: v) { (type, txId, error) in
                if error != nil {
                    return
                }

                //delay를 주지 않으면 트랜잭션 리셉 받아올 때 error가 떨어지기 때문에 어느정도의 delay가 필요합니다.
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {

                    wallet.transactionReceipt(type: type!, txId: txId!) { (error, receipt) in

                        if error != nil {
                            return
                        }

                        if receipt == nil {
                            wallet.transactionReceipt(type: type!, txId: txId!, complection: nil)

                            return
                        }

                        print("status: \(receipt!.status), hash : \(receipt!.transactionHash)")


                        let did = wallet.getDid()
                        print(did)

                        let jsonStr:String = wallet.toJson()!
                        print(jsonStr)
                        
                        do {
                            try MetaWalletHelper.save(data: jsonStr, service: self.service, account: self.account)
                        }catch KeychainError.duplicateItem {
                            do{
                                try MetaWalletHelper.update(data: jsonStr, service: self.service, account: self.account)
                            }catch{
                                print(error)
                            }
                        } catch {
                            
                        }

                        DispatchQueue.main.async {
//                            MKeepinUtil.showAlert(message: did, controller: self, onComplection: nil)
                            if(did .isEmpty){
                                self.dispatchCallback(scriptCallbackFn: self.scriptCallbackFn, resultCode: "NO", jsonData: "{}")
                            }else{
                                self.dispatchCallback(scriptCallbackFn: self.scriptCallbackFn, resultCode: "OK", jsonData: "{DID: '\(did)'}")
                            }
                        }
                    }
                }
            }
        }
        catch {
            print(error)
        }
    }
    
    func deleteDID() {
        
        var data: String = ""
        
        do{
            data = try MetaWalletHelper.read(service: service, account: account)
        }catch{
            print(error)
        }
        
        if(!data .isEmpty){
            let delegator:MetaDelegator = getMetaDelegator()
            let dic = data.jsonStringToDictionary
            let didParam = dic?["did"] as! String
            let keyParam = dic?["private_key"] as! String
            
            let wallet: MetaWallet = MetaWallet.init(delegator: delegator, privateKey: keyParam, did: didParam)
            
            
            do {
                let (_, r, s, v) = try wallet.getRemovePublicKeySign()

                delegator.removePublicKeyDelegated(r: r, s: s, v: v, complection: { (type, txId, error) in
                    if error != nil {
                        return
                    }

                    wallet.transactionReceipt(type: type!, txId: txId!, complection: { (error, receipt) in
                        if receipt!.status == .success {
                            do {
                                let (_, r, s, v) = try wallet.getRemoveAssociatedAddressSign()

                                delegator.removeAssociatedAddressDelegated(r: r, s: s, v: v, complection: { (type, txId, error) in
                                    if error != nil {
                                        return
                                    }
                                    wallet.transactionReceipt(type: type!, txId: txId!, complection: { (error, receipt) in
                                        if receipt!.status == .success {
                                            
                                            do {
                                                try MetaWalletHelper.delete(service: self.service, account: self.account)
                                                DispatchQueue.main.async {
                                                    let alert = UIAlertController.init(title: "ddd", message: receipt!.transactionHash, preferredStyle: .alert)
                                                    let action = UIAlertAction.init(title: "확인", style: .default, handler: nil)

                                                    alert.addAction(action)
                                                    self.present(alert, animated: true, completion: nil)
                                                }
                                            }catch{
                                                print(error)
                                            }
                                        }
                                        else {
                                            //
                                        }
                                    })
                                })
                            } catch {
                                //
                            }
                        }
                        else {
                            //
                        }
                    })
                })
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
}

