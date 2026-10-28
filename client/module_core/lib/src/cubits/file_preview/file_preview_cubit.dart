import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/file_preview/file_preview_result.dart";
import "../../foundation/models/file_reference/file_reference.dart";
import "../../logging/logging.dart";
import "../../repositories/file_preview_repository.dart";
import "file_preview_state.dart";

/// Loads one file's preview once, for as long as its preview screen is open.
class FilePreviewCubit({
  required final FilePreviewRepository _repository,
  required final FileReference reference,
}) extends Cubit<FilePreviewState> {
  this : super(const FilePreviewLoading()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final next = switch (await _repository.load(path: reference.absolutePath)) {
      FilePreviewTextContent(:final content) => FilePreviewShowsText(content: content),
      FilePreviewImageContent(:final bytes, :final mime) => FilePreviewShowsImage(bytes: bytes, mime: mime),
      FilePreviewContentUnavailable(:final reason) => FilePreviewUnavailable(reason: reason),
      FilePreviewBridgeTooOld() => const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.bridgeTooOld),
      FilePreviewFailed(:final innerError, :final stackTrace) => _failed(error: innerError, stackTrace: stackTrace),
    };
    if (!isClosed) emit(next);
  }

  FilePreviewState _failed({
    // ignore: no_slop_linter/prefer_specific_type, transport errors and decode failures share this path
    required Object error,
    required StackTrace stackTrace,
  }) {
    loge("Failed to load the preview of ${reference.absolutePath}", error, stackTrace);
    return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.failed);
  }
}
