//
//  InterfaceController.swift
//  WatchRealmSyncWatchApp Extension
//
//  Created by Takuji Hori on 2017/02/13.
//  Copyright © 2017 AgePro. All rights reserved.
//

import WatchKit
import Foundation
import RealmSwift

class InterfaceController: WKInterfaceController {
    
    let common2 = Common2.sharedInstance
    let realm = try! Realm()
    var laps: Results<Lap>!
    var notificationToken: NotificationToken? = nil
    
    @IBOutlet var deleteButton: WKInterfaceButton!
    @IBOutlet var addButton: WKInterfaceButton!
    @IBOutlet var modifyButton: WKInterfaceButton!
    @IBOutlet var displayTable: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        laps = realm.objects(Lap.self).sorted(byKeyPath: "usertime", ascending:false)
        
        notificationToken = laps.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard let wself = self else { return }
            
            switch changes {
            case .initial:
                wself.displayTable.setNumberOfRows(wself.laps.count, withRowType: "default")
                wself.laps.enumerated().forEach { index, item in
                    wself.setTableContents(lap: item)
                }
                break
                
            case .update(_, let deletions, let insertions, let modifications):
                // NSLog("deleted: \(deletions) : \(deletions.count), inserted: \(insertions) : \(insertions.count), modification: \(modifications) : \(modifications.count)")
                
                if deletions.isEmpty == true && insertions.isEmpty == true {
                    wself.applyChangeset(deleted:deletions, inserted:insertions, updated:modifications)
                } else {
                    wself.displayTable.setNumberOfRows(wself.laps.count, withRowType: "default")
                    wself.laps.enumerated().forEach { index, item in
                        wself.setTableContents(lap: item)
                    }
                }
                break
                
            case .error(let error):
                fatalError("\(error)")
                break
            }
            // }
        }
        common2.realmTokens.append(self.notificationToken!)
        inquireSendALL()
    }
    
    deinit {
        if notificationToken != nil {
            notificationToken?.stop()
            let index = common2.realmTokens.index(of: self.notificationToken!)
            if index != NSNotFound {
                common2.realmTokens.remove(at: index!)
            }
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // Menu Sync All
    @IBAction func syncAllButton() {
        inquireSendALL()
    }
    
    // Delete item
    @IBAction func deleteButtonAct() {
        DispatchQueue(label: "background").async { [weak self] _ in
            guard let wself = self else { return }
            let realm2 = try! Realm()
            let deleteItem = realm2.objects(Lap.self).filter("select==true")
            if deleteItem.isEmpty == false {
                do {
                    try realm2.write {
                        realm2.delete(deleteItem)
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Modify item
    @IBAction func modifyButtonAct() {
        DispatchQueue(label: "background").async { [weak self] _ in
            guard let wself = self else { return }
            let realm2 = try! Realm()
            let firstdate = Date()
            let lastdate = DateHelper.getDateBeforeOrAfterSomeMonth(baseDate:firstdate, month: Double(-WatchViewMonth))
            let laps2 = realm2.objects(Lap.self).filter("select==true")
            if laps2.isEmpty == false {
                laps2.realm!.beginWrite()
                laps2.forEach { lap in
                    lap.usertime = RandomMaker.randomDate3(firstdate, lastDate: lastdate)!
                    lap.text = RandomMaker.randomStringWithLength(16)
                }
                do {
                    try laps2.realm!.commitWrite()
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add new item
    @IBAction func addButtonAct() {
        
        let lap = Lap()
        lap.text = "New Text"
        do {
            try realm.write {
                realm.add(lap)
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
    }
    
    //
    func applyChangeset(deleted:[Int], inserted:[Int], updated:[Int]) {
        deleted.reversed().forEach { index in
            displayTable.removeRows(at: [index])
        }
        inserted.forEach { index in
            if laps.count <= index {
                return
            }
            displayTable.insertRows(at: [index], withRowType: "default")
            setTableContents(lap:self.laps[index])
        }
        updated.forEach { index in
            if laps.count <= index {
                return
            }
            setTableContents(lap:self.laps[index])
        }
    }
    
    func setTableContents(lap:Lap) {
        
        var index = NSNotFound
        laps.enumerated().forEach { idx, element in
            if lap.identifier == element.identifier {
                index = idx
            }
        }
        if index == NSNotFound {
            NSLog("InterfaceController: setTableContent error 01")
            return
        }
        guard let zcontroller = displayTable.rowController(at: index) else {
            NSLog("InterfaceController: setTableContent error 02")
            return
        }
        let controller = zcontroller as! MasterTableRowController
        controller.titleLabel.setText(lap.text)
        if DateHelper.firstDateFromDate(Date()) == DateHelper.firstDateFromDate(lap.usertime) {
            controller.thisTimeLabel.setText(timeformatter.string(from: lap.usertime))
        } else {
            controller.thisTimeLabel.setText(dateformatter.string(from: lap.usertime))
        }
//        if DateHelper.firstDateFromDate(Date()) == DateHelper.firstDateFromDate(lap.modifyDate) {
//            controller.thisTimeLabel.setText(timeformatter.string(from: lap.modifyDate))
//        } else {
//            controller.thisTimeLabel.setText(dateformatter.string(from: lap.modifyDate))
//        }
        if lap.select == true {
            controller.selectSeparator.setColor(UIColor.rgbColor(0x3498DB))     // UIColor.flatBlueColor())
        } else {
            controller.selectSeparator.setColor(UIColor.rgbColor(0xECF0F1))     // UIColor.flatWhiteColor())
        }
    }
    
    override func table(_ table: WKInterfaceTable,  didSelectRowAt rowIndex: Int) {
        
        laps.realm!.beginWrite()
        laps[rowIndex].select = !laps[rowIndex].select
        do {
            try laps.realm!.commitWrite()
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
    }
    
    func requestSendALL() {
        common2.watchTableSendAll()
        common2.requestSendAll()
    }
    
    func inquireSendALL() {
        requestSendALL()
//        NSLog("InterfaceController: send Wake up.")
//        common2.sendWakeUp( replyHandler: { replyDict in
//            NSLog("Reply: \(replyDict)")
//            let replyMsg = replyDict["SendWakeUpReply"] as! String
//            if replyMsg.hasPrefix("ACK:sendWakeUp$$") == true {
//                self.requestSendALL()
//            } else {
//                NSLog("Reply MSG: \(replyMsg)")
//                dispatch_async_main {
//                    let cancelAction = WKAlertAction(title:"cancel", style: .default){}
//                    let retryAction = WKAlertAction(title:"retry", style: .default) { _ in
//                        self.inquireSendALL()
//                    }
//                    let subTitle = "Not connect to paired iPhone.\nPlease try again.\n[Reply MSG]\n" + replyMsg
//                    self.presentAlert(withTitle: "Alert", message: subTitle, preferredStyle: .alert, actions: [retryAction, cancelAction])
//                }
//            }
//        })
    }
}

