//
//  Common.swift
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

class Common : NSObject, WatchIPhoneConnectDelegate {
    
    static let sharedInstance = Common()
    let WatchConnectInstance = WatchIPhoneConnect.sharedConnectivityManager
    
    let userDefaults = UserDefaults.standard
    var isLoadedStatus:loadInitType = .kLoadeFirst
    
    var notificationToken: NotificationToken? = nil
    var realmTokens = [NotificationToken]()
    var currentItemTalbe = [String]()
    private let lockQueue = DispatchQueue(label: "Lap notification lock serial queue")
    private let lockQueue1 = DispatchQueue(label: "Receive RQS SyncDigest lock serial queue")
    private let lockQueue2 = DispatchQueue(label: "Receive TransFile lock serial queue")
    
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
        case .kLoadedPrevios:           /* After version update */
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
        
        #if os(iOS)
        if WatchConnectInstance.watchAppInstalled() == false {
            assertionFailure("NOT watchAppInstalled: \(WatchConnectInstance.watchAppInstalled())")
        }
        #endif
        
        let transDBPath = FileHelper.temporaryDirectoryWithFileName(fileName: WATCH_TRAN_REALM)
        if FileHelper.fileExists(path: transDBPath) == true {
            _ = FileHelper.removeFilePath(path: transDBPath)
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
                    
                case .update( _, let deletions, let insertions, let modifications):
//                    NSLog("Coomon deleted: \(deletions) : \(deletions.count), inserted: \(insertions) : \(insertions.count), updated: \(modifications) : \(modifications.count)")
                    let inWriteTransaction = realm.isInWriteTransaction
                    if inWriteTransaction == true {
                        NSLog("Realm isInWriteTransaction!")
    //                   return
                    }
                    if insertions.isEmpty == false {
                        if inWriteTransaction == false {
                            laps.realm!.beginWrite()
                        }
                        var updateItems = [String]()
                        insertions.forEach { index in
                            if index >= laps.count { return }
                            let lap = laps[index]
                            let hashNumber = lapItemHashNumber(lap:lap)
                            if lap.hashNumber != hashNumber {
                                lap.modifyDate = Date()
                                lap.hashNumber = hashNumber
                                updateItems.append(lap.identifier)
                            }
                        }
                        if inWriteTransaction == false {
                            do {
                                try laps.realm!.commitWrite(withoutNotifying: wself2.realmTokens)
                            }
                            catch let error as NSError {
                                NSLog("Error - \(error.localizedDescription)")
                                return
                            }
                        }
                        if updateItems.isEmpty == false {
                            wself2.pushUpdates(updateIds:updateItems)
                        }
                    }
                    if modifications.isEmpty == false {
                        if inWriteTransaction == false {
                            laps.realm!.beginWrite()
                        }
                        var updateItems = [String]()
                        modifications.forEach { index in
                            if index >= laps.count { return }
                            let lap = laps[index]
                            let hashNumber = lapItemHashNumber(lap:lap)
                            if lap.hashNumber != hashNumber {
                                lap.modifyDate = Date()
                                lap.hashNumber = hashNumber
                                updateItems.append(lap.identifier)
                            }
                        }
                        if inWriteTransaction == false {
                            do {
                                try laps.realm!.commitWrite(withoutNotifying: wself2.realmTokens)
                            }
                            catch let error as NSError {
                                NSLog("Error - \(error.localizedDescription)")
                                return
                            }
                        }
                        if updateItems.isEmpty == false {
                            wself2.pushUpdates(updateIds: updateItems)
                        }
                    }
                    let newIdArray = laps.map{ $0.identifier } as [String]
                    var deleteIDs = [String]()
                    wself2.currentItemTalbe.forEach { element in
                        if newIdArray.index(of: element) == nil {
                            deleteIDs.append(element)
                        }
                    }
                    if deleteIDs.isEmpty == false {
                        wself2.pushDeletes(deletedIds: deleteIDs)
                    }
                    wself2.currentItemTalbe = laps.map{ $0.identifier }
                    
                case .error(let error):
                    assertionFailure("RealmNotificationBlock: \(error)")
                }
            }
        }
        self.realmTokens.append(self.notificationToken!)
