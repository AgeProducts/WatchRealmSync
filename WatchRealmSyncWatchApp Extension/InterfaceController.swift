//
//  InterfaceController.swift
//  WatchRealmSyncWatchApp Extension
//
//  Created by Takuji Hori on 2017/02/13.
//  Copyright © 2017 AgePro. All rights reserved.

import WatchKit
import Foundation
import RealmSwift

class InterfaceController: WKInterfaceController {
    
    let common = Common.sharedInstance
    
    let realm = try! Realm()
    var laps: Results<Lap>!
    var notificationToken: NotificationToken? = nil
    
    let hapticSuccess = WKHapticType.success
    let hapticClick = WKHapticType.click
    
    @IBOutlet var displayTable: WKInterfaceTable!
    @IBOutlet var countLabel: WKInterfaceLabel!
    
    let REDRAW_INTERVAL = 0.2
    var workItem:DispatchWorkItem? = nil
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        let viewLastDate = Date()
        let viewFirstDate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:viewLastDate, day:Double(-WATCH_SHOW_DATE))
        let predicate = NSPredicate(format:"usertime >= %@", viewFirstDate as CVarArg)
        laps = realm.objects(Lap.self).filter(predicate).sorted(byKeyPath: "usertime", ascending:false)
        let predicate2 = NSPredicate(format:"usertime >= %@ && select == true", viewFirstDate as CVarArg)
        let lapsSelect = realm.objects(Lap.self).filter(predicate2).sorted(byKeyPath: "usertime", ascending:false)
        
        notificationToken = laps.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard let wself = self else { return }
