//
//  AppDelegate.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/27/25.
//
import SwiftUI
import UserNotifications
import Supabase

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private var pendingAPNsToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        // If the user logs in after the token was already received, save it then
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidLogin"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let token = self?.pendingAPNsToken {
                Task {
                    await self?.saveAPNsToken(token)
                    self?.pendingAPNsToken = nil
                }
            }
        }

        return true
    }

    // Called by iOS when APNs issues a device token (or rotates it)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs device token: \(String(token.prefix(20)))...")
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        Task { await saveAPNsToken(token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error)")
    }

    // Handle silent background notifications (e.g. new activity sync trigger)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let syncType = userInfo["sync_type"] as? String, syncType == "new_activity" {
            Task {
                await DataManager.shared.refreshActivities()
                await MainActor.run { completionHandler(.newData) }
            }
        } else {
            completionHandler(.noData)
        }
    }

    // Show notification banner even when app is foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 Notification tapped: \(userInfo)")
        completionHandler()
    }

    private func saveAPNsToken(_ token: String) async {
        guard let userId = UserSession.shared.userId else {
            print("⚠️ APNs token received before login — will save after UserDidLogin")
            await MainActor.run { pendingAPNsToken = token }
            return
        }
        do {
            try await supabase
                .from("athletes")
                .update(["apns_token": token])
                .eq("id", value: userId)
                .execute()
            print("✅ APNs token saved")
        } catch {
            print("❌ Failed to save APNs token: \(error)")
        }
    }
}
