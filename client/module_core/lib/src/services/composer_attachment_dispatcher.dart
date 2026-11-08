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
import "composer_image_downscale_builder.dart";
import "models/composer_attach_outcome.dart";

/// The chosen bytes are not a recognized image format that the transcript
/// renderer can decode honestly.
final class const UnsupportedAttachmentImageError() implements Exception;

/// Dispatches platform picks, drops and clipboard bytes through the shared
/// composer attachment validation pipeline.
@lazySingleton
class ComposerAttachmentDispatcher({
  required final ComposerFilePicker _filePicker,
  required final ComposerImageDownscaleBuilder _downscaleBuilder,
  required final HostFileClient _fileClient,
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _locality,
}) {
  /// Enough bytes for every supported raster signature.
  static const _headerBytes = 16;
  static final _needsQuotes = RegExp(r'[\s"]');

  /// Opens the shell's picker and routes what it returns, or returns `null`
  /// when the user dismisses it.
  ///
  /// [stagedAttachmentBytes] is what the composer already holds, so images are
  /// staged only while they fit the rest of the prompt's attachment budget.
  Future<ComposerAttachOutcome?> pick({
    required bool? attachmentsSupported,
    required int stagedAttachmentBytes,
  }) async {
    switch (await _filePicker.pick()) {
      case null:
        return null;
      case ComposerPickedImage(:final bytes, :final filename):
        final attachment = await attachmentFromBytes(bytes: bytes, filename: filename);
        return ComposerAttachOutcome(attachments: [attachment], insertedText: null, rejections: const {});
      case ComposerPickedHostPaths(:final paths):
        return await routeHostPaths(
          paths: paths,
          attachmentsSupported: attachmentsSupported,
          stagedAttachmentBytes: stagedAttachmentBytes,
        );
    }
  }

  /// Decides what each path on this computer becomes in the composer.
  ///
  /// A supported image is staged while the backend accepts attachments and,
  /// once downscaled, it fits the rest of the budget. Anything else is inserted as its path when
  /// the active bridge runs on this computer, since the agent can read it
  /// there, and is otherwise turned away: nothing but images can reach another
  /// computer yet.
  Future<ComposerAttachOutcome> routeHostPaths({
    required List<String> paths,
    required bool? attachmentsSupported,
    required int stagedAttachmentBytes,
  }) async {
    final bridgeId = _connectionService.activeConfig?.bridgeId;
    final bridgeIsLocal = bridgeId != null && _locality.isLocalBridge(bridgeId: bridgeId);
    var remainingBytes = maxComposerPromptAttachmentBytes - stagedAttachmentBytes;
    final attachments = <ComposerAttachment>[];
    final insertedPaths = <String>[];
    final rejections = <ComposerAttachRejectionReason, int>{};
    for (final hostPath in paths) {
      final route = await _routeHostPath(
        hostPath: hostPath,
        attachmentsSupported: attachmentsSupported,
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
    required bool? attachmentsSupported,
    required int remainingBytes,
  }) async {
    try {
      final int sizeBytes;
      switch (await _fileClient.kindOf(path: hostPath)) {
        case HostRegularFile(sizeBytes: final size):
          sizeBytes = size;
        case HostDirectory() || HostOtherPath():
          return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.notTransferable);
      }
      final header = await _fileClient.readHeader(path: hostPath, length: _headerBytes);
      if (detectSupportedRasterImageFormat(bytes: header) == null) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.notTransferable);
      }
      if (attachmentsSupported != true) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.attachmentsUnsupported);
      }
      // A file above the per-prompt cap is never read: downscaling only
      // starts from bytes that could have been sent as they are, so a huge
      // file is never loaded whole.
      if (sizeBytes > maxComposerPromptAttachmentBytes) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
      }
      // Downscaled first, so a large image that shrinks to fit still stages.
      final attachment = await attachmentFromBytes(
        bytes: await _fileClient.readAll(path: hostPath),
        filename: path.basename(hostPath),
      );
      if (attachment.bytes.length > remainingBytes) {
        return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
      }
      return _HostPathStaged(attachment: attachment);
    } on AttachmentTooLargeError {
      return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.overBudget);
    } on Object catch (error, stackTrace) {
      logw("Could not read $hostPath as a composer image; treating it as a plain file", error, stackTrace);
      return const _HostPathNotStaged(reason: ComposerAttachRejectionReason.notTransferable);
    }
  }

  /// Validates [bytes] as a supported image and shrinks an oversized one
  /// before the transport limit is checked, so a large screenshot can still
  /// fit once downscaled.
  Future<ComposerAttachment> attachmentFromBytes({
    required Uint8List bytes,
    required String? filename,
  }) async {
    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == null) throw const UnsupportedAttachmentImageError();

    final trimmedName = filename?.trim();
    final name = trimmedName == null || trimmedName.isEmpty ? null : trimmedName;
    final original = ComposerAttachment(mime: format.mime, bytes: bytes, filename: name);
    final ComposerAttachment attachment;
    switch (await _downscaleBuilder.downscale(bytes: bytes, format: format)) {
      case ComposerImageDownscaled(bytes: final downscaled):
        const jpeg = SupportedRasterImageFormat.jpeg;
        attachment = ComposerAttachment(
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
      throw const AttachmentTooLargeError();
    }
    return attachment;
  }
}

sealed class const _HostPathRoute();

final class const _HostPathStaged({required final ComposerAttachment attachment}) extends _HostPathRoute;

final class const _HostPathNotStaged({required final ComposerAttachRejectionReason reason}) extends _HostPathRoute;
