 

import Foundation
import UIKit
import Alamofire
 
 class CommonRequest: NSObject {
    
    /**
     数据请求
     
     - parameter method:     请求方式
     - parameter url:        请求URL
     - parameter params:     请求参数
     - parameter cacheTime:  缓存时间，传入大于0的参数，缓存才起效
     - parameter superView:  显示加载HUD的视图，可不传
     
     - parameter callBack:   请求回调
     - parameter statusCode: 请求结束状态码
     - parameter resultData: 请求结束数据
     */
    static func request(method: Alamofire.Method, url: String, params: [String: AnyObject]?, cacheTime: Int64 = -1, superView: UIView?, callBack:(fromCache: Bool, statusCode: Int, resultData: AnyObject?) -> Void) {
        
        //检查cache time （如果不是get请求或者不是get请求的第一页时，重置cacheTime = -1.即不缓存）
        // page 和 until 属性字段可根据项目更改
        var cache = cacheTime
        if cache != -1 && (method != .GET || (params != nil && ((params!.keys.contains("page") && "1" != params!["page"] as! String) || (params!.keys.contains("until") && "0" != params!["until"] as! String)))) {
            cache = -1
        }
        
        //构建请求体
        let builder: EasyBuilder = EasyLoad.loadUrl(url).parameters(params).progressSuperView(superView).localDataTime(cache)
        
        //构建请求Request，并指定请求方式
        var request: EasyRequest?
        
        switch method {
        case .GET:
            request = builder.asGet()
        case .POST:
            request = builder.asPost()
        case .DELETE:
            request = builder.asDelete()
        default:
            request = builder.asGet()
        }
        
        //如果reqeust构建成功，则发起真正的请求
        if let r = request {
            r.request(completion: { (local, response, data, error) -> Void in
                
                //根据请求返回的状态码(statusCode)，返回不同的消息
                var statusCode = -1
                if let res = response {
                    statusCode = res.statusCode
                }
                
                if (statusCode != -1 && statusCode != 200) {
                    var errMsg = "网络异常"
                    if let d = data {
                        errMsg = d as! String
                    }
                    
                    debugPrint("请求异常 >>>>>>>>  ERROR MSG : \(errMsg)")
                    
                    MessageTool.showMessage(errMsg, isError: true)
                }
                callBack(fromCache: local, statusCode: statusCode, resultData: data)
            })
        }else{
            debugPrint("请求参数错误，必须指定请求方式")
            callBack(fromCache: false, statusCode: -1, resultData: nil)
        }
    } 
    
    /**
     图片上传
     
     - parameter url:          上传url
     - parameter image:        图片对象（UIImage）
     - parameter key:          上传时指定的key
     - parameter loadProgress: 上传进度（可能需要服务器支持后，才有效）  可不使用
     - parameter callBack:     上传完成回调
     - parameter resultString: 上传返回图片id
     */
    static func uploadImage(url: String, image: UIImage, key: String, uploadProgress: ((Int64, Int64, Int64) -> Void)?, callBack: (statusCode: Int, resultString: String?) -> Void) {
        
        let uploadData = UIImageJPEGRepresentation(image, 0.7)
        
        if let data = uploadData {
            EasyLoad.loadUrl(url).asUpload().upload([key: data], progress: { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
                if let p = uploadProgress{
                    p(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                }
                }) { (response, responseString, error) -> Void in
                    
                    if let _ = error {
                        callBack(statusCode: (response?.statusCode)!, resultString: nil)
                    }else {
                        callBack(statusCode: (response?.statusCode)!, resultString: responseString)
                    }
            }
        }else{
            debugPrint("预上传的图片为空，请检查图片")
            callBack(statusCode: -1, resultString: nil)
        }
    }
    
    /**
     文件下载
     
     - parameter url:          下载URL
     - parameter folderName:   文件保存文件夹名称
     - parameter downProgress: 下载进度
     - parameter callBack:     完成回调
     - parameter filePath:     文件路径
     */
    static func downloadFile(url: String, folderName: String, downProgress: ((Int64, Int64, Int64) -> Void)?, callBack:(statusCode: Int, filePath: NSURL) -> Void){
        
        EasyLoad.loadUrl(url)
            .asDownload()
            .download(folderName, progress: { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
                if let p = downProgress{
                    p(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                }
                }, responseCallBack: { (url, response) -> Void in
                    
                    print("请求结果 : 文件本地路径 \(url)== 请求响应 \(response)")
                    
                    callBack(statusCode: (response?.statusCode)!, filePath: url!)
            })
    }
    
 }