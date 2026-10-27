import "dart:async";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Dumb adapter for the macOS runner's Sparkle updater; see
/// `SparkleUpdater.swift`.
@LazySingleton(as: SparkleUpdateEngine)
class MethodChannelSparkleUpdateEngine.forTesting({required final MethodChannel _channel})
    implements SparkleUpdateEngine {
  new() : this.forTesting(channel: const MethodChannel("sesori/sparkle"));

  @visibleForTesting
  this;

  final StreamController<SparkleDownloadedUpdate> _downloads = StreamController<SparkleDownloadedUpdate>.broadcast(
    sync: true,
  );
  final StreamController<void> _restartRequests = StreamController<void>.broadcast(sync: true);

  @override
  Stream<SparkleDownloadedUpdate> get downloadedUpdates => _downloads.stream;

  @override
  Stream<void> get restartRequests => _restartRequests.stream;

  @override
  Future<void> start({required Uri feedUri, required bool automaticChecks, required bool showsBuildNumber}) {
    _channel.setMethodCallHandler(_onRunnerCall);
    return _channel.invokeMethod<void>("start", <String, Object>{
      "feedUrl": feedUri.toString(),
      "automaticChecks": automaticChecks,
      "showsBuildNumber": showsBuildNumber,
    });
  }

  @override
  Future<void> setAutomaticChecks({required bool enabled}) =>
      _channel.invokeMethod<void>("setAutomaticChecks", <String, Object>{"enabled": enabled});

  @override
  Future<void> checkNow() => _channel.invokeMethod<void>("checkNow");

  @override
  Future<void> installAndRelaunch() => _channel.invokeMethod<void>("installAndRelaunch");

  Future<void> _onRunnerCall(MethodCall call) async {
    switch (call) {
      case MethodCall(
        method: "updateDownloaded",
        arguments: {"version": final String version, "build": final String build},
      ):
        _downloads.add(SparkleDownloadedUpdate(version: version, buildNumber: int.parse(build)));
      case MethodCall(method: "restartRequested"):
        _restartRequests.add(null);
      default:
        throw MissingPluginException();
    }
  }
}
