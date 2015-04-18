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
    var bestFriendStatus: String? {
        didSet {
            if let status = bestFriendStatus {
                switch status {
                case "accepted":
                    bestFriendButton.setTitle("Remove from Best Friends", forState: UIControlState.Normal)
                case "pending":
                    bestFriendButton.setTitle("Cancel Best Friend Request", forState: UIControlState.Normal)
                default: break
                }
            } else {
                bestFriendButton.setTitle("Add to Best Friends", forState: UIControlState.Normal)
            }
        }
    }

    override func viewDidLoad() {
        nameLabel.text = friend.name
        updateStatus()
    }

    func updateStatus() {
        if let user = User.currentUser() {
            self.bestFriendStatus = nil
            user.fetchInBackgroundWithBlock { object, error in
                if let error = error {
                    let message = error.userInfo!["error"] as! String
                    println(message)
                    // TODO: Send to Parse
                } else {
                    let result = object as! User
                    let results = result.bestFriends.filter { $0.objectId == self.friend.objectId }
                    if results.count > 0 {
                        self.bestFriendStatus = "accepted"
                    }
                }
            }

            let query = PFQuery(className: "BestFriendRequest")
            query.whereKey("fromUser", equalTo: user)
            query.whereKey("toUser", equalTo: friend)
            query.findObjectsInBackgroundWithBlock { objects, error in
                if let error = error {
                    let message = error.userInfo!["error"] as! String
                    println(message)
                    // TODO: Send to Parse
                } else {
                    if objects?.count > 0 {
                        self.bestFriendStatus = "pending"
                    }
                }
            }
        }
    }

    @IBAction func toggleBestFriend() {
        if let status = bestFriendStatus {
            switch status {
            case "accepted":
                removeBestFriend()
            case "pending":
                cancelBestFriendRequest()
            default: break
            }
        } else {
            addBestFriend()
        }
    }

    func addBestFriend() {
        self.bestFriendStatus = "pending"
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("addBestFriend", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
                self.updateStatus()
            }
        }
    }

    func removeBestFriend() {
        self.bestFriendStatus = nil
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("removeBestFriend", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
                self.updateStatus()
            }
        }
    }

    func cancelBestFriendRequest() {
        self.bestFriendStatus = nil
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("removeBestFriendRequest", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                println(message)
                // TODO: Send to Parse
                self.updateStatus()
            }
        }
    }
}
