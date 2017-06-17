//
//  LapShare.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2017/02/03.
//  Copyright © 2017 AgePro. All rights reserved.
//

import Foundation
import RealmSwift


/* Compare item digest. */
func lapItemDigestComp(first:Lap, second:Lap) -> Bool {
    return lapItemDigest(lap:first) == lapItemDigest(lap:second)
}

/* Compare item hash.  */
func lapItemHashNumberComp(first:Lap, second:Lap) -> Bool {
    return lapItemHashNumber(lap:first) == lapItemHashNumber(lap:second)
}

/* Make item digest.  */
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

