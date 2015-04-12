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
    var user: User

    init(user: User) {
        self.user = user
        super.init()

        let timeAgo = user.loc.timestamp.shortTimeAgoSinceNow()
        self.title = user.name
        self.subtitle = "\(timeAgo) ago"
        self.coordinate = user.loc.coordinate
    }
}
