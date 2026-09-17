import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "release_status/push",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    ReleaseStatusPush.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "register":
        NSApplication.shared.registerForRemoteNotifications()
        if let token = ReleaseStatusPush.token {
          ReleaseStatusPush.channel?.invokeMethod("tokenUpdated", arguments: token)
        }
        result(nil)
      case "getApnsToken":
        result(ReleaseStatusPush.token)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
