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

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!

    let locationRelay = LocationRelay()
    let geocoder = CLGeocoder()
    let nearbyDistance = 150.0
    var refreshControl: UIRefreshControl!

    var refreshNearbyFriendsOnActive: Bool = false {
        willSet {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
            if newValue == true {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "getNearbyFriends", name: "UIApplicationDidBecomeActiveNotification", object: nil)
            }
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
                mapView.addAnnotation(friend.annotation)
            }
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locationRelay.addObserver(self, forKeyPath: "userLocation", options: (NSKeyValueObservingOptions.Old | NSKeyValueObservingOptions.New), context: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOn, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "disableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOff, object: nil)

        if let user = User.currentUser() {
            if !user.hideLocation {
                locationRelay.startUpdatingLocation()
                refreshNearbyFriendsOnActive = true
            }
        }

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "getNearbyFriends", forControlEvents: UIControlEvents.ValueChanged)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if User.currentUser() == nil {
            let logInController = PFLogInViewController()
            logInController.delegate = self
            logInController.facebookPermissions = ["user_friends"]
            logInController.fields = (PFLogInFields.Facebook)
            // TODO: Handle user denying "user_friends" permission
            // TODO: Handle user cancelling log in

            presentViewController(logInController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        func centerAndZoomMapOnCoordinate(coordinate: CLLocationCoordinate2D) {
            let degree = (nearbyDistance + 50) / 111000.0
            let span = MKCoordinateSpan(latitudeDelta: degree, longitudeDelta: degree)
            let region = MKCoordinateRegion(center: coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }

        if keyPath == "userLocation" {
            let oldLocation = change[NSKeyValueChangeOldKey] as? CLLocation
            let newLocation = change[NSKeyValueChangeNewKey] as? CLLocation
            if oldLocation == nil && newLocation != nil {
                mapView.showsUserLocation = true
                centerAndZoomMapOnCoordinate(newLocation!.coordinate)
                getNearbyFriends()
            }
        }
    }

    func enableStealthMode() {
        locationRelay.stopUpdatingLocation()
        mapView.showsUserLocation = false
        refreshNearbyFriendsOnActive = false
        mapView.removeAnnotations(mapView.annotations)
    }

    func disableStealthMode() {
        locationRelay.startUpdatingLocation()
        mapView.showsUserLocation = true
        refreshNearbyFriendsOnActive = true
        getNearbyFriends()
    }

    func getNearbyFriends() {
        PFCloud.callFunctionInBackground("nearbyFriends", withParameters: nil, block: {
            (result, error) in
            if error == nil {
                self.nearbyFriends = result as [User]
                self.refreshControl?.endRefreshing()
            } else {
                let message = error.userInfo!["error"] as String
                println(message)
            }
        })
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController!, didLogInUser user: User!) {
        dismissViewControllerAnimated(true, completion: nil)
        FBRequestConnection.startForMeWithCompletionHandler({ connection, result, error in
            if error == nil {
                let userData = result as [NSObject: AnyObject]
                user.name = userData["name"] as String
                user.firstName = userData["first_name"] as String
                user.lastName = userData["last_name"] as String
                user.fbId = userData["id"] as String
                user.saveInBackground()
            }
            // TODO: Retry getting user's data at later point if request fails
        })
        locationRelay.startUpdatingLocation()
        refreshNearbyFriendsOnActive = true
    }

    // MARK: - UITableViewDataSource

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        func showMessageInTable(message: String) {
            let label = UILabel(frame: CGRectMake(0, 0, tableView.bounds.size.width, tableView.bounds.size.height))
            label.text = message
            label.numberOfLines = 0
            label.textAlignment = NSTextAlignment.Center
            label.sizeToFit()

            tableView.backgroundView = label
            tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        }

        func hideMessageInTable() {
            tableView.backgroundView = nil
            tableView.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
        }

        let user = User.currentUser()
        if user != nil && user.hideLocation {
            showMessageInTable("Nearby friends are hidden in Stealth Mode.")
            if refreshControl.superview != nil {
                refreshControl.removeFromSuperview()
            }
            return 0;
        } else if nearbyFriends.count == 0 {
            showMessageInTable("No friends are nearby.")
            if refreshControl.superview == nil {
                tableView.addSubview(refreshControl)
            }
            return 0;
        } else {
            hideMessageInTable()
            if refreshControl.superview == nil {
                tableView.addSubview(refreshControl)
            }
            return 1;
        }
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nearbyFriends.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "NearbyFriendCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier) as UITableViewCell
        let friend = nearbyFriends[indexPath.row]
        cell.textLabel!.text = friend.name
        geocoder.reverseGeocodeLocation(friend.loc, completionHandler: { placemarks, error in
            if error == nil {
                let placemark = placemarks[0] as CLPlacemark
                cell.detailTextLabel!.text = placemark.name
            }
        })
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let friend = nearbyFriends[indexPath.row]
        mapView.showAnnotations([friend.annotation], animated: true)
        // Delay to make sure all of callout fits on screen after centering
        delay(0.2) {
            self.mapView.selectAnnotation(friend.annotation, animated: true)
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
}

