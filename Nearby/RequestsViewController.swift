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

    // MARK: - PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        // FIXME: currentUser may be nil
        let user = User.currentUser()!
        let query = PFQuery(className: "BestFriendRequest")
        query.whereKey("toUser", equalTo: user)
        query.whereKey("status", equalTo: "pending")
        query.includeKey("fromUser")
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
