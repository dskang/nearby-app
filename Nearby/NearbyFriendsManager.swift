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

    dynamic var nearbyFriends: [User]? {
        didSet {
            nearbyFriends?.sort({ $0.name < $1.name })
        }
    }

    var bestFriends: [User]?

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
            if newValue == true {
                updateTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self, selector: "update:", userInfo: nil, repeats: true)
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationDidBecomeActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer = NSTimer.scheduledTimerWithTimeInterval(self.updateInterval, target: self, selector: "update:", userInfo: nil, repeats: true)
                }
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationWillResignActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer?.invalidate()
                }
            } else {
                updateTimer?.invalidate()
            }
        }
    }

    func update(timer: NSTimer) {
        update()
    }

    func update(completion: (() -> Void)? = nil) {
        // NB: If lastUpdated is updated inside the success callback, there is a race condition in which nearbyFriends may be updated on the opening of a wave but the pin will lose focus if nearbyFriends are updated again (second update will be called between the first one being called and before it returns)
        lastUpdated = NSDate()
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
            } else {
                if let result = result as? [String: [User]] {
                    self.bestFriends = result["bestFriends"]
                    self.nearbyFriends = result["nearbyFriends"]
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
                println(message)
                // TODO: Send to Parse
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