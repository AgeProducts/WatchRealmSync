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
    func receiveRQSSendAll()
    func receiveWakeup() -> String
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
        #if BACKGROUND
            if watchSupport()==true {
                NSLog("Watch connection Supported.")
            } else {
                fatalError("Watch connection: not Supported! error.")
            }
        #else
            if watchSupport()==true {
                let session = WCSession.default()
                session.delegate = self
                session.activate()
            } else {
                fatalError("Watch connection : not Supported! error.")
            }
        #endif
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
//        var status = ""
//        if sessionActivationState == .activated {
//            status = "Activated"
//        } else if sessionActivationState == .inactive {
//            status = "Inactive"
//        } else if sessionActivationState == .notActivated {
//            status = "NotActivated"
//        } else {
//            status = "UnKnown"
//        }
//        NSLog("session activation: \(status)")
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

    // SendMessage

    let sendMessageTimeout = 10.0
    func sendMessage(_ command:String, replyHandler: (([String : Any]) -> Swift.Void)? = nil) {

        let timeOutWorkItem = DispatchWorkItem() {
            (replyHandler?(["SendMessageReply":"No Response."]))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + sendMessageTimeout, execute: timeOutWorkItem)
        WCSession.default().sendMessage(["command":command], replyHandler: {
            replyDict in
            timeOutWorkItem.cancel()
            (replyHandler?(["SendMessageReply":replyDict["reply"] as! String]))
        }, errorHandler: {
            error in
            timeOutWorkItem.cancel()
            (replyHandler?(["SendMessageReply":"error:\(error)"]))
        })
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = message["command"] as? String else {
            replyHandler(["reply":"NACK:Error"])
            return
        }
        if command == "sendWakeUp$$" {
            let retMsg = self.delegate?.receiveWakeup()
            replyHandler(["reply":String(format:"ACK:%@ %@",command, retMsg!)])
        } else {
            replyHandler(["reply":String(format:"NACK:%@",command)])
        }
    }

    // Transfer User Info Data
 
    func transferUserInfo(_ command:String) {
        WCSession.default().transferUserInfo(["command":command])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        guard let command = userInfo["command"] as? String else { return }
        if command == "requestSendAll$$" {
            self.delegate?.receiveRQSSendAll()
        }
    }

    // Transfer Files
    
    func transferFile(_ fileUrl:URL, command:String) {
        WCSession.default().transferFile(fileUrl, metadata: ["command":command])
    }
    
    func transferFileCount() -> Int {
        return WCSession.default().outstandingFileTransfers.count
    }
    
    func transferFileHasContentPending() -> Bool {
        return WCSession.default().hasContentPending
    }
    
    func transferFileArray() -> [WCSessionFileTransfer] {
        return WCSession.default().outstandingFileTransfers
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let command = file.metadata?["command"] as? String else { return }
        if command == "sendTransFile$$" {
            self.delegate?.receiveTransFile(file: file)
        }
    }
}

