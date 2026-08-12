import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/message_image_repository.dart";
import "message_image_state.dart";

class MessageImageCubit extends Cubit<MessageImageState> {
  final MessageImageRepository _repository;
  final String _sessionId;
  final MessageAttachment _attachment;
  int _previewGeneration = 0;
  int _originalGeneration = 0;

  MessageImageCubit({
    required MessageImageRepository repository,
    required String sessionId,
    required MessageAttachment attachment,
  }) : _repository = repository,
       _sessionId = sessionId,
       _attachment = attachment,
       super(
         MessageImageState(
           preview: repository.canLoad(attachment: attachment)
               ? const MessageImagePreviewLoading()
               : const MessageImagePreviewUnsupported(),
           original: repository.canLoadOriginal(attachment: attachment)
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
      logw("Failed to load a message image preview");
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
