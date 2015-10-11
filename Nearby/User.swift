//
//  User.swift
//  Nearby
//
//  Created by Dan Kang on 4/4/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation

class User: PFUser {
    @NSManaged var fbId: String!
    @NSManaged var name: String
    @NSManaged var firstName: String
    @NSManaged var lastName: String
    @NSManaged var location: [String: Double]
    @NSManaged var bestFriends: [User]
    @NSManaged var blockedUsers: [User]

    // Accessing @NSManaged variables of type Bool results in crashes in iPhone 5 and older models
    var hideLocation: Bool {
        set {
            self["hideLocation"] = newValue
        }
        get {
            return (self["hideLocation"] as? Bool) ?? false
        }
    }

    var loc: CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: location["latitude"]!, longitude: location["longitude"]!)
        let timestamp = NSDate(timeIntervalSince1970: location["timestamp"]!)
        let horizontalAccuracy = location["accuracy"]!
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: 0, timestamp: timestamp)
    }

    func hasBlocked(user: User) -> Bool {
        let results = self.blockedUsers.filter { $0.objectId == user.objectId }
        return results.count > 0
    }

    func hasBestFriend(user: User) -> Bool {
        let results = self.bestFriends.filter { $0.objectId == user.objectId }
        return results.count > 0
    }
}