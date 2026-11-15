import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/composer/composer_draft.dart";
import "../foundation/models/composer/restored_composer.dart";
import "../foundation/models/file_preview/file_preview_result.dart";
import "../logging/logging.dart";
import "../repositories/file_preview_repository.dart";
import "../repositories/message_image_repository.dart";

/// Brings a sent user message back into a composer: its text, its images and
/// the files the bridge saved for it, each of which the user can remove again
/// before sending.
@lazySingleton
class MessageComposerRestoreService({
  required final MessageImageRepository _images,
  required final FilePreviewRepository _filePreviews,
}) {
  /// Restores [message] of [sessionId].
  ///
  /// Its text loses the saved-file notes, and each note becomes a
  /// [ComposerHostFileAttachment], so the bridge sends the file it already
  /// holds again. Each image is fetched again into a [ComposerImageAttachment].
  /// An attachment the bridge can no longer serve is left out and counted.
  Future<RestoredComposer> restore({required String sessionId, required MessageWithParts message}) async {
    final split = splitSavedFileNotes(
      text: message.parts.whereType<MessagePartText>().map((part) => part.text).join("\n"),
    );
    final files = [
      for (final part in message.parts)
        if (part case MessagePartFile(:final attachment) when attachment is! MessageAttachmentUnknown) attachment,
    ];
    final (images, savedFiles) = await (
      Future.wait([for (final attachment in files) _restoreImage(sessionId: sessionId, attachment: attachment)]),
      Future.wait([for (final note in split.notes) _restoreSavedFile(note: note)]),
    ).wait;
    final attachments = <ComposerAttachment>[...images.nonNulls, ...savedFiles.nonNulls];
    return RestoredComposer(
      draft: ComposerDraft.typed(text: split.text),
      attachments: List.unmodifiable(attachments),
      leftOutCount: files.length + split.notes.length - attachments.length,
    );
  }

  Future<ComposerImageAttachment?> _restoreImage({
    required String sessionId,
    required MessageAttachment attachment,
  }) async {
    final result = await _images.loadWhole(sessionId: sessionId, attachment: attachment);
    switch (result) {
      case MessageImageLoadSuccess(:final bytes, :final mime):
        return ComposerImageAttachment(
          mime: mime,
          bytes: bytes,
          filename: _filenameOf(attachment: attachment),
        );
      case MessageImageLoadFailure(:final cause, :final stackTrace):
        logw("Could not fetch an image of a message in $sessionId again; leaving it out", cause, stackTrace);
        return null;
      case MessageImageLoadUnsupported() || MessageImageLoadRejected():
        return null;
    }
  }

  /// The saved file a note names, unless the bridge reports it gone. Its path
  /// is on the bridge's computer, so only the bridge can tell.
  Future<ComposerHostFileAttachment?> _restoreSavedFile({required SavedFileNote note}) async {
    final preview = await _filePreviews.load(path: note.path);
    switch (preview) {
      case FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.missing):
        return null;
      case FilePreviewFailed(:final innerError, :final stackTrace):
        // Unknown rather than gone, so it stays: at worst the agent finds no
        // file at the path.
        logw("Could not check a saved file of a message; keeping it", innerError, stackTrace);
      case FilePreviewTextContent() ||
          FilePreviewImageContent() ||
          FilePreviewPdfContent() ||
          FilePreviewContentUnavailable() ||
          FilePreviewBridgeTooOld():
        break;
    }
    return ComposerHostFileAttachment(path: note.path, filename: note.name);
  }

  static String? _filenameOf({required MessageAttachment attachment}) {
    final filename = switch (attachment) {
      MessageAttachmentInlineImage(:final filename) ||
      MessageAttachmentRemoteUrl(:final filename) ||
      MessageAttachmentStoredImage(:final filename) ||
      MessageAttachmentMetadata(:final filename) => filename?.trim(),
      MessageAttachmentUnknown() => null,
    };
    return filename == null || filename.isEmpty ? null : filename;
  }
}
