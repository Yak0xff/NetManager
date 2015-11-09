 

import UIKit

class MessageTool: NSObject, MBProgressHUDDelegate {

    private var showMessage: MBProgressHUD = MBProgressHUD()
    
    
    //MARK: -- Private
    //单例
    class var shareInstance: MessageTool {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: MessageTool? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = MessageTool()
        }
        return Static.instance!
    }
    
    private func showDuration() {
        showMessage.hide(true, afterDelay: 1.46)
    }
    
    private func buildMessage(message: String, view: UIView, isError: Bool) {
        showMessage.removeFromSuperview()
        showMessage = MBProgressHUD(view: view)
        showMessage.labelFont = UIFont.systemFontOfSize(16)
        
        if !isError{
            showMessage.customView = UIImageView(image: UIImage(named: "success.png"))
        }else{
            showMessage.customView = UIImageView(image: UIImage(named: "error.png"))
        }
        showMessage.labelText = message
        showMessage.mode = MBProgressHUDMode.CustomView
        view.addSubview(showMessage)
        showMessage.show(true)
        
        self.performSelectorOnMainThread("showDuration", withObject: nil, waitUntilDone: false)
    }
    
    private func buildMessage(message: String, isError: Bool) {
        showMessage.removeFromSuperview()
        showMessage = MBProgressHUD(view: self.getTopLevelWindow())
        showMessage.labelFont = UIFont.systemFontOfSize(16)
        
        if !isError{
            showMessage.customView = UIImageView(image: UIImage(named: "success.png"))
        }else{
            showMessage.customView = UIImageView(image: UIImage(named: "error.png"))
        }
        showMessage.labelText = message
        showMessage.mode = MBProgressHUDMode.CustomView
        self.getTopLevelWindow().addSubview(showMessage)
        showMessage.show(true)
        
        self.performSelectorOnMainThread("showDuration", withObject: nil, waitUntilDone: false)
    }
    
    private func getTopLevelWindow() -> UIWindow {
        var window : UIWindow = UIWindow()
        for levelWindow in UIApplication.sharedApplication().windows {
            if levelWindow.windowLevel > window.windowLevel {
                window = levelWindow
            }
        }
        return window
    }
    
    private func buildProcessMessage(message: String) {
        showMessage.removeFromSuperview()
        showMessage = MBProgressHUD(view: self.getTopLevelWindow())
        self.getTopLevelWindow().addSubview(showMessage)
        showMessage.labelText = message
        showMessage.show(true)
    }
    
    private func buildProcessMessage(message: String, view: UIView) {
        showMessage.removeFromSuperview()
        showMessage = MBProgressHUD(view: view)
        view.addSubview(showMessage)
        showMessage.labelText = message
        showMessage.show(true)
    }
    
    //MARK: -- Public
    static func showMessage(message: String, isError: Bool) {
        MessageTool.shareInstance.buildMessage(message, isError: isError)
    }
    
    static func showMessage(message: String, view: UIView, isError: Bool) {
        MessageTool.shareInstance.buildMessage(message, view: view, isError: isError)
    }
    
    static func showProcessMessage(message: String) -> MBProgressHUD {
        let tool = MessageTool.shareInstance
        tool.buildProcessMessage(message)
        return tool.showMessage
    }
    
    static func showProcessMessage(message: String, view: UIView) -> MBProgressHUD {
        let tool = MessageTool.shareInstance
        tool.buildProcessMessage(message, view: view)
        return tool.showMessage
    }
    
}
