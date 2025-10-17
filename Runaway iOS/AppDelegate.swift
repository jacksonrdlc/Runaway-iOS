//
//  AppDelegate.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/27/25.
//
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Supabase

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    private var pendingFCMToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Configure Firebase with reduced analytics tracking
        FirebaseApp.configure()

        // Disable automatic screen tracking to prevent XPC timeouts
        // (Automatic tracking causes blocking operations on keyboard events)
        #if DEBUG
        print("🔥 Firebase configured with reduced analytics tracking")
        #endif

        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )

        application.registerForRemoteNotifications()

        // Listen for user login to save pending FCM token
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidLogin"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔔 User logged in - checking for pending FCM token")
            if let token = self?.pendingFCMToken {
                print("   Found pending FCM token, saving now...")
                Task {
                    await self?.saveFCMTokenToSupabase(token)
                    self?.pendingFCMToken = nil
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Handle silent background notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("🔔 Push notification received")
        print("   App state: \(application.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
        print("   User info: \(userInfo)")

        // Check if this is a silent notification for activity sync
        if let syncType = userInfo["sync_type"] as? String, syncType == "new_activity" {
            print("🔄 Activity sync notification detected - triggering background sync...")

            Task {
                // Refresh activity data in background
                await DataManager.shared.refreshActivities()

                print("✅ Background activity sync completed successfully")

                await MainActor.run {
                    completionHandler(.newData)
                }
            }
        } else {
            print("⚠️ No sync_type found in notification - checking all keys...")
            for (key, value) in userInfo {
                print("   Key: \(key), Value: \(value)")
            }
            completionHandler(.noData)
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 Firebase registration token received: \(String(describing: fcmToken))")

        let dataDict:[String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)

        // Save FCM token to Supabase for push notifications
        if let token = fcmToken {
            print("💾 Attempting to save FCM token to Supabase...")
            Task {
                await saveFCMTokenToSupabase(token)
            }
        } else {
            print("⚠️ No FCM token available to save")
        }
    }

    private func saveFCMTokenToSupabase(_ token: String) async {
        print("🔍 saveFCMTokenToSupabase called")
        print("   Token: \(String(token.prefix(20)))... (length: \(token.count))")
        print("   UserSession.shared.userId: \(String(describing: UserSession.shared.userId))")

        guard let userId = UserSession.shared.userId else {
            print("⚠️ Cannot save FCM token: No user logged in yet")
            print("   📌 Saving token as pending - will save after login")
            await MainActor.run {
                self.pendingFCMToken = token
            }
            return
        }

        print("   Updating athletes table for user ID: \(userId)")

        do {
            try await supabase
                .from("athletes")
                .update(["fcm_token": token])
                .eq("id", value: userId)
                .execute()

            print("✅ FCM token saved to Supabase successfully!")
            print("   Updated athlete ID: \(userId)")
        } catch {
            print("❌ Failed to save FCM token to Supabase")
            print("   Error: \(error)")
            print("   Error type: \(type(of: error))")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print message ID.
        if let messageID = userInfo["gcm.message_id"] {
            print("Message ID: \(messageID)")
        }

        print(userInfo)

        // Change this to your preferred presentation option
        completionHandler([[.alert, .sound]])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Print message ID.
        if let messageID = userInfo["gcm.message_id"] {
            print("Message ID: \(messageID)")
        }

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        print(userInfo)

        completionHandler()
    }
}
