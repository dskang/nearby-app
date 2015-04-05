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

    @IBAction func stealthModeToggled(sender: UISwitch) {
        if sender.on {
            NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.stealthModeOn, object: self)
        } else {
            NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.stealthModeOff, object: self)
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        if cell == logOutCell {
            User.logOut()
            let nearbyVC = tabBarController?.viewControllers![0] as NearbyViewController
            nearbyVC.refreshNearbyFriendsOnActive = false
            tabBarController?.selectedViewController = nearbyVC
        }
    }
}
