import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  let engine = FlutterEngine(name: "main engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    return true
  }
}
