import "dart:async";

import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:share_plus/share_plus.dart";
import "package:universal_platform/universal_platform.dart";

import "../../capabilities/creator_recording/creator_recording_channel_client.dart";
import "share_plus_client.dart";

@LazySingleton(as: CreatorRecording)
class FlutterCreatorRecording({
  required final CreatorRecordingChannelClient _channelClient,
  required final SharePlusClient _sharePlusClient,
}) implements CreatorRecording {
  @override
  bool get isSupported => UniversalPlatform.isIOS;

  @override
  Stream<CreatorRecordingEvent> get events => _parseEvents();

  Stream<CreatorRecordingEvent> _parseEvents() async* {
    await for (final rawEvent in _channelClient.events) {
      try {
        final event = _requiredMap(rawEvent, description: "creator recording event");
        final type = _requiredString(event, "type");
        final payload = event["payload"];
        switch (type) {
          case "recordingSaving":
            yield const CreatorRecordingSaving();
          case "recordingCompleted":
            yield CreatorRecordingCompleted(artifact: _artifactFrom(payload));
          case "recordingFailed":
            final details = _requiredMap(payload, description: "recording failure");
            yield CreatorRecordingFailed(failure: _failureFromCode(_requiredString(details, "code")));
          default:
            throw const FormatException("Unknown creator recording event type");
        }
      } on Object catch (error, stackTrace) {
        loge("Failed to parse native creator recording event", error, stackTrace);
        yield CreatorRecordingFailed(
          failure: CreatorRecordingFailure(
            reason: CreatorRecordingFailureReason.unexpected,
            innerError: error,
          ),
        );
      }
    }
  }

  @override
  Future<void> preparePreview() => _invoke(_channelClient.preparePreview);

  @override
  Future<void> dismissPreview() => _invoke(_channelClient.dismissPreview);

  @override
  Future<void> start() => _invoke(_channelClient.start);

  @override
  Future<CreatorRecordingArtifact> stop() async {
    try {
      return _artifactFrom(await _channelClient.stop());
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } on CreatorRecordingFailure {
      rethrow;
    } on Object catch (error) {
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.unexpected,
        innerError: error,
      );
    }
  }

  @override
  Future<List<CreatorRecordingArtifact>> listRecordings() async {
    try {
      final raw = await _channelClient.listRecordings();
      if (raw is! List<Object?>) throw const FormatException("Creator recording list was not an array");
      return raw.map(_artifactFrom).toList(growable: false);
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } on CreatorRecordingFailure {
      rethrow;
    } on Object catch (error) {
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.storage,
        innerError: error,
      );
    }
  }

  @override
  Future<void> deleteRecording({required CreatorRecordingArtifact artifact}) async {
    try {
      await _channelClient.deleteRecording(id: artifact.id);
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } on Object catch (error) {
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.storage,
        innerError: error,
      );
    }
  }

  @override
  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  }) async {
    final paths = switch (kind) {
      CreatorRecordingExportKind.composedVideo => [artifact.composedVideoPath],
      CreatorRecordingExportKind.sourceLayers => [
        artifact.screenVideoPath,
        artifact.cameraVideoPath,
        artifact.microphoneAudioPath,
        artifact.movementMetadataPath,
        artifact.manifestPath,
      ],
    };

    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      final logicalSize = view == null ? const Size(1, 1) : view.physicalSize / view.devicePixelRatio;
      await _sharePlusClient.share(
        params: ShareParams(
          files: paths.map(XFile.new).toList(growable: false),
          subject: "Sesori creator recording",
          sharePositionOrigin: Rect.fromCenter(
            center: logicalSize.center(Offset.zero),
            width: 1,
            height: 1,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      loge("Failed to share creator recording export", error, stackTrace);
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.export,
        innerError: error,
      );
    }
  }

  Future<void> _invoke(Future<void> Function() operation) async {
    try {
      await operation();
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } on Object catch (error) {
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.unexpected,
        innerError: error,
      );
    }
  }

  static CreatorRecordingArtifact _artifactFrom(Object? raw) {
    try {
      final map = _requiredMap(raw, description: "creator recording artifact");
      return CreatorRecordingArtifact(
        id: _requiredString(map, "id"),
        createdAt: DateTime.parse(_requiredString(map, "createdAt")),
        duration: Duration(milliseconds: _requiredInt(map, "durationMs")),
        composedVideoPath: _requiredString(map, "composedVideoPath"),
        screenVideoPath: _requiredString(map, "screenVideoPath"),
        cameraVideoPath: _requiredString(map, "cameraVideoPath"),
        microphoneAudioPath: _requiredString(map, "microphoneAudioPath"),
        movementMetadataPath: _requiredString(map, "movementMetadataPath"),
        manifestPath: _requiredString(map, "manifestPath"),
      );
    } on Object catch (error) {
      throw CreatorRecordingFailure(
        reason: CreatorRecordingFailureReason.storage,
        innerError: error,
      );
    }
  }

  static CreatorRecordingFailure _failureFromPlatform(PlatformException error) =>
      _failureFromCode(error.code, innerError: error);

  static CreatorRecordingFailure _failureFromCode(String code, {Object? innerError}) => CreatorRecordingFailure(
    reason: switch (code) {
      "unsupported" => CreatorRecordingFailureReason.unsupported,
      "camera_permission_denied" => CreatorRecordingFailureReason.cameraPermissionDenied,
      "microphone_permission_denied" => CreatorRecordingFailureReason.microphonePermissionDenied,
      "portrait_required" => CreatorRecordingFailureReason.portraitRequired,
      "screen_capture_unavailable" => CreatorRecordingFailureReason.screenCaptureUnavailable,
      "recording_already_in_progress" => CreatorRecordingFailureReason.recordingAlreadyInProgress,
      "recording_not_in_progress" => CreatorRecordingFailureReason.recordingNotInProgress,
      "storage_failed" => CreatorRecordingFailureReason.storage,
      "capture_failed" => CreatorRecordingFailureReason.capture,
      "export_failed" => CreatorRecordingFailureReason.export,
      _ => CreatorRecordingFailureReason.unexpected,
    },
    innerError: innerError,
  );

  static Map<Object?, Object?> _requiredMap(Object? value, {required String description}) {
    if (value is Map<Object?, Object?>) return value;
    if (value is Map) return Map<Object?, Object?>.from(value);
    throw FormatException("Invalid $description");
  }

  static String _requiredString(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException("Missing $key");
  }

  static int _requiredInt(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException("Missing $key");
  }
}
