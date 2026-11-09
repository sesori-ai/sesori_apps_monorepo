import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../capabilities/server_connection/connection_service.dart";
import "../foundation/io/host_file_client.dart";
import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/image/supported_raster_image_format.dart";
import "../foundation/platform/active_bridge_locality.dart";
import "../foundation/platform/composer_file_picker.dart";
import "../logging/logging.dart";
import "../repositories/host_file_repository.dart";
import "composer_image_downscale_builder.dart";
import "models/composer_attach_outcome.dart";

/// The chosen bytes are not a recognized image format that the transcript
/// renderer can decode honestly.
final class const UnsupportedAttachmentImageError() implements Exception;

/// The image exceeds the per-prompt cap even once downscaled.
final class const _ImageTooLargeError() implements Exception;

/// Dispatches platform picks, drops, copied files and clipboard bytes through the shared
/// composer attachment validation pipeline.
@lazySingleton
class ComposerAttachmentDispatcher({
  required final ComposerFilePicker _filePicker,
  required final ComposerImageDownscaleBuilder _downscaleBuilder,
  required final HostFileRepository _hostFiles,
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _locality,
}) {
  static final _needsQuotes = RegExp(r'[\s"]');

  /// Opens the shell's picker for [source] and routes what it returns, or
  /// returns `null` when the user dismisses it.
  ///
  /// [stagedAttachmentBytes] is what the composer already holds, so
  /// attachments are staged only while they fit the rest of the prompt's
  /// attachment budget. Files the picker left out as too large count as over
  /// budget.
  Future<ComposerAttachOutcome?> pick({
    required ComposerPickSource source,
    required bool? attachmentsSupported,
    required bool? fileUploadsSupported,
    required int stagedAttachmentBytes,
  }) async {
    switch (await _filePicker.pick(source: source)) {
      case null:
        return null;
      case ComposerPickedImage(:final bytes, :final filename):
        return await routeImageBytes(
          bytes: bytes,
          filename: filename,
          source: ComposerAttachmentSource.picker,
          attachmentsSupported: attachmentsSupported,
          fileUploadsSupported: fileUploadsSupported,
          stagedAttachmentBytes: stagedAttachmentBytes,
        );
      case ComposerPickedHostPaths(:final paths, :final oversizedCount):
        final routed = await routeHostPaths(
          paths: paths,
          source: ComposerAttachmentSource.picker,
          attachmentsSupported: attachmentsSupported,
          fileUploadsSupported: fileUploadsSupported,
          stagedAttachmentBytes: stagedAttachmentBytes,
        );
        if (oversizedCount == 0) return routed;
        return ComposerAttachOutcome(
          attachments: routed.attachments,
          insertedText: routed.insertedText,
          rejections: {
            ...routed.rejections,
            ComposerAttachRejectionReason.overBudget:
                (routed.rejections[ComposerAttachRejectionReason.overBudget] ?? 0) + oversizedCount,
          },
        );
    }
  }

  /// Routes the files copied in the file manager like a drop, or returns
  /// `null` when the clipboard holds no files, so the paste falls back to an
  /// image or text.
  ///
  /// Every path must exist: a path that doesn't is not a copied file, and
  /// the clipboard's text is what the user meant to paste.
  Future<ComposerAttachOutcome?> routeClipboardPaths({
    required List<String> paths,
    required bool? attachmentsSupported,
    required bool? fileUploadsSupported,
    required int stagedAttachmentBytes,
  }) async {
    if (paths.isEmpty) return null;
    for (final hostPath in paths) {
      if (await _hostFiles.kindOf(path: hostPath) is HostOtherPath) return null;
    }
    return await routeHostPaths(
      paths: paths,
      source: ComposerAttachmentSource.paste,
      attachmentsSupported: attachmentsSupported,
      fileUploadsSupported: fileUploadsSupported,
      stagedAttachmentBytes: stagedAttachmentBytes,
    );
  }

  /// Decides what each path on this computer becomes in the composer, by the
  /// first rule that applies:
  ///
  /// 1. A supported image is staged as an image while the backend accepts
  ///    attachments and, once downscaled, it fits the rest of the budget.
  /// 2. Anything else is inserted as its path when the active bridge runs on
  ///    this computer, since the agent can read it there.
  /// 3. A regular file is staged as a file, with its original bytes, when the
  ///    bridge on another computer saves uploads and the file fits the rest of
  ///    the budget. Its size is checked before it is read.
  /// 4. Anything else is turned away, with the reason.
  ///
  /// [source] is how the paths were added, recorded on the staged files.
  Future<ComposerAttachOutcome> routeHostPaths({
    required List<String> paths,
    required ComposerAttachmentSource source,
    required bool? attachmentsSupported,
    required bool? fileUploadsSupported,
    required int stagedAttachmentBytes,
  }) async {
    final bridgeId = _connectionService.activeConfig?.bridgeId;
    final bridgeIsLocal = bridgeId != null && _locality.isLocalBridge(bridgeId: bridgeId);
    final stagesFiles = !bridgeIsLocal && (fileUploadsSupported ?? false);
    var remainingBytes = maxComposerPromptAttachmentBytes - stagedAttachmentBytes;
    final attachments = <ComposerAttachment>[];
    final insertedPaths = <String>[];
    final rejections = <ComposerAttachRejectionReason, int>{};
    for (final hostPath in paths) {
      final route = await _routeHostPath(
        hostPath: hostPath,
        source: source,
        attachmentsSupported: attachmentsSupported,
        stagesFiles: stagesFiles,
        remainingBytes: remainingBytes,
      );
      switch (route) {
        case _HostPathStaged(:final attachment):
          attachments.add(attachment);
          remainingBytes -= attachment.bytes.length;
        case _HostPathNotStaged() when bridgeIsLocal:
          insertedPaths.add(_needsQuotes.hasMatch(hostPath) ? '"${hostPath.replaceAll('"', r'\"')}"' : hostPath);
        case _HostPathNotStaged(:final reason):
          rejections.update(reason, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return ComposerAttachOutcome(
      attachments: attachments,
      insertedText: insertedPaths.isEmpty ? null : insertedPaths.join(" "),
      rejections: rejections,
    );
  }

  Future<_HostPathRoute> _routeHostPath({
    required String hostPath,
    required ComposerAttachmentSource source,
    required bool? attachmentsSupported,
    required bool stagesFiles,
    required int remainingBytes,
  }) async {
    try {
      final int sizeBytes;
      switch (await _hostFiles.kindOf(path: hostPath)) {
        case HostRegularFile(sizeBytes: final size):
          sizeBytes = size;
        case HostDirectory():
          return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.folderNotTransferable);
        case HostOtherPath():
          return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.unreadable);
      }
      final isImage = await _hostFiles.imageFormatOf(path: hostPath) != null;
      if (isImage && (attachmentsSupported ?? false)) {
        if (await _stageHostImage(hostPath: hostPath, sizeBytes: sizeBytes, remainingBytes: remainingBytes)
            case final image?) {
          return _HostPathStaged(attachment: image);
        }
        if (!stagesFiles) return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
      } else if (!stagesFiles) {
        return _HostPathNotStaged(
          reason: isImage
              ? ComposerAttachRejectionReason.attachmentsUnsupported
              : ComposerAttachRejectionReason.notTransferable,
        );
      }
      // Checked before the read, so a file that can't fit is never loaded.
      if (sizeBytes > remainingBytes) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
      }
      final bytes = await _hostFiles.readAll(path: hostPath);
      // The file can grow between the size check and the read.
      if (bytes.length > remainingBytes) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
      }
      return _HostPathStaged(
        attachment: ComposerFileAttachment(bytes: bytes, filename: path.basename(hostPath), source: source),
      );
    } on Object catch (error, stackTrace) {
      logw("Could not read $hostPath for the composer; turning it away", error, stackTrace);
      return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.unreadable);
    }
  }

  /// The image at [hostPath], downscaled, or null when even downscaled it
  /// doesn't fit [remainingBytes].
  Future<ComposerAttachment?> _stageHostImage({
    required String hostPath,
    required int sizeBytes,
    required int remainingBytes,
  }) async {
    // A file above the per-prompt cap is never read: downscaling only starts
    // from bytes that could have been sent as they are, so a huge file is
    // never loaded whole.
    if (sizeBytes > maxComposerPromptAttachmentBytes) return null;
    try {
      // Downscaled first, so a large image that shrinks to fit still stages.
      final image = await _imageFromBytes(
        bytes: await _hostFiles.readAll(path: hostPath),
        filename: path.basename(hostPath),
      );
      return image.bytes.length > remainingBytes ? null : image;
    } on _ImageTooLargeError {
      return null;
    }
  }

  /// Decides what image bytes handed over without a path become: a photo from
  /// the gallery picker, or an image pasted from the clipboard, which has no
  /// [filename].
  ///
  /// They are staged as a downscaled image when the harness takes images, and
  /// otherwise as a file with their original bytes when the bridge saves
  /// uploads, named after the picked file or `pasted-image.<ext>`. Throws
  /// [UnsupportedAttachmentImageError] when the bytes are not a supported
  /// image and an image, or a name for them, is needed. [source] is how the
  /// bytes were added, recorded when they are staged as a file.
  Future<ComposerAttachOutcome> routeImageBytes({
    required Uint8List bytes,
    required String? filename,
    required ComposerAttachmentSource source,
    required bool? attachmentsSupported,
    required bool? fileUploadsSupported,
    required int stagedAttachmentBytes,
  }) async {
    final ComposerAttachment attachment;
    if (attachmentsSupported ?? false) {
      try {
        attachment = await _imageFromBytes(bytes: bytes, filename: filename);
      } on _ImageTooLargeError {
        return _rejected(reason: ComposerAttachRejectionReason.overBudget);
      }
    } else if (fileUploadsSupported ?? false) {
      attachment = ComposerFileAttachment(
        bytes: bytes,
        filename: _nameOf(filename: filename) ?? _pastedImageName(bytes: bytes),
        source: source,
      );
    } else {
      return _rejected(reason: ComposerAttachRejectionReason.attachmentsUnsupported);
    }
    if (attachment.bytes.length > maxComposerPromptAttachmentBytes - stagedAttachmentBytes) {
      return _rejected(reason: ComposerAttachRejectionReason.overBudget);
    }
    return ComposerAttachOutcome(attachments: [attachment], insertedText: null, rejections: const {});
  }

  static ComposerAttachOutcome _rejected({required ComposerAttachRejectionReason reason}) =>
      ComposerAttachOutcome(attachments: const [], insertedText: null, rejections: {reason: 1});

  static String? _nameOf({required String? filename}) {
    final trimmed = filename?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _pastedImageName({required Uint8List bytes}) {
    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == null) throw const UnsupportedAttachmentImageError();
    return "pasted-image${format.filenameExtension}";
  }

  /// Validates [bytes] as a supported image and shrinks an oversized one
  /// before the transport limit is checked, so a large screenshot can still
  /// fit once downscaled.
  Future<ComposerImageAttachment> _imageFromBytes({
    required Uint8List bytes,
    required String? filename,
  }) async {
    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == null) throw const UnsupportedAttachmentImageError();

    final name = _nameOf(filename: filename);
    final original = ComposerImageAttachment(
      mime: format.mime,
      bytes: bytes,
      filename: name,
    );
    final ComposerImageAttachment attachment;
    switch (await _downscaleBuilder.downscale(bytes: bytes, format: format)) {
      case ComposerImageDownscaled(bytes: final downscaled):
        const jpeg = SupportedRasterImageFormat.jpeg;
        attachment = ComposerImageAttachment(
          mime: jpeg.mime,
          bytes: downscaled,
          filename: name == null ? null : path.setExtension(name, jpeg.filenameExtension),
        );
      case ComposerImageKept():
        attachment = original;
      case ComposerImageDownscaleFailed(:final cause, :final stackTrace):
        logw("Downscaling a ${format.mime} composer image failed; staging the original", cause, stackTrace);
        attachment = original;
    }

    if (attachment.bytes.length > maxComposerPromptAttachmentBytes) {
      throw const _ImageTooLargeError();
    }
    return attachment;
  }
}

sealed class const _HostPathRoute();

final class const _HostPathStaged({required final ComposerAttachment attachment}) extends _HostPathRoute;

final class const _HostPathNotStaged({required final ComposerAttachRejectionReason reason}) extends _HostPathRoute;
