//
//  MeViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/5/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class MeViewController: UITableViewController {

    @IBOutlet weak var logOutCell: UITableViewCell!

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let cell = self.tableView.cellForRowAtIndexPath(indexPath)
        if cell == logOutCell {
            User.logOut()
            let nearbyVC = self.tabBarController?.viewControllers![0] as NearbyViewController
            NSNotificationCenter.defaultCenter().removeObserver(nearbyVC, name: "UIApplicationDidBecomeActiveNotification", object: nil)
            self.tabBarController?.selectedViewController = nearbyVC
        }
    }
}
