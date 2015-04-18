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

    override func viewDidLoad() {
        nameLabel.text = friend.name
        updateStatus()
    }

    func updateStatus() {
        if let user = User.currentUser() {
            self.bestFriendRequestStatus = nil
            user.fetchInBackgroundWithBlock { object, error in
                if let error = error {
                    let message = error.userInfo!["error"] as! String
                    println(message)
                    // TODO: Send to Parse
                } else {
                    let result = object as! User
                    let results = result.bestFriends.filter { $0.objectId == self.friend.objectId }
                    if results.count > 0 {
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
                    println(message)
                    // TODO: Send to Parse
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
                println(message)
                // TODO: Send to Parse
                self.updateStatus()
            }
        }
    }

    func removeBestFriend() {
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
