// ignore_for_file: no_slop_linter/prefer_specific_type, untyped JSON and caught errors are this file's boundary

import "dart:convert";

import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../../foundation/models/voice/voice_realtime.dart";

/// Wire format of `/voice/realtime`, protocol v1. The server's
/// `tests/fixtures/voice-realtime-protocol-v1.json` is the authority, copied to
/// `test/fixtures/voice_realtime_protocol_v1.json`.
const int realtimeVoiceProtocolVersion = 1;
const int realtimeVoiceMinFrameBytes = 2;
const int realtimeVoiceMaxFrameBytes = 65536;

const int _maxSessionSeconds = 900;
const int _maxTextLength = 32768;

const int realtimeVoiceNormalCloseCode = 1000;

/// WebSocket's own code for a protocol violation, for reporting one by the server.
const int realtimeVoiceProtocolViolationCode = 1002;
const int _policyCloseCode = 1008;
const int _internalCloseCode = 1011;
const int _unavailableCloseCode = 1013;

String encodeRealtimeVoiceStart({
  required VoiceRealtimeSampleRate sampleRate,
  required ProjectGlossaryKey? projectKey,
}) => jsonEncode({
  "type": "start",
  "protocolVersion": realtimeVoiceProtocolVersion,
  "projectKey": projectKey?.value,
  "audio": {"encoding": "pcm_s16le", "sampleRate": sampleRate.hertz, "channels": 1},
});

const String realtimeVoiceFinishFrame = '{"type":"finish"}';
const String realtimeVoiceCancelFrame = '{"type":"cancel"}';

enum RealtimeVoiceCompleteReason({required final String wireName}) {
  finished(wireName: "finished"),
  sessionLimit(wireName: "session_limit"),
  quotaLimit(wireName: "quota_limit"),
}

enum RealtimeVoiceErrorCode({
  required final String wireName,
  required final bool retryable,
  required final int closeCode,
}) {
  invalidMessage(wireName: "invalid_message", retryable: false, closeCode: _policyCloseCode),
  unsupportedProtocol(wireName: "unsupported_protocol", retryable: false, closeCode: _policyCloseCode),
  quotaExhausted(wireName: "quota_exhausted", retryable: false, closeCode: _policyCloseCode),
  invalidAudio(wireName: "invalid_audio", retryable: false, closeCode: _policyCloseCode),
  providerRejected(wireName: "provider_rejected", retryable: false, closeCode: _internalCloseCode),
  audioTimeout(wireName: "audio_timeout", retryable: true, closeCode: _internalCloseCode),
  providerTimeout(wireName: "provider_timeout", retryable: true, closeCode: _internalCloseCode),
  internalError(wireName: "internal_error", retryable: true, closeCode: _internalCloseCode),
  startTimeout(wireName: "start_timeout", retryable: true, closeCode: _unavailableCloseCode),
  providerCapacity(wireName: "provider_capacity", retryable: true, closeCode: _unavailableCloseCode),
  providerUnavailable(wireName: "provider_unavailable", retryable: true, closeCode: _unavailableCloseCode),
  slowClient(wireName: "slow_client", retryable: true, closeCode: _unavailableCloseCode),
  serviceRestarting(wireName: "service_restarting", retryable: true, closeCode: _unavailableCloseCode),
}

/// Everything a realtime session reports. A session ends after a
/// [RealtimeVoiceCompleteEvent], [RealtimeVoiceErrorEvent] or
/// [RealtimeVoiceConnectionFailedEvent].
sealed class const RealtimeVoiceEvent();

/// An event the server sent.
sealed class const RealtimeVoiceServerEvent() extends RealtimeVoiceEvent;

final class const RealtimeVoiceReadyEvent({
  required final int maxSessionSeconds,
  required final int dailySecondsRemaining,
}) extends RealtimeVoiceServerEvent;

final class const RealtimeVoiceTranscriptEvent({
  required final String confirmedDelta,
  required final String provisional,
}) extends RealtimeVoiceServerEvent;

final class const RealtimeVoiceCompleteEvent({
  required final RealtimeVoiceCompleteReason reason,
  required final int dailySecondsRemaining,
}) extends RealtimeVoiceServerEvent;

final class const RealtimeVoiceErrorEvent({required final RealtimeVoiceErrorCode code})
    extends RealtimeVoiceServerEvent {
  @override
  String toString() => "RealtimeVoiceErrorEvent(code: ${code.wireName})";
}

/// The socket ended without a terminal event, or the server broke the protocol.
final class const RealtimeVoiceConnectionFailedEvent({required final RealtimeVoiceException exception})
    extends RealtimeVoiceEvent;

sealed class const RealtimeVoiceException() implements Exception;

/// No access token is available.
final class const RealtimeVoiceNotAuthenticatedException() extends RealtimeVoiceException {
  @override
  String toString() => "RealtimeVoiceNotAuthenticatedException";
}

/// The server answered the upgrade with something other than 101.
final class const RealtimeVoiceUpgradeRejectedException({
  required final int statusCode,
  required final Object cause,
}) extends RealtimeVoiceException {
  @override
  String toString() =>
      "RealtimeVoiceUpgradeRejectedException(statusCode: ${statusCode.toString()}, cause: ${cause.toString()})";
}

