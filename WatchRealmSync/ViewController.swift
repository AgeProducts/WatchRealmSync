//
//  ViewController.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2017/02/13.
//  Copyright © 2017 AgePro. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RealmSwift
import RxRealm
import WatchConnectivity

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var trashButton: UIBarButtonItem!
    @IBOutlet weak var numberButton: UIButton!
    
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    @IBOutlet weak var make10dButton: UIBarButtonItem!
    @IBOutlet weak var delAllButton: UIBarButtonItem!
    
    let bag = DisposeBag()
    let realm = try! Realm()
    var lapsAll: Results<Lap>!
    var laps: Results<Lap>!
    var lapsSelect: Results<Lap>!
    let common = Common.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if WatchIPhoneConnect.sharedConnectivityManager.watchSupport() == false ||
            WatchIPhoneConnect.sharedConnectivityManager.watchIsPaired() == false {
            NSLog("Watch connect setting error.")
            // assertionFailure("Watch setting error. Give up!")
        }
        
        let viewLastDate = Date()
        let viewFirstDate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:viewLastDate, day:Double(-IPHONE_SHOW_DATE))
        let predicate = NSPredicate(format:"usertime >= %@", viewFirstDate as CVarArg)
        
        lapsAll = realm.objects(Lap.self)
        lapsSelect = lapsAll.filter("select==true")
        laps = lapsAll.filter(predicate).sorted(byKeyPath: "usertime", ascending:false)
        
        Observable.changeset(from: lapsAll)
            .subscribe(onNext: { [weak self] results, changes in
                guard let wself = self else { return }
                let count = "\(wself.lapsSelect.count)/\(wself.laps.count)/\(wself.lapsAll.count)"
                wself.numberButton.setTitle(count, for: .normal)
            })
            .addDisposableTo(bag)
        
        Observable.changeset(from: laps)
            .subscribe(onNext: { [weak self] results, changes in
                
//                NSLog("View changeset changes: \(results.count) : \(changes.debugDescription))")
                
                guard let wself = self else { return }
                dispatch_async_main {
                    wself.tableView.reloadData()                            // RELOAD all
                }
            })
            .addDisposableTo(bag)
        
        addButton.rx.tap                    // Add an item.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                let lap = Lap()
                lap.textstring = "I> New Text"
                try! wself.realm.write {
                    wself.realm.add(lap)
                }
            })
            .addDisposableTo(bag)
        
        trashButton.rx.tap                  // Delete (selected) items.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                let items = wself.realm.objects(Lap.self).filter("select==true")
                if items.isEmpty == false {
                    try! wself.realm.write {
                        wself.realm.delete(items)
                    }
                }
            })
            .addDisposableTo(bag)
        
        numberButton.rx.tap
            .subscribe(onNext: { [weak self] in
                let simulationFirstDate = Date()
                let simulationLastDate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:simulationFirstDate, day:Double(-SIMULATE_TARGET_DATE))
                let realm2 = try! Realm()
                let items = realm2.objects(Lap.self).filter("select==true")
                if items.isEmpty == false {
                    try! realm2.write {
                        items.forEach { lap in
                            lap.usertime = RandomMaker.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                            lap.textstring = "I> " + RandomMaker.randomStringWithLength(16)
                        }
                    }
                }
            })
            .addDisposableTo(bag)
        
        reloadButton.rx.tap                 // Force update and sync.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                wself.inquireSendALL()
            })
            .addDisposableTo(bag)
        
        make10dButton.rx.tap               // Make 10 items
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                wself.make10Items()
            })
            .addDisposableTo(bag)
        
        delAllButton.rx.tap               // Delete All
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                wself.deleteItems()
            })
            .addDisposableTo(bag)
        
        inquireSendALL()
    }
    
    deinit {
    }
    
    func inquireSendALL() {
        common.watchTableSyncAll()
    }
    
    /* Make 10 items */
    let makeCount = 10
    func make10Items() {
        DispatchQueue(label: "background").async {
            let simulationFirstDate = Date()
            let simulationLastDate = DateHelper.getDateBeforeOrAfterSomeDay(baseDate:simulationFirstDate, day:Double(-SIMULATE_TARGET_DATE))
            autoreleasepool { [weak self] in
                guard let wself = self else { return }
                let realm2 = try! Realm()
                try! realm2.write {
                    for _ in 0 ..< wself.makeCount {
                        let lap = Lap()
                        lap.usertime = RandomMaker.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                        lap.textstring = "I> " + RandomMaker.randomStringWithLength(16)
                        lap.select = RandomMaker.randomBool(percent:33.3)   // select 1/3
                        realm2.add(lap)
                    }
                }
            }
        }
    }
    
    /* Delete all */
    func deleteItems() {
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
}


extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return laps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lap = laps[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.detailTextLabel?.text = lap.textstring
        cell.imageView?.image = nil

        let (TY, TM, _) = DateHelper.yearMonthDayFromDate(Date())
        let (UY, UM, _) = DateHelper.yearMonthDayFromDate(lap.usertime)
        if TY != UY || TM != UM {
            cell.textLabel?.text = yearformatter.string(from: lap.usertime)
        } else {
            cell.textLabel?.text = dateformatter.string(from: lap.usertime) // same month
        }
        if lap.select == true {
            cell.backgroundColor = UIColor.rgbColor(0x3498DB)       // UIColor.flatBlueColor())
        } else {
            cell.backgroundColor = UIColor.rgbColor(0xECF0F1)       // UIColor.flatWhiteColor())
        }
        
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let lap = laps[indexPath.row]
        try! realm.write {
            lap.select = !lap.select
        }
    }
}

extension UITableView {
    func applyChangeset(_ changes: RealmChangeset) {
        beginUpdates()
        deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        endUpdates()
    }
}
