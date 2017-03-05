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
        
        let (firstdate, lastdate) = common2.viewDate(baseDate: Date(), month: WatchViewMonth)
        let predicate = NSPredicate(format: "(usertime >= %@) AND (usertime <= %@)", firstdate as CVarArg, lastdate as CVarArg)
        laps = realm.objects(Lap.self).filter(predicate).sorted(byKeyPath: "usertime", ascending:false)

        notificationToken = laps.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard let `self` = self else { return }

            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                self.displayTable.setNumberOfRows(self.laps.count, withRowType: "default")
                self.laps.enumerated().forEach { index, item in
                    self.setTableContents(index: index, lap: item)
                }
                break
            case .update(_, let deletions, let insertions, let modifications):
                self.applyChangeset(deleted:deletions, inserted:insertions, updated:modifications)
                break
            case .error(let error):
                fatalError("\(error)")
                break
            }
        }
        
        /*
         Initial Sync All
        */
//        if common2.isLoadedStatus != .kLoaded {
            inquireSendALL()
//        }
    }
    
    deinit {
        notificationToken?.stop()
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
            guard let `self` = self else { return }
            let realm2 = try! Realm()
            let (firstdate, lastdate) = self.common2.viewDate(baseDate: Date(), month: WatchViewMonth)
            let predicate = NSPredicate(format: "(usertime >= %@) AND (usertime <= %@)", firstdate as CVarArg, lastdate as CVarArg)
            let deleteItem = realm2.objects(Lap.self).filter(predicate).filter("select==true")
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
            guard let `self` = self else { return }
            let realm2 = try! Realm()
            let (firstdate, lastdate) = self.common2.viewDate(baseDate: Date(), month: WatchViewMonth)
            let predicate = NSPredicate(format: "(usertime >= %@) AND (usertime <= %@)", firstdate as CVarArg, lastdate as CVarArg)
            let laps2 = realm2.objects(Lap.self).filter(predicate).filter("select==true")
            if laps2.isEmpty == false {
                do {
                    try realm2.write {
                        laps2.forEach { lap in
                            lap.usertime = RandomGenerator.randomDate3(firstdate, lastDate: lastdate)!
                            lap.text = RandomGenerator.randomStringWithLength(16)
                        }
                    }
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

    /* addNotificationBloc version */
    func applyChangeset(deleted:[Int], inserted:[Int], updated:[Int]) {
        deleted.reversed().forEach { index in
            displayTable.removeRows(at: [index])
        }
        inserted.forEach { index in
            if laps.count <= index {
                return
            }
            displayTable.insertRows(at: [index], withRowType: "default")
            setTableContents(index:index, lap:self.laps[index])
        }
        updated.forEach { index in
            if laps.count <= index {
                return
            }
            setTableContents(index:index, lap:self.laps[index])
        }
    }
    
    func setTableContents(index:Int, lap:Lap) {
        guard let zcontroller = displayTable.rowController(at: index) else {
            NSLog("set TableContent error 01")
            return
        }
        let controller = zcontroller as! MasterTableRowController
        controller.titleLabel.setText(lap.text)
        controller.todayCountLabel.setText(index.description)
        controller.thisTimeLabel.setText(formatter.string(from: lap.usertime))
        controller.todayTimeLabel.setText(formatter.string(from: lap.modifyDate))
        if lap.select == true {
            controller.selectSeparator.setColor(UIColor.rgbColor(0x3498DB))     // UIColor.flatBlueColor())
        } else {
            controller.selectSeparator.setColor(UIColor.rgbColor(0xECF0F1))     // UIColor.flatWhiteColor())
        }
    }
    
    override func table(_ table: WKInterfaceTable,  didSelectRowAt rowIndex: Int) {
        if rowIndex >= laps.count {
            return
        }
        do {
            try realm.write {
                laps[rowIndex].select = !laps[rowIndex].select
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
        }
        self.setTableContents(index:rowIndex, lap: laps[rowIndex])
    }
    
    func requestSendALL() {
        common2.watchTableSendAll()
        common2.requestSendAll()
    }
    
    func inquireSendALL() {
        requestSendALL()
//        NSLog("send Wake up.")
//        common2.sendWakeUp( replyHandler: { replyDict in
//            NSLog("Reply: \(replyDict)")
//           if (replyDict["SendWakeUpReply"] as! String).hasPrefix("ACK:sendWakeUp$$") == true {
//                self.requestSendALL()
//            } else {
//                NSLog("Reply MSG: \(replyDict["SendWakeUpReply"])")
//                dispatch_async_main {
//                    let cancelAction = WKAlertAction(title:"cancel", style: .default){}
//                    let retryAction = WKAlertAction(title:"retry", style: .default) { _ in
//                        self.inquireSendALL()
//                    }
//                    let subTitle = "Not connect to paired iPhone.\nPlease try again."
//                    self.presentAlert(withTitle: "Alert", message: subTitle, preferredStyle: .alert, actions: [retryAction, cancelAction])
//                }
//            }
//        })
    }
}

