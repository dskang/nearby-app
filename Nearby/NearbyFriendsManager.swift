//
//  NearbyFriendsManager.swift
//  Nearby
//
//  Created by Dan Kang on 4/7/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class NearbyFriendsManager: NSObject {

    let updateInterval = 30.0
    var updateTimer: NSTimer?
    var lastUpdated: NSDate?

    var nearbyFriends: [User]? {
        didSet {
            nearbyFriends?.sort({ $0.name < $1.name })
        }
    }

    var bestFriends: [User]? {
        didSet {
            bestFriends?.sort({ $0.name < $1.name })
        }
    }

    var visibleFriends: [User]? {
        if let nearbyFriends = nearbyFriends, bestFriends = bestFriends {
            return nearbyFriends + bestFriends
        } else {
            return nil
        }
    }

    var updateOnActive: Bool = false {
        willSet {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
            if newValue == true {
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationDidBecomeActiveNotification", object: nil, queue: nil) { notification in
                    if let lastUpdated = self.lastUpdated {
                        let secondsPassed = abs(lastUpdated.timeIntervalSinceNow)
                        if secondsPassed >= self.updateInterval {
                            self.syncFriends {
                                self.update()
                            }
                        }
                    } else {
                        self.syncFriends {
                            self.update()
                        }
                    }
                }
            }
        }
    }

    var updatePeriodically: Bool = false {
        willSet {
            updateTimer?.invalidate()
            if newValue == true {
                updateTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self, selector: "update:", userInfo: nil, repeats: true)
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationDidBecomeActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer?.invalidate()
                    self.updateTimer = NSTimer.scheduledTimerWithTimeInterval(self.updateInterval, target: self, selector: "update:", userInfo: nil, repeats: true)
                }
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationWillResignActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer?.invalidate()
                }
            }
        }
    }

    func update(timer: NSTimer) {
        update()
    }

    func update(completion: (() -> Void)? = nil) {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                if let result = result as? [String: [User]] {
                    self.bestFriends = result["bestFriends"]
                    self.nearbyFriends = result["nearbyFriends"]
                    self.lastUpdated = NSDate()
                    NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.updatedVisibleFriends, object: self)
                    if let completion = completion {
                        completion()
                    }
                }
            }
        }
    }

    func syncFriends(completion: (() -> Void)? = nil) {
        PFCloud.callFunctionInBackground("updateFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                if let completion = completion {
                    completion()
                }
            }
        }
    }

    func startUpdates() {
        update()
        updateOnActive = true
        updatePeriodically = true
    }

    func stopUpdates() {
        updateOnActive = false
        updatePeriodically = false
    }
}