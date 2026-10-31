import "dart:async";

import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// The platform's speech engine over a method channel. Native answers `prepare`,
/// `start`, `sendAudio`, `finish` and `cancel`, and calls back with `event` for the
/// session id it was given, so a late event can't reach a newer session.
@LazySingleton(as: OnDeviceSpeechSource)
class ChannelOnDeviceSpeechSource() implements OnDeviceSpeechSource {
  static const MethodChannel _channel = MethodChannel("com.sesori.app/on-device-speech");

  _ChannelOnDeviceSpeechSession? _active;
  int _lastSessionId = 0;

  @override
  Future<bool> prepare() async {
    try {
      return await _channel.invokeMethod<bool>("prepare") ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate}) async {
    if (_active != null) throw StateError("An on-device speech session is already open");

    final session = _ChannelOnDeviceSpeechSession(
      channel: _channel,
      id: ++_lastSessionId,
      onClosed: (closed) {
        if (identical(_active, closed)) _active = null;
      },
    );
    _active = session;
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      await _channel.invokeMethod<void>("start", {"sessionId": session.id, "sampleRate": sampleRate.hertz});
    } catch (_) {
      session.close();
      rethrow;
    }
    return session;
  }

  Future<void> _onNativeCall(MethodCall call) async {
    final active = _active;
    final event = call.arguments;
    // ignore: no_slop_linter/prefer_specific_type, platform channel maps are untyped
    if (call.method != "event" || active == null || event is! Map<Object?, Object?>) return;
    if (event["sessionId"] == active.id) active.onNativeEvent(event: event);
  }
}

final class _ChannelOnDeviceSpeechSession({
  required final MethodChannel _channel,
  required final int id,
  required final void Function(_ChannelOnDeviceSpeechSession) _onClosed,
}) implements OnDeviceSpeechSession {
  final StreamController<OnDeviceSpeechEvent> _events = StreamController<OnDeviceSpeechEvent>();
  bool _closed = false;

  @override
  Stream<OnDeviceSpeechEvent> get events => _events.stream;

  @override
  void sendAudio({required Uint8List frame}) => _send(method: "sendAudio", arguments: {"bytes": frame});

  @override
  void finish() => _send(method: "finish", arguments: {});

  @override
  Future<void> cancel() async {
    if (_closed) return;
    close();
    try {
      await _channel.invokeMethod<void>("cancel", {"sessionId": id});
    } on PlatformException catch (error, stackTrace) {
      logw("Could not cancel on-device speech", error, stackTrace);
    }
  }

  void close() {
    _closed = true;
    _onClosed(this);
    // Closing waits for a listener, and a session that failed to start never has one.
    unawaited(_events.close());
  }

  // ignore: no_slop_linter/prefer_specific_type, platform channel maps are untyped
  void onNativeEvent({required Map<Object?, Object?> event}) {
    if (_closed) return;
    switch (event) {
      case {"type": "words", "confirmedDelta": final String confirmedDelta, "provisional": final String provisional}:
        _events.add(OnDeviceSpeechWords(confirmedDelta: confirmedDelta, provisional: provisional));
      case {"type": "completed"}:
        _events.add(const OnDeviceSpeechCompleted());
        close();
      case {"type": "failed", "reason": final String reason}:
        _fail(cause: reason);
      default:
        _fail(cause: StateError("Unknown on-device speech event: ${event["type"].toString()}"));
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, causes can be any object
  void _fail({required Object cause}) {
    if (_closed) return;
    _events.add(OnDeviceSpeechFailed(cause: cause));
    close();
  }

  // ignore: no_slop_linter/prefer_specific_type, platform channel maps are untyped
  void _send({required String method, required Map<String, Object> arguments}) {
    if (_closed) return;
    unawaited(_invoke(method: method, arguments: {"sessionId": id, ...arguments}));
  }

  // ignore: no_slop_linter/prefer_specific_type, platform channel maps are untyped
  Future<void> _invoke({required String method, required Map<String, Object> arguments}) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      _fail(cause: error);
    } on MissingPluginException catch (error) {
      _fail(cause: error);
    }
  }
}
