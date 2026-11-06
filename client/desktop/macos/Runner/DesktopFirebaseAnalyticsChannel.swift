import FirebaseAnalytics
import FirebaseCore
import FlutterMacOS
import Foundation

/// Attaching the channel never configures Firebase. Dart invokes initialization
/// only for an admitted primary process in an eligible packaged macOS release.
enum DesktopFirebaseAnalyticsChannel {
  static func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "sesori/desktop_firebase_analytics",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "initialize":
        // Read the registered desktop app's explicit options only here, never
        // through a default Firebase plist or automatic plugin startup.
        guard let path = Bundle.main.path(forResource: "DesktopFirebase-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
          result(FlutterError(
            code: "firebase_configuration_missing",
            message: "Missing desktop Firebase configuration",
            details: nil
          ))
          return
        }
        FirebaseApp.configure(options: options)
        Analytics.setAnalyticsCollectionEnabled(false)
        Analytics.setConsent([
          .analyticsStorage: .granted,
          .adStorage: .denied,
          .adUserData: .denied,
          .adPersonalization: .denied,
        ])
        Analytics.setAnalyticsCollectionEnabled(true)
        result(nil)
      case "logInstallationEvent":
        guard let arguments = call.arguments as? [String: Any],
              let name = arguments["name"] as? String,
              let parameters = arguments["parameters"] as? [String: Any] else {
          result(FlutterError(
            code: "invalid_analytics_event",
            message: "Expected a bounded authentication event and parameters",
            details: nil
          ))
          return
        }
        Analytics.logEvent(name, parameters: parameters)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
