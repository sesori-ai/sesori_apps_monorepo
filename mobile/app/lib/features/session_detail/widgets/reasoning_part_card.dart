import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:markdown/markdown.dart" as md;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "reasoning_modal.dart";

class ReasoningPartCard extends StatefulWidget {
  final String text;
  final bool isStreaming;
  final String partId;
  final String messageId;

  const ReasoningPartCard({
    super.key,
    required this.text,
    required this.isStreaming,
    required this.partId,
    required this.messageId,
  });

  @override
  State<ReasoningPartCard> createState() => _ReasoningPartCardState();
}

class _ReasoningPartCardState extends State<ReasoningPartCard> {
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

    final zyra = context.zyra;
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showFullText(context: context),
        child: Container(
          decoration: BoxDecoration(
            color: zyra.colors.bgSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: zyra.colors.borderSecondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 18,
                      color: zyra.colors.borderPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isStreaming
                            ? loc.sessionDetailThinking
                            : loc.sessionDetailThought,
                        style: zyra.textTheme.textXs.regular.copyWith(
                          color: zyra.colors.borderPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: zyra.colors.borderPrimary,
                    ),
                  ],
                ),
              ),
              if (widget.isStreaming && widget.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.35],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: OverflowBox(
                        alignment: Alignment.bottomLeft,
                        maxHeight: double.infinity,
                        child: Text(
                          widget.text,
                          style: zyra.textTheme.textXs.regular.copyWith(
                            color: zyra.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!widget.isStreaming && widget.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: Text(
                    _previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                      style: zyra.textTheme.textXs.regular.copyWith(
                        color: zyra.colors.textSecondary,
                      ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullText({required BuildContext context}) {
    final cubit = context.read<SessionDetailCubit>();

    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ReasoningModal(
          partId: widget.partId,
          messageId: widget.messageId,
        ),
      ),
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

    final document = md.Document();
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
