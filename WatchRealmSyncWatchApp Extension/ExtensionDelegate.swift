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
        defaultSession.addObserver(self, forKeyPath: "activationState", options: [], context: nil)
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
            } else {
                // immediately complete all other task types as we have not added support for them
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
    #else
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        NSLog("handle handle(_ backgroundTasks \(backgroundTasks)")
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompleted()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompleted()
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompleted()
            default:
                // make sure to complete unhandled task types
                task.setTaskCompleted()
            }
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