//            wself.countLabel.setText(String(wself.laps.count))
            wself.countLabel.setText(String(format:"%d/%d",lapsSelect.count,wself.laps.count))
            
            switch changes {
            case .initial:
                wself.displayTable.setNumberOfRows(wself.laps.count, withRowType: "default")
                wself.laps.forEach {item in
                    wself.setTableContents(lap: item)
                }
                
            case .update(_, let deletions, let insertions, let modifications):
//                NSLog("Interface deleted: \(deletions) : \(deletions.count), inserted: \(insertions) : \(insertions.count), updated: \(modifications) : \(modifications.count)")
                
//                if wself.workItem != nil {
//                    wself.workItem?.cancel()
//                }
                wself.workItem = DispatchWorkItem() { [weak wself] in
                    guard let wself2 = wself else { return }
                    if deletions.isEmpty == true && insertions.isEmpty == true {
                        // wself2.applyChangeset(deleted:deletions, inserted:insertions, updated:modifications)
                        modifications.forEach { index in
                            if wself2.laps.count <= index {
                                assertionFailure("modifications error")
                            }
                            wself2.setTableContents(lap:wself2.laps[index])
                        }
                    } else {
                        wself2.displayTable.setNumberOfRows(wself2.laps.count, withRowType: "default")
                        wself2.laps.enumerated().forEach { index, item in
                            wself2.setTableContents(lap: item)
                        }
                    }
                    wself2.workItem = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + wself.REDRAW_INTERVAL, execute: wself.workItem!)

            case .error(let error):
                fatalError("\(error)")
            }
        }
        common.realmTokens.append(self.notificationToken!)
        
        inquireSendALL()
        WKInterfaceDevice.current().play(hapticSuccess)
    }
    
    deinit {
        if notificationToken != nil {
            notificationToken?.stop()
            if let index = common.realmTokens.index(of: notificationToken!) {
                common.realmTokens.remove(at: index)
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
    
    // Menu : Sync All
    @IBAction func syncAllButton() {
        WKInterfaceDevice.current().play(hapticSuccess)
        inquireSendALL()
    }
    
    // Menu : Make 10 items
    let  makeCount = 10
    @IBAction func make10Item() {
        WKInterfaceDevice.current().play(hapticSuccess)
        DispatchQueue(label: "background").async { [weak self] in
            guard let wself = self else { return }
            let simulationFirstDate = Date()
            let simulationLastDate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:simulationFirstDate, day:Double(-SIMULATE_TARGET_DATE))
            autoreleasepool {
                let realm2 = try! Realm()
                try! realm2.write {
                    for _ in 0 ..< wself.makeCount {
                        let lap = Lap()
                        lap.usertime = RandomMaker.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                        lap.textstring = "W> " + RandomMaker.randomNihonngoStringWithLength(16)
                        lap.select = RandomMaker.randomBool(percent:33.3)   // select 1/3
                        realm2.add(lap)
                    }
                }
            }
        }
    }
    
    // Menu : Delete All
    @IBAction func deleteAll() {
        WKInterfaceDevice.current().play(hapticSuccess)
        DispatchQueue(label: "background").async {
            autoreleasepool {
                let realm2 = try! Realm()
                try! realm2.write {
                    realm2.deleteAll()
                }
            }
        }
        common.requestDeleteAll()
    }
    
    // Add new item
    @IBAction func addButtonAct() {
        WKInterfaceDevice.current().play(hapticSuccess)
        let lap = Lap()
        lap.textstring = "W> 新てきすと"
        try! realm.write {
            realm.add(lap)
        }
    }
    
    // Delete selected items
    @IBAction func deleteButtonAct() {
        WKInterfaceDevice.current().play(hapticSuccess)
        DispatchQueue(label: "background").async {
            let realm2 = try! Realm()
            let deleteItem = realm2.objects(Lap.self).filter("select==true")
            if deleteItem.isEmpty == false {
                try! realm2.write {
                    realm2.delete(deleteItem)
                }
            }
        }
    }
    
    // Modify selected items
    @IBAction func modifyButtonAct() {
        WKInterfaceDevice.current().play(hapticSuccess)
        DispatchQueue(label: "background").async {
            let realm2 = try! Realm()
            let firstdate = Date()
            let lastdate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:firstdate, day:Double(-SIMULATE_TARGET_DATE))
            let laps2 = realm2.objects(Lap.self).filter("select==true")
            if laps2.isEmpty == false {
                try! laps2.realm!.write {
                    laps2.forEach { lap in
                        lap.usertime = RandomMaker.randomDate3(firstdate, lastDate: lastdate)!
                        lap.textstring = "W> " + RandomMaker.randomNihonngoStringWithLength(16)
                    }
                }
            }
        }
    }
    
    func setTableContents(lap:Lap) {
        autoreleasepool {
            var index = NSNotFound
            laps.enumerated().forEach { idx, element in
                if lap.identifier == element.identifier {
                    index = idx
                }
            }
            if index == NSNotFound {
                NSLog("InterfaceController: setTableContents error 01")
                return
            }
            guard let zcontroller = displayTable.rowController(at: index) else {
                NSLog("InterfaceController: setTableContents error 02")
                return
            }
            let controller = zcontroller as! MasterTableRowController
            controller.titleLabel.setText(lap.textstring)
            
            let (TY, TM, _) = DateHelper.yearMonthDayFromDate(Date())
            let (UY, UM, _) = DateHelper.yearMonthDayFromDate(lap.usertime)
            if TY != UY || TM != UM {
                controller.timeLabel.setText(yearformatter.string(from: lap.usertime))
            } else {
                controller.timeLabel.setText(dateformatter.string(from: lap.usertime))      // same year
            }
            if lap.select == true {
                controller.selectSeparator.setColor(UIColor.rgbColor(0x3498DB))     // UIColor.flatBlueColor())
            } else {
                controller.selectSeparator.setColor(UIColor.rgbColor(0xECF0F1))     // UIColor.flatWhiteColor())
            }
        }
    }
    
    override func table(_ table: WKInterfaceTable,  didSelectRowAt rowIndex: Int) {
        WKInterfaceDevice.current().play(hapticSuccess)
        try! realm.write {
            laps[rowIndex].select = !laps[rowIndex].select
        }
    }
    
    func inquireSendALL() {
        common.watchTableSyncAll()
    }
}

