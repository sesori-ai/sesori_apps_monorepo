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

  final StreamController<String> _downloads = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get downloadedVersions => _downloads.stream;

  @override
  Future<void> start({required Uri feedUri, required bool automaticChecks}) {
    _channel.setMethodCallHandler(_onRunnerCall);
    return _channel.invokeMethod<void>("start", <String, Object>{
      "feedUrl": feedUri.toString(),
      "automaticChecks": automaticChecks,
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
      case MethodCall(method: "updateDownloaded", arguments: final String version):
        _downloads.add(version);
      default:
        throw MissingPluginException();
    }
  }
}
