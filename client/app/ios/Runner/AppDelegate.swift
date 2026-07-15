import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "NativeActivityIndicatorPlatformViewPlugin"
      )
    else {
      fatalError("Unable to register the native activity indicator platform view")
    }
    registrar.register(
      NativeActivityIndicatorPlatformViewFactory(),
      withId: NativeActivityIndicatorPlatformViewFactory.viewType
    )
  }
}
