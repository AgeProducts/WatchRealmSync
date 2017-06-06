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
    dynamic var itemDigest = "Initial_Item_Digest"
    override static func primaryKey() -> String? { return "identifier" }
    
    /* Following can be changed. As you like */
    dynamic var select = false
    dynamic var usertime = Date()
    dynamic var textstring = ""

    /* No sync items.  As you like. */
    dynamic var nosyncitem = (iOS == true ? "I'm Phone" : "Watch me")
}

func lapItemCopy(from:Lap, to:Lap) {
    /* Don't change! */
//    to.identifier = from.identifier
    to.createDate = from.createDate
    to.modifyDate = from.modifyDate
    to.itemDigest = from.itemDigest
    
    /* Please change. */
    to.select = from.select
    to.usertime = from.usertime
    to.textstring = from.textstring
}

func lapItemDigest(lap:Lap) -> String {
    
    /* Don't change! */
    var digest:String = lap.identifier + "_"
    
    /* Please change. */
    digest += Crypto.MD5(input: lap.select as Any)
    digest += Crypto.MD5(input: lap.usertime as Any)
    digest += Crypto.MD5(input: lap.textstring as Any)
    
    return digest
}

/* item digest. Don't change! */
func lapItemDigestComp(first:Lap, second:Lap) -> Bool {
    return lapItemDigest(lap:first) == lapItemDigest(lap:second)
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

