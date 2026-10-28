import "dart:async";
import "dart:convert";
import "dart:isolate";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

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
      FilePreviewLoaded(:final response) => await _stateFor(response: response),
      FilePreviewBridgeTooOld() => const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.bridgeTooOld),
      FilePreviewFailed(:final innerError) => _failed(error: innerError, stackTrace: innerError.stackTrace),
    };
    if (!isClosed) emit(next);
  }

  Future<FilePreviewState> _stateFor({required FilePreviewResponse response}) async {
    switch (response) {
      case FilePreviewText(:final content):
        return FilePreviewShowsText(content: content);
      case FilePreviewImage(:final mime, :final base64):
        try {
          return FilePreviewShowsImage(bytes: await Isolate.run(() => base64Decode(base64)), mime: mime);
        } on FormatException catch (error, stackTrace) {
          return _failed(error: error, stackTrace: stackTrace);
        }
      case FilePreviewMissing():
        return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.missing);
      case FilePreviewTooLarge():
        return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.tooLarge);
      case FilePreviewUnsupported():
        return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.unsupported);
      case FilePreviewDenied():
        return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.denied);
    }
  }

  FilePreviewState _failed({
    // ignore: no_slop_linter/prefer_specific_type, transport errors and decode failures share this path
    required Object error,
    required StackTrace? stackTrace,
  }) {
    loge("Failed to load the preview of ${reference.absolutePath}", error, stackTrace);
    return const FilePreviewUnavailable(reason: FilePreviewUnavailableReason.failed);
  }
}
