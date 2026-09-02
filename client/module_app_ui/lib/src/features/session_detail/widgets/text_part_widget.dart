import "dart:async";

import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart"
    show isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_markdown_link_handler.dart";
import "image_attachment_viewer.dart";

class const TextPartWidget({
  super.key,
  required final String text,
  final bool isStreaming = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MarkdownBody(
        data: text,
        selectable: false,
        onTapLink: buildSessionDetailMarkdownLinkTapHandler(context: context),
        imageBuilder: (uri, title, alt) => MarkdownMessageImage(
          uri: uri,
          semanticLabel: alt,
        ),
        styleSheet: buildSessionMarkdownStyleSheet(prego: context.prego),
        blockSyntaxes: sessionMarkdownBlockSyntaxes,
        builders: buildSessionMarkdownBuilders(
          highlightEnabled: !isStreaming,
          copyTooltip: context.loc.sessionDetailCopy,
        ),
      ),
    );
  }
}

class const MarkdownMessageImage({
  super.key,
  required final Uri uri,
  required final String? semanticLabel,
}) extends StatefulWidget {
  @override
  State<MarkdownMessageImage> createState() => _MarkdownMessageImageState();
}

class _MarkdownMessageImageState() extends State<MarkdownMessageImage> {
  static const _maxDecodedImageDimension = 2048;

  final _heroTag = UniqueKey();
  late ImageProvider? _provider;
  bool _isDecoded = false;

  @override
  void initState() {
    super.initState();
    _provider = _imageProvider(uri: widget.uri);
  }

  @override
  void didUpdateWidget(covariant MarkdownMessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _provider = _imageProvider(uri: widget.uri);
      _isDecoded = false;
    }
  }

  ImageProvider? _imageProvider({required Uri uri}) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == "http" || scheme == "https") && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
      return _boundedProvider(provider: NetworkImage(uri.toString()));
    }
    if (scheme == "resource" && uri.path.isNotEmpty) {
      return _boundedProvider(provider: AssetImage(uri.path));
    }
    if (scheme != "data") return null;

    try {
      final data = uri.data;
      if (data == null || !data.mimeType.toLowerCase().startsWith("image/")) return null;
      final encoded = uri.toString();
      final separator = encoded.indexOf(",");
      if (separator < 0) return null;
      final encodedDataLength = encoded.length - separator - 1;
      final isWithinEncodedLimit = data.isBase64
          ? isInlineMessageAttachmentWithinSizeLimit(base64Length: encodedDataLength)
          : encodedDataLength <= maxInlineMessageAttachmentBytes * 3;
      if (!isWithinEncodedLimit) return null;

      final bytes = data.contentAsBytes();
      if (bytes.length > maxInlineMessageAttachmentBytes) return null;
      return _boundedProvider(provider: MemoryImage(bytes));
    } on FormatException {
      return null;
    }
  }

  ImageProvider _boundedProvider({required ImageProvider provider}) {
    return ResizeImage(
      provider,
      width: _maxDecodedImageDimension,
      height: _maxDecodedImageDimension,
      policy: ResizeImagePolicy.fit,
    );
  }

  void _markDecoded() {
    if (_isDecoded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDecoded) setState(() => _isDecoded = true);
    });
  }

  String? get _displayFilename {
    final scheme = widget.uri.scheme.toLowerCase();
    if (scheme != "http" && scheme != "https") return null;
    final segments = widget.uri.pathSegments;
    if (segments.isEmpty) return null;
    final filename = segments.last.trim();
    if (filename.isEmpty) return null;
    return String.fromCharCodes(filename.runes.take(255));
  }

  Uri? get _originalUri {
    final scheme = widget.uri.scheme.toLowerCase();
    return scheme == "http" || scheme == "https" ? widget.uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return Icon(
        Icons.broken_image,
        size: context.prego.spacing.x6l,
        color: context.prego.colors.textTertiary,
      );
    }

    return Semantics(
      button: _isDecoded,
      label: context.loc.sessionDetailImageOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !_isDecoded
            ? null
            : () => unawaited(
                showImageAttachmentViewer(
                  context: context,
                  image: ViewOnlyMessageImage(
                    provider: provider,
                    originalUri: _originalUri,
                  ),
                  heroPresentation: ImageAttachmentHeroPresentation.contained,
                  filename: _displayFilename,
                  heroTag: _heroTag,
                ),
              ),
        child: Hero(
          tag: _heroTag,
          child: Image(
            image: provider,
            semanticLabel: widget.semanticLabel,
            frameBuilder: (_, child, frame, _) {
              if (frame != null) _markDecoded();
              return child;
            },
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image,
              size: context.prego.spacing.x6l,
              color: context.prego.colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
