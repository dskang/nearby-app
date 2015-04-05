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

            if nearbyFriends.count == 0 {
                let label = UILabel(frame: CGRectMake(0, 0, tableView.bounds.size.width, tableView.bounds.size.height))
                label.text = "No friends are nearby."
                label.textAlignment = NSTextAlignment.Center
                label.sizeToFit()

                tableView.backgroundView = label
                tableView.separatorStyle = UITableViewCellSeparatorStyle.None
            } else {
                tableView.backgroundView = nil
                tableView.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
            }
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locationRelay.addObserver(self, forKeyPath: "userLocation", options: (NSKeyValueObservingOptions.Old | NSKeyValueObservingOptions.New), context: nil)
        NSNotificationCenter.defaultCenter().addObserverForName(GlobalConstants.NotificationKey.stealthModeOn, object: nil, queue: nil, usingBlock: { notification in
            self.mapView.showsUserLocation = false
        })
        NSNotificationCenter.defaultCenter().addObserverForName(GlobalConstants.NotificationKey.stealthModeOff, object: nil, queue: nil, usingBlock: { notification in
            self.mapView.showsUserLocation = true
        })

        if User.currentUser() != nil {
            locationRelay.startUpdatingLocation()
            mapView.showsUserLocation = true
            refreshNearbyFriendsOnActive = true
        }

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "getNearbyFriends", forControlEvents: UIControlEvents.ValueChanged)
        tableView.addSubview(refreshControl)
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
            presentViewController(logInController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == "userLocation" {
            let oldLocation = change[NSKeyValueChangeOldKey] as CLLocation
            let newLocation = change[NSKeyValueChangeNewKey] as CLLocation
            if oldLocation.coordinate.latitude == 0 && oldLocation.coordinate.longitude == 0 {
                mapView.showsUserLocation = true
                centerAndZoomMapOnCoordinate(newLocation.coordinate)
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
        dismissViewControllerAnimated(true, completion: nil)
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
        locationRelay.startUpdatingLocation()
        getNearbyFriends()
        refreshNearbyFriendsOnActive = true
    }

    // MARK: - UITableViewDataSource

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
        mapView.selectAnnotation(friend.annotation, animated: true)
        mapView.showAnnotations([friend.annotation], animated: true)
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
}

