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

    var token: NotificationToken? = nil
    var notificationRunLoop: CFRunLoop? = nil
    var currentItemTalbe = [String]()
    var transDB:Realm? = nil
    
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
    
    func loadDefault() {
        
        transDB = transRealm()          // init transactionDB
        if isLoadedStatus != .kLoaded {
            do {
                try transDB?.write { transDB?.deleteAll() }
            }
            catch let error as NSError {
                NSLog("Error - \(error.localizedDescription)")
            }
        }
        
        let realm = try! Realm()
        let laps = realm.objects(Lap.self).sorted(byKeyPath: "createDate", ascending: false)
        
        self.notificationRunLoop = CFRunLoopGetCurrent()
        CFRunLoopPerformBlock(self.notificationRunLoop, CFRunLoopMode.defaultMode.rawValue) { [weak self] in
            guard let `self` = self else { return }
            self.token = laps.addNotificationBlock { [weak self] changes in
                guard let `self` = self else { return }
                dispatch_async_main {
                    self.applyChange(changes:changes)
                }
            }
            CFRunLoopRun()
        }
        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(Common2.receiveNotification), name: NSNotification.Name(rawValue: WCSessionWatchStateDidChangeNotification), object: nil)
        #else
            NotificationCenter.default.addObserver(self, selector: #selector(Common2.receiveNotification), name: NSNotification.Name(rawValue: WCSessionReachabilityDidChangeNotification), object: nil)
        #endif
        
        requestUpdate()
    }
    
    deinit {
        token?.stop()
        if let runloop = notificationRunLoop {
            CFRunLoopStop(runloop)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func applyChange(changes:RealmCollectionChange<Results<Lap>>) {
        
        let realm = try! Realm()
        let laps = realm.objects(Lap.self).sorted(byKeyPath: "createDate", ascending: false)
        
        switch changes {
        case .initial:
            currentItemTalbe = laps.map { $0.identifier }
            break
            
        case .update( _, let deletions, let insertions, let modifications):
//          NSLog("deleted: \(deletions) : \(deletions.count), inserted: \(insertions) : \(insertions.count), updated: \(modifications) : \(modifications.count)")
            if insertions.isEmpty == false {
                var updateArray = [Lap]()
              laps.realm!.beginWrite()
                insertions.forEach { index in
                    if index >= laps.count { return }
                    if laps[index].youWrote == true {
                        laps[index].youWrote = false
                    } else {
                        laps[index].modifyDate = Date()
                        updateArray.append(laps[index])
                    }
                }
              do {
                  try laps.realm!.commitWrite(withoutNotifying: [token!])
              }
              catch let error as NSError {
                  NSLog("Error - \(error.localizedDescription)")
              }
                if updateArray.isEmpty == false {
                    self.pushUpdates(items:updateArray)
                }
            }
            if modifications.isEmpty == false {
                var updateArray = [Lap]()
              laps.realm!.beginWrite()
                modifications.forEach { index in
                    if index >= laps.count { return }
                    if laps[index].youWrote == true {
                        laps[index].youWrote = false
                    } else {
                        laps[index].modifyDate = Date()
                        updateArray.append(laps[index])
                    }
                }
              do {
                  try laps.realm!.commitWrite(withoutNotifying: [token!])
              }
              catch let error as NSError {
                  NSLog("Error - \(error.localizedDescription)")
              }
                if updateArray.isEmpty == false {
                    self.pushUpdates(items:updateArray)
                }
            }

            let newIdArray = laps.map{ $0.identifier } as [String]
            currentItemTalbe.forEach { element in
                if newIdArray.index(of: element) == nil {
                    self.pushDeletes(deletedIds: [element])
                }
            }
            currentItemTalbe = laps.map{ $0.identifier }
            break
            
        case .error(let error):
            assertionFailure("RealmNotificationBlock: \(error)")
            break
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
        let laps = realm.objects(Lap.self).sorted(byKeyPath: "createDate", ascending: false)
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
                    lapItemCopy(from: item, to: newItem)
                    newItem.identifier = item.identifier
                    newItem.youWrote = false
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
        let deleteTransItems = transRealm.objects(Lap.self).filter(predicate).sorted(byKeyPath: "createDate", ascending: true)
        do {
            try transRealm.write {
                transRealm.delete(deleteTransItems)
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        transRealm.invalidate()
        let transItems = transRealm.objects(Lap.self)
        if transItems.isEmpty == true {
            NSLog("No updated items. Sleep until changed. Zzzz...")
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
    
    func receiveTransFile(file: WCSessionFile) {

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
        
        do {
            try realm.write {
                recievedItems.forEach { recievedItem in
                    if let item = realm.objects(Lap.self).filter("identifier == '\(recievedItem.identifier)'").first {
                        /* Item found. */
                        if recievedItem.createDate == DateHelper.onceUponATime() {
                            if recievedItem.modifyDate >= item.modifyDate {           /* deleted item */
                                realm.delete(item)
                            } else if recievedItem.modifyDate < item.modifyDate {
                                item.youWrote = true        // touch
                                item.youWrote = false       // touch
                            }
                        } else {
                            if recievedItem.modifyDate > item.modifyDate {             /* normal item */
                                lapItemCopy(from: recievedItem, to: item)
                                item.youWrote = true
                            } else if recievedItem.modifyDate < item.modifyDate {
                                item.youWrote = true         // touch
                                item.youWrote = false        // touch
                            } else {
                                if lapItemComp(first: recievedItem, second: item) == false {
                                    /*
                                    * Should not come??? It would be a bug.
                                    * ID and Modify date are the same and the contents are different.
                                    * In this case, take the iOS side item.
                                    */
                                    NSLog("DEBUG!!! Same modtime but different. recieve:\(recievedItem), exist:\(item) iOS:\(iOS)")
                                    lapItemCopy(from: recievedItem, to: item)
                                    item.youWrote = true
                                }
                            }
                        }
                    } else {    /* Item not found. */
                        if recievedItem.createDate == DateHelper.onceUponATime() {
//                            NSLog("Not find deleted item. NOP")         /* deleted item */
                        } else {
                            let newItem = Lap()
                            lapItemCopy(from: recievedItem, to: newItem)
                            newItem.identifier = recievedItem.identifier
                            newItem.youWrote = true
                            realm.add(newItem)
                        }
                    }
                }
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
    }
    
    /* Trans REALM DB */
    
    func transRealm() -> Realm? {
        let config = Realm.Configuration(inMemoryIdentifier: "TransInMemoryRealm")
        do {
            let realm = try Realm(configuration: config)
            return realm
        } catch let error as NSError {
            assertionFailure("Realm Trans open error \(error)")
            return nil
        }
    }
    
    /* calculate　Month range */
 
    func viewDate(baseDate:Date, month: Int) -> (Date, Date) {
        if month != 0 && month <= 120 {
            let (y, m, d) = DateHelper.yearMonthDayFromDate(DateHelper.firstDateFromDate(baseDate))
            let zmonth = m - month + 1
            let y2 = y - zmonth / 12
            let m2 = zmonth % 12
            let firstdate = DateHelper.firstDateFromYearMonthDay(y2, month: m2, day: 1)
            let lastdayofmonth =  DateHelper.dateCountFromYearMonth(y, month: m)
            let lastdate = DateHelper.lastDateFromYearMonthDay(y, month: m, day: lastdayofmonth)
            return (firstdate, lastdate)
        } else {
            assertionFailure("View date error. month:\(month)")
            return (DateHelper.onceUponATime(), DateHelper.farDistantFuture())
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

