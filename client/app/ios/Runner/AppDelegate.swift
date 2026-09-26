import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var recorderPrewarmService: RecorderPrewarmService?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    recorderPrewarmService = RecorderPrewarmService(
      channel: FlutterMethodChannel(
        name: RecorderPrewarmService.channelName,
        binaryMessenger: messenger
      )
    )
    FlutterMethodChannel(name: "com.sesori.app/app_review", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "requestReview" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive }) else {
          result(FlutterError(code: "no_active_scene", message: "No active scene for the review prompt", details: nil))
          return
        }
        if #available(iOS 16.0, *) {
          AppStore.requestReview(in: scene)
        } else {
          SKStoreReviewController.requestReview(in: scene)
        }
        // StoreKit does not report whether its prompt appeared.
        result(nil)
      }
  }
}
