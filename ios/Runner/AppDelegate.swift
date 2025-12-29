import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Firebase phải được configure trước khi register plugins
    // print("🔥 [AppDelegate] Configuring Firebase...")
    FirebaseApp.configure()
    // print("✅ [AppDelegate] Firebase configured successfully")
      
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ Register for remote notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    // print("✅ [AppDelegate] Registered for remote notifications")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle successful APNs token registration
  override func application(_ application: UIApplication, 
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // print("✅ [AppDelegate] APNs device token received: \(tokenString)")
    
    // ✅ QUAN TRỌNG: Set APNs token cho Firebase Messaging
    // Sử dụng .unknown để Firebase tự động xác định môi trường (development/production)
    Messaging.messaging().apnsToken = deviceToken
    // print("✅ [AppDelegate] APNs token set for Firebase Messaging")
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle APNs token registration failure
  override func application(_ application: UIApplication, 
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // print("❌ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
