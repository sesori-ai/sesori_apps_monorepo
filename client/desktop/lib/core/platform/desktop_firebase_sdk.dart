import "package:flutter/services.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// The macOS-only SDK channel avoids pulling Firebase's unsupported Windows ARM64
/// C++ library into desktop builds through a transitive FlutterFire dependency.
class DesktopFirebaseSdk({required final MethodChannel _channel}) {
  Future<void> initialize() => _channel.invokeMethod<void>("initialize");

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) => _channel.invokeMethod<void>(
    "logInstallationEvent",
    {
      "name": event.wireName,
      "parameters": {...event.parameters, "schema_version": 1},
    },
  );
}
