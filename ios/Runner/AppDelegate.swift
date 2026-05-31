import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    applyFirebaseAppCheckDebugTokenIfPresent()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Must run before Firebase configures App Check (simulator cannot use Device Check).
  private func applyFirebaseAppCheckDebugTokenIfPresent() {
    if ProcessInfo.processInfo.environment["FIRAAppCheckDebugToken"] != nil {
      return
    }
    guard
      let token = Bundle.main.object(forInfoDictionaryKey: "FIRAAppCheckDebugToken") as? String,
      !token.isEmpty
    else {
      return
    }
    setenv("FIRAAppCheckDebugToken", token, 1)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
