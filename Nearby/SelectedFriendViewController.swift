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
    var bestFriendRequestStatus: String? {
        didSet {
            if let status = bestFriendRequestStatus {
                switch status {
                case "accepted":
                    bestFriendButton.setTitle("Remove from Best Friends", forState: UIControlState.Normal)
                case "sent":
                    bestFriendButton.setTitle("Cancel Best Friend Request", forState: UIControlState.Normal)
                case "received":
                    bestFriendButton.setTitle("Accept Best Friend Request", forState: UIControlState.Normal)
                default: break
                }
            } else {
                bestFriendButton.setTitle("Add to Best Friends", forState: UIControlState.Normal)
            }
        }
    }
    var friendBlocked = false {
        didSet {
            if friendBlocked {
                blockButton.setTitle("Unblock", forState: UIControlState.Normal)
                bestFriendButton.hidden = true
            } else {
                blockButton.setTitle("Block", forState: UIControlState.Normal)
                bestFriendButton.hidden = false

            }
        }
    }

    override func viewDidLoad() {
        nameLabel.text = friend.name
        updateBlocked()
        updateStatus()
    }

    func updateBlocked() {
        if let user = User.currentUser() {
            self.friendBlocked = user.hasBlocked(friend)
        }
    }

    func updateStatus() {
        if let user = User.currentUser() {
            self.bestFriendRequestStatus = nil
            user.fetchInBackgroundWithBlock { object, error in
                if let error = error {
                    let message = error.userInfo!["error"] as! String
                    PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
                } else {
                    if user.hasBestFriend(self.friend) {
                        self.bestFriendRequestStatus = "accepted"
                    }
                }
            }

            let sentRequest = PFQuery(className: "BestFriendRequest")
            sentRequest.whereKey("fromUser", equalTo: user)
            sentRequest.whereKey("toUser", equalTo: friend)
            let receivedRequest = PFQuery(className: "BestFriendRequest")
            sentRequest.whereKey("fromUser", equalTo: friend)
            sentRequest.whereKey("toUser", equalTo: user)
            let query = PFQuery.orQueryWithSubqueries([sentRequest, receivedRequest])
            query.findObjectsInBackgroundWithBlock { objects, error in
                if let error = error {
                    let message = error.userInfo!["error"] as! String
                    PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
                } else {
                    if let bestFriendRequests = objects {
                        if bestFriendRequests.count > 0 {
                            let request = bestFriendRequests[0] as! PFObject
                            let userSentRequest = request["fromUser"]?.objectId == user.objectId
                            if userSentRequest {
                                self.bestFriendRequestStatus = "sent"
                            } else {
                                self.bestFriendRequestStatus = "received"
                            }
                        }
                    }
                }
            }
        }
    }

    @IBAction func toggleBestFriend() {
        if let status = bestFriendRequestStatus {
            switch status {
            case "accepted":
                removeBestFriend()
                bestFriendRequestStatus = nil
            case "sent":
                cancelBestFriendRequest()
                bestFriendRequestStatus = nil
            case "received":
                addBestFriend()
                bestFriendRequestStatus = "accepted"
            default: break
            }
        } else {
            addBestFriend()
            bestFriendRequestStatus = "sent"
        }
    }

    func addBestFriend() {
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("addBestFriend", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
                self.updateStatus()
            } else {
                // Update best friends
                if let user = User.currentUser() {
                    user.fetchInBackground()
                }
            }
        }
    }

    func removeBestFriend() {
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("removeBestFriend", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
                self.updateStatus()
            } else {
                // Update best friends
                if let user = User.currentUser() {
                    user.fetchInBackground()
                }
            }
        }
    }

    func cancelBestFriendRequest() {
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("removeBestFriendRequest", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
                self.updateStatus()
            }
        }
    }

    @IBAction func toggleBlock() {
        if friendBlocked {
            unblockFriend()
            friendBlocked = false
        } else {
            blockFriend()
            friendBlocked = true
        }
    }

    func blockFriend() {
        if let user = User.currentUser() {
            user.addUniqueObject(friend, forKey: "blockedUsers")
            user.saveInBackground()
        }
    }

    func unblockFriend() {
        if let user = User.currentUser() {
            user.removeObject(friend, forKey: "blockedUsers")
            user.saveInBackground()
        }
    }

}
