import "dart:async";
import "dart:math" as math;

import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/code_highlighter.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "../widgets/image_attachment_viewer.dart";

typedef FilePreviewCubitFactory = FilePreviewCubit Function({required FileReference reference});

const _openDuration = Duration(milliseconds: 320);
const _closeDuration = Duration(milliseconds: 240);
const _contentDuration = Duration(milliseconds: 200);
const _headerHeight = 52.0;

/// Text up to this many characters is syntax highlighted; larger files show
/// as plain text so opening them stays quick.
const _maxHighlightedLength = 200 * 1024;

/// Slides [reference]'s preview up over the session. Its cubit comes from the
/// session's [SessionDetailPresentationScope] and lives as long as the route.
Future<void> showFilePreview({required BuildContext context, required FileReference reference}) {
  final scope = SessionDetailPresentationScope.read(context);
  final reducedMotion = context.isReducedMotion;
  // ignore: no_slop_linter/avoid_navigator_of, the preview is a transient route over the session page
  final navigator = Navigator.of(context);
  final route = PageRouteBuilder<void>(
    transitionDuration: reducedMotion ? Duration.zero : _openDuration,
    reverseTransitionDuration: reducedMotion ? Duration.zero : _closeDuration,
    pageBuilder: (_, _, _) => scope.around(
      openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {
        navigator.pop();
        scope.openSession(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly);
      },
      child: BlocProvider(
        create: (_) => scope.createFilePreviewCubit(reference: reference),
        child: FilePreviewScreen(reference: reference, onClose: navigator.pop),
      ),
    ),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      ),
      child: child,
    ),
  );
  // ignore: no_slop_linter/avoid_raw_go_router, the preview carries an in-memory cubit that cannot be represented in a URL
  return navigator.push<void>(route);
}

/// A read-only view of one file from the bridge's computer: highlighted text
/// with line numbers, rendered Markdown with a source toggle, or an image in
/// the image viewer. Every other outcome is a one-line message.
class const FilePreviewScreen({
  super.key,
  required final FileReference reference,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState() extends State<FilePreviewScreen> {
  /// A Markdown file opens formatted, unless the reference names a line,
  /// which only its source can show.
  late bool _showsSource = widget.reference.line != null;

  bool get _isMarkdown {
    final name = widget.reference.fileName.toLowerCase();
    return name.endsWith(".md") || name.endsWith(".markdown");
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final state = context.watch<FilePreviewCubit>().state;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                reference: widget.reference,
                onClose: widget.onClose,
                actions: [
                  if (state case FilePreviewShowsText(:final content)) ...[
                    if (_isMarkdown)
                      IconButton(
                        key: const Key("file-preview-source-toggle"),
                        tooltip: _showsSource
                            ? context.loc.filePreviewShowFormatted
                            : context.loc.filePreviewShowSource,
                        icon: Icon(_showsSource ? TablerRegular.markdown : TablerRegular.code, size: PregoIconSize.md),
                        onPressed: () => setState(() => _showsSource = !_showsSource),
                      ),
                    PregoCopyIconButton(
                      tooltip: context.loc.sessionDetailCopy,
                      iconSize: PregoIconSize.md,
                      onCopy: () => copyTextToClipboard(text: content, operation: "file preview"),
                    ),
                  ],
                ],
              ),
              Divider(height: 1, thickness: 1, color: prego.colors.borderSecondary),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.isReducedMotion ? Duration.zero : _contentDuration,
                  // Each view fills the page, so text starts at the top and edges.
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey((state.runtimeType, _showsSource)),
                    child: _body(state: state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body({required FilePreviewState state}) => switch (state) {
    FilePreviewLoading() => const Center(child: PregoActivityIndicator(color: null)),
    FilePreviewShowsText(:final content) when _isMarkdown && !_showsSource => _MarkdownPreview(content: content),
    FilePreviewShowsText(:final content) => _CodePreview(
      content: content,
      language: _languageOf(fileName: widget.reference.fileName),
      line: widget.reference.line,
    ),
    FilePreviewShowsImage(:final bytes, :final mime) => _ImagePreview(
      image: LoadedMessageImage(
        bytes: bytes,
        provider: MemoryImage(bytes),
        mime: mime,
        actionFilename: widget.reference.fileName,
        originalUri: null,
      ),
      fileName: widget.reference.fileName,
    ),
    FilePreviewUnavailable(:final reason) => _UnavailableMessage(reason: reason),
  };

  static String? _languageOf({required String fileName}) {
    final dot = fileName.lastIndexOf(".");
    return dot < 0 ? null : fileName.substring(dot + 1);
  }
}

class const _Header({
  required final FileReference reference,
  required final VoidCallback onClose,
  required final List<Widget> actions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final padding = MediaQuery.paddingOf(context);
    return Container(
      constraints: BoxConstraints(minHeight: padding.top + _headerHeight),
      padding: EdgeInsetsDirectional.only(top: padding.top, start: PregoSpacing.xs, end: PregoSpacing.sm),
      alignment: Alignment.center,
      child: Row(
        children: [
          IconButton(
            key: const Key("file-preview-close"),
            tooltip: context.loc.filePreviewClose,
            icon: const Icon(TablerRegular.chevron_down, size: PregoIconSize.md),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reference.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
                ),
                Text(
                  reference.absolutePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                ),
              ],
            ),
          ),
          // The text's actions fade in with it rather than popping in.
          AnimatedSwitcher(
            duration: context.isReducedMotion ? Duration.zero : _contentDuration,
            child: Row(key: ValueKey(actions.length), mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      ),
    );
  }
}

class const _MarkdownPreview({required final String content}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scope = SessionDetailPresentationScope.read(context);
    return PregoReadableSelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          PregoSpacing.lg,
          PregoSpacing.lg,
          PregoSpacing.lg,
          PregoSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: MarkdownBody(
          data: content,
          selectable: false,
          onTapLink: buildMarkdownLinkTapHandler(openExternalLink: scope.openExternalLink),
          styleSheet: buildChatMessageMarkdownStyleSheet(prego: context.prego),
          blockSyntaxes: sessionMarkdownBlockSyntaxes,
          builders: buildSessionMarkdownBuilders(highlightEnabled: true, copyTooltip: context.loc.sessionDetailCopy),
        ),
      ),
    );
  }
}

