import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/message_image_repository.dart";
import "message_image_state.dart";

class MessageImageCubit({
  required final MessageImageRepository _repository,
  required final String _sessionId,
  required final MessageAttachment _attachment,
}) extends Cubit<MessageImageState> {
  int _previewGeneration = 0;
  int _originalGeneration = 0;

  this
    : super(
        MessageImageState(
          preview: _repository.canLoad(attachment: _attachment)
              ? const MessageImagePreviewLoading()
              : const MessageImagePreviewUnsupported(),
          original: _repository.canLoadOriginal(attachment: _attachment)
              ? const MessageImageOriginalAvailable()
              : const MessageImageOriginalUnavailable(),
        ),
      ) {
    if (state.preview is MessageImagePreviewLoading) unawaited(_loadPreview());
  }

  Future<void> loadPreview() async {
    if (!_repository.canLoad(attachment: _attachment) || state.preview is MessageImagePreviewLoading) return;
    emit(MessageImageState(preview: const MessageImagePreviewLoading(), original: state.original));
    await _loadPreview();
  }

  Future<void> retryPreview() => loadPreview();

  Future<void> loadOriginal() async {
    if (!_repository.canLoadOriginal(attachment: _attachment) ||
        state.original is MessageImageOriginalLoading ||
        state.original is MessageImageOriginalLoaded) {
      return;
    }
    final generation = ++_originalGeneration;
    emit(MessageImageState(preview: state.preview, original: const MessageImageOriginalLoading()));
    final result = await _repository.load(
      sessionId: _sessionId,
      attachment: _attachment,
      rendition: SessionAttachmentRendition.original,
    );
    if (isClosed || generation != _originalGeneration) return;
    if (result case MessageImageLoadFailure(:final cause, :final stackTrace)) {
      logw("Failed to load a stored message image original", cause, stackTrace);
    }
    emit(
      MessageImageState(
        preview: state.preview,
        original: switch (result) {
          MessageImageLoadSuccess(:final bytes, :final mime, :final actionFilename) => MessageImageOriginalLoaded(
            bytes: bytes,
            mime: mime,
            actionFilename: actionFilename,
          ),
          MessageImageLoadUnsupported() => const MessageImageOriginalUnavailable(),
          MessageImageLoadRejected() => const MessageImageOriginalRejected(),
          MessageImageLoadFailure(:final cause, :final stackTrace) => MessageImageOriginalFailed(
            cause: cause,
            stackTrace: stackTrace,
          ),
        },
      ),
    );
  }

  Future<void> retryOriginal() => loadOriginal();

  Future<void> _loadPreview() async {
    final generation = ++_previewGeneration;
    final result = await _repository.load(
      sessionId: _sessionId,
      attachment: _attachment,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    if (isClosed || generation != _previewGeneration) return;
    if (result is MessageImageLoadFailure) {
      if (_attachment is MessageAttachmentStoredImage) {
        logw("Failed to load a stored message image preview", result.cause, result.stackTrace);
      } else {
        logw("Failed to load a message image preview");
      }
    }
    emit(
      MessageImageState(
        preview: switch (result) {
          MessageImageLoadSuccess(:final bytes, :final mime, :final actionFilename, :final originalUri) =>
            MessageImagePreviewLoaded(
              bytes: bytes,
              mime: mime,
              actionFilename: actionFilename,
              originalUri: originalUri,
            ),
          MessageImageLoadUnsupported() => const MessageImagePreviewUnsupported(),
          MessageImageLoadRejected() => const MessageImagePreviewRejected(),
          MessageImageLoadFailure(:final cause, :final stackTrace) => MessageImagePreviewFailed(
            cause: cause,
            stackTrace: stackTrace,
          ),
        },
        original: state.original,
      ),
    );
  }
}
