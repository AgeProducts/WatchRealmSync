//
//  Common2.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2016/10/11.
//  Copyright © 2016 AgePro. All rights reserved.
//

import UIKit
import RealmSwift
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

class Common2 : NSObject, WatchIPhoneConnectDelegate {
    
    let userDefaults = UserDefaults.standard
    var isLoadedStatus:loadInitType = .kLoadeFirst
    
    let WatchConnectInstance = WatchIPhoneConnect.sharedConnectivityManager
    
    var notificationToken: NotificationToken? = nil
    var realmTokens = [NotificationToken]()
    var currentItemTalbe = [String]()
    
    static let sharedInstance = Common2()
    
    private override init() {
        super.init()
        initSettings()
    }
    
    func initSettings() {
        
        WatchConnectInstance.delegate = self
        
        isLoadedStatus = isLoadedOnceUserDefaults()
        
        switch isLoadedStatus {
        case .kLoadeFirst:              /* For the first time after installation */
            #if os(iOS)
                // loadPlist()
            #endif
            break;
        case .kLoadedPrevios:           /* After update */
            break;
        default: //.kLoaded:            /* Normal Boot */
            break;
        }
        loadDefault()
        setLoadedOnceUserDefaults()
    }
    
    func isLoadedOnceUserDefaults() ->loadInitType {
        if userDefaults.bool(forKey: UD_LOADED_ONCE)==true {
            return .kLoaded
        }
        if userDefaults.bool(forKey: UD_LOADED_ONCE_PREVIOS)==true {
            return .kLoadedPrevios
        }
        return .kLoadeFirst
    }
    
    func setLoadedOnceUserDefaults() {
        if userDefaults.bool(forKey: UD_LOADED_ONCE_PREVIOS) == true {
            userDefaults.removeObject(forKey: UD_LOADED_ONCE_PREVIOS)
        }
        userDefaults.set(true, forKey:UD_LOADED_ONCE)
        userDefaults.synchronize()
    }
    
    private let lockQueue = DispatchQueue(label: "Lap notification lock serial queue")
    
    func loadDefault() {
        
        let transDB = transRealm()
        do {
            try transDB?.write { transDB?.deleteAll() }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        
        let realm = try! Realm()
        let laps = realm.objects(Lap.self)
        
        notificationToken = laps.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            
            guard let wself = self else { return }
            wself.lockQueue.sync { [weak wself] in
                guard let wself2 = wself else { return }
                
                let realm = try! Realm()
                let laps = realm.objects(Lap.self)
                
                switch changes {
                case .initial:
                    wself2.currentItemTalbe = laps.map { $0.identifier }
                    break
                    
                case .update( _, let deletions, let insertions, let modifications):
                    // NSLog("deleted: \(deletions) : \(deletions.count), inserted: \(insertions) : \(insertions.count), updated: \(modifications) : \(modifications.count)")
                    
                    let inWriteTransaction = realm.isInWriteTransaction                    
                    if insertions.isEmpty == false {
                        var updateArray = [Lap]()
                        if inWriteTransaction == false {
                            laps.realm!.beginWrite()
                        }
                        insertions.forEach { index in
                            if index >= laps.count { return }
                            let lap = laps[index]
                            if lap.youWrote == true {
                                lap.youWrote = false
                            } else {
                                lap.modifyDate = Date()
                                updateArray.append(lap)
                            }
                        }
                        if inWriteTransaction == false {
                            do {
                                if wself2.realmTokens.isEmpty == true {
                                    try laps.realm!.commitWrite()
                                } else {
                                    try laps.realm!.commitWrite(withoutNotifying: wself2.realmTokens)
                                }
                            }
                            catch let error as NSError {
                                NSLog("Error - \(error.localizedDescription)")
                            }
                        }
                        if updateArray.isEmpty == false {
                            wself2.pushUpdates(items:updateArray)
                        }
                    }
                    if modifications.isEmpty == false {
                        var updateArray = [Lap]()
                        if inWriteTransaction == false {
                            laps.realm!.beginWrite()
                        }
                        modifications.forEach { index in
                            if index >= laps.count { return }
                            let lap = laps[index]
                            if lap.youWrote == true {
                                lap.youWrote = false
                            } else {
                                lap.modifyDate = Date()
                                updateArray.append(lap)
                            }
                        }
                        if inWriteTransaction == false {
                            do {
                                if wself2.realmTokens.isEmpty == true {
                                    try laps.realm!.commitWrite()
                                } else {
                                    try laps.realm!.commitWrite(withoutNotifying: wself2.realmTokens)
                                }
                            }
                            catch let error as NSError {
                                NSLog("Error - \(error.localizedDescription)")
                            }
                        }
                        if updateArray.isEmpty == false {
                            wself2.pushUpdates(items:updateArray)
                        }
                    }
                    let newIdArray = laps.map{ $0.identifier } as [String]
                    wself2.currentItemTalbe.forEach { element in
                        if newIdArray.index(of: element) == nil {
                            wself2.pushDeletes(deletedIds: [element])
                        }
                    }
                    wself2.currentItemTalbe = laps.map{ $0.identifier }
                    break
                    
                case .error(let error):
                    assertionFailure("RealmNotificationBlock: \(error)")
                    break
                }
            }
        }
        self.realmTokens.append(self.notificationToken!)
        
//        #if os(iOS)
//            NotificationCenter.default.addObserver(self, selector: #selector(Common2.receiveNotification), name: NSNotification.Name(rawValue: WCSessionWatchStateDidChangeNotification), object: nil)
//        #else
//            NotificationCenter.default.addObserver(self, selector: #selector(Common2.receiveNotification), name: NSNotification.Name(rawValue: WCSessionReachabilityDidChangeNotification), object: nil)
//        #endif
        
        requestUpdate()
    }
    
