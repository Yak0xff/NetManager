import Foundation  

class EasyUtil {

    static func dictionaryWithJson(jsonString: String) -> AnyObject? {
        let jsonData = jsonString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)

        let jsonDic: AnyObject?
        
        if let json = jsonData {
            do {
                jsonDic = try NSJSONSerialization.JSONObjectWithData(json, options: .MutableContainers)
            } catch _ as NSError {
                return jsonString
            }
            return jsonDic
        }
        
        debugPrint("String转JSON失败")
        return nil
    }

    static func dictionaryToJson(dic: [String:AnyObject]) -> String? {
        var err: NSError?

        let jsonData: NSData?
        do {
            jsonData = try NSJSONSerialization.dataWithJSONObject(dic, options: .PrettyPrinted)
        } catch let error as NSError {
            err = error
            jsonData = nil
        }

        if let e = err {
            debugPrint(e, terminator: "")
            return nil
        }

        let str: String? = NSString(data: jsonData!, encoding: NSUTF8StringEncoding) as? String

        if str == nil {
            debugPrint("JSON转String失败", terminator: "")
            return nil
        }

        return str
    }
}

extension String {
    var md5: String! {
        let str = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = CC_LONG(self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer < CUnsignedChar>.alloc(digestLen)

        CC_MD5(str!, strLen, result)

        let hash = NSMutableString()
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i])
        }

        result.destroy()

        return String(format: hash as String)
    }
}