//
//  RequestsViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/18/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Parse

class RequestsViewController: PFQueryTableViewController {
    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
        paginationEnabled = false
    }

    @IBAction func confirmRequest(sender: UIButton) {
        let buttonPosition = sender.convertPoint(CGPointZero, toView: tableView)
        let indexPath = tableView.indexPathForRowAtPoint(buttonPosition)!
        let request = objectAtIndexPath(indexPath)
        let friend = request!["fromUser"] as! User
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("addBestFriend", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                self.loadObjects()
                if let user = User.currentUser() {
                    // Update bestFriends array
                    user.fetchInBackground()
                    // TODO: Update nearby friends
                }
            }
        }
    }

    @IBAction func deleteRequest(sender: UIButton) {
        let buttonPosition = sender.convertPoint(CGPointZero, toView: tableView)
        let indexPath = tableView.indexPathForRowAtPoint(buttonPosition)
        let request = objectAtIndexPath(indexPath)
        let friend = request!["fromUser"] as! User
        let params = ["recipientId": friend.objectId!]
        PFCloud.callFunctionInBackground("removeBestFriendRequest", withParameters: params) { result, error in
            if let error = error {
                let message = error.userInfo!["error"] as! String
                PFAnalytics.trackEvent("error", dimensions:["code": "\(error.code)", "message": message])
            } else {
                self.loadObjects()
            }
        }
    }

    // MARK: - PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        // FIXME: currentUser may be nil
        let user = User.currentUser()!
        let query = PFQuery(className: "BestFriendRequest")
        query.whereKey("toUser", equalTo: user)
        query.includeKey("fromUser")
        if user.blockedUsers.count > 0 {
            query.whereKey("fromUser", notContainedIn: user.blockedUsers)
        }
        return query
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let identifier = "RequestCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier) as! RequestTableViewCell
        let friend = object!["fromUser"] as! User
        cell.nameLabel.text = friend.name
        return cell
    }
}
