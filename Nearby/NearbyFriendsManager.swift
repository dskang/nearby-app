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
    dynamic var nearbyFriends: [User]? {
        didSet {
            nearbyFriends?.sort({ $0.name < $1.name })
        }
    }

    var updateNearbyFriendsOnActive: Bool = false {
        willSet {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
            if newValue == true {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "update", name: "UIApplicationDidBecomeActiveNotification", object: nil)
            }
        }
    }

    func update() {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
            } else {
                self.nearbyFriends = result as? [User]
            }
        }
    }

    func startUpdates() {
        update()
        updateNearbyFriendsOnActive = true
    }

    func stopUpdates() {
        updateNearbyFriendsOnActive = false
    }
}