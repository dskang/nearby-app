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

    var stealthMode: Bool {
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey("stealthMode")
        }
        set {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: "stealthMode")
            var key: String
            if newValue {
                key = GlobalConstants.NotificationKey.stealthModeOn
            } else {
                key = GlobalConstants.NotificationKey.stealthModeOff
            }
            NSNotificationCenter.defaultCenter().postNotificationName(key, object: self)
        }
    }

    @IBAction func stealthModeToggled(sender: UISwitch) {
        stealthMode = sender.on
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        stealthModeSwitch.on = stealthMode
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
