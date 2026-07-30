import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/external_link.dart";

Uint8List? _tryDecodeBase64Image(String base64Data) {
  try {
    return base64Decode(base64Data);
  } on FormatException {
    return null;
  }
}

class FilePartWidget extends StatefulWidget {
  final MessageAttachment attachment;

  const FilePartWidget({super.key, required this.attachment});

  @override
  State<FilePartWidget> createState() => _FilePartWidgetState();
}

class _FilePartWidgetState extends State<FilePartWidget> {
  static const _maxDecodedImageDimension = 2048;
  static const _maxMetadataCharacters = 255;

  Future<Uint8List?>? _imageBytes;

  @override
  void initState() {
    super.initState();
    _refreshImage();
  }

  @override
  void didUpdateWidget(covariant FilePartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment != widget.attachment) _refreshImage();
  }

  void _refreshImage() {
    final attachment = widget.attachment;
    if (attachment case MessageAttachmentInlineImage(:final base64)) {
      if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64.length)) {
        logw("Ignoring an oversized inline message attachment");
        _imageBytes = Future<Uint8List?>.value();
        return;
      }
      _imageBytes = _decodeInlineImage(base64Data: base64);
      return;
    }
    _imageBytes = null;
  }

  Future<Uint8List?> _decodeInlineImage({required String base64Data}) async {
    try {
      return await compute(_tryDecodeBase64Image, base64Data);
    } on Object catch (error, stackTrace) {
      logw("Could not decode an inline message attachment", error, stackTrace);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return switch (widget.attachment) {
      MessageAttachmentInlineImage(:final mime, :final filename) => _buildInlineImage(
        prego: prego,
        mime: _displayMime(mime: mime),
        filename: _displayFilename(context: context, filename: filename),
      ),
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(context: context, filename: filename),
        mime: _displayMime(mime: mime),
        uri: widget.attachment.safeRemoteUri,
        icon: Icons.insert_drive_file,
      ),
      MessageAttachmentMetadata(:final mime, :final filename) => _buildFileTile(
        prego: prego,
        filename: _displayFilename(context: context, filename: filename),
        mime: _displayMime(mime: mime),
        uri: null,
        icon: Icons.insert_drive_file,
      ),
      MessageAttachmentUnknown() => const SizedBox.shrink(),
    };
  }

  String _displayFilename({required BuildContext context, required String? filename}) {
    final normalized = filename?.trim();
    if (normalized == null || normalized.isEmpty) return context.loc.sessionDetailFileUnknown;
    return String.fromCharCodes(normalized.runes.take(_maxMetadataCharacters));
  }

  String? _displayMime({required String mime}) {
    final normalized = mime.trim();
    if (normalized.isEmpty) return null;
    return String.fromCharCodes(normalized.runes.take(_maxMetadataCharacters));
  }

  Widget _buildInlineImage({
    required PregoDesignSystem prego,
    required String? mime,
    required String filename,
  }) {
    final imageBytes = _imageBytes;
    if (imageBytes == null) {
      return _buildFileTile(
        prego: prego,
        filename: filename,
        mime: mime,
        uri: null,
        icon: Icons.broken_image,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: imageBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildFileTile(
            prego: prego,
            filename: filename,
            mime: mime,
            uri: null,
            icon: Icons.image_outlined,
          );
        }
        if (bytes == null) {
          return _buildFileTile(
            prego: prego,
            filename: filename,
            mime: mime,
            uri: null,
            icon: Icons.broken_image,
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: prego.spacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(prego.radius.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: prego.widths.xxs),
              child: Image(
                image: ResizeImage(
                  MemoryImage(bytes),
                  width: _maxDecodedImageDimension,
                  height: _maxDecodedImageDimension,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                semanticLabel: filename,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image,
                  size: prego.spacing.x6l,
                  color: prego.colors.textTertiary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileTile({
    required PregoDesignSystem prego,
    required String filename,
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
          onTap: uri == null ? null : () => unawaited(openExternalLink(url: uri)),
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
