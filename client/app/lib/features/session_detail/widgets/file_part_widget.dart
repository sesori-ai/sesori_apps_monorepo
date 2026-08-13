import "dart:async";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/external_link.dart";
import "image_attachment_viewer.dart";

class const FilePartWidget({
  super.key,
  required final String sessionId,
  required final MessageAttachment attachment,
}) extends StatelessWidget {
  static const previewImageKey = ValueKey("filePartWidget.previewImage");
  static const previewTapTargetKey = ValueKey("filePartWidget.previewTapTarget");

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey((sessionId, attachment)),
      create: (_) => MessageImageCubit(
        repository: getIt<MessageImageRepository>(),
        sessionId: sessionId,
        attachment: attachment,
      ),
      child: _FilePartContent(attachment: attachment),
    );
  }
}

class const _FilePartContent({required final MessageAttachment attachment}) extends StatelessWidget {
  static const _maxMetadataCharacters = 255;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MessageImageCubit>().state;
    return switch (state.preview) {
      MessageImagePreviewLoading() => _buildLoadingAttachment(context: context),
      MessageImagePreviewLoaded(:final bytes, :final mime, :final actionFilename, :final originalUri) =>
        _LoadedImageAttachment(
          bytes: bytes,
          mime: mime,
          actionFilename: actionFilename,
          originalUri: originalUri,
          filename: _displayFilename(filename: _attachmentFilename),
        ),
      MessageImagePreviewUnsupported() => _buildFallbackAttachment(
        context: context,
        imageLoadFailed: false,
        retryable: false,
      ),
      MessageImagePreviewRejected() || MessageImagePreviewFailed() => _buildFallbackAttachment(
        context: context,
        imageLoadFailed: true,
        retryable: true,
      ),
    };
  }

  String? get _attachmentFilename => switch (attachment) {
    MessageAttachmentInlineImage(:final filename) ||
    MessageAttachmentRemoteUrl(:final filename) ||
    MessageAttachmentStoredImage(:final filename) ||
    MessageAttachmentMetadata(:final filename) => filename,
    MessageAttachmentUnknown() => null,
  };

  Widget _buildLoadingAttachment({required BuildContext context}) {
    return switch (attachment) {
      MessageAttachmentInlineImage(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.image_outlined,
        loading: true,
        retryable: false,
      ),
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: attachment.safeRemoteUri,
        icon: Icons.image_outlined,
        loading: true,
        retryable: false,
      ),
      MessageAttachmentStoredImage(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.image_outlined,
        loading: true,
        retryable: false,
      ),
      MessageAttachmentMetadata() || MessageAttachmentUnknown() => _buildFallbackAttachment(
        context: context,
        imageLoadFailed: false,
        retryable: false,
      ),
    };
  }

  Widget _buildFallbackAttachment({
    required BuildContext context,
    required bool imageLoadFailed,
    required bool retryable,
  }) {
    return switch (attachment) {
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: attachment.safeRemoteUri,
        icon: imageLoadFailed ? Icons.broken_image : Icons.insert_drive_file,
        loading: false,
        retryable: retryable,
      ),
      MessageAttachmentMetadata(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.insert_drive_file,
        loading: false,
        retryable: false,
      ),
      MessageAttachmentStoredImage(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: imageLoadFailed ? Icons.broken_image : Icons.insert_drive_file,
        loading: false,
        retryable: retryable,
      ),
      MessageAttachmentInlineImage(:final mime, :final filename) => _buildFileTile(
        context: context,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.broken_image,
        loading: false,
        retryable: retryable,
      ),
      MessageAttachmentUnknown() => const SizedBox.shrink(),
    };
  }

  String? _displayFilename({required String? filename}) {
    final normalized = filename?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return String.fromCharCodes(normalized.runes.take(_maxMetadataCharacters));
  }

  String? _displayMime({required String mime}) {
    final normalized = mime.trim();
    if (normalized.isEmpty) return null;
    return String.fromCharCodes(normalized.runes.take(_maxMetadataCharacters));
  }

  Widget _buildFileTile({
    required BuildContext context,
    required String? filename,
    required String? mime,
    required Uri? uri,
    required IconData icon,
    required bool loading,
    required bool retryable,
  }) {
    final prego = context.prego;
    final onTap = uri == null ? null : () => unawaited(openExternalLink(url: uri, mode: UrlLaunchMode.externalApp));
    final label = filename ?? mime ?? context.loc.sessionDetailAttachedImage;
    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(prego.radius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: prego.colors.bgSurface2,
                  child: Center(
                    child: loading
                        ? PregoActivityIndicator(color: prego.colors.textSecondary)
                        : Icon(icon, size: prego.spacing.x6l, color: prego.colors.textSecondary),
                  ),
                ),
                _AttachmentMetadataOverlay(filename: filename, mime: mime),
                if (retryable)
                  Center(
                    child: Semantics(
                      button: true,
                      label: context.loc.sessionDetailRetry,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => unawaited(context.read<MessageImageCubit>().retryPreview()),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: prego.colors.bgSurface1.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(prego.radius.full),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: prego.spacing.lg,
                              vertical: prego.spacing.sm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: prego.spacing.x2l, color: prego.colors.textPrimary),
                                SizedBox(width: prego.spacing.xs),
                                Text(context.loc.sessionDetailRetry, style: prego.textTheme.textXs.medium),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (uri != null)
                  PositionedDirectional(
                    top: prego.spacing.md,
                    end: prego.spacing.md,
                    child: Icon(Icons.open_in_new, size: prego.spacing.x2l, color: prego.colors.textPrimary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class const _AttachmentMetadataOverlay({required final String? filename, required final String? mime})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (filename == null && mime == null) return const SizedBox.shrink();
    final prego = context.prego;
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            prego.spacing.md,
            prego.spacing.x4l,
            prego.spacing.md,
            prego.spacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filename != null)
                  Text(
                    filename!,
                    style: prego.textTheme.textXs.medium.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (mime != null)
                  Text(
                    mime!,
                    style: prego.textTheme.textXs.regular.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class const _LoadedImageAttachment({
  required final Uint8List bytes,
  required final String mime,
  required final String actionFilename,
  required final Uri? originalUri,
  required final String? filename,
}) extends StatefulWidget {
  @override
  State<_LoadedImageAttachment> createState() => _LoadedImageAttachmentState();
}

class _LoadedImageAttachmentState() extends State<_LoadedImageAttachment> {
  static const _maxDecodedImageDimension = 2048;

  final _heroTag = UniqueKey();
  late LoadedMessageImage _image;
  bool _isDecoded = false;

  @override
  void initState() {
    super.initState();
    _refreshImage();
  }

  @override
  void didUpdateWidget(covariant _LoadedImageAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.mime != widget.mime ||
        oldWidget.actionFilename != widget.actionFilename ||
        oldWidget.originalUri != widget.originalUri) {
      _refreshImage();
    }
  }

  void _refreshImage() {
    _isDecoded = false;
    _image = LoadedMessageImage(
      bytes: widget.bytes,
      provider: ResizeImage(
        MemoryImage(widget.bytes),
        width: _maxDecodedImageDimension,
        height: _maxDecodedImageDimension,
        policy: ResizeImagePolicy.fit,
      ),
      mime: widget.mime,
      actionFilename: widget.actionFilename,
      originalUri: widget.originalUri,
    );
  }

  void _markImageDecoded() {
    if (_isDecoded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDecoded) setState(() => _isDecoded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Semantics(
      button: _isDecoded,
      label: context.loc.sessionDetailImageOpen,
      child: GestureDetector(
        key: FilePartWidget.previewTapTargetKey,
        behavior: HitTestBehavior.opaque,
        onTap: !_isDecoded
            ? null
            : () => unawaited(
                showImageAttachmentViewer(
                  context: context,
                  image: _image,
                  filename: widget.filename,
                  heroTag: _heroTag,
                ),
              ),
        child: Hero(
          tag: _heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(prego.radius.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    key: FilePartWidget.previewImageKey,
                    image: _image.provider,
                    fit: BoxFit.cover,
                    semanticLabel: widget.filename ?? context.loc.sessionDetailAttachedImage,
                    frameBuilder: (_, child, frame, _) {
                      if (frame != null) _markImageDecoded();
                      return child;
                    },
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image,
                      size: prego.spacing.x6l,
                      color: prego.colors.textTertiary,
                    ),
                  ),
                  _AttachmentMetadataOverlay(filename: widget.filename, mime: widget.mime),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
