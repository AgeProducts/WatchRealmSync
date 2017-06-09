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
    
    /* Change the following from here. Sync items. As you like. */
    dynamic var select = false
    dynamic var usertime = Date()
    dynamic var textstring = ""
//    dynamic var exchangePhoto:Data? = nil

    /* No sync items. */
//    let localPhotoLink = List<localPhoto>()
    dynamic var nosyncitem = (iOS == true ? "I'm Phone" : "Watch me")
}

func lapItemCopy(from:Lap, to:Lap) {
    /* Don't change! */
    to.createDate = from.createDate
    to.modifyDate = from.modifyDate
    
    /* Change the following from here. */
    to.select = from.select
    to.usertime = from.usertime
    to.textstring = from.textstring
//    to.exchangePhoto = from.exchangePhoto
    
    /* Don't change! */
    to.hashNumber = lapItemHashNumber(lap: to)
}

func lapItemDigest(lap:Lap) -> String {
    /* Don't change! */
    var digest:String = lap.identifier + "_"
    digest += Crypto.MD5(input: lap.createDate as Any) + "_"
    digest += Crypto.MD5(input: lap.modifyDate as Any) + "_"
    
    /* Change the following from here. */
    digest += Crypto.MD5(input: lap.select as Any) + "_"
    digest += Crypto.MD5(input: lap.usertime as Any) + "_"
    digest += Crypto.MD5(input: lap.textstring as Any) + "_"
//    digest += Crypto.MD5(input: lap.exchangePhoto as Any) + "_"
    
    return digest
}

/* Compare item digest. Don't change! */
func lapItemDigestComp(first:Lap, second:Lap) -> Bool {
    return lapItemDigest(lap:first) == lapItemDigest(lap:second)
}

func lapItemHashNumber(lap:Lap) -> Int64 {
    /* Don't change! */
    var aHash:Int = lap.identifier.hashValue
    aHash ^= lap.createDate.hashValue
    aHash ^= lap.modifyDate.hashValue
    
    /* Change the following from here. */
    aHash ^= lap.select.hashValue
    aHash ^= lap.usertime.hashValue
    aHash ^= lap.textstring.hashValue
//    aHash ^= lap.exchangePhoto != nil ? lap.exchangePhoto!.hashValue : 0   // Optional item
    
    return Int64(aHash)
}

/* Compare item hash. Don't change! */
func lapItemHashNumberComp(first:Lap, second:Lap) -> Bool {
    return lapItemHashNumber(lap:first) == lapItemHashNumber(lap:second)
}

/* item digest. Don't change! */
@objc(LapDigest)
class LapDigest: NSObject, NSCoding {
    var identifier:String = ""
    var modifyDate = Date()
    var digestString = ""
    override init() {
        super.init()
    }
    required init(coder aDecoder: NSCoder) {
        self.identifier = aDecoder.decodeObject(forKey: "identifier") as? String ?? ""
        self.modifyDate = aDecoder.decodeObject(forKey: "modifyDate") as? Date ?? Date()
        self.digestString = aDecoder.decodeObject(forKey: "digestString") as? String ?? ""
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.identifier, forKey:"identifier")
        aCoder.encode(self.modifyDate, forKey:"modifyDate")
        aCoder.encode(self.digestString, forKey:"digestString")
    }
}

