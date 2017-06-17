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
    dynamic var createDate = Date()
    dynamic var modifyDate = Date()
    dynamic var hashNumber:Int64 = 0
    override static func primaryKey() -> String? { return "identifier" }
    
    /****** Change the following from here. Sync item. As you like. ******/
    dynamic var select = false
    dynamic var usertime = Date()
    dynamic var textstring = ""
    /****** that's it. ******/
    
    /* No sync items. */
    dynamic var nosyncitem = (iOS == true ? "I'm Phone" : "Watch me")
}

func lapItemCopy(from:Lap, to:Lap) {
    
    /* Don't change! */
    to.createDate = from.createDate
    to.modifyDate = from.modifyDate
    
    /****** Change the following from here. ******/
    to.select = from.select
    to.usertime = from.usertime
    to.textstring = from.textstring
    /****** that's it. ******/
    
    /* Don't change! */
    to.hashNumber = lapItemHashNumber(lap: to)
}

func lapItemDigest(lap:Lap) -> String {
    
    var digest:String = ""

    /* Don't change! */
    digest += Crypto.MD5(input: lap.identifier as Any)
    digest += Crypto.MD5(input: lap.createDate as Any)
    digest += Crypto.MD5(input: lap.modifyDate as Any)
    
    /****** Change the following from here. ******/
    digest += Crypto.MD5(input: lap.select as Any)
    digest += Crypto.MD5(input: lap.usertime as Any)
    digest += Crypto.MD5(input: lap.textstring as Any)
    /****** that's it. ******/
    
    return digest
}


func lapItemHashNumber(lap:Lap) -> Int64 {
    
    var aHash:Int = 0

    /* Don't change! */
    aHash ^= lap.identifier.hashValue
    aHash ^= lap.createDate.hashValue
    aHash ^= lap.modifyDate.hashValue
    
    /****** Change the following from here. ******/
    aHash ^= lap.select.hashValue
    aHash ^= lap.usertime.hashValue
    aHash ^= lap.textstring.hashValue
    /****** that's it. ******/
    
    return Int64(aHash)
}

