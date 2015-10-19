//
//  ViewController.swift
//  Nearby
//
//  Created by Dan Kang on 3/10/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class NearbyViewController: UIViewController, PFLogInViewControllerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emojiButton: UIButton!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    let locationRelay = LocationRelay.sharedInstance
    let nearbyFriendsManager = NearbyFriendsManager.sharedInstance
    let nearbyDistance = 400.0
    var refreshControl: UIRefreshControl!
    let emojiTextField = UITextField()
    var tap: UIGestureRecognizer!
    var defaultWaveEmoji = "👋"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOn, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "disableStealthMode", name: GlobalConstants.NotificationKey.stealthModeOff, object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "focusOnSender:", name: GlobalConstants.NotificationKey.focusOnSender, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateVisibleFriends", name: GlobalConstants.NotificationKey.updatedVisibleFriends, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInitialUserLocationWhenActive", name: GlobalConstants.NotificationKey.initialUserLocationUpdate, object: nil)

        if let user = User.currentUser() {
            if user.fbId == nil {
                getFacebookData()
            }

            if !user.hideLocation {
                locationRelay.startUpdates()
            }
        }

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self.nearbyFriendsManager, action: "updateWithSender:", forControlEvents: UIControlEvents.ValueChanged)

        emojiButton.hidden = true
        emojiTextField.delegate = self
        emojiTextField.returnKeyType = UIReturnKeyType.Done
        view.addSubview(emojiTextField)

        // Include skin tone if iOS version >= 8.3
        if NSProcessInfo().isOperatingSystemAtLeastVersion(NSOperatingSystemVersion(majorVersion: 8, minorVersion: 3, patchVersion: 0)) {
            defaultWaveEmoji += "\u{1F3FD}"
        }
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
            let logInController = NearbyLogInViewController()
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

    func updateVisibleFriends() {
        refreshControl?.endRefreshing()

        // Prevent adding pins when user toggles Stealth Mode very quickly
        if let user = User.currentUser() {
            if user.hideLocation {
                return
            }
        }

        if let visibleFriends = nearbyFriendsManager.visibleFriends {
            // Remove outdated annotations
            for annotation in mapView.annotations {
                if let annotation = annotation as? FriendAnnotation {
                    var found = false
                    for friend in visibleFriends {
                        if annotation.userId == friend.objectId && !friend.hideLocation {
                            found = true
                            break
                        }
                    }
                    if !found {
                        mapView.removeAnnotation(annotation)
                    }
                }
            }

            // Add or update annotations
            for friend in visibleFriends {
                var friendAnnotation: FriendAnnotation? = nil
                for annotation in mapView.annotations {
                    if let annotation = annotation as? FriendAnnotation {
                        if annotation.userId == friend.objectId {
                            friendAnnotation = annotation
                            break
                        }
                    }
                }
                if let annotation = friendAnnotation {
                    annotation.setValues(userName: friend.name, userLocation: friend.loc)
                } else {
                    if !friend.hideLocation {
                        let annotation = FriendAnnotation(userId: friend.objectId!)
                        annotation.setValues(userName: friend.name, userLocation: friend.loc)
                        mapView.addAnnotation(annotation)
                    }
                }
            }

            tableView.reloadData()
        }
    }

    func handleInitialUserLocationWhenActive() {
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active {
            handleInitialUserLocation()
        } else {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInitialUserLocation", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        }
    }

    func handleInitialUserLocation() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidBecomeActiveNotification", object: nil)
        if let location = locationRelay.userLocation {
            mapView.showsUserLocation = true
            centerAndZoomMapOnCoordinate(location.coordinate)
            nearbyFriendsManager.startUpdates()
        }
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

    func enableStealthMode() {
        locationRelay.stopUpdates()
        locationRelay.userLocation = nil
        mapView.showsUserLocation = false
        nearbyFriendsManager.stopUpdates()
        mapView.removeAnnotations(mapView.annotations)
        tableView.reloadData()
    }

    func disableStealthMode() {
        locationRelay.startUpdates()
        tableView.reloadData()
    }

    func focusOnSender(notification: NSNotification) {
        nearbyFriendsManager.update {
            let senderId = notification.userInfo!["senderId"] as! String
            var senderFound = false

            for annotation in self.mapView.annotations {
                if let annotation = annotation as? FriendAnnotation {
                    if annotation.userId == senderId {
                        self.mapView.showAnnotations([annotation], animated: true)
                        delay(0.2) {
                            self.mapView.selectAnnotation(annotation, animated: true)
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

    @IBAction func changeEmoji() {
        if !emojiTextField.isFirstResponder() {
            emojiTextField.becomeFirstResponder()
            tap = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
            view.addGestureRecognizer(tap)
        }
    }

    func dismissKeyboard() {
        emojiTextField.resignFirstResponder()
        view.removeGestureRecognizer(tap)
    }

    // MARK: - PFLogInViewControllerDelegate

    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        dismissViewControllerAnimated(true, completion: nil)
        let user = user as! User
        getFacebookData()

        // Associate the device with the user
        let installation = PFInstallation.currentInstallation()
        installation["user"] = user
        installation.saveInBackground()

        nearbyFriendsManager.syncFriends {
            self.locationRelay.startUpdates()
        }
    }

    func getFacebookData() {
        if let user = User.currentUser() {
            let request = FBSDKGraphRequest(graphPath: "me?fields=id,name,first_name,last_name", parameters: nil)
            request.startWithCompletionHandler() { connection, result, error in
                if let error = error {
                    let errorCode = error.userInfo[FBSDKGraphRequestErrorGraphErrorCode] as! Int
                    let message = error.userInfo[FBSDKErrorDeveloperMessageKey] as! String
                    PFAnalytics.trackEvent("error", dimensions:["code": "\(errorCode)", "message": message])
                } else {
                    let userData = result as! [NSObject: AnyObject]
                    user.name = userData["name"] as! String
                    user.firstName = userData["first_name"] as! String
                    user.lastName = userData["last_name"] as! String
                    user.fbId = userData["id"] as! String
                    user.hideLocation = false
                    user.saveInBackground()
                }
            }
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
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier)!

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
            for annotation in mapView.annotations {
                if let annotation = annotation as? FriendAnnotation {
                    if annotation.userId == friend.objectId {
                        mapView.showAnnotations([annotation], animated: true)
                        // Delay to make sure all of callout fits on screen after centering
                        delay(0.2) {
                            self.mapView.selectAnnotation(annotation, animated: true)
                        }
                    }
                }
            }
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }

    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel!.textColor = UIColor.whiteColor()
        header.backgroundView?.backgroundColor = GlobalConstants.Colors.nearbyBlue
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.0
    }

    // MARK: - MKMapViewDelegate

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? FriendAnnotation {
            let identifier = "PinAnnotationView"
            var view: MKPinAnnotationView! = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView
            if view == nil {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
            } else {
                view.annotation = annotation
            }

            if let user = User.currentUser(), visibleFriends = nearbyFriendsManager.visibleFriends {
                for friend in visibleFriends {
                    if friend.objectId == annotation.userId {
                        if user.hasBestFriend(friend) {
                            view.pinColor = MKPinAnnotationColor.Purple
                        } else {
                            view.pinColor = MKPinAnnotationColor.Red
                        }
                        break
                    }
                }
            }

            let waveButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            waveButton.setTitle(defaultWaveEmoji, forState: UIControlState.Normal)
            waveButton.setTitleColor(UIColor.darkTextColor(), forState: UIControlState.Normal)
            waveButton.titleLabel?.font = UIFont.systemFontOfSize(30.0)
            view.rightCalloutAccessoryView = waveButton

            return view
        } else {
            return nil
        }
    }

    func sendWave(recipientId recipientId: String, message: String) {
        activityIndicatorView.startAnimating()

        let dimensions = ["message": message]
        PFAnalytics.trackEvent("wave", dimensions: dimensions)

        let params = ["recipientId": recipientId, "message": message]
        PFCloud.callFunctionInBackground("wave", withParameters: params) { result, error in
            self.activityIndicatorView.stopAnimating()
            if let error = error {
                let message = error.userInfo["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
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

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let annotation = view.annotation as! FriendAnnotation
        let waveButton = control as! UIButton
        let message = waveButton.titleLabel!.text!
        sendWave(recipientId: annotation.userId, message: message)
    }

    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        if view.annotation is FriendAnnotation {
            emojiButton.hidden = false
        }
    }

    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        if view.annotation is FriendAnnotation {
            emojiButton.hidden = true
            // Delay until callout is closed
            delay(0.5) {
                let waveButton = view.rightCalloutAccessoryView as! UIButton
                waveButton.setTitle(self.defaultWaveEmoji, forState: UIControlState.Normal)
            }
        }
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        dismissKeyboard()
        return false
    }

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let isEmoji = textField.textInputMode == nil
        let notBackspace = string.characters.count > 0
        if isEmoji && notBackspace {
            let selectedAnnotation = mapView.selectedAnnotations[0] as! FriendAnnotation
            let view = mapView.viewForAnnotation(selectedAnnotation)
            let waveButton = view!.rightCalloutAccessoryView as! UIButton
            waveButton.setTitle(string, forState: UIControlState.Normal)
            dismissKeyboard()
        }
        return false
    }
}

class NearbyLogInViewController : PFLogInViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let logoView = UIImageView(image: UIImage(named:"logo"))
        self.logInView!.logo = logoView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        logInView!.center = view.center
        var frame = logInView!.logo!.frame
        frame.size.width = 244.0
        frame.size.height = 91.0
        logInView!.logo!.frame = frame
    }
}
