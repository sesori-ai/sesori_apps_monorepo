import Flutter
import UIKit
#if DEBUG
import AVFoundation
import StoreKit
#endif

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
    recorderPrewarmService = RecorderPrewarmService(
      channel: FlutterMethodChannel(
        name: RecorderPrewarmService.channelName,
        binaryMessenger: engineBridge.applicationRegistrar.messenger()
      )
    )
    #if DEBUG
    // Local feedback playbook only. The production Dart entry point has no caller.
    FlutterMethodChannel(
      name: "com.sesori.app/feedback_preview",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      if call.method == "requestMicrophoneAccess" {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
          result(true)
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { result(granted) }
          }
        case .denied, .restricted:
          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) { _ in
            result(false)
          }
        @unknown default:
          result(false)
        }
        return
      }
      guard call.method == "requestReview" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }) else {
        result(FlutterError(code: "no_active_scene", message: "No active scene for native rating.", details: nil))
        return
      }
      if #available(iOS 16.0, *) {
        AppStore.requestReview(in: scene)
      } else {
        SKStoreReviewController.requestReview(in: scene)
      }
      // StoreKit does not report whether the sheet appeared or a rating was sent.
      result(nil)
    }
    #endif
  }
}
