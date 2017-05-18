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
    @IBOutlet weak var composeButton: UIBarButtonItem!
    
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    @IBOutlet weak var make10dButton: UIBarButtonItem!
    @IBOutlet weak var delAllButton: UIBarButtonItem!
    
    let bag = DisposeBag()
    let realm = try! Realm()
    var lapsAll: Results<Lap>!
    var laps: Results<Lap>!
    var lapsSelect: Results<Lap>!
    let common2 = Common2.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if WatchIPhoneConnect.sharedConnectivityManager.watchSupport() == false ||
            WatchIPhoneConnect.sharedConnectivityManager.watchIsPaired() == false {
            NSLog("Watch connect setting error.")
            // assertionFailure("Watch setting error. Give up!")
        }
        
        lapsAll = realm.objects(Lap.self)
        laps = lapsAll.sorted(byKeyPath: "usertime", ascending:false)
        lapsSelect = laps.filter("select==true")
        
        Observable.changeset(from: lapsAll)
            .subscribe(onNext: { [weak self] results, changes in
                guard let wself = self else { return }
                let count = "\(wself.laps.count)/\(wself.lapsSelect.count)/\(wself.lapsAll.count)"
                wself.title = count
            })
            .addDisposableTo(bag)
        
        Observable.changeset(from: laps)
            .subscribe(onNext: { [weak self] results, changes in
                guard let wself = self else { return }
                if let changes = changes {
                    // it's an update only
                    wself.tableView.applyChangeset(changes)
                } else {
                    // it's the initial data
                    wself.tableView.reloadData()
                }
            })
            .addDisposableTo(bag)
        
        addButton.rx.tap                    // Add item.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                let lap = Lap()
                lap.usertime = Date()
                lap.text = "新てきすと"
                do {
                    try wself.realm.write {
                        wself.realm.add(lap)
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
                
            })
            .addDisposableTo(bag)
        
        trashButton.rx.tap                  // Delete (selected) items.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                let items = wself.realm.objects(Lap.self).filter("select==true")
                if items.isEmpty == false {
                    do {
                        try wself.realm.write {
                            wself.realm.delete(items)
                        }
                    }
                    catch let error as NSError {
                        NSLog("Error - \(error.localizedDescription)")
                    }
                }
            })
            .addDisposableTo(bag)
        
        composeButton.rx.tap                // Make random. text and usertime.
            .subscribe(onNext: { [weak self] in
                guard let wself = self else { return }
                // let (simulationFirstDate, simulationLastDate) = self.common2.viewDate(baseDate: Date(), month: MakeSimulationMonth)
                let simulationFirstDate = Date()
                let simulationLastDate = DateHelper.getDateBeforeOrAfterSomeMonth(baseDate:simulationFirstDate, month: Double(-MakeSimulationMonth))
                let realm2 = try! Realm()
                let items = realm2.objects(Lap.self).filter("select==true")
                if items.isEmpty == false {
                    do {
                        try realm2.write {
                            // let items = wself.realm.objects(Lap.self).filter("select==true")
                            items.forEach { item in
                                item.usertime = RandomMaker.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                                item.text = RandomMaker.randomStringWithLength(16)
                            }
                        }
                    }
                    catch let error as NSError {
                        NSLog("Error - \(error.localizedDescription)")
                    }
                }
            })
            .addDisposableTo(bag)
        
        reloadButton.rx.tap                 // Update and Sync all.
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
        
        /* init Sync All */
        inquireSendALL()
    }
    
    deinit {
    }
    
    func requestSendALL() {
        common2.watchTableSendAll()
        common2.requestSendAll()
    }
    
    func inquireSendALL() {
        requestSendALL()
    }
    
    /* Make 10 items */
    let makeCount = 10
    func make10Items() {
        DispatchQueue(label: "background").async {
            let simulationFirstDate = Date()
            let simulationLastDate = DateHelper.getDateBeforeOrAfterSomeMonth(baseDate:simulationFirstDate, month: Double(-MakeSimulationMonth))
            autoreleasepool { [weak self] in
                guard let wself = self else { return }
                let realm2 = try! Realm()
                do {
                    try realm2.write {
                        for _ in 0 ..< wself.makeCount {
                            let lap = Lap()
                            lap.usertime = RandomMaker.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                            lap.text = RandomMaker.randomStringWithLength(16)
                            lap.select = RandomMaker.randomNumIntegerWithLimits(lower: 0, upper: 2) == 0 ? true : false   // select 33%
                            realm2.add(lap)
                        }
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /* Delete all */
    func deleteItems() {
        DispatchQueue(label: "background").async {
            autoreleasepool {
                let realm2 = try! Realm()
                do {
                    try realm2.write {
                        realm2.deleteAll()
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            }
        }
    }
}


extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return laps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lap = laps[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.detailTextLabel?.text = lap.text
        if DateHelper.firstDateFromDate(Date()) == DateHelper.firstDateFromDate(lap.usertime) {
            cell.textLabel?.text = timeformatter.string(from: lap.usertime)
        } else {
            cell.textLabel?.text = dateformatter.string(from: lap.usertime)
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
        do {
            try realm.write {
                lap.select = !lap.select
            }
        }
        catch let error as NSError {
            NSLog("Error - \(error.localizedDescription)")
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
