import "dart:convert";
import "dart:isolate";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/filesystem_api.dart";
import "../foundation/models/file_preview/file_preview_result.dart";

/// Loads read-only file previews from the connected bridge. Nothing is cached:
/// each preview reads the file as it is now.
@lazySingleton
class FilePreviewRepository({required final FilesystemApi _api}) {
  Future<FilePreviewResult> load({required String path}) async {
    return switch (await _api.readFilePreview(path: path)) {
      SuccessResponse(:final data) => await _resultFor(response: data),
      // COMPATIBILITY 2026-10-27 (v1.10.2): a bridge without the
      // /filesystem/file route answers 404, while every outcome of a bridge
      // that has it is a 200. Remove once no supported bridge predates the route.
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const FilePreviewBridgeTooOld(),
      ErrorResponse(:final error) => FilePreviewFailed(
        innerError: error,
        stackTrace: error.stackTrace ?? StackTrace.current,
      ),
    };
  }

  Future<FilePreviewResult> _resultFor({required FilePreviewResponse response}) async {
    switch (response) {
      case FilePreviewText(:final content):
        return FilePreviewTextContent(content: content);
      case FilePreviewImage(:final mime, :final base64):
        try {
          return FilePreviewImageContent(bytes: await Isolate.run(() => base64Decode(base64)), mime: mime);
        } on FormatException catch (error, stackTrace) {
          return FilePreviewFailed(innerError: error, stackTrace: stackTrace);
        }
      case FilePreviewMissing():
        return const FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.missing);
      case FilePreviewTooLarge():
        return const FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.tooLarge);
      case FilePreviewUnsupported():
        return const FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.unsupported);
      case FilePreviewDenied():
        return const FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.denied);
    }
  }
}
