import "dart:async";
import "dart:typed_data";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
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
      MessageImagePreviewUnsupported() => _buildFallbackAttachment(context: context, imageLoadFailed: false),
      MessageImagePreviewRejected() || MessageImagePreviewFailed() => _buildFallbackAttachment(
        context: context,
        imageLoadFailed: true,
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
    final prego = context.prego;
    return switch (attachment) {
      MessageAttachmentInlineImage(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.image_outlined,
      ),
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: attachment.safeRemoteUri,
        icon: Icons.image_outlined,
      ),
      MessageAttachmentStoredImage() ||
      MessageAttachmentMetadata() ||
      MessageAttachmentUnknown() => _buildFallbackAttachment(
        context: context,
        imageLoadFailed: false,
      ),
    };
  }

  Widget _buildFallbackAttachment({
    required BuildContext context,
    required bool imageLoadFailed,
  }) {
    final prego = context.prego;
    return switch (attachment) {
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: attachment.safeRemoteUri,
        icon: imageLoadFailed ? Icons.broken_image : Icons.insert_drive_file,
      ),
      MessageAttachmentMetadata(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.insert_drive_file,
      ),
      MessageAttachmentStoredImage(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.insert_drive_file,
      ),
      MessageAttachmentInlineImage(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.broken_image,
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
    required PregoDesignSystem prego,
    required String? filename,
    required String? mime,
    required Uri? uri,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: prego.spacing.xs),
      child: Semantics(
        button: uri != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: uri == null ? null : () => unawaited(openExternalLink(url: uri, mode: UrlLaunchMode.externalApp)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: prego.spacing.lg, vertical: prego.spacing.md),
            decoration: BoxDecoration(
              color: prego.colors.bgSurface2,
              borderRadius: BorderRadius.circular(prego.radius.md),
            ),
            child: Row(
              children: [
                Icon(icon, size: prego.spacing.x3l, color: prego.colors.textSecondary),
                SizedBox(width: prego.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (filename != null)
                        Text(filename, style: prego.textTheme.textSm.regular, overflow: TextOverflow.ellipsis),
                      if (mime != null)
                        Text(
                          mime,
                          style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (uri != null) Icon(Icons.open_in_new, size: prego.spacing.x2l, color: prego.colors.textSecondary),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: prego.spacing.md),
      child: Semantics(
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
              borderRadius: BorderRadius.circular(prego.radius.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: prego.spacing.x6l,
                  minHeight: prego.spacing.x6l,
                  maxHeight: prego.widths.xxs,
                ),
                child: Image(
                  key: FilePartWidget.previewImageKey,
                  image: _image.provider,
                  fit: BoxFit.contain,
                  semanticLabel: widget.filename,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
