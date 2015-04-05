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

    @IBAction func stealthModeToggled(sender: UISwitch) {
        let user = User.currentUser()
        user.hideLocation = sender.on
        user.saveInBackground()

        let key = sender.on ? GlobalConstants.NotificationKey.stealthModeOn : GlobalConstants.NotificationKey.stealthModeOff
        NSNotificationCenter.defaultCenter().postNotificationName(key, object: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        stealthModeSwitch.on = User.currentUser().hideLocation
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
