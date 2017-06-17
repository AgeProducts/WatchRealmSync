//
//  SysDefines.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2016/10/11.
//  Copyright © 2016 AgePro. All rights reserved.
//

import Foundation

#if os(iOS)
let iOS = true
#else
let iOS = false
#endif

/* Boot load status */
enum loadInitType {
    case kLoaded
    case kLoadedPrevios
    case kLoadeFirst
}

/* Setup defaults & UD Keys */
let UD_LOADED_ONCE          = "UD_LOADED_ONCEv2.2"
let UD_LOADED_ONCE_PREVIOS  = "UD_LOADED_ONCEv2.0"
// let UD_LOADED_ONCE_PREVIOS  = "UD_LOADED_ONCEv1.0"
// let UD_LOADED_ONCE_PREVIOS  = "UD_LOADED_ONCEvNON"   first ver

/* REALM DB */
let WATCH_TRAN_REALM        = "WatchTrans.realm"
let TMP_REALM_FILE          = "TmpRealmFile"
let TMP_DIGEST_FILE         = "TmpDigestFile"

/* notification */
let WCSessionReachabilityDidChangeNotification =  "ReachabilityDidChangeNotification"
let WCSessionWatchStateDidChangeNotification =    "WatchStateDidChangeNotification"

/* setting date (month) */
let SIMULATE_TARGET_DATE = (31*12)
let IPHONE_SHOW_DATE = SIMULATE_TARGET_DATE
let WATCH_SHOW_DATE = SIMULATE_TARGET_DATE // (31*3)

