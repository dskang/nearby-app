//
//  FriendsViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/12/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation
import Parse

class FriendsViewController: PFQueryTableViewController {
    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }

    // MARK: - PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        // FIXME: currentUser may be nil
        let user = User.currentUser()!
        let relation = user.relationForKey("friends")
        return relation.query()!
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let user = object as! User
        let identifier = "FriendCell"
        let reusableCell = tableView.dequeueReusableCellWithIdentifier(identifier) as? PFTableViewCell
        let cell = reusableCell ?? PFTableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: identifier)
        cell.textLabel!.text = user.name
        return cell
    }
}
