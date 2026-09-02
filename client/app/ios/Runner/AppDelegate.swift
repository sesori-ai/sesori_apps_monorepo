import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var recorderPrewarmService: RecorderPrewarmService?
  private var creatorRecordingService: CreatorRecordingService?

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
    creatorRecordingService = CreatorRecordingService(
      channel: FlutterMethodChannel(
        name: CreatorRecordingService.channelName,
        binaryMessenger: messenger
      )
    )
  }
}
