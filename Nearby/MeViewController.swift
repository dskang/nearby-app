//
//  MeViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/5/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class MeViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet weak var logOutCell: UITableViewCell!
    @IBOutlet weak var stealthModeSwitch: UISwitch!
    @IBOutlet weak var testUserCell: UITableViewCell!
    @IBOutlet weak var defaultMessageCell: UITableViewCell!
    @IBOutlet weak var defaultMessageTextField: NoCursorTextField!

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
            if let defaultMessage = user.defaultMessage {
                defaultMessageTextField.text = defaultMessage
            }
        }
    }

    override func viewDidAppear(animated: Bool) {
        // Make "Switch to Test User" appear and disappear appropriately
        tableView.reloadData()
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let user = User.currentUser() {
            if user.name == "Dan Kang" {
                return super.numberOfSectionsInTableView(tableView)
            }
        }
        return super.numberOfSectionsInTableView(tableView) - 1
    }

    func updateDefaultMessage(message: String) {
        if let user = User.currentUser() {
            user.defaultMessage = message
            user.saveInBackground()
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        if cell == logOutCell {
            User.logOut()
            let nearbyVC = tabBarController?.viewControllers![0] as! NearbyViewController
            nearbyVC.locationRelay.stopUpdates()
            nearbyVC.nearbyFriendsManager.stopUpdates()
            tabBarController?.selectedViewController = nearbyVC
        } else if cell == defaultMessageCell {
            defaultMessageTextField.becomeFirstResponder()
        } else if cell == testUserCell {
            PFUser.logInWithUsernameInBackground("fzbOL1KqIvbZE2lG2UMdo56ER", password: "test") { user, error in
                if let user = user as? User {
                    // Associate the device with the user
                    let installation = PFInstallation.currentInstallation()
                    installation["user"] = user
                    installation.saveInBackground()

                    let nearbyVC = self.tabBarController?.viewControllers![0] as! NearbyViewController
                    self.tabBarController?.selectedViewController = nearbyVC
                    nearbyVC.locationRelay.stopUpdates()
                    nearbyVC.locationRelay.startUpdates()
                }
            }
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let isEmoji = textField.textInputMode == nil
        let notBackspace = count(string) > 0
        if isEmoji && notBackspace {
            textField.text = string
            textField.resignFirstResponder()
            updateDefaultMessage(textField.text)
        }
        return false
    }
}

class NoCursorTextField: UITextField {
    override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
        // Disable paste
        // NB: Making caret invisible already makes it impossible to bring up paste option so this is being super safe
        if action == "paste:" {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func caretRectForPosition(position: UITextPosition!) -> CGRect {
        return CGRectZero
    }
}
