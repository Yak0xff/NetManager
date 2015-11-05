import Foundation
import Alamofire

class EasyLoad {

    static func loadUrl(url: String) ->EasyBuilder! {
        return EasyBuilder(url: url)
    }
}
