
import UIKit
import MercariQRScanner

/*
 라이브러리 사용
 https://github.com/mercari/QRScanner 참조
 */
public class QRScannerViewController: UIViewController {
    
    @IBOutlet weak var closeBtn : UIButton!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let qrScannerView = QRScannerView(frame: view.bounds)
//        view.addSubview(qrScannerView)
        view.insertSubview(qrScannerView, belowSubview: closeBtn)
        qrScannerView.configure(delegate: self)
        qrScannerView.startRunning()
    }
    
    @IBAction func onPressCloseBtn(_ sender : UIButton){
        print("onPressCloseBtn!!!")
        let dataDict:[String: String] = ["qrCode": ""]
        NotificationCenter.default.post(name: Notification.Name("receiveQRNotification"), object: nil, userInfo: dataDict)
        dismiss(animated: true, completion: nil)
    }
    
}

/*
 응답받은 데이터를 노티피케이션을 통해 전달
 */
extension QRScannerViewController: QRScannerViewDelegate {
    public func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: QRScannerError) {
        // 실패시
        let dataDict:[String: String] = ["qrCode": ""]
        NotificationCenter.default.post(name: Notification.Name("receiveQRNotification"), object: nil, userInfo: dataDict)
        dismiss(animated: true)
    }
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String) {
        // 성공시
        let dataDict:[String: String] = ["qrCode": code]
        NotificationCenter.default.post(name: Notification.Name("receiveQRNotification"), object: nil, userInfo: dataDict)
        dismiss(animated: true)
    }
}
