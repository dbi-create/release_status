import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let tokenDefaultsKey = "release_status.apnsToken"
  private static var pushChannel: FlutterMethodChannel?
  private static var apnsToken: String? {
    get { UserDefaults.standard.string(forKey: tokenDefaultsKey) }
    set { UserDefaults.standard.set(newValue, forKey: tokenDefaultsKey) }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "release_status/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    AppDelegate.pushChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "register":
        UIApplication.shared.registerForRemoteNotifications()
        if let token = AppDelegate.apnsToken, !token.isEmpty {
          AppDelegate.pushChannel?.invokeMethod("tokenUpdated", arguments: token)
        }
        result(nil)
      case "getApnsToken":
        result(AppDelegate.apnsToken)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if let token = AppDelegate.apnsToken, !token.isEmpty {
      channel.invokeMethod("tokenUpdated", arguments: token)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    AppDelegate.apnsToken = token
    AppDelegate.pushChannel?.invokeMethod("tokenUpdated", arguments: token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
