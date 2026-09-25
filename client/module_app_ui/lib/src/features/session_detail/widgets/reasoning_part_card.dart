import "dart:math";

import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";
import "reasoning_modal.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";

class const ReasoningPartCard({
  super.key,
  required final String text,
  required final bool isStreaming,
  required final String partId,
  required final String messageId,
}) extends StatefulWidget {
  @override
  State<ReasoningPartCard> createState() => _ReasoningPartCardState();

  /// How much of the end of a streaming thought the live row considers; more
  /// than one line holds, so the row stays full, without laying out the whole
  /// accumulated document on every flush.
  static const int _kLatestWordsChars = 160;

  /// The latest words of a streaming thought, on one line.
  @visibleForTesting
  static String latestWords({required String text}) {
    var start = max(0, text.length - _kLatestWordsChars);
    // Never start on the low half of a UTF-16 surrogate pair (emoji etc.):
    // an orphaned low surrogate renders as a replacement character.
    if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start++;
    return text.substring(start).replaceAll(RegExp(r"\s+"), " ").trim();
  }

  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;
}

class _ReasoningPartCardState() extends State<ReasoningPartCard> {
  late String _previewText;
  late String _cachedFirstLine;

  @override
  void initState() {
    super.initState();
    _cachedFirstLine = _extractFirstLine(widget.text);
    _previewText = _firstLinePlainText(widget.text);
  }

  @override
  void didUpdateWidget(covariant ReasoningPartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newFirstLine = _extractFirstLine(widget.text);
    if (newFirstLine != _cachedFirstLine) {
      _cachedFirstLine = newFirstLine;
      _previewText = _firstLinePlainText(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty && !widget.isStreaming) {
      return const SizedBox.shrink();
    }

    final prego = context.prego;
    final loc = context.loc;
    final label = widget.isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought;
    final heading = Text(
      label,
      style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
    );

    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => _showFullText(context: context),
              borderRadius: BorderRadius.circular(PregoRadius.xs),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          PregoAiLoader(
                            animate: widget.isStreaming,
                            fillMode: .outline,
                            color: prego.colors.textSecondary,
                          ),
                          SizedBox(width: prego.spacing.md),
                          if (widget.isStreaming)
                            Expanded(child: TranscriptLiveLabel(label: heading, semanticLabel: null))
                          else ...[
                            ExcludeSemantics(child: heading),
                            if (widget.text.isNotEmpty) ...[
                              SizedBox(width: prego.spacing.md),
                              Expanded(
                                child: Text(
                                  _previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style.copyWith(color: prego.colors.textTertiary),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    // The tail eases in with the first streamed words.
                    TranscriptPresenceColumn(
                      children: [
                        if (widget.isStreaming && widget.text.isNotEmpty)
                          Padding(
                            key: const ValueKey("reasoning.latestWords"),
                            // Lines up under the label, past the 20 px sparkle.
                            padding: EdgeInsetsDirectional.only(start: 20 + prego.spacing.md, bottom: 8),
                            child: _LatestWords(
                              text: ReasoningPartCard.latestWords(text: widget.text),
                              style: style,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullText({required BuildContext context}) {
    ReasoningModal.show(
      context,
      partId: widget.partId,
      messageId: widget.messageId,
      openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
    );
  }

  /// Returns the first non-empty physical line of [text], or the empty
  /// string if [text] contains no non-empty lines. Used to decide whether
  /// the preview needs re-parsing — most streaming updates append to later
  /// paragraphs, leaving the first line unchanged.
  static String _extractFirstLine(String text) {
    if (text.isEmpty) return '';
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.trim().isNotEmpty) return line;
    }
    return '';
  }

  /// Extracts the first non-empty block from [markdown] and returns its
  /// plain text by walking the markdown AST. Only the first physical line
  /// is parsed, avoiding unnecessary work for long documents.
  static String _firstLinePlainText(String markdown) {
    final firstLine = _extractFirstLine(markdown);
    if (firstLine.isEmpty) return markdown.trim();

    // The AST is rendered directly into a Text widget rather than serialized
    // to HTML, so decode Markdown character references instead of re-escaping them.
    final document = md.Document(encodeHtml: false);
    final nodes = document.parse(firstLine);

    for (final node in nodes) {
      final buffer = StringBuffer();
      _extractText(node, buffer: buffer);
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return firstLine.trim();
  }

  static void _extractText(md.Node node, {required StringBuffer buffer}) {
    if (node is md.Text) {
      buffer.write(node.text);
    } else if (node is md.Element) {
      // Skip images entirely — they have no text content to display.
      if (node.tag == 'img') return;

      for (final child in node.children ?? const <md.Node>[]) {
        _extractText(child, buffer: buffer);
      }
    }
  }
}

/// One line holding the end of [text]: the newest words stay in view and the
/// older start fades out at the leading edge.
class const _LatestWords({required final String text, required final TextStyle style}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [Colors.transparent, Colors.white],
        stops: [0.0, 0.15],
      ).createShader(bounds, textDirection: direction),
      blendMode: BlendMode.dstIn,
      child: UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        alignment: AlignmentDirectional.centerEnd,
        clipBehavior: Clip.hardEdge,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}
