//
//  AppDelegate.swift
//  Nearby
//
//  Created by Dan Kang on 3/10/15.
//  Copyright (c) 2015 Dan Kang. All rights reserved.
//

import UIKit
import Parse
import ParseCrashReporting

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        ParseCrashReporting.enable()

        User.registerSubclass()
        Parse.setApplicationId("qezEspdd6WnEHMneZCr9gt9sUFzUQzAjhx03xfuQ", clientKey: "wZj94Bzosernq83Z5267e6k9lVcozPYWwCdNe3xI")
        PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showLocationDisabledAlert", name: GlobalConstants.NotificationKey.disabledLocation, object: nil)

        if application.applicationState != UIApplicationState.Background {
            // Track an app open here if we launch with a push, unless
            // "content_available" was used to trigger a background push (introduced in iOS 7).
            // In that case, we skip tracking here to avoid double counting the app-open.

            let pushPayload: AnyObject? = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey]
            if pushPayload == nil {
                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
            }
        }

        // Ask user to accept push notifications
        let userNotificationTypes = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
        let settings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()

        // Restart location services if app is relaunched due to significant location change
        if launchOptions?[UIApplicationLaunchOptionsLocationKey] != nil {
            LocationRelay.sharedInstance.startUpdates()
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        FBSDKAppEvents.activateApp()

        let status = CLLocationManager.authorizationStatus()
        if status == .Denied || status == .Restricted {
            self.showLocationDisabledAlert()
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func showLocationDisabledAlert() {
        let alertController = UIAlertController(
            title: "Background Location Access Disabled",
            message: "In order to be notified about nearby friends, please open this app's settings and set location access to 'Always'.",
            preferredStyle: .Alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)

        let openAction = UIAlertAction(title: "Open Settings", style: .Default) { (action) in
            if let url = NSURL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.sharedApplication().openURL(url)
            }
        }
        alertController.addAction(openAction)

        self.window?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: Facebook SDK Integration

    func application(application: UIApplication,
                     openURL url: NSURL,
                     sourceApplication: String?,
                     annotation: AnyObject?) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    // MARK: Push Notifications

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.saveInBackground()
    }

    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if error.code == 3010 {
            println("Push notifications are not supported in the iOS Simulator.")
        } else {
            println("application:didFailToRegisterForRemoteNotificationsWithError: %@", error)
        }
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        let isSilentNotification = userInfo["aps"]?["content-available"] != nil
        if isSilentNotification {
            if let type = userInfo["type"] as? String {
                switch type {
                case "updateLocation":
                    if let user = User.currentUser() {
                        if !user.hideLocation {
                            updateLocation(completionHandler)
                        }
                    }
                default:
                    completionHandler(UIBackgroundFetchResult.NoData)
                }
            }
        } else {
            PFPush.handlePush(userInfo)
            if application.applicationState == UIApplicationState.Inactive {
                if let type = userInfo["type"] as? String {
                    switch type {
                    case "wave":
                        handleWave(userInfo)
                    case "bestFriendRequest":
                        handleBestFriendRequest(userInfo)
                    default: break
                    }
                }
                PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
            }
            completionHandler(UIBackgroundFetchResult.NoData)
        }
    }

    // FIXME: Ugly solution to make sure block with completionHandler is only called once
    private var observer: NSObjectProtocol?
    func updateLocation(completionHandler: (UIBackgroundFetchResult) -> Void) {
        if let observer = observer {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        observer = NSNotificationCenter.defaultCenter().addObserverForName(GlobalConstants.NotificationKey.userLocationSaved, object: nil, queue: nil) { notification in
            completionHandler(UIBackgroundFetchResult.NewData)
        }
        LocationRelay.sharedInstance.stopUpdates()
        LocationRelay.sharedInstance.startUpdates()
    }

    func handleWave(userInfo: [NSObject: AnyObject]) {
        // Display NearbyViewController
        if let tabBarVC = self.window?.rootViewController as? UITabBarController {
            tabBarVC.selectedIndex = 0
        }
        NSNotificationCenter.defaultCenter().postNotificationName(GlobalConstants.NotificationKey.openedOnWave, object: self, userInfo: userInfo)
    }

    func handleBestFriendRequest(userInfo: [NSObject: AnyObject]) {
        // Display RequestsViewController
        if let tabBarVC = self.window?.rootViewController as? UITabBarController {
            tabBarVC.selectedIndex = 1
            if let navVC = tabBarVC.viewControllers?[1] as? UINavigationController {
                if let friendsVC = navVC.topViewController as? FriendsViewController {
                    friendsVC.performSegueWithIdentifier("ShowRequests", sender: nil)
                }
            }
        }
    }
}

// MARK: - Global Constants

struct GlobalConstants {
    struct NotificationKey {
        static let disabledLocation = "com.dskang.disabledLocationNotification"
        static let stealthModeOn = "com.dskang.stealthModeOnNotification"
        static let stealthModeOff = "com.dskang.stealthModeOffNotification"
        static let openedOnWave = "com.dskang.openedOnWaveNotification"
        static let updatedVisibleFriends = "com.dskang.updatedVisibleFriendsNotification"
        static let userLocationUpdated = "com.dskang.userLocationUpdatedNotification"
        static let userLocationSaved = "com.dskang.userLocationSavedNotification"
    }
}

// MARK: - Global Functions

func delay(delay: Double, closure: () -> ()) {
    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
    dispatch_after(time, dispatch_get_main_queue(), closure)
}

