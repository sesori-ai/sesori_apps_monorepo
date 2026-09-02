import "dart:async";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  late _FakeCreatorRecording platform;
  late CreatorRecordingCubit cubit;
  late CreatorRecordingArtifact artifact;

  setUp(() async {
    artifact = CreatorRecordingArtifact(
      id: "recording-1",
      createdAt: DateTime.utc(2026, 9, 2),
      duration: const Duration(seconds: 12),
      composedVideoPath: "/recording/final.mov",
      screenVideoPath: "/recording/screen.mov",
      cameraVideoPath: "/recording/camera.mov",
      microphoneAudioPath: "/recording/microphone.m4a",
      movementMetadataPath: "/recording/movement.json",
      manifestPath: "/recording/manifest.json",
    );
    platform = _FakeCreatorRecording(initialRecordings: []);
    final repository = CreatorRecordingRepository(recording: platform);
    final service = CreatorRecordingService(repository: repository);
    cubit = CreatorRecordingCubit(service: service);
    await _waitForLibrary(cubit);
  });

  tearDown(() async {
    await cubit.close();
    await platform.close();
  });

  test("prepares, records, stops, and refreshes the persisted artifact", () async {
    expect(await cubit.preparePreview(), isTrue);
    expect(cubit.state.capture, isA<CreatorRecordingPreviewReady>());

    expect(await cubit.start(), isTrue);
    expect(cubit.state.capture, isA<CreatorRecordingActive>());

    platform.stopArtifact = artifact;
    platform.recordings = [artifact];
    await cubit.stop();

    final capture = cubit.state.capture as CreatorRecordingCaptureCompleted;
    expect(capture.artifact, same(artifact));
    expect(
      (cubit.state.library as CreatorRecordingLibraryLoaded).recordings,
      [same(artifact)],
    );
    expect(platform.prepareCalls, 1);
    expect(platform.startCalls, 1);
    expect(platform.stopCalls, 1);
  });

  test("reconciles a stop initiated by the native camera bubble", () async {
    await cubit.preparePreview();
    await cubit.start();

    platform.emit(const CreatorRecordingSaving());
    await _waitForCapture<CreatorRecordingSavingCapture>(cubit);

    platform.recordings = [artifact];
    platform.emit(CreatorRecordingCompleted(artifact: artifact));
    await _waitForCapture<CreatorRecordingCaptureCompleted>(cubit);
    await _waitForLibrary(cubit);

    expect(
      (cubit.state.capture as CreatorRecordingCaptureCompleted).artifact,
      same(artifact),
    );
    expect(
      (cubit.state.library as CreatorRecordingLibraryLoaded).recordings,
      [same(artifact)],
    );
  });

  test("keeps a failed start recoverable while the preview remains prepared", () async {
    await cubit.preparePreview();
    platform.startFailure = const CreatorRecordingFailure(
      reason: CreatorRecordingFailureReason.microphonePermissionDenied,
      innerError: null,
    );

    expect(await cubit.start(), isFalse);

    final failure = cubit.state.capture as CreatorRecordingStartFailed;
    expect(failure.failure.reason, CreatorRecordingFailureReason.microphonePermissionDenied);
    platform.startFailure = null;
    expect(await cubit.start(), isTrue);
  });

  test("shares the selected output kind and deletes through the service flow", () async {
    platform.recordings = [artifact];
    await cubit.refreshLibrary();

    await cubit.shareRecording(
      artifact: artifact,
      kind: CreatorRecordingExportKind.sourceLayers,
    );
    expect(platform.shared, [(artifact.id, CreatorRecordingExportKind.sourceLayers)]);
    expect(cubit.state.export, isA<CreatorRecordingExportIdle>());

    await cubit.deleteRecording(artifact: artifact);
    expect(platform.deletedIds, [artifact.id]);
    expect((cubit.state.library as CreatorRecordingLibraryLoaded).recordings, isEmpty);
  });

  test("surfaces a native interruption and retains its closed failure reason", () async {
    await cubit.preparePreview();
    await cubit.start();
    const failure = CreatorRecordingFailure(
      reason: CreatorRecordingFailureReason.capture,
      innerError: null,
    );

    platform.emit(const CreatorRecordingFailed(failure: failure));
    await _waitForCapture<CreatorRecordingCaptureFailed>(cubit);

    expect(
      (cubit.state.capture as CreatorRecordingCaptureFailed).failure.reason,
      CreatorRecordingFailureReason.capture,
    );
  });
}

Future<void> _waitForLibrary(CreatorRecordingCubit cubit) async {
  if (cubit.state.library is CreatorRecordingLibraryLoading) {
    await cubit.stream.firstWhere((state) => state.library is! CreatorRecordingLibraryLoading);
  }
}

Future<void> _waitForCapture<T extends CreatorRecordingCaptureState>(CreatorRecordingCubit cubit) async {
  if (cubit.state.capture is! T) {
    await cubit.stream.firstWhere((state) => state.capture is T);
  }
}

final class _FakeCreatorRecording({
  required List<CreatorRecordingArtifact> initialRecordings,
}) implements CreatorRecording {
  final StreamController<CreatorRecordingEvent> _events = StreamController.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<CreatorRecordingEvent> get events => _events.stream;

  List<CreatorRecordingArtifact> recordings = initialRecordings;
  CreatorRecordingArtifact? stopArtifact;
  CreatorRecordingFailure? startFailure;
  int prepareCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  final List<String> deletedIds = [];
  final List<(String, CreatorRecordingExportKind)> shared = [];

  void emit(CreatorRecordingEvent event) => _events.add(event);

  @override
  Future<void> preparePreview() async {
    prepareCalls++;
  }

  @override
  Future<void> dismissPreview() async {}

  @override
  Future<void> start() async {
    startCalls++;
    final failure = startFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<CreatorRecordingArtifact> stop() async {
    stopCalls++;
    return stopArtifact ?? (throw StateError("Missing fake stop artifact"));
  }

  @override
  Future<List<CreatorRecordingArtifact>> listRecordings() async => List.unmodifiable(recordings);

  @override
  Future<void> deleteRecording({required CreatorRecordingArtifact artifact}) async {
    deletedIds.add(artifact.id);
    recordings = recordings.where((candidate) => candidate.id != artifact.id).toList();
  }

  @override
  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  }) async {
    shared.add((artifact.id, kind));
  }

  Future<void> close() => _events.close();
}
