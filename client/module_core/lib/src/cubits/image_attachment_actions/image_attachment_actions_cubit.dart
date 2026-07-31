import "dart:typed_data";

import "package:bloc/bloc.dart";

import "../../foundation/platform/image_clipboard.dart";
import "../../foundation/platform/image_saver.dart";
import "../../foundation/platform/image_sharer.dart";
import "../../logging/logging.dart";
import "image_attachment_actions_state.dart";

class ImageAttachmentActionsCubit extends Cubit<ImageAttachmentActionsState> {
  final ImageSaver _imageSaver;
  final ImageClipboard _imageClipboard;
  final ImageSharer _imageSharer;
  final Uint8List _bytes;
  final String _mime;
  final String _filename;

  ImageAttachmentActionsCubit({
    required ImageSaver imageSaver,
    required ImageClipboard imageClipboard,
    required ImageSharer imageSharer,
    required Uint8List bytes,
    required String mime,
    required String actionFilename,
  }) : _imageSaver = imageSaver,
       _imageClipboard = imageClipboard,
       _imageSharer = imageSharer,
       _bytes = bytes,
       _mime = mime,
       _filename = actionFilename,
       super(const ImageAttachmentActionsIdle());

  Future<void> copy() async {
    if (state is ImageAttachmentActionRunning) return;
    emit(const ImageAttachmentActionRunning(action: ImageAttachmentAction.copy));
    try {
      await _imageClipboard.writeImage(bytes: _bytes);
      if (isClosed) return;
      emit(const ImageAttachmentCopied());
    } on Object catch (cause, stackTrace) {
      if (isClosed) {
        logw("Failed to copy a closed message image", cause, stackTrace);
        return;
      }
      emit(ImageAttachmentCopyFailed(cause: cause, stackTrace: stackTrace));
    }
  }

  Future<void> share({required ImageShareOrigin? origin}) async {
    if (state is ImageAttachmentActionRunning) return;
    emit(const ImageAttachmentActionRunning(action: ImageAttachmentAction.share));
    try {
      await _imageSharer.shareImage(
        bytes: _bytes,
        mime: _mime,
        filename: _filename,
        origin: origin,
      );
      if (isClosed) return;
      emit(const ImageAttachmentActionsIdle());
    } on Object catch (cause, stackTrace) {
      if (isClosed) {
        logw("Failed to share a closed message image", cause, stackTrace);
        return;
      }
      emit(ImageAttachmentShareFailed(cause: cause, stackTrace: stackTrace));
    }
  }

  Future<void> save() async {
    if (state is ImageAttachmentActionRunning) return;
    emit(const ImageAttachmentActionRunning(action: ImageAttachmentAction.save));
    try {
      final result = await _imageSaver.saveImage(bytes: _bytes, mime: _mime, filename: _filename);
      if (isClosed) return;
      emit(
        switch (result) {
          ImageSaveResult.saved => const ImageAttachmentSaved(),
          ImageSaveResult.accessDenied => const ImageAttachmentSaveAccessDenied(),
          ImageSaveResult.cancelled => const ImageAttachmentActionsIdle(),
        },
      );
    } on Object catch (cause, stackTrace) {
      if (isClosed) {
        logw("Failed to save a closed message image", cause, stackTrace);
        return;
      }
      emit(ImageAttachmentSaveFailed(cause: cause, stackTrace: stackTrace));
    }
  }

  void outcomeHandled() {
    if (state is ImageAttachmentCopied ||
        state is ImageAttachmentSaved ||
        state is ImageAttachmentSaveAccessDenied ||
        state is ImageAttachmentCopyFailed ||
        state is ImageAttachmentShareFailed ||
        state is ImageAttachmentSaveFailed) {
      emit(const ImageAttachmentActionsIdle());
    }
  }
}