/// Text with line numbers, one row per line, opened on [line] with that row
/// tinted. Rows have one fixed height, so the list starts at [line] without
/// measuring anything and nothing moves once it shows.
class const _CodePreview({
  required final String content,
  required final String? language,
  required final int? line,
}) extends StatefulWidget {
  @override
  State<_CodePreview> createState() => _CodePreviewState();
}

class _CodePreviewState() extends State<_CodePreview> {
  ScrollController? _controller;
  (Brightness, TextStyle)? _linesKey;
  List<TextSpan> _lines = const [];

  List<TextSpan> _linesFor({required Brightness brightness, required TextStyle style}) {
    final key = (brightness, style);
    if (key == _linesKey) return _lines;
    _linesKey = key;
    final code = widget.content.replaceAll("\t", "    ");
    final highlighted = code.length > _maxHighlightedLength
        ? null
        : CodeHighlighter.highlight(code: code, language: widget.language, brightness: brightness, baseStyle: style);
    return _lines = highlighted == null
        ? [for (final text in code.split("\n")) TextSpan(text: text, style: style)]
        : splitSpanIntoLines(span: highlighted);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final style = prego.textTheme.code.copyWith(color: prego.colors.textPrimary);
    final lines = _linesFor(brightness: Theme.of(context).brightness, style: style);
    final textScaler = MediaQuery.textScalerOf(context);
    final glyph = TextPainter(
      text: TextSpan(text: "0", style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final rowHeight = glyph.height;
    final charWidth = glyph.width;
    glyph.dispose();
    final gutterWidth = "${lines.length}".length * charWidth;
    final longest = lines.fold<int>(0, (longest, line) => math.max(longest, line.toPlainText().length));
    const gap = PregoSpacing.md;
    const horizontalPadding = PregoSpacing.md;
    final targetIndex = switch (widget.line) {
      final line? when line <= lines.length => line - 1,
      _ => null,
    };
    final targetColor = prego.colors.bgBrandPrimary;
    final numberStyle = style.copyWith(color: prego.colors.textTertiary);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Created at the first layout, when the viewport's height is known, so
        // the target line opens a third of the way down.
        final controller = _controller ??= ScrollController(
          initialScrollOffset: targetIndex == null
              ? 0
              : math.max(0, targetIndex * rowHeight - constraints.maxHeight / 3),
        );
        // Wide enough for the longest line, so rows never wrap and the
        // whole text scrolls sideways together.
        final contentWidth = math.max(
          constraints.maxWidth,
          horizontalPadding * 2 + gutterWidth + gap + longest * charWidth,
        );
        return Scrollbar(
          controller: controller,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: ListView.builder(
                controller: controller,
                itemExtent: rowHeight,
                padding: EdgeInsetsDirectional.only(
                  top: PregoSpacing.sm,
                  bottom: PregoSpacing.sm + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: lines.length,
                itemBuilder: (context, index) => ColoredBox(
                  color: index == targetIndex ? targetColor : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: gutterWidth,
                          child: Text("${index + 1}", textAlign: TextAlign.end, style: numberStyle),
                        ),
                        const SizedBox(width: gap),
                        Expanded(child: Text.rich(lines[index], softWrap: false, overflow: TextOverflow.clip)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Splits a highlighted span into one span per line, each carrying the
/// resolved style of every piece of text in it.
@visibleForTesting
List<TextSpan> splitSpanIntoLines({required TextSpan span}) {
  final lines = <TextSpan>[];
  var current = <TextSpan>[];
  void visit({required InlineSpan node, required TextStyle? inherited}) {
    if (node is! TextSpan) return;
    final style = inherited == null ? node.style : inherited.merge(node.style);
    final text = node.text;
    if (text != null) {
      final pieces = text.split("\n");
      for (var index = 0; index < pieces.length; index++) {
        if (index > 0) {
          lines.add(TextSpan(children: current));
          current = <TextSpan>[];
        }
        if (pieces[index].isNotEmpty) current.add(TextSpan(text: pieces[index], style: style));
      }
    }
    for (final child in node.children ?? const <InlineSpan>[]) {
      visit(node: child, inherited: style);
    }
  }

  visit(node: span, inherited: null);
  lines.add(TextSpan(children: current));
  return lines;
}

/// Hands the image to the image viewer as soon as the preview has settled,
/// flying it from here. Closing the viewer comes back to the image here, which
/// opens it again.
class const _ImagePreview({
  required final LoadedMessageImage image,
  required final String fileName,
}) extends StatefulWidget {
  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState() extends State<_ImagePreview> {
  final _heroTag = UniqueKey();

  @override
  void initState() {
    super.initState();
    unawaited(_openWhenSettled());
  }

  /// Waits for the preview's own slide to finish, so the two transitions run
  /// one after the other rather than over each other.
  Future<void> _openWhenSettled() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && !animation.isCompleted) {
      final settled = Completer<void>();
      void onStatus(AnimationStatus status) {
        if (status == AnimationStatus.forward || settled.isCompleted) return;
        animation.removeStatusListener(onStatus);
        settled.complete();
      }

      animation.addStatusListener(onStatus);
      await settled.future;
      if (!animation.isCompleted) return;
    }
    if (mounted) await _open();
  }

  Future<void> _open() => showImageAttachmentViewer(
    context: context,
    image: widget.image,
    heroPresentation: ImageAttachmentHeroPresentation.contained,
    filename: widget.fileName,
    heroTag: _heroTag,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.loc.sessionDetailImageOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_open()),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            PregoSpacing.lg,
            PregoSpacing.lg,
            PregoSpacing.lg,
            PregoSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: Hero(
              tag: _heroTag,
              child: Image(image: widget.image.provider, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class const _UnavailableMessage({required final FilePreviewUnavailableReason reason}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final message = switch (reason) {
      FilePreviewUnavailableReason.missing => loc.filePreviewMissing,
      FilePreviewUnavailableReason.tooLarge => loc.filePreviewTooLarge,
      FilePreviewUnavailableReason.unsupported => loc.filePreviewUnsupported,
      FilePreviewUnavailableReason.denied => loc.filePreviewDenied,
      FilePreviewUnavailableReason.bridgeTooOld => loc.filePreviewBridgeTooOld,
      FilePreviewUnavailableReason.failed => loc.filePreviewFailed,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.x2l),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    );
  }
}
