//
//  FriendsViewController.swift
//  Nearby
//
//  Created by Dan Kang on 4/12/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import Foundation

class FriendsViewController: PFQueryTableViewController {
    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        paginationEnabled = false
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let identifier = segue.identifier {
            switch identifier {
            case "ShowFriend":
                let cell = sender as! UITableViewCell
                if let indexPath = tableView.indexPathForCell(cell) {
                    let vc = segue.destinationViewController as! SelectedFriendViewController
                    vc.friend = objectAtIndexPath(indexPath) as? User
                }
            default: break
            }
        }
    }

    // MARK: - PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        // FIXME: currentUser may be nil
        let user = User.currentUser()!
        let relation = user.relationForKey("friends")
        let query = relation.query()!
        query.orderByAscending("name")
        return query
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let user = object as! User
        let identifier = "FriendCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier) as! PFTableViewCell
        cell.textLabel?.text = user.name
        return cell
    }
}
