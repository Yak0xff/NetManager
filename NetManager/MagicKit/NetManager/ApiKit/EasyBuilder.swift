import Foundation
import Alamofire
import UIKit

class EasyBuilder {

    let url: String

    var parameters: [String:AnyObject]?

    var exceedTime: Double = -1

    var superView: UIView?

    init(url: String) {
        self.url = url
    }

    func parameters(parameters: [String:AnyObject]?) -> EasyBuilder {
        self.parameters = parameters
        return self
    }

    func localDataTime(exceedTime: Int64) -> EasyBuilder {
        self.exceedTime = Double(exceedTime)
        return self
    }

    func progressSuperView(superView: UIView?) -> EasyBuilder {
        self.superView = superView
        return self
    }

    func asGet() -> EasyRequest {
        return EasyRequest(method: .GET, Builder: self)
    }

    func asDelete() -> EasyRequest {
        return EasyRequest(method: .DELETE, Builder: self)
    }

    func asPost() -> EasyRequest {
        return EasyRequest(method: .POST, Builder: self)
    }

    func asUpload() -> EasyUpload {
        return EasyUpload(Builder: self)
    }

    func asDownload() -> EasyDownload {
        return EasyDownload(Builder: self)
    }
}
