import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for Firebase Cloud Messaging on iOS.
    //
    // Without `FirebaseApp.configure()` the native Firebase SDK is never
    // initialised, so `FirebaseMessaging.instance.getToken()` on the Dart side
    // returns null and the device never registers for push. The Flutter
    // `Firebase.initializeApp` call in main.dart initialises the *Dart* side
    // only — it does not configure the native iOS app.
    //
    // FCM also needs the APNs device token, which is why this class registers
    // for remote notifications and implements the two delegate callbacks
    // below. With `FirebaseAppDelegateProxyEnabled = true` (set in
    // Info.plist) the messaging delegate forwards those tokens to FCM for us.
    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Ask for permission and register with APNs. Doing this here (rather than
    // only from Dart) means a token is obtained even when the app is launched
    // by a notification rather than by the user tapping the icon.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// APNs handed us a device token. With the app delegate proxy enabled,
  /// FirebaseMessaging picks this up automatically; forwarding it explicitly is
  /// harmless and keeps the behaviour correct if the proxy is ever disabled.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  /// Registration failed — usually a missing `aps-environment` entitlement or
  /// an APNs problem in the provisioning profile. Surfaced rather than swallowed
  /// so "push never arrives" is diagnosable from the device log.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Coopvest] APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
