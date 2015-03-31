//
//  ViewController.swift
//  Nearby
//
//  Created by Dan Kang on 3/10/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import UIKit
import Parse
import CoreLocation
import MapKit

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!

    let locationManager = CLLocationManager()
    var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0) {
        willSet {
            if userLocation.coordinate.latitude == 0 && userLocation.coordinate.longitude == 0 {
                // Center map on user's location
                let latitude = newValue.coordinate.latitude
                let longitude = newValue.coordinate.longitude
                let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let span = MKCoordinateSpan(latitudeDelta: 0.0045, longitudeDelta: 0.0045)
                let region = MKCoordinateRegion(center: center, span: span)
                mapView.setRegion(region, animated: true)
            }
        }
        didSet {
            let latitude = userLocation.coordinate.latitude
            let longitude = userLocation.coordinate.longitude
            let accuracy = userLocation.horizontalAccuracy
            let location: [String: Double] = ["latitude": latitude, "longitude": longitude, "accuracy": accuracy]
            let user = PFUser.currentUser()
            user["location"] = location
            user.saveInBackground()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let user = PFUser.currentUser() {
            if CLLocationManager.locationServicesEnabled() {
                mapView.showsUserLocation = true

                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                locationManager.distanceFilter = kCLDistanceFilterNone

                switch CLLocationManager.authorizationStatus() {
                case .AuthorizedAlways:
                    locationManager.startUpdatingLocation()
                case .NotDetermined:
                    locationManager.requestAlwaysAuthorization()
                case .Restricted, .Denied:
                    // TODO: Check if location disabled when the user returns to the app after it's already open
                    showLocationDisabledAlert()
                default:
                    break
                }
            }

            FBRequestConnection.startForMeWithCompletionHandler({ connection, result, error in
                if error == nil {
                    let userData = result as [NSObject: AnyObject]
                    let name = userData["name"] as String
                    let facebookID = userData["id"] as String
                    user["name"] = name
                    user["fbID"] = facebookID
                    user.saveInBackground()
                }
            })

//            PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil, block: {
//                (result, error) in
//                let result = result as [PFUser]
//                println("\(result)")
//                println(result[0].objectId)
//            })
        } else {
            // Create the log in view controller
            let logInController = PFLogInViewController()
            logInController.delegate = self
            logInController.facebookPermissions = ["user_friends"]
            logInController.fields = (PFLogInFields.Facebook)
            // TODO: Handle user denying "user_friends" permission
            // TODO: Handle user cancelling log in

            // Present the log in view controller
            self.presentViewController(logInController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func showLocationDisabledAlert() {
        let alertController = UIAlertController(
            title: "Background Location Access Disabled",
            message: "In order to be notified about nearby friends, please open this app's settings and set location access to 'Always'.",
            preferredStyle: .Alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)

        let openAction = UIAlertAction(title: "Open Settings", style: .Default) { (action) in
            if let url = NSURL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.sharedApplication().openURL(url)
            }
        }
        alertController.addAction(openAction)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController!, didLogInUser user: PFUser!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let eventDate = location.timestamp
        let howRecent = eventDate.timeIntervalSinceNow
        if abs(howRecent) < 15.0 {
            userLocation = location
        }
    }

}

