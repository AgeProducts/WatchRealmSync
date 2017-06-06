//
//  ExtensionDelegate.swift
//  WatchRealmSyncWatchApp Extension
//
//  Created by Takuji Hori on 2017/02/13.
//  Copyright © 2017 AgePro. All rights reserved.
//

import WatchKit
#if BACKGROUND
import WatchConnectivity
#endif

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    #if BACKGROUND
    /* Now, BACKGROUND is not used.
     If you want to use, target WatchRealmSyncWatchApp Extension
     [Other Swift Flag] add "-D" "BACKGROUND".
     */
    var wcBackgroundTasks: [WKWatchConnectivityRefreshBackgroundTask]
    override init() {
        wcBackgroundTasks = []
        super.init()
    
        let defaultSession = WCSession.default()
        defaultSession.delegate = WatchIPhoneConnect.sharedConnectivityManager
        /*
        Here we add KVO on the session properties that this class is interested in before activating
        the session to ensure that we do not miss any value change events
        */
        defaultSession.addObserver(self, forKeyPath: "activationState", options: [], context: nil)      // ??
        defaultSession.addObserver(self, forKeyPath: "hasContentPending", options: [], context: nil)
        defaultSession.activate()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            self.completeAllTasksIfReady()
        }
    }
    
    // MARK: Background
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        NSLog("handle handle(_ backgroundTasks \(backgroundTasks)")
        for backgroundTask in backgroundTasks {
    
            if let wcBackgroundTask = backgroundTask as? WKWatchConnectivityRefreshBackgroundTask {
                // store a reference to the task objects as we might have to wait to complete them
                self.wcBackgroundTasks.append(wcBackgroundTask)
                NSLog("add BackGround: \(wcBackgroundTask)")
            } else {
                // immediately complete all other task types as we have not added support for them
                NSLog("NOT BackGround: \(wcBackgroundTasks)")
                backgroundTask.setTaskCompleted()
            }
        }
        completeAllTasksIfReady()
    }
    
    func completeAllTasksIfReady() {
        let session = WCSession.default()
        // the session's properties only have valid values if the session is activated, so check that first
        if session.activationState == .activated && !session.hasContentPending {
            wcBackgroundTasks.forEach { $0.setTaskCompleted() }
            wcBackgroundTasks.removeAll()
        }
    }
    #endif
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
    func applicationWillEnterForeground() {
    }
    
    func applicationDidEnterBackground() {
    }
}
