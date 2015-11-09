import Foundation
import Alamofire
import UIKit

class EasyRequest {
    let builder: EasyBuilder

    var method: Alamofire.Method

    var encoding: ParameterEncoding = .URL

    let progressView: UIView = UIView()
     
    var messageHUD: MBProgressHUD = MBProgressHUD()

    init(method: Alamofire.Method, Builder builder: EasyBuilder) {
        self.builder = builder
        self.method = method
    }

    func request(completion completionHandler: (local:Bool, response:NSHTTPURLResponse?, data:AnyObject?, error:NSError?) -> Void) {

        debugPrint("EasyRequest request: \(self.builder.url) parameters: \(self.builder.parameters)")

        if let superView = self.builder.superView {
            self.showMessageHUD(superView)
        }
 
        if self.method == .POST {
            self.encoding = .JSON
        }

        EasyDB(Builder: builder).request {
            (loadNet, data, error) -> Void in


            if data != nil {
                
                if let _ = self.builder.superView {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.hideMessageHUD()
                    })
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler(local: true, response: NSHTTPURLResponse(URL: NSURL(string: self.builder.url)!, statusCode: 200, HTTPVersion: "1.0", headerFields: nil), data: EasyUtil.dictionaryWithJson(data as! String), error: nil)
                })
                
            }
            
            print("\(self.builder.url) >>>>>>>> \(self.builder.parameters)")
        

            if loadNet {
                Alamofire.request(self.method, self.builder.url, parameters: self.builder.parameters, encoding: self.encoding)
                    .responseString { response in
                    
                        if let _ = self.builder.superView {
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.hideMessageHUD()
                            })
                        }
                        
                        switch response.result {
                        case .Success:
                            if  response.response?.statusCode == 200  && response.result.value != nil {
                                if self.builder.exceedTime > 0{
                                    EasyDB(Builder: self.builder).save(response.result.value!)
                                }
                                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                    completionHandler(local: false, response: response.response, data: EasyUtil.dictionaryWithJson(response.result.value!), error: nil)
                                })
                                
                            } else {
                                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                    completionHandler(local: false, response: response.response, data: response.result.value, error: nil)
                                })
                            }
                            break
                        case .Failure:
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                completionHandler(local: false, response: response.response, data: response.result.value, error: nil)
                            })
                            break
                        }
                    }
            }
        }
    }

   private func showMessageHUD(superView: UIView?) {
        if let hudView = superView{
            messageHUD = MessageTool.showProcessMessage("加载中...", view: hudView)
        }else{
            messageHUD = MessageTool.showProcessMessage("加载中...")
        }
    }

    private func hideMessageHUD() {
        messageHUD.hide(true)
    }
}
