//
//  NearbyFriendsManager.swift
//  Nearby
//
//  Created by Dan Kang on 4/7/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation

class NearbyFriendsManager: NSObject {
    static let sharedInstance = NearbyFriendsManager()

    let updateInterval = 30.0
    var updateTimer: NSTimer?
    var lastUpdated: NSDate?

    var nearbyFriends: [User]? {
        didSet {
            nearbyFriends?.sortInPlace({ $0.name < $1.name })
        }
    }

    var bestFriends: [User]? {
        didSet {
            bestFriends?.sortInPlace({ $0.name < $1.name })
        }
    }

    var visibleFriends: [User]? {
        if let nearbyFriends = nearbyFriends, bestFriends = bestFriends {
            return nearbyFriends + bestFriends
        } else {
            return nil
        }
    }

    var updateOnActive = false {
        willSet {
            if newValue == true {
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationDidBecomeActiveNotification", object: nil, queue: nil) { notification in
                    if let lastUpdated = self.lastUpdated {
                        let secondsPassed = abs(lastUpdated.timeIntervalSinceNow)
                        if secondsPassed >= self.updateInterval {
                            self.update()
                        }
                    } else {
                        self.update()
                    }
                }
            }
        }
    }

    var updatePeriodicallyWhileActive = false {
        willSet {
            updateTimer?.invalidate()
            if newValue == true {
                if UIApplication.sharedApplication().applicationState == UIApplicationState.Active {
                    updateTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self, selector: "updateWithTimer:", userInfo: nil, repeats: true)
                }
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationDidBecomeActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer?.invalidate()
                    self.updateTimer = NSTimer.scheduledTimerWithTimeInterval(self.updateInterval, target: self, selector: "updateWithTimer:", userInfo: nil, repeats: true)
                }
                NSNotificationCenter.defaultCenter().addObserverForName("UIApplicationWillResignActiveNotification", object: nil, queue: nil) { notification in
                    self.updateTimer?.invalidate()
                }
            }
        }
    }

    func updateWithTimer(timer: NSTimer) {
        update()
    }

    func updateWithSender(sender: AnyObject) {
        update()
    }

    func update(completion: (() -> Void)? = nil) {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo["error"] as! String
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
                let message = error.userInfo["error"] as! String
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
        updatePeriodicallyWhileActive = true
    }

    func stopUpdates() {
        updateOnActive = false
        updatePeriodicallyWhileActive = false
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationWillResignActiveNotification", object: nil)
    }
}