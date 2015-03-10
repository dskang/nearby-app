//
//  ViewController.swift
//  Nearby
//
//  Created by Dan Kang on 3/10/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import UIKit
import Parse

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        var user = PFUser()
        user.username = "DK"
        user.password = "password"
        user.email = "dan@dskang.com"

        user.signUpInBackgroundWithBlock() { (succeeded, error) in
            if error == nil {
            } else {
                let errorString = error.userInfo!["error"] as String
                println(errorString)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

