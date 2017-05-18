//
//  Lap.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2017/02/03.
//  Copyright © 2017 AgePro. All rights reserved.
//

import Foundation
import RealmSwift

class Lap: Object {
    /* Don't change! */
    dynamic var identifier = UUID().uuidString
    dynamic var createDate = Date()             // if createDate is onceUponATime is DELETED Item
    dynamic var modifyDate = Date()
    dynamic var youWrote = false
    override static func primaryKey() -> String? { return "identifier" }
    
    /* As you like */
    dynamic var select = false
    dynamic var usertime = Date()
    dynamic var text = ""
    
    /* No sync item */
    dynamic var nosyncitem = (iOS == true ? "I'm Phone." : "Watch me.")
    
//    override static func indexedProperties() -> [String] {
//        return ["title"]
//    }
}

func lapItemCopy(from:Lap, to:Lap) {
    /* */
    to.createDate = from.createDate
    to.modifyDate = from.modifyDate
    
    /* */
    to.select = from.select
    to.usertime = from.usertime
    to.text = from.text
    
    /* */
    // to.nosyncitem = from.nosyncitem
}

/* Only DEBUG use */
func lapItemComp(first:Lap, second:Lap) -> Bool {
    /* */
    if first.createDate != second.createDate { return false }
    // if first.youWrote != second.youWrote { return false }
    /* */
    if first.select != second.select { return false }
    if first.usertime != second.usertime { return false }
    if first.text != second.text { return false }
    /* */
    // if first.nosyncitem != second.nosyncitem { return false }
    return true
}
