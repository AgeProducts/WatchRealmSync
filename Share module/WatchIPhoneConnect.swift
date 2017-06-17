//
//  WatchIPhoneConnect.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2016/10/11.
//  Copyright © 2016 AgePro. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity
import RealmSwift

protocol WatchIPhoneConnectDelegate: class {
    func receiveTransFile(file: WCSessionFile)
    func receiveRQSSyncDigest(file: WCSessionFile)
    func receiveRQSSendItems(userInfo: [String : Any])
    func receiveRQSSyncAll()
    func receiveRQSDeleteAll()
}

class WatchIPhoneConnect:NSObject, WCSessionDelegate {
    
    var IsSupport = false
    var IsReachable = false
    var IsPaired = false
    var IsComplicationEnabled = false
    var IsWatchAppInstalled = false
    var sessionActivationState:WCSessionActivationState = .notActivated
    
    static let sharedConnectivityManager = WatchIPhoneConnect()
    weak var delegate: WatchIPhoneConnectDelegate?
    
    private override init() {
        super.init()
        WatchIPhoneConnectInit()
    }
    
    func WatchIPhoneConnectInit() {
        if watchSupport()==true {
            let session = WCSession.default()
            session.delegate = self
            session.activate()
        } else {
            fatalError("Watch connection : not Supported! error.")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        _ = watchReachable()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: WCSessionReachabilityDidChangeNotification), object: nil)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        _ = watchSessionActivationState()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        _ = watchSessionActivationState()
        WCSession.default().activate()
    }
    
    func sessionWatchStateDidChange(_ session : WCSession) {
        _ = watchAppInstalled()
        _ = watchIsPaired()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: WCSessionWatchStateDidChangeNotification), object: nil)
    }
    #endif
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            NSLog("session activation failed with error: \(error.localizedDescription)")
            return
        }
        _ = watchSessionActivationState()
        var status = ""
        switch sessionActivationState {
        case .activated:
            status = "Activated"
        case .inactive:
            status = "Inactive"
        case .notActivated:
            status = "NotActivated"
        }
        NSLog("session activation: \(status)")
        #if os(iOS)
        _ = watchIsPaired()
        #endif
    }
    
    // Connection Status
    func watchSupport() -> Bool {
        IsSupport = WCSession.isSupported()
        return IsSupport
    }
    
    func watchReachable() -> Bool{
        IsReachable = WCSession.default().isReachable
        return IsReachable
    }
    
    #if os(iOS)
    func watchIsPaired() -> Bool {
        IsPaired = WCSession.default().isPaired
        return IsPaired
    }
    
    func watchIsComplicationEnabled() -> Bool {
        IsComplicationEnabled = WCSession.default().isComplicationEnabled
        return IsComplicationEnabled
    }
    
    func watchAppInstalled() -> Bool {
        IsWatchAppInstalled = WCSession.default().isWatchAppInstalled
        return IsWatchAppInstalled
    }
    #endif
    
    func watchSessionActivationState() -> WCSessionActivationState {
        sessionActivationState = WCSession.default().activationState
        return sessionActivationState
    }
    
    // Transfer User Info Data
    func transferUserInfo(_ command:String, addInfo:[Any]) {
        
        let infoDic:[String:Any] = makeMessageCommon(command:command, addInfo:addInfo)
        if infoDic.isEmpty == true {
            NSLog("infoDic error:\(String(describing: infoDic))")
            return
        }
        WCSession.default().transferUserInfo(infoDic)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        guard let command = userInfo["command"] as? String else { return }
        switch command {
        case "requestSyncAll$$":
            self.delegate?.receiveRQSSyncAll()
        case "requestSendItems$$":
            self.delegate?.receiveRQSSendItems(userInfo:userInfo)
        case "requestDeleteAll$$":
            self.delegate?.receiveRQSDeleteAll()
        default:
            assertionFailure("Receive userInfo command error: \(command)")
        }
    }
    
    // Transfer Files
    func transferFile(_ fileUrl:URL, command:String) {
        WCSession.default().transferFile(fileUrl, metadata: ["command":command])
    }
    
    func transferFileHasContentPending() -> Bool {
        return WCSession.default().hasContentPending
    }
    
    func transferFileArray() -> [WCSessionFileTransfer] {
        return WCSession.default().outstandingFileTransfers
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let command = file.metadata?["command"] as? String else { return }
        switch command {
        case "sendTransFile$$":
            self.delegate?.receiveTransFile(file: file)
        case "sendDigestFile$$":
            self.delegate?.receiveRQSSyncDigest(file: file)
        default:
            assertionFailure("Receive transferFile command error: \(command)")
        }
    }
    
    // make args
    private func makeMessageCommon(command:String, addInfo:[Any]) -> Dictionary<String,Any>  {
        if command.hasSuffix("$$")==false {
            assertionFailure("command format error: \(command)")
            return [:]
        }
        var infoDic = ["command":command as Any]            // Xcommand$$ = [command]
        infoDic[command] = Date() as Any?                   // timestamp = [Xcommand$$]
        addInfo.enumerated().forEach { index, addObj in
            autoreleasepool {
                let className = String(describing: type(of: addObj as Any)).lowercased()
                switch className {
                case _ where className.hasPrefix("array"):
                    infoDic[command + String(format:"Array%02d",index)] = addObj
                default:
                    assertionFailure("addInfo Unsupport class: \(String(describing: type(of: addObj as Any)))")
                }
            }
        }
        return infoDic
    }
}

