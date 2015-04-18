//
//  User.swift
//  Nearby
//
//  Created by Dan Kang on 4/4/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class User: PFUser, PFSubclassing {
    @NSManaged var fbId: String
    @NSManaged var name: String
    @NSManaged var firstName: String
    @NSManaged var lastName: String
    @NSManaged var location: [String: Double]
    @NSManaged var hideLocation: Bool
    @NSManaged var bestFriends: [User]

    var loc: CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: location["latitude"]!, longitude: location["longitude"]!)
        let timestamp = NSDate(timeIntervalSince1970: location["timestamp"]!)
        let horizontalAccuracy = location["accuracy"]!
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: 0, timestamp: timestamp)
    }

    func isBestFriend(user: User) -> Bool {
        let results = bestFriends.filter { $0 == user }
        return results.count > 0
    }

    func requestedBestFriend(user: User) -> Bool {
        return false
    }

    var annotation: FriendAnnotation?
}