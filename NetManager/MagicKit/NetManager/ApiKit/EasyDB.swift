import Foundation


class EasyDB {

    let builder: EasyBuilder

    init(Builder builder: EasyBuilder) {
        self.builder = builder
    }
    
    private func keys() -> (dataKey:String, timeKey:String) {
        let key = "\(builder.url)-\(builder.parameters)".md5
        
        let dataKey = "data-\(key)"
        let timeKey = "time-\(key)"
        
        return (dataKey, timeKey)
    }
    
    
    private func read(callBack: (data:String?, time:String?) -> Void) {
        let key = keys()
        
        let data = YTKKeyValueStore.sharedYTK().getStringById(key.dataKey, fromTable: DBKVTableName)
        let time = YTKKeyValueStore.sharedYTK().getStringById(key.timeKey, fromTable: DBKVTableName)
        
        callBack(data: data, time: time)
    }
    
    
    func request(completion completionHandler: (loadNet:Bool, data:AnyObject?, error:NSError?) -> Void) {
        if builder.exceedTime < 0 {
            completionHandler(loadNet: true, data: nil, error: nil)
            return
        }
        
        read {
            (data, timeIn) -> Void in
            if data == nil {
                completionHandler(loadNet: true, data: nil, error: nil)
                return
            }
            var time: String? = timeIn
            if time == nil {
                time = "0"
            }
            let t = NSDate().timeIntervalSince1970 - (time as NSString!).doubleValue
            
            let loadNet = t * 1000.0 > self.builder.exceedTime
                
            completionHandler(loadNet: loadNet, data: data, error: nil)
        }
    }
    
    func save(data: String) {
        if builder.exceedTime < 0 {
            return
        }
        let key = keys()
        
        YTKKeyValueStore.sharedYTK().putString(data, withId: key.dataKey, intoTable: DBKVTableName)
        YTKKeyValueStore.sharedYTK().putString(String(stringInterpolationSegment: NSDate().timeIntervalSince1970), withId: key.timeKey, intoTable: DBKVTableName)
    } 
}
