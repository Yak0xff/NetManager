 

import Foundation

 
 class User: NSObject,Evo {
    /*
    @property (nonatomic, strong) NSString *userId;
    @property (nonatomic, strong) NSString *userName;
    @property (nonatomic, strong) NSString *sign;
    @property (nonatomic, strong) NSArray *fits;*/
    
    var  userId = ""
    var userName = ""
    var sign = ""
    var fits = [String]()
     
//    static func modelPropertyMapper() -> NSDictionary {
//        return [
//            "userId" : "id",
//            "userName" : "name"
//        ]
//    }
 }