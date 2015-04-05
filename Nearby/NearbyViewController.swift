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

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!

    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    let nearbyDistance = 150.0
    var refreshControl: UIRefreshControl!

    var userLocation: CLLocation = CLLocation(latitude: 0, longitude: 0) {
        willSet {
            if userLocation.coordinate.latitude == 0 && userLocation.coordinate.longitude == 0 {
                centerAndZoomMapOnCoordinate(newValue.coordinate)
            }
        }
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

    var nearbyFriends: [User] = [] {
        didSet {
            nearbyFriends.sort({ $0.name < $1.name })

            for friend in nearbyFriends {
                let timeAgo = friend.loc.timestamp.shortTimeAgoSinceNow()
                friend.annotation.title = friend.name
                friend.annotation.subtitle = "\(timeAgo) ago"
                friend.annotation.coordinate = friend.loc.coordinate
                self.mapView.addAnnotation(friend.annotation)
            }

            if nearbyFriends.count == 0 {
                let label = UILabel(frame: CGRectMake(0, 0, self.tableView.bounds.size.width, self.tableView.bounds.size.height))
                label.text = "No friends are nearby."
                label.textAlignment = NSTextAlignment.Center
                label.sizeToFit()

                self.tableView.backgroundView = label
                self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
            } else {
                self.tableView.backgroundView = nil
                self.tableView.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
            }
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if User.currentUser() != nil {
            startUpdatingLocation()
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "getNearbyFriends", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        }

        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "getNearbyFriends", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if User.currentUser() == nil {
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

    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = kCLDistanceFilterNone

            switch CLLocationManager.authorizationStatus() {
            case .AuthorizedAlways:
                mapView.showsUserLocation = true
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

    func getNearbyFriends() {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil, block: {
            (result, error) in
            self.nearbyFriends = result as [User]
            self.refreshControl?.endRefreshing()
        })
    }

    func centerAndZoomMapOnCoordinate(coordinate: CLLocationCoordinate2D) {
        let degree = (nearbyDistance + 50) / 111000.0
        let span = MKCoordinateSpan(latitudeDelta: degree, longitudeDelta: degree)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController!, didLogInUser user: User!) {
        self.dismissViewControllerAnimated(true, completion: nil)
        FBRequestConnection.startForMeWithCompletionHandler({ connection, result, error in
            if error == nil {
                let userData = result as [NSObject: AnyObject]
                let name = userData["name"] as String
                let facebookID = userData["id"] as String
                user.name = name
                user.fbId = facebookID
                user.saveInBackground()
            }
            // TODO: Retry getting user's data at later point if request fails
        })
        startUpdatingLocation()
        getNearbyFriends()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "getNearbyFriends", name: "UIApplicationDidBecomeActiveNotification", object: nil)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let recent = abs(location.timestamp.timeIntervalSinceNow) < 15.0
        let locationChanged = userLocation.distanceFromLocation(location) > 5
        if recent && locationChanged {
            self.userLocation = location
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nearbyFriends.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "NearbyFriendCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier) as UITableViewCell
        let friend = self.nearbyFriends[indexPath.row]
        cell.textLabel!.text = friend.name
        self.geocoder.reverseGeocodeLocation(friend.loc, completionHandler: { placemarks, error in
            if error == nil {
                let placemark = placemarks[0] as CLPlacemark
                cell.detailTextLabel!.text = placemark.name
            }
        })
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let friend = self.nearbyFriends[indexPath.row]
        self.mapView.selectAnnotation(friend.annotation, animated: true)
        self.mapView.showAnnotations([friend.annotation], animated: true)
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
}

