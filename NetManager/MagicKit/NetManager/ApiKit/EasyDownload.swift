import Foundation
import Alamofire

class EasyDownload {
    let builder: EasyBuilder

    init(Builder builder: EasyBuilder) {
        self.builder = builder
    }


    func download(filePath: String, responseCallBack: (NSURL?, NSHTTPURLResponse?) -> Void){
        download(filePath, progress:nil, responseCallBack:responseCallBack)
    }

    func download(filePath: String, progress: ((Int64, Int64, Int64) -> Void)?, responseCallBack: (NSURL?, NSHTTPURLResponse?) -> Void) {
       
        debugPrint("Download start: url- \(self.builder.url) filePathName- \(filePath)", terminator: "")
        
        var fileURL: NSURL? = nil
 
        let download = Alamofire.download(.GET, self.builder.url) { (temporaryURL, response) -> NSURL in
            let fileManager = NSFileManager.defaultManager()
            let documentDir = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] 
            
            fileURL = documentDir.URLByAppendingPathComponent("\(filePath)/\(response.suggestedFilename!)")
            
            return fileURL!
        }
        
        download.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
            if let p = progress {
                p(bytesRead, totalBytesRead, totalBytesExpectedToRead)
            }
            debugPrint("Download progress: bytesRead- \(bytesRead) totalRead- \(totalBytesRead) total- \(totalBytesExpectedToRead)", terminator: "")
        }
        download.response { request, response, data, error in
   
            var statusCode = -1
            
            if let res = response {
                statusCode = res.statusCode
            }
            
            if fileURL != nil && statusCode == 200 {
                debugPrint("Download response: fileURL- \(fileURL)", terminator: "")
                responseCallBack(fileURL!, response)
            } else {
                debugPrint("Download response: error- \(error)", terminator: "")
                responseCallBack(nil, response)
            }
        }
    }
}