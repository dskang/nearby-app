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

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = kCLDistanceFilterNone

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "stopUpdatingLocation", name: GlobalConstants.NotificationKey.stealthModeOn, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startUpdatingLocation", name: GlobalConstants.NotificationKey.stealthModeOff, object: nil)
    }

    dynamic var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0) {
        didSet {
            let user = User.currentUser()
            user.location = [
                "timestamp": userLocation.timestamp.timeIntervalSince1970,
                "latitude": userLocation.coordinate.latitude,
                "longitude": userLocation.coordinate.longitude,
                "accuracy": userLocation.horizontalAccuracy
            ]
            user.saveInBackground()
        }
    }

    func startUpdatingLocation() {
        // TODO: Check for location services in delegate and create alert if disabled
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

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let recent = abs(location.timestamp.timeIntervalSinceNow) < 15.0
        let locationChanged = userLocation.distanceFromLocation(location) > 5
        if recent && locationChanged {
            userLocation = location
        }
    }
}
