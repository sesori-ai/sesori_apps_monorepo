import "dart:async";

import "package:flutter/services.dart";
import "package:injectable/injectable.dart";

/// Injectable seam around Sesori's native creator-recording method channel.
@lazySingleton
class CreatorRecordingChannelClient() {
  static const _channelName = "com.sesori.app/creator-recording";

  final MethodChannel _channel = const MethodChannel(_channelName);
  // ignore: no_slop_linter/prefer_specific_type, the platform codec carries heterogeneous payloads parsed by the adapter
  final StreamController<Object?> _events = StreamController<Object?>.broadcast();

  this {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "recordingSaving" || "recordingCompleted" || "recordingFailed":
          _events.add({"type": call.method, "payload": call.arguments});
        default:
          return;
      }
    });
  }

  // ignore: no_slop_linter/prefer_specific_type, untrusted platform values are validated by the adapter
  Stream<Object?> get events => _events.stream;

  Future<void> preparePreview() => _channel.invokeMethod<void>("preparePreview");

  Future<void> dismissPreview() => _channel.invokeMethod<void>("dismissPreview");

  Future<void> start() => _channel.invokeMethod<void>("start");

  // ignore: no_slop_linter/prefer_specific_type, untrusted platform values are validated by the adapter
  Future<Object?> stop() => _channel.invokeMethod<Object?>("stop");

  // ignore: no_slop_linter/prefer_specific_type, untrusted platform values are validated by the adapter
  Future<Object?> listRecordings() => _channel.invokeMethod<Object?>("listRecordings");

  Future<void> deleteRecording({required String id}) => _channel.invokeMethod<void>("deleteRecording", {"id": id});
}
