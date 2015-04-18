//
//  SelectedFriendViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/17/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class SelectedFriendViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var bestFriendButton: UIButton!
    @IBOutlet weak var blockButton: UIButton!

    var friend: User!

    override func viewDidLoad() {
        nameLabel.text = friend.name
    }

    func updateUI() {
        if let user = User.currentUser() {
            if user.isBestFriend(friend) {
                bestFriendButton.setTitle("Remove from Best Friends", forState: UIControlState.Normal)
            } else if user.requestedBestFriend(friend) {
                bestFriendButton.setTitle("Cancel Best Friend Request", forState: UIControlState.Normal)
            } else {
                bestFriendButton.setTitle("Add to Best Friends", forState: UIControlState.Normal)
            }
        }
    }

    @IBAction func toggleBestFriend() {
        if let user = User.currentUser() {
            if user.isBestFriend(friend) {
                // remove from best friends
            } else if user.requestedBestFriend(friend) {
                // cancel best friend request
            } else {
                let params = ["recipientId": friend.objectId!]
                PFCloud.callFunctionInBackground("requestBestFriend", withParameters: params) { result, error in
                    if let error = error {
                        let message = error.userInfo!["error"] as! String
                        println(message)
                        // TODO: Send to Parse
                    } else {
                        user.fetchInBackgroundWithBlock { result, error in
                            self.updateUI()
                        }
                    }
                }
            }
        }
    }
}
