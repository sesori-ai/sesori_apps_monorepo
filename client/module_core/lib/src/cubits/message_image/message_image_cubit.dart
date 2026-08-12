import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/message_image_repository.dart";
import "message_image_state.dart";

class MessageImageCubit({
    required MessageImageRepository repository,
    required MessageAttachment attachment,
  }) extends Cubit<MessageImageState> {
  final MessageImageRepository _repository;
  final MessageAttachment _attachment;

  this : _repository = repository,
       _attachment = attachment,
       super(
         repository.canLoad(attachment: attachment) ? const MessageImageLoading() : const MessageImageUnsupported(),
       ) {
    if (state is MessageImageLoading) unawaited(_load());
  }

  Future<void> _load() async {
    final result = await _repository.load(attachment: _attachment);
    if (isClosed) return;
    if (result is MessageImageLoadFailure) {
      logw("Failed to load a message image");
    }
    emit(
      switch (result) {
        MessageImageLoadSuccess(:final bytes, :final mime, :final actionFilename, :final originalUri) =>
          MessageImageLoaded(
            bytes: bytes,
            mime: mime,
            actionFilename: actionFilename,
            originalUri: originalUri,
          ),
        MessageImageLoadUnsupported() => const MessageImageUnsupported(),
        MessageImageLoadRejected() => const MessageImageRejected(),
        MessageImageLoadFailure(:final cause, :final stackTrace) => MessageImageFailed(
          cause: cause,
          stackTrace: stackTrace,
        ),
      },
    );
  }
}
