import "package:json_annotation/json_annotation.dart";

/// Auth-server client identity used to label the device that starts OAuth.
enum AuthClientType {
  @JsonValue("bridge")
  bridge,
  @JsonValue("app")
  app,
  @JsonValue("bridge_macos")
  bridgeMacos,
  @JsonValue("bridge_windows")
  bridgeWindows,
  @JsonValue("bridge_linux")
  bridgeLinux,
  @JsonValue("app_ios")
  appIos,
  @JsonValue("app_android")
  appAndroid,
  @JsonValue("app_macos")
  appMacos,
  @JsonValue("app_windows")
  appWindows,
  @JsonValue("app_linux")
  appLinux,
}
