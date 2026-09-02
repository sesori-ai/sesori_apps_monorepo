import "../../foundation/platform/creator_recording.dart";

final class const CreatorRecordingState({
  required final CreatorRecordingCaptureState capture,
  required final CreatorRecordingLibraryState library,
  required final CreatorRecordingExportState export,
}) {
  CreatorRecordingState withCapture({required CreatorRecordingCaptureState capture}) =>
      CreatorRecordingState(capture: capture, library: library, export: export);

  CreatorRecordingState withLibrary({required CreatorRecordingLibraryState library}) =>
      CreatorRecordingState(capture: capture, library: library, export: export);

  CreatorRecordingState withExport({required CreatorRecordingExportState export}) =>
      CreatorRecordingState(capture: capture, library: library, export: export);
}

sealed class const CreatorRecordingCaptureState();

final class const CreatorRecordingUnsupported() extends CreatorRecordingCaptureState;

final class const CreatorRecordingIdle() extends CreatorRecordingCaptureState;

final class const CreatorRecordingPreparing() extends CreatorRecordingCaptureState;

final class const CreatorRecordingPreviewReady() extends CreatorRecordingCaptureState;

final class const CreatorRecordingStarting() extends CreatorRecordingCaptureState;

final class const CreatorRecordingActive() extends CreatorRecordingCaptureState;

final class const CreatorRecordingSavingCapture() extends CreatorRecordingCaptureState;

final class const CreatorRecordingCaptureCompleted({required final CreatorRecordingArtifact artifact})
    extends CreatorRecordingCaptureState;

final class const CreatorRecordingPrepareFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingCaptureState;

/// Start failed while the prepared camera preview remains available.
final class const CreatorRecordingStartFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingCaptureState;

final class const CreatorRecordingCaptureFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingCaptureState;

sealed class const CreatorRecordingLibraryState();

final class const CreatorRecordingLibraryLoading() extends CreatorRecordingLibraryState;

final class const CreatorRecordingLibraryLoaded({required final List<CreatorRecordingArtifact> recordings})
    extends CreatorRecordingLibraryState;

final class const CreatorRecordingLibraryFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingLibraryState;

sealed class const CreatorRecordingExportState();

final class const CreatorRecordingExportIdle() extends CreatorRecordingExportState;

final class const CreatorRecordingSharing({
  required final CreatorRecordingArtifact artifact,
  required final CreatorRecordingExportKind kind,
}) extends CreatorRecordingExportState;

final class const CreatorRecordingShareFailed({
  required final CreatorRecordingArtifact artifact,
  required final CreatorRecordingExportKind kind,
  required final CreatorRecordingFailure failure,
}) extends CreatorRecordingExportState;