    deinit {
        if notificationToken != nil {
            notificationToken?.stop()
            let index = realmTokens.index(of: self.notificationToken!)
            if index != NSNotFound {
                realmTokens.remove(at: index!)
            }
        }
    }
    
    
    /* Request Wake Up. Hello world! */
    
    func sendWakeUp(replyHandler: (([String : Any]) -> Swift.Void)? = nil) {
        WatchConnectInstance.sendMessage("sendWakeUp$$", replyHandler: { replyDict in
            replyHandler?(["SendWakeUpReply":replyDict["SendMessageReply"] as! String])
        })
    }
    
    func receiveWakeup() -> String {
        return "I just woke up now."
    }
    
    /* Request SendAll */
    
    func requestSendAll() {
        WatchConnectInstance.transferUserInfo("requestSendAll$$")
    }
    
    func receiveRQSSendAll() {
        watchTableSendAll()
    }
    
    func watchTableSendAll() {
        let realm = try! Realm()
        let laps = realm.objects(Lap.self) //.sorted(byKeyPath: "createDate", ascending: false)
        if laps.isEmpty == false {
            do {
                try realm.write {
                    laps.forEach { item in
                        let status = item.youWrote        // touch
                        item.youWrote = status
                    }
                }
            }
            catch let error as NSError {
                NSLog("Error - \(error.localizedDescription)")
            }
        }
    }
    
    /* Transaction handling : push item. */
    
