//
//  FriendAnnotation.swift
//  Nearby
//
//  Created by Dan Kang on 4/11/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import MapKit

class FriendAnnotation: MKPointAnnotation {
    let userId: String

    init(userId: String) {
        self.userId = userId
    }

    func setValues(userName userName: String, userLocation: CLLocation) {
        let timeAgo = userLocation.timestamp.shortTimeAgoSinceNow()
        title = userName
        subtitle = "\(timeAgo) ago"
        coordinate = userLocation.coordinate
    }
}
