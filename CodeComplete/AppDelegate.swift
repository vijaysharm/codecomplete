//
//  AppDelegate.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import Firebase
import SwiftRater
import iAd
import AdSupport

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	private let gcmMessageIDKey = "ca.vijaysharma.CodeComplete.gcmMessageIDKey"
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		FirebaseApp.configure()
		
		UNUserNotificationCenter.current().delegate = self
		application.registerForRemoteNotifications()
		Messaging.messaging().delegate = self
		
		Settings.loggingBehaviors = [.appEvents]
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
		SwiftRater.daysUntilPrompt = 2
        SwiftRater.usesUntilPrompt = 3
        SwiftRater.significantUsesUntilPrompt = 2
        SwiftRater.daysBeforeReminding = 2
        SwiftRater.showLaterButton = true
        SwiftRater.debugMode = true
		#if !DEBUG
		SwiftRater.debugMode = false
		#endif
		SwiftRater.appLaunched()
		
		TestFairy.disableCrashHandler()
		TestFairy.setFeedbackEmailVisible(false)
		TestFairy.setServerEndpoint("app3-vijay1.testfairy.com")
		#if !DEBUG
		TestFairy.begin("5b3af35e59a1e074e2d50675b1b629306cf0cfbd", withOptions: ["verbose": true])
		#endif
		collectAdAttributtion()
		return true
	}

	// MARK: UISceneSession Lifecycle

	@available(iOS 13.0, *)
	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		// Called when a new scene session is being created.
		// Use this method to select a configuration to create the new scene with.
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	@available(iOS 13.0, *)
	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
		// Called when the user discards a scene session.
		// If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
		// Use this method to release any resources that were specific to the discarded scenes, as they will not return.
	}
	
	func application(
	   _ app: UIApplication,
	   open url: URL,
	   options: [UIApplication.OpenURLOptionsKey : Any] = [:]
   ) -> Bool {
	   ApplicationDelegate.shared.application(
		   app,
		   open: url,
		   sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
		   annotation: options[UIApplication.OpenURLOptionsKey.annotation]
	   )
   }
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
	  // If you are receiving a notification message while your app is in the background,
	  // this callback will not be fired till the user taps on the notification launching the application.
	  // TODO: Handle data of notification

	  // With swizzling disabled you must let Messaging know about the message, for Analytics
	  // Messaging.messaging().appDidReceiveMessage(userInfo)

	  // Print message ID.
	  if let messageID = userInfo[gcmMessageIDKey] {
		print("Message ID: \(messageID)")
	  }

	  // Print full message.
	  print(userInfo)
	}

	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
					 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
	  // If you are receiving a notification message while your app is in the background,
	  // this callback will not be fired till the user taps on the notification launching the application.
	  // TODO: Handle data of notification

	  // With swizzling disabled you must let Messaging know about the message, for Analytics
	  // Messaging.messaging().appDidReceiveMessage(userInfo)

	  // Print message ID.
	  if let messageID = userInfo[gcmMessageIDKey] {
		print("Message ID: \(messageID)")
	  }

	  // Print full message.
	  print(userInfo)

	  completionHandler(UIBackgroundFetchResult.newData)
	}
	
	private func collectAdAttributtion() {
		ADClient.shared().requestAttributionDetails({ (attributionDetails, error) in
			guard error == nil else { return }
			guard let details = attributionDetails else { return }
			for (type, dictionary) in details {
				guard let data = dictionary as? Dictionary<AnyHashable, Any> else { continue }
				DispatchQueue.main.async {
					TestFairy.setAttribute("Attributtion Version", withValue: type)
				}
				for (key, string) in data {
					guard let value = string as? String, let _ = key as? String else { continue }
					DispatchQueue.main.async {
						TestFairy.setAttribute((key as! String), withValue: value)
					}
				}
			}
		});
	}
}

extension AppDelegate: MessagingDelegate {
	func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
	  print("Firebase registration token: \(fcmToken)")

	  let dataDict:[String: String] = ["token": fcmToken]
	  NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
	  // TODO: If necessary send token to application server.
	  // Note: This callback is fired at each app startup and whenever a new token is generated.
	}
}

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {

  // Receive displayed notifications for iOS 10 devices.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    // With swizzling disabled you must let Messaging know about the message, for Analytics
    // Messaging.messaging().appDidReceiveMessage(userInfo)

    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
      print("Message ID: \(messageID)")
    }

    // Print full message.
    print(userInfo)

    // Change this to your preferred presentation option
    completionHandler([[.alert, .sound]])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    // Print message ID.
    if let messageID = userInfo[gcmMessageIDKey] {
      print("Message ID: \(messageID)")
    }

    // With swizzling disabled you must let Messaging know about the message, for Analytics
    // Messaging.messaging().appDidReceiveMessage(userInfo)

    // Print full message.
    print(userInfo)

    completionHandler()
  }
}