    func pushUpdates(items:[Lap]) {
        let transRealm = self.transRealm()!
        do {
            try transRealm.write {
                items.forEach { item in
                    let newItem = Lap()
                    newItem.youWrote = false
                    lapItemCopy(from: item, to: newItem)
                    newItem.identifier = item.identifier
                    transRealm.add(newItem, update:true)
                }
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        requestUpdate()
    }
    
    func pushDeletes(deletedIds:[String]) {
        let transRealm = self.transRealm()!
        do {
            try transRealm.write {
                deletedIds.forEach { deletedItem in
                    let dummyItem = Lap()
                    dummyItem.identifier = deletedItem
                    dummyItem.createDate = DateHelper.onceUponATime()
                    dummyItem.modifyDate = Date()
                    transRealm.add(dummyItem, update:true)
                }
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        requestUpdate()
    }
    
    /* Send transaction */
    let delaySec = UpdateDelayTimer
    let pollingSec = PollingDelayTimer
    var updateTime = DateHelper.onceUponATime()
    let marginSec = 0.0
    var timer: Timer!
    
    func receiveNotification() {
        if timer != nil && timer.isValid == true {
            updateDemon()
        }
    }
    
    func requestUpdate() {
        if timer != nil && timer.isValid == true {
            timer.invalidate()
        }
        timer = Timer.scheduledTimer(timeInterval: delaySec, target: self, selector: #selector(Common2.updateDemon), userInfo: nil, repeats: false)
    }
    
    func updateDemon() {
        timer.invalidate()
        
        if checkWatchConnect() == false {
            NSLog("Check WatchConnect false. Sleep \(pollingSec) sec.")
            timer = Timer.scheduledTimer(timeInterval: pollingSec, target: self, selector: #selector(Common2.updateDemon), userInfo: nil, repeats: false)
            return
        }
        
        let transRealm = self.transRealm()!
        let predicate = NSPredicate(format:"modifyDate < %@", updateTime as CVarArg)
        let deleteTransItems = transRealm.objects(Lap.self).filter(predicate) //.sorted(byKeyPath: "createDate", ascending: true)
        if deleteTransItems.isEmpty == false {
            do {
                try transRealm.write {
                    transRealm.delete(deleteTransItems)
                }
            }
            catch let error as NSError {
                NSLog("Error - \(error.localizedDescription)")
            }
        }
        transRealm.invalidate()
        let transItems = transRealm.objects(Lap.self)
        if transItems.isEmpty == true {
            NSLog("No updated items. Sleep until changed. Zzzz...")
            return
        }
        
        if WatchConnectInstance.transferFileHasContentPending() == true {
            NSLog("Previous TransferFile is not over. Sleep a little. Zzzz...")
            requestUpdate()
            return
        }
        
        let  tmpRealmPath = FileHelper.temporaryDirectoryWithFileName(fileName: "TmpRealmFile")
        if FileHelper.fileExists(path: tmpRealmPath) == true {
            _ = FileHelper.removeFilePath(path: tmpRealmPath)
        }
        do {
            try transRealm.writeCopy(toFile: URL(fileURLWithPath: tmpRealmPath))
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        
        WatchConnectInstance.transferFile(URL(fileURLWithPath: tmpRealmPath), command: "sendTransFile$$")
        
        updateTime = Date(timeIntervalSinceNow: -marginSec)
        requestUpdate()
    }
    
    private let lockQueue2 = DispatchQueue(label: "ReceiveTransFile lock serial queue")
    
    func receiveTransFile(file: WCSessionFile) {
        self.lockQueue2.sync {
            receiveTransFile2(file: file)
        }
    }
    
    func receiveTransFile2(file: WCSessionFile) {
        
        guard let zURL:URL = file.fileURL else {
            return
        }
        if FileHelper.fileExists(path: zURL.path) == false {
            NSLog("Received file not found. URL error \(zURL.path)")
            return
        }
        
        let config = Realm.Configuration( fileURL: file.fileURL, readOnly: true)
        let recieverdRelm:Realm = try! Realm(configuration: config)
        let recievedItems = recieverdRelm.objects(Lap.self)
        
        let realm = try! Realm()
        let laps = realm.objects(Lap.self) //.sorted(byKeyPath: "createDate", ascending: false)
        
        let inWriteTransaction = realm.isInWriteTransaction
        if inWriteTransaction == true {
            assertionFailure("realm.isInWriteTransaction BB")
            //                   return
        }
        
        laps.realm!.beginWrite()
        
        recievedItems.forEach { recievedItem in
            if let item = laps.filter("identifier == '\(recievedItem.identifier)'").first {
                /* Item found. */
                if recievedItem.createDate == DateHelper.onceUponATime() {
                    if recievedItem.modifyDate >= item.modifyDate {           /* deleted item */
                        realm.delete(item)
                    } else if recievedItem.modifyDate < item.modifyDate {
                        item.youWrote = true        // touch
                        item.youWrote = false
                    }
                } else {
                    if recievedItem.modifyDate > item.modifyDate {             /* normal item */
                        item.youWrote = true
                        lapItemCopy(from: recievedItem, to: item)
                    } else if recievedItem.modifyDate < item.modifyDate {
                        item.youWrote = true         // touch
                        item.youWrote = false
                    } else {
                        if lapItemComp(first: recievedItem, second: item) == false {
                            /*
                             * Should not come??? It would be a bug.
                             * ID and Modify date are the same and the contents are different.
                             * In this case, take the iOS side item.
                             */
                            // NSLog("DEBUG!!! Same modtime but different. recieve:\(recievedItem), exist:\(item) iOS:\(iOS)")
                            if iOS == true {
                                item.youWrote = true         // touch
                                item.youWrote = false
                            } else {
                                item.youWrote = true
                                lapItemCopy(from: recievedItem, to: item)
                            }
                        }
                    }
                }
            } else {    /* Item not found. */
                if recievedItem.createDate == DateHelper.onceUponATime() {
                    /* NOP */
                } else {
                    let newItem = Lap()
                    newItem.youWrote = true
                    newItem.identifier = recievedItem.identifier
                    lapItemCopy(from: recievedItem, to: newItem)
                    realm.add(newItem)
                }
            }
        }
        do {
            try laps.realm!.commitWrite()
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
    }
    
    /* Trans REALM DB */
    
    func transRealm() -> Realm? {
        let url = NSURL(fileURLWithPath: FileHelper.temporaryDirectoryWithFileName(fileName: WATCH_TRAN_REALM)) as URL
        do {
            let realm = try Realm(fileURL: url)
            return realm
        } catch let error as NSError {
            assertionFailure("Realm Trans open error \(error)")
            return nil
        }
    }
    
    /* Check WatchConnectivity */
    
    #if os(iOS)
    func checkWatchConnect() -> Bool {
        if WatchConnectInstance.watchSessionActivationState() == .activated &&
            WatchConnectInstance.watchAppInstalled() == true {
            return true
        } else {
            NSLog("checkWatchConnect, watchSessionActivationState:\(WatchConnectInstance.watchSessionActivationState())\n watchAppInstalled:\(WatchConnectInstance.watchAppInstalled())")
            return false
        }
    }
    #else
    func checkWatchConnect() -> Bool {
        if WatchConnectInstance.watchReachable() == true {
            return true
        } else {
            NSLog("checkWatchConnect, watchReachable():\(WatchConnectInstance.watchReachable())")
            return false
        }
    }
    #endif
}