//        #if os(iOS)
//            NotificationCenter.default.addObserver(self, selector: #selector(Common.receiveNotification), name: NSNotification.Name(rawValue: WCSessionWatchStateDidChangeNotification), object: nil)
//        #else
//            NotificationCenter.default.addObserver(self, selector: #selector(Common.receiveNotification), name: NSNotification.Name(rawValue: WCSessionReachabilityDidChangeNotification), object: nil)
//        #endif
        requestUpdate()
    }
    
    deinit {
        if notificationToken != nil {
            notificationToken?.stop()
            if let index = realmTokens.index(of: self.notificationToken!) {
                realmTokens.remove(at: index)
            }
        }
    }
    
    /* Request SyncAll */
    func requestSyncAll() {
        WatchConnectInstance.transferUserInfo("requestSyncAll$$", addInfo:[])
    }
    
    func receiveRQSSyncAll() {
        watchTableSyncAll()
    }
    
    func watchTableSyncAll() {              // Send digest
        var digestList = [LapDigest]()
        let realm = try! Realm()
        let laps = realm.objects(Lap.self)
        if laps.isEmpty == false {
            laps.forEach { item in
                autoreleasepool {
                    let digest = LapDigest()
                    digest.identifier = item.identifier
                    digest.modifyDate = item.modifyDate
                    digest.digestString = lapItemDigest(lap: item)
                    digestList.append(digest)
                }
            }
        } else {
            let digest = LapDigest()
            digest.identifier = "IgnoreIdentifierString"
            digestList.append(digest)
        }
        let encodedDigest = NSKeyedArchiver.archivedData(withRootObject: digestList)
        WatchConnectInstance.transferUserInfo("sendSyncDigest$$", addInfo: [encodedDigest])
    }
    
    func receiveRQSSyncDigest(userInfo: [String : Any]) {
        self.lockQueue1.sync {  [weak self] _ in
            guard let wself = self else {
                return
            }
            guard let arry = userInfo["sendSyncDigest$$Data00"] as? Data else {
                return
            }
            guard let digestList:[LapDigest] = NSKeyedUnarchiver.unarchiveObject(with: arry) as? [LapDigest] else {
                return
            }
            if digestList.isEmpty == false {
                dispatch_async_main {
                    wself.receiveRQSSyncDigest2(digestList:digestList)
                }
            }
        }
    }
    
    func receiveRQSSyncDigest2(digestList:[LapDigest]) {
        let realm = try! Realm()
        let laps = realm.objects(Lap.self)
        var allRecievedItemIds = [String]()
        var updateItems = [String]()
        var requestItemIDs = [String]()
        digestList.forEach { recievedItem in
            allRecievedItemIds.append(recievedItem.identifier)
            if let item = laps.filter("identifier == '\(recievedItem.identifier)'").first {
                autoreleasepool {
                    /* Item found. */
                    if recievedItem.modifyDate > item.modifyDate {              /* normal item */
                        requestItemIDs.append(item.identifier)
                    } else if recievedItem.modifyDate < item.modifyDate {
                        updateItems.append(item.identifier)
                    } else {
                        if recievedItem.digestString != lapItemDigest(lap: item) {
                            NSLog("Copy item iOS -> Watch @Same id and modtime.　recieve \(recievedItem.digestString) lap \(lapItemDigest(lap: item))")
                            if iOS == true {
                                updateItems.append(item.identifier)
                            } else {
                                requestItemIDs.append(item.identifier)
                            }
                        }
                    }
                }
            } else {                                                            /* Item not found. */
                autoreleasepool {
                    if recievedItem.identifier != "IgnoreIdentifierString" {
                        requestItemIDs.append(recievedItem.identifier)
                    }
                }
            }
        }
        if requestItemIDs.isEmpty == false {
            requestSendItems(itemIDs:requestItemIDs)
        }
        if updateItems.isEmpty == false {
            pushUpdates(updateIds:updateItems)
        }
        if laps.isEmpty == false {
            var nonItems = [String]()
            laps.forEach { lap in
                autoreleasepool {
                    if allRecievedItemIds.index(of: lap.identifier) == nil {
                        nonItems.append(lap.identifier)
                    }
                }
            }
            if nonItems.isEmpty == false {
                pushUpdates(updateIds: nonItems)
            }
        }
    }
    
    /* Request Items */
    func requestSendItems(itemIDs:[String]) {
        WatchConnectInstance.transferUserInfo("requestSendItems$$", addInfo: [itemIDs])
    }
    
    func receiveRQSSendItems(userInfo: [String : Any]) {
        guard let command:String = userInfo["command"] as? String else {
            return
        }
        guard let requestItems:[String] = userInfo[command + "Array00"] as? [String] else {
            return
        }
        if requestItems.isEmpty == false {
            pushUpdates(updateIds:requestItems)
        }
    }
    
    /* Request delete all */
    func requestDeleteAll() {
        WatchConnectInstance.transferUserInfo("requestDeleteAll$$", addInfo: [])
    }
    
    func receiveRQSDeleteAll() {
        let realm = try! Realm()
        let items = realm.objects(Lap.self)
        if items.isEmpty == false {
            do {
                try realm.write {
                    items.realm!.deleteAll()
                }
            }
            catch let error as NSError {
                NSLog("Error - \(error.localizedDescription)")
                return
            }
        }
    }
    
    /* Transaction handling : push item. */
    func pushUpdates(updateIds:[String]) {
        let realm = try! Realm()
        let laps = realm.objects(Lap.self)
        let predicate = NSPredicate(format: "identifier IN %@", updateIds)
        let items:[Lap] = Array(laps.filter(predicate))
        
        let transRealm = self.transRealm()!
        do {
            try transRealm.write {
                items.forEach { item in
                    autoreleasepool {
                        let newItem = Lap()
                        newItem.identifier = item.identifier
                        lapItemCopy(from: item, to: newItem)
                        transRealm.add(newItem, update:true)
                    }
                }
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
            return
        }
        self.requestUpdate()
    }
    
    func pushDeletes(deletedIds:[String]) {
        let transRealm = self.transRealm()!
        do {
            try transRealm.write {
                deletedIds.forEach { deletedItem in
                    autoreleasepool {
                        let dummyItem = Lap()
                        dummyItem.createDate = DateHelper.onceUponATime()
                        dummyItem.modifyDate = Date()
                        dummyItem.identifier = deletedItem
                        transRealm.add(dummyItem, update:true)
                    }
                }
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
            return
        }
        self.requestUpdate()
    }
    
    /* Send transaction */
    let UPDATE_DELAY_TIME = 0.5
//    let ERROR_RETRY_TIME = 3.0
    var workItem:DispatchWorkItem? = nil
    
    func receiveNotification() {
        requestUpdate()
    }
    
    func requestUpdate() {
//        if workItem != nil {        // Cancel previous acts
//            workItem?.cancel()
//            NSLog("Cancel previous schedule.")
//        }
        
        workItem = DispatchWorkItem() { [weak self] in
            guard let wself = self else { return }
//            let start = Date()
//            NSLog("WorkItem Start.")
            if wself.checkWatchConnect() == false {
                NSLog("Check WatchConnect false!")
            //  return
            }
            let transRealm = wself.transRealm()!
            let transItems = transRealm.objects(Lap.self)
            if transItems.isEmpty == true {
                NSLog("No updated items. Sleep until changed. Zzzz...")
                return
            }
            if wself.WatchConnectInstance.transferFileHasContentPending() == true {
                NSLog("Previous TransferFile is not over. Short sleep. Zzzz...")
                // DispatchQueue.main.asyncAfter(deadline: .now() + wself.UPDATE_DELAY_TIME, execute: wself.workItem!)
                return
            }
            let deleteTransItemIDs = transItems.map { $0.identifier } as [String]
            let tmpRealmPath = FileHelper.temporaryDirectoryWithFileName(fileName: "TmpRealmFile")
            if FileHelper.fileExists(path: tmpRealmPath) == true {
                _ = FileHelper.removeFilePath(path: tmpRealmPath)
            }
            do {
                try transRealm.writeCopy(toFile: URL(fileURLWithPath: tmpRealmPath))
            }
            catch let error as NSError {
                NSLog("Error - \(error.localizedDescription)")
                return
            }
            wself.WatchConnectInstance.transferFile(URL(fileURLWithPath: tmpRealmPath), command: "sendTransFile$$")
            let predicate = NSPredicate(format: "identifier IN %@", deleteTransItemIDs)
            let deleteTransItems = transRealm.objects(Lap.self).filter(predicate)
            if deleteTransItems.isEmpty == false {
                do {
                    try transRealm.write {
                        transRealm.delete(deleteTransItems)
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                    return
                }
                transRealm.invalidate()
            }
//            NSLog("WorkItem Complete \(Date().timeIntervalSince(start))")
            wself.workItem = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + UPDATE_DELAY_TIME, execute: workItem!)
    }
    
    func receiveTransFile(file: WCSessionFile) {
        self.lockQueue2.sync {  [weak self] _ in
            guard let wself = self else { return }
            dispatch_async_main {   [weak wself] _ in
                guard let wself2 = wself else { return }
                let fileUrl:URL = file.fileURL
                if FileHelper.fileExists(path: fileUrl.path) == false {
                    NSLog("Received file not found. URL error \(fileUrl.path)")
//                    DispatchQueue.main.asyncAfter(deadline: .now() + wself2.ERROR_RETRY_TIME) {
//                        wself2.watchTableSyncAll()
//                    }
                    return
                }
                let config = Realm.Configuration( fileURL: file.fileURL, readOnly: true)
                var recieverdRelm:Realm? = nil
                do {
                    recieverdRelm = try Realm(configuration: config)
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                    return
                }
                let recievedItems = recieverdRelm?.objects(Lap.self)
                
                let realm = try! Realm()
                let laps = realm.objects(Lap.self)
                
                let inWriteTransaction = realm.isInWriteTransaction
                if inWriteTransaction == true {
                    assertionFailure("realm.isInWriteTransaction BB")
                }
                laps.realm!.beginWrite()
                recievedItems?.forEach { recievedItem in
                    if let item = laps.filter("identifier == '\(recievedItem.identifier)'").first {
                        /* Item found. */
                        autoreleasepool {
                            if recievedItem.createDate == DateHelper.onceUponATime() {
                                if recievedItem.modifyDate >= item.modifyDate {             /* deleted item */
                                    realm.delete(item)
                                } else if recievedItem.modifyDate < item.modifyDate {
                                    wself2.pushUpdates(updateIds:[item.identifier])
                                }
                            } else {
                                if recievedItem.modifyDate > item.modifyDate {              /* normal item */
                                    lapItemCopy(from: recievedItem, to: item)
                                } else if recievedItem.modifyDate < item.modifyDate {
                                    wself2.pushUpdates(updateIds:[item.identifier])
                                } else {
                                    if lapItemHashNumberComp(first: recievedItem, second: item) == false {
                                        /*
                                         * Should not come here??? It would be a bug.
                                         * ID and Modify date are the same and the contents are different.
                                         * In this case, take the iOS side item.
                                         */
                                        // assertionFailure("DEBUG!!! Same modtime but different!")
                                        NSLog("DEBUG!!! Same modtime but different. recieve:\(recievedItem), exist:\(item) iOS:\(iOS)")
                                        if iOS == true {
                                            wself2.pushUpdates(updateIds:[item.identifier])
                                        } else {
                                            lapItemCopy(from: recievedItem, to: item)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        /* Item not found. */
                        autoreleasepool {
                            if recievedItem.createDate == DateHelper.onceUponATime() ||
                                    recievedItem.identifier == "IgnoreIdentifierString" {
                                /* NOP */
                            } else {
                                let newItem = Lap()
                                newItem.identifier = recievedItem.identifier
                                lapItemCopy(from: recievedItem, to: newItem)
                                realm.add(newItem)
                            }
                        }
                    }
                }
                do {
                    try laps.realm!.commitWrite(withoutNotifying: [wself2.notificationToken!])
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                    return
                }
                wself2.currentItemTalbe = laps.map{ $0.identifier }
            }
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
            NSLog("checkWatchConnect :\(WatchConnectInstance.watchReachable())")
            return false
        }
    }
    #endif
}

