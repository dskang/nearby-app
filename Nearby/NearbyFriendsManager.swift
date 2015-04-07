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
            if nearbyFriends != nil {
                nearbyFriends!.sort({ $0.name < $1.name })
                for friend in nearbyFriends! {
                    let timeAgo = friend.loc.timestamp.shortTimeAgoSinceNow()
                    friend.annotation.title = friend.name
                    friend.annotation.subtitle = "\(timeAgo) ago"
                    friend.annotation.coordinate = friend.loc.coordinate
                }
            }
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
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil, block: {
            (result, error) in
            if error == nil {
                self.nearbyFriends = result as? [User]
            } else {
                let message = error.userInfo!["error"] as String
                println(message)
            }
        })
    }

    func startUpdates() {
        update()
        updateNearbyFriendsOnActive = true
    }

    func stopUpdates() {
        updateNearbyFriendsOnActive = false
    }
}