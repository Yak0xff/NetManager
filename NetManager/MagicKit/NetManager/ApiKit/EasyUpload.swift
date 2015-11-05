import Foundation
import Alamofire

class EasyUpload {

    let builder: EasyBuilder

    init(Builder builder: EasyBuilder) {
        self.builder = builder
    }


    func upload(datas: [String:NSData], responseCallBack: (NSHTTPURLResponse?, String?, NSError?) -> Void){
        upload(datas, progress:nil, responseCallBack:responseCallBack)
    }
    
    func upload(datas: [String:NSData], progress: ((Int64, Int64, Int64) -> Void)?, responseCallBack: (NSHTTPURLResponse?, String?, NSError?) -> Void) {
        Alamofire.upload(
                .POST,
                self.builder.url,
                multipartFormData: {
                    multipartFormData in
                    for (key, value) in datas {
                        multipartFormData.appendBodyPart(data: value, name: key, fileName: key, mimeType: "image/jpeg")
                    }
                },
                encodingCompletion: {
                    encodingResult in
                    switch encodingResult {
                    case .Success(let upload, _, _ ):
                        upload.progress {
                            bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
                            if let p = progress{
                                p(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                            }
                        }
                        .responseString { response in
                            responseCallBack(response.response, response.result.value, nil)
                        }
                    case .Failure(_):
                        responseCallBack(nil, nil, nil)
                    }
                }
        )
    }
}
