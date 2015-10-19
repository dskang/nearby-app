//
//  MeViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/5/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation

class MeViewController: UITableViewController {

    @IBOutlet weak var logOutCell: UITableViewCell!
    @IBOutlet weak var stealthModeSwitch: UISwitch!
    @IBOutlet weak var testUserCell: UITableViewCell!

    @IBAction func stealthModeToggled(sender: UISwitch) {
        if let user = User.currentUser() {
            user.hideLocation = sender.on
            user.saveInBackground()

            let key = sender.on ? GlobalConstants.NotificationKey.stealthModeOn : GlobalConstants.NotificationKey.stealthModeOff
            NSNotificationCenter.defaultCenter().postNotificationName(key, object: self)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = User.currentUser() {
            stealthModeSwitch.on = user.hideLocation
        }
    }

    override func viewDidAppear(animated: Bool) {
        // To make "Switch to Test User" appear and disappear
        tableView.reloadData()
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let user = User.currentUser() {
            if user.objectId == "6AsIH1uuc1" {
                return super.numberOfSectionsInTableView(tableView)
            }
        }
        return super.numberOfSectionsInTableView(tableView) - 1
    }

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        if cell == logOutCell {
            User.logOut()

            LocationRelay.sharedInstance.userLocation = nil
            LocationRelay.sharedInstance.stopUpdates()

            let nearbyVC = tabBarController?.viewControllers![0] as! NearbyViewController
            nearbyVC.mapView.showsUserLocation = false
            nearbyVC.nearbyFriendsManager.stopUpdates()
            tabBarController?.selectedViewController = nearbyVC
        } else if cell == testUserCell {
            PFUser.logInWithUsernameInBackground("fzbOL1KqIvbZE2lG2UMdo56ER", password: "test") { user, error in
                if let user = user as? User {
                    // Associate the device with the user
                    let installation = PFInstallation.currentInstallation()
                    installation["user"] = user
                    installation.saveInBackground()

                    let locationRelay = LocationRelay.sharedInstance
                    locationRelay.userLocation = nil
                    locationRelay.stopUpdates()
                    locationRelay.startUpdates()

                    let nearbyVC = self.tabBarController?.viewControllers![0] as! NearbyViewController
                    self.tabBarController?.selectedViewController = nearbyVC
                }
            }
        }
    }
}
