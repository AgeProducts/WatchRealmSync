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
    @IBOutlet weak var make100dButton: UIBarButtonItem!
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
//            assertionFailure("Watch setting error. Give up!")
        }

        lapsAll = realm.objects(Lap.self)
        let (firstDate, lastDate) = common2.viewDate(baseDate: Date(), month: IPhoneViewMonth)
        let predicate = NSPredicate(format: "(usertime >= %@) AND (usertime <= %@)", firstDate as CVarArg, lastDate as CVarArg)
        laps = lapsAll.filter(predicate).sorted(byKeyPath: "usertime", ascending:false)
        lapsSelect = lapsAll.filter("select == true")

        Observable.changeset(from: lapsAll)
            .subscribe(onNext: { [weak self] results, changes in
                guard let `self` = self else { return }
                let count = "\(self.laps.count)/\(self.lapsSelect.count)/\(self.lapsAll.count)"
                self.title = count
            })
            .addDisposableTo(bag)

        Observable.changeset(from: laps)
            .subscribe(onNext: { [weak self] results, changes in
                guard let `self` = self else { return }
                if let changes = changes {
                    // it's an update only
                        self.tableView.applyChangeset(changes)
                } else {
                    // it's the initial data
                    self.tableView.reloadData()
                }
            })
            .addDisposableTo(bag)
        
        addButton.rx.tap                    // Add item.
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                let lap = Lap()
                lap.usertime = Date()
                lap.text = "新てきすと"
                do {
                    try self.realm.write {
                        self.realm.add(lap)
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }

            })
            .addDisposableTo(bag)

        trashButton.rx.tap                  // Delete (selected) items.
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                do {
                    try self.realm.write {
                        let items = self.realm.objects(Lap.self).filter("select==true")
                        self.realm.delete(items)
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            })
            .addDisposableTo(bag)

        composeButton.rx.tap                // Make random. text and usertime.
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                let (simulationFirstDate, simulationLastDate) = self.common2.viewDate(baseDate: Date(), month: MakeSimulationMonth)
                 do {
                    try self.realm.write {
                        let items = self.realm.objects(Lap.self).filter("select==true")
                        items.forEach { item in
                            item.usertime = RandomGenerator.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                            item.text = RandomGenerator.randomStringWithLength(16)
                        }
                    }
                }
                catch let error as NSError {
                    NSLog("Error - \(error.localizedDescription)")
                }
            })
            .addDisposableTo(bag)
        
        reloadButton.rx.tap                 // Update and Sync all.
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.inquireSendALL()
             })
            .addDisposableTo(bag)
        
        make100dButton.rx.tap               // Make 100 items
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.makeItems()
            })
            .addDisposableTo(bag)

        delAllButton.rx.tap               // Delete All
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.deleteItems()
            })
            .addDisposableTo(bag)
        
        /* init Sync All */
//        if common2.isLoadedStatus != .kLoaded {
            inquireSendALL()
//        }
    }
    
    deinit {
    }
    
    func requestSendALL() {
        common2.watchTableSendAll()
        common2.requestSendAll()
    }

    func inquireSendALL() {
        requestSendALL()
//        if WatchIPhoneConnect.sharedConnectivityManager.watchSessionActivationState() == .activated &&
//            WatchIPhoneConnect.sharedConnectivityManager.watchAppInstalled() == true {
//            self.requestSendALL()
//        } else {
//            NSLog("Watch Connection error!!")
//            // NSLog("watchReachable:\(WatchIPhoneConnect.sharedConnectivityManager.watchReachable())")
//            NSLog("watchSessionActivationState:\(WatchIPhoneConnect.sharedConnectivityManager.watchSessionActivationState())")
//            NSLog("watchAppInstalled:\(WatchIPhoneConnect.sharedConnectivityManager.watchAppInstalled())")
//            dispatch_async_main {
//                let alert = UIAlertController(title: "Alert", message: "Counterpart app not installed.\nCheck setting and please try again.", preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
//                alert.addAction(UIAlertAction(title: "retry", style: .default) { _ in
//                    self.inquireSendALL()
//                })
//                self.present(alert, animated: true, completion: nil)
//            }
//        }
    }
    
    /* Make 100 items */
    let count = 100
    func makeItems() {
        DispatchQueue(label: "background").async {
            let (simulationFirstDate, simulationLastDate) = self.common2.viewDate(baseDate: Date(), month: MakeSimulationMonth)
            autoreleasepool { [weak self] in
                guard let `self` = self else { return }
                let realm2 = try! Realm()
                do {
                    try realm2.write {
                        for _ in 0 ..< self.count {
                            let lap = Lap()
                            lap.usertime = RandomGenerator.randomDate3(simulationFirstDate, lastDate: simulationLastDate)!
                            lap.text = RandomGenerator.randomStringWithLength(16)
                            lap.select = RandomGenerator.randomNumIntegerWithLimits(lower: 0, upper: 3) == 0 ? true : false   // select 25%
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
        cell.textLabel?.text = formatter.string(from: lap.usertime)
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
        do {
            try realm.write {
                self.laps[indexPath.row].select = !self.laps[indexPath.row].select
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
