import Flutter
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
    recorderPrewarmService = RecorderPrewarmService(
      channel: FlutterMethodChannel(
        name: RecorderPrewarmService.channelName,
        binaryMessenger: engineBridge.applicationRegistrar.messenger()
      )
    )
  }
}
