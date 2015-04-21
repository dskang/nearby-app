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

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!

    let locationRelay = LocationRelay()
    let nearbyFriendsManager = NearbyFriendsManager()
    let nearbyDistance = 150.0
    var refreshControl: UIRefreshControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locationRelay.addObserver(self, forKeyPath: "userLocation", options: (NSKeyValueObservingOptions.Old | NSKeyValueObservingOptions.New), context: nil)
        nearbyFriendsManager.addObserver(self, forKeyPath: "nearbyFriends", options: NSKeyValueObservingOptions.allZeros, context: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOn, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "disableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOff, object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "focusOnWaveSender:", name: GlobalConstants.NotificationKey.openedOnWave, object: nil)

        if let user = User.currentUser() {
            if !user.hideLocation {
                locationRelay.startUpdates()
            }
        }

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self.nearbyFriendsManager, action: "update:", forControlEvents: UIControlEvents.ValueChanged)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let user = User.currentUser() {
            if !user.hideLocation {
                // FIXME: Replace with a remote notification when best friend changes
                user.fetchInBackground()
            }
        }

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

    func centerAndZoomMapOnCoordinate(coordinate: CLLocationCoordinate2D) {
        let degree = (nearbyDistance + 50) / 111000.0
        let span = MKCoordinateSpan(latitudeDelta: degree, longitudeDelta: degree)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }

    @IBAction func centerUserOnMap() {
        if let location = locationRelay.userLocation {
            centerAndZoomMapOnCoordinate(location.coordinate)
        }
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == "userLocation" {
            let oldLocation = change[NSKeyValueChangeOldKey] as? CLLocation
            let newLocation = change[NSKeyValueChangeNewKey] as? CLLocation
            if oldLocation == nil && newLocation != nil {
                mapView.showsUserLocation = true
                centerAndZoomMapOnCoordinate(newLocation!.coordinate)
                nearbyFriendsManager.startUpdates()
            }
        } else if keyPath == "nearbyFriends" {
            refreshControl?.endRefreshing()

            // Prevent adding pins when user toggles Stealth Mode very quickly
            if let user = User.currentUser() {
                if user.hideLocation {
                    return
                }
            }

            // Remove annotations
            let pins = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(pins)

            // Add annotations
            if let visibleFriends = nearbyFriendsManager.visibleFriends {
                for friend in visibleFriends {
                    if !friend.hideLocation {
                        friend.annotation = FriendAnnotation(user: friend)
                        mapView.addAnnotation(friend.annotation!)
                    }
                }
                tableView.reloadData()
            }
        }
    }

    func enableStealthMode() {
        locationRelay.stopUpdates()
        mapView.showsUserLocation = false
        nearbyFriendsManager.stopUpdates()
        mapView.removeAnnotations(mapView.annotations)
        tableView.reloadData()
    }

    func disableStealthMode() {
        locationRelay.startUpdates()
        mapView.showsUserLocation = true
        tableView.reloadData()
    }

    func focusOnWaveSender(notification: NSNotification) {
        nearbyFriendsManager.update {
            let senderId = notification.userInfo!["senderId"] as! String
            var senderFound = false

            if let visibleFriends = self.nearbyFriendsManager.visibleFriends {
                for friend in visibleFriends {
                    if friend.objectId == senderId {
                        self.mapView.showAnnotations([friend.annotation!], animated: true)
                        delay(0.2) {
                            self.mapView.selectAnnotation(friend.annotation!, animated: true)
                        }
                        senderFound = true
                        break
                    }
                }
            }

            if !senderFound {
                let senderName = notification.userInfo!["senderName"] as! String
                let alertController = UIAlertController(
                    title: "\(senderName) is no longer nearby.",
                    message: nil,
                    preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))

                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        dismissViewControllerAnimated(true, completion: nil)
        let user = user as! User
        let request = FBSDKGraphRequest(graphPath: "me", parameters: nil)
        request.startWithCompletionHandler() { connection, result, error in
            if error == nil {
                let userData = result as! [NSObject: AnyObject]
                user.name = userData["name"] as! String
                user.firstName = userData["first_name"] as! String
                user.lastName = userData["last_name"] as! String
                user.fbId = userData["id"] as! String
                user.hideLocation = false
                user.saveInBackground()
            }
            // TODO: Retry getting user's data at later point if request fails
        }

        // Associate the device with the user
        let installation = PFInstallation.currentInstallation()
        installation["user"] = user
        installation.saveInBackground()

        // Refresh location if user logged out and is logging back in
        locationRelay.stopUpdates()

        nearbyFriendsManager.syncFriends {
            self.locationRelay.startUpdates()
        }
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
        if user != nil && user!.hideLocation {
            showMessageInTable("Nearby friends are hidden in Stealth Mode.")
            if refreshControl.superview != nil {
                refreshControl.removeFromSuperview()
            }
            return 0
        } else if nearbyFriendsManager.visibleFriends?.count == 0 {
            showMessageInTable("No friends are nearby.")
            if refreshControl.superview == nil {
                tableView.addSubview(refreshControl)
            }
            return 0
        } else {
            hideMessageInTable()
            if refreshControl.superview == nil {
                tableView.addSubview(refreshControl)
            }
            if nearbyFriendsManager.bestFriends?.count > 0 {
                return 2
            } else {
                return 1
            }
        }
    }

    func listForSection(section: Int) -> [User] {
        if section == 0 {
            return nearbyFriendsManager.nearbyFriends!
        } else {
            return nearbyFriendsManager.bestFriends!
        }
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if nearbyFriendsManager.nearbyFriends == nil {
            return 0
        }
        return listForSection(section).count
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if nearbyFriendsManager.nearbyFriends == nil {
            return nil
        }

        if section == 0 {
            if nearbyFriendsManager.nearbyFriends?.count == 0 {
                return "No Nearby Friends"
            } else {
                return "Nearby Friends"
            }
        } else {
            return "Best Friends"
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "NearbyFriendCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier) as! UITableViewCell

        let friend = listForSection(indexPath.section)[indexPath.row]
        cell.textLabel?.text = friend.name
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let friend = listForSection(indexPath.section)[indexPath.row]
        if friend.hideLocation {
            let alertController = UIAlertController(
                title: "\(friend.firstName) is currently hidden.",
                message: nil,
                preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))

            self.presentViewController(alertController, animated: true, completion: nil)
        } else {
            mapView.showAnnotations([friend.annotation!], animated: true)
            // Delay to make sure all of callout fits on screen after centering
            delay(0.2) {
                self.mapView.selectAnnotation(friend.annotation!, animated: true)
            }
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }

    // MARK: - MKMapViewDelegate

    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if let annotation = annotation as? MKUserLocation {
            return nil
        } else if let annotation = annotation as? FriendAnnotation {
            let identifier = "PinAnnotationView"
            var view: MKPinAnnotationView! = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView
            if view == nil {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
            } else {
                view.annotation = annotation
            }

            if let user = User.currentUser() {
                if user.hasBestFriend(annotation.user) {
                    view.pinColor = MKPinAnnotationColor.Purple
                } else {
                    view.pinColor = MKPinAnnotationColor.Red
                }
            }

            let rightButton = UIButton.buttonWithType(UIButtonType.ContactAdd) as! UIButton
            rightButton.addTarget(nil, action: nil, forControlEvents: UIControlEvents.TouchUpInside)
            view.rightCalloutAccessoryView = rightButton

            return view
        } else {
            return nil
        }
    }

    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        let annotation = view.annotation as! FriendAnnotation
        let friend = annotation.user
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("wave", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
                let alertController = UIAlertController(
                    title: message,
                    message: nil,
                    preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)

                self.nearbyFriendsManager.update()
            } else {
                let alertController = UIAlertController(
                    title: "Wave sent!",
                    message: nil,
                    preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
}
