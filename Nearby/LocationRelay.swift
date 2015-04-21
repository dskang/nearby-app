//
//  LocationRelay.swift
//  Nearby
//
//  Created by Dan Kang on 4/5/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import CoreLocation

class LocationRelay: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()

    dynamic var userLocation: CLLocation? {
        didSet {
            if let location = userLocation, user = User.currentUser() {
                user.location = [
                    "timestamp": location.timestamp.timeIntervalSince1970,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy
                ]
                user.saveInBackground()
            }
        }
    }

    func startUpdates() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false

        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .AuthorizedAlways:
                locationManager.startUpdatingLocation()
            case .NotDetermined:
                locationManager.requestAlwaysAuthorization()
            case .Restricted, .Denied:
                NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.disabledLocation, object: self)
            default:
                break
            }
        }
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
        userLocation = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as! CLLocation
        let recent = abs(location.timestamp.timeIntervalSinceNow) < 15.0
        let locationChanged = userLocation == nil || userLocation!.distanceFromLocation(location) > 5.0
        if recent && locationChanged {
            userLocation = location
        }
    }
}
