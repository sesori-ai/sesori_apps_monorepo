import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/markdown_plain_text.dart";
import "../session_detail_presentation_scope.dart";
import "reasoning_modal.dart";
import "transcript_latest_words.dart";
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => _showFullText(context: context),
              borderRadius: BorderRadius.circular(PregoRadius.xs),
              child: TranscriptStepRow(
                leading: PregoAiLoader(
                  animate: widget.isStreaming,
                  fillMode: .outline,
                  color: prego.colors.textSecondary,
                ),
                label: widget.isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
                detail: widget.isStreaming || widget.text.isEmpty ? null : TextSpan(text: _previewText),
                live: widget.isStreaming,
                color: null,
                // The tail eases in with the first streamed words.
                below: TranscriptPresenceColumn(
                  children: [
                    if (widget.isStreaming && widget.text.isNotEmpty)
                      TranscriptLatestWords(
                        key: const ValueKey("reasoning.latestWords"),
                        text: widget.text,
                        style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                      ),
                  ],
                ),
                trailing: null,
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

  /// The plain text of the first non-empty block of [markdown]. Only the first
  /// physical line is parsed, avoiding unnecessary work for long documents.
  static String _firstLinePlainText(String markdown) {
    final firstLine = _extractFirstLine(markdown);
    if (firstLine.isEmpty) return markdown.trim();
    // This row shows words beside a label, never a picture, so an image has
    // nothing to contribute to it.
    final plain = markdownPlainText(markdown: firstLine, nameImage: null);
    return plain.isEmpty ? firstLine.trim() : plain;
  }
}
