 
 
 import Foundation
 
 
 #if DEBUG
    let kBaseURL = "http://42.62.77.92/api"
 #else
    let kBaseURL = "http://api.zsreader.com/api"
 #endif
 
 
 //分页大小
 private let kPageSize: Int64 = 20
 
 //初始缓存时间  单位:毫秒
 private let kCacheTime: Int64 = 10
 
 
 class APIManager: NSObject {
    
    //单例
    class var manager: APIManager {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: APIManager? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = APIManager()
        }
        return Static.instance!
    }
    
    
    //*****************************Demo  Methods***************************************
    
    //模拟POST请求
    func loginWithMobile(mobile: String, password: String, superView: UIView, callBack: (statusCode: Int, resultData: AnyObject?) -> Void){
        let parameters = ["mobile" : mobile, "password" : password]
        let URL: String = kBaseURL + "/pub/login"
        
        CommonRequest.request(.POST, url: URL, params: parameters, superView: superView) { (fromCache, statusCode, resultData) -> Void in
            callBack(statusCode: statusCode, resultData: resultData)
        }
    }
    
    //模拟GET请求
    func getUserInfo(userId: String, superView: UIView, callBack: (statusCode: Int, resultData: AnyObject?) -> Void) {
        let URL: String = kBaseURL + "/me/user/\(userId)"
        
        CommonRequest.request(.GET, url: URL, params: nil,cacheTime: 10, superView: superView) { (fromCache, statusCode, resultData) -> Void in
            callBack(statusCode: statusCode, resultData: resultData)
        }
    }

    //模拟DELETE请求
    func favourReview(reviewId: String, praise: Bool, callBack:(statusCode: Int) -> Void){
        let URL: String = kBaseURL + "/me/review/\(reviewId)/praise"
        CommonRequest.request(praise ? .DELETE : .POST, url: URL, params: nil, superView: nil) { (fromCache, statusCode, resultData) -> Void in
            callBack(statusCode: statusCode)
        }
    }
 }
 
 