/// The upgrade never completed, or the socket dropped before a terminal event.
final class const RealtimeVoiceConnectionException({
  required final int? closeCode,
  required final String? closeReason,
  required final Object? cause,
}) extends RealtimeVoiceException {
  @override
  String toString() =>
      "RealtimeVoiceConnectionException(closeCode: ${closeCode.toString()}, closeReason: $closeReason, cause: ${cause.toString()})";
}

/// A frame from the server does not match protocol v1. [message] never holds a
/// transcript field's value, so this is safe to log.
final class const RealtimeVoiceProtocolException({required final String message}) extends RealtimeVoiceException {
  @override
  String toString() => "RealtimeVoiceProtocolException: $message";
}

/// Throws [RealtimeVoiceProtocolException] for anything the fixture rejects,
/// including unknown fields, types and codes.
RealtimeVoiceServerEvent parseRealtimeVoiceEvent({required String frame}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(frame);
  } on FormatException catch (error) {
    // Only the position survives, because `source` is the whole frame and the
    // frame can hold transcript text.
    throw RealtimeVoiceProtocolException(message: "Frame is not JSON: ${error.message} at ${error.offset.toString()}");
  }
  if (decoded is! Map<String, Object?>) {
    throw const RealtimeVoiceProtocolException(message: "Frame is not a JSON object");
  }
  return switch (decoded["type"]) {
    "ready" => _parseReady(json: decoded),
    "transcript" => _parseTranscript(json: decoded),
    "complete" => _parseComplete(json: decoded),
    "error" => _parseError(json: decoded),
    final type => throw RealtimeVoiceProtocolException(message: "Unknown event type: ${type.toString()}"),
  };
}

RealtimeVoiceReadyEvent _parseReady({required Map<String, Object?> json}) {
  _expectKeys(json: json, keys: const {"type", "protocolVersion", "maxSessionSeconds", "dailySecondsRemaining"});
  if (json["protocolVersion"] != realtimeVoiceProtocolVersion) {
    throw const RealtimeVoiceProtocolException(message: "Unsupported protocol version in ready");
  }
  final maxSessionSeconds = json["maxSessionSeconds"];
  if (maxSessionSeconds is! int || maxSessionSeconds < 1 || maxSessionSeconds > _maxSessionSeconds) {
    throw const RealtimeVoiceProtocolException(message: "maxSessionSeconds is out of bounds");
  }
  return RealtimeVoiceReadyEvent(
    maxSessionSeconds: maxSessionSeconds,
    dailySecondsRemaining: _dailySecondsRemaining(json: json),
  );
}

RealtimeVoiceTranscriptEvent _parseTranscript({required Map<String, Object?> json}) {
  _expectKeys(json: json, keys: const {"type", "confirmedDelta", "provisional"});
  final confirmedDelta = _text(value: json["confirmedDelta"]);
  final provisional = _text(value: json["provisional"]);
  if (confirmedDelta.isEmpty && provisional.isEmpty) {
    throw const RealtimeVoiceProtocolException(message: "Transcript carries no text");
  }
  return RealtimeVoiceTranscriptEvent(confirmedDelta: confirmedDelta, provisional: provisional);
}

RealtimeVoiceCompleteEvent _parseComplete({required Map<String, Object?> json}) {
  _expectKeys(json: json, keys: const {"type", "reason", "dailySecondsRemaining"});
  final reasonName = json["reason"];
  final reason = RealtimeVoiceCompleteReason.values.firstWhereOrNull((value) => value.wireName == reasonName);
  if (reason == null) {
    throw RealtimeVoiceProtocolException(message: "Unknown complete reason: ${reasonName.toString()}");
  }
  return RealtimeVoiceCompleteEvent(
    reason: reason,
    dailySecondsRemaining: _dailySecondsRemaining(json: json),
  );
}

RealtimeVoiceErrorEvent _parseError({required Map<String, Object?> json}) {
  _expectKeys(json: json, keys: const {"type", "code", "retryable"});
  final codeName = json["code"];
  final code = RealtimeVoiceErrorCode.values.firstWhereOrNull((value) => value.wireName == codeName);
  if (code == null) {
    throw RealtimeVoiceProtocolException(message: "Unknown error code: ${codeName.toString()}");
  }
  if (json["retryable"] != code.retryable) {
    throw RealtimeVoiceProtocolException(message: "Wrong retryable for error code: ${codeName.toString()}");
  }
  return RealtimeVoiceErrorEvent(code: code);
}

void _expectKeys({required Map<String, Object?> json, required Set<String> keys}) {
  if (json.length != keys.length || !json.keys.every(keys.contains)) {
    throw RealtimeVoiceProtocolException(message: "Unexpected fields: ${json.keys.join(",")}");
  }
}

int _dailySecondsRemaining({required Map<String, Object?> json}) {
  final value = json["dailySecondsRemaining"];
  if (value is! int || value < 0) {
    throw const RealtimeVoiceProtocolException(message: "dailySecondsRemaining is out of bounds");
  }
  return value;
}

String _text({required Object? value}) {
  if (value is! String || value.length > _maxTextLength) {
    throw const RealtimeVoiceProtocolException(message: "Transcript text is out of bounds");
  }
  return value;
}
