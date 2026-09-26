import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../widgets/markdown_styles.dart";
import "transcript_sticky_position.dart";
import "user_prompt_markdown_image.dart";

/// The prompt of the turn being read, pinned over the transcript's top edge
/// in the user bubble's style, rendered as Markdown and clipped to about three
/// lines of that bubble's text. The next turn's prompt pushes it out. A tap on
/// the bubble, or a screen reader's activation, jumps to the prompt; in a long
/// turn the prompt's own row is not built, so this is the only place it can be
/// reached from.
class const TranscriptStickyPromptOverlay({
  super.key,
  required final ValueListenable<TranscriptStickyPosition?> position,
  required final TranscriptTurns turns,
  required final void Function({required String openerMessageId}) onJumpToTurn,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: position,
      builder: (context, position, _) {
        // The turns may have changed since the position was measured; the next
        // frame's position catches up.
        final turn = position == null ? null : turns.promptTurnFor(openerMessageId: position.openerMessageId);
        if (position == null || turn == null) return const SizedBox.shrink();
        return Flow(
          delegate: _PushOutDelegate(nextOpenerTop: position.nextOpenerTop),
          children: [_band(context: context, turn: turn)],
        );
      },
    );
  }

  Widget _band({required BuildContext context, required TranscriptPromptTurn turn}) {
    final prego = context.prego;
    final markdown = _markdownOf(opener: turn.opener);
    final label = markdown ?? _attachmentLabelOf(loc: context.loc, opener: turn.opener);
    final styleSheet = buildChatMessageMarkdownStyleSheet(prego: prego);
    final background = Theme.of(context).scaffoldBackgroundColor;
    void jump() => onJumpToTurn(openerMessageId: turn.opener.info.id);
    return GestureDetector(
      // The band hides the top of the rows beneath it, so a tap on the faded
      // area must not reach a row the reader cannot see; only the bubble jumps.
      // Translucent, so a drag or a wheel that starts anywhere on the band
      // still scrolls those rows.
      behavior: HitTestBehavior.translucent,
      onTap: () {},
      child: Stack(
        children: [
          // The page's background fades out below the bubble, so the rows it
          // covers do not read as part of it. Ignored, because a box decoration
          // hit-tests as opaque and would swallow the rows' scroll.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.78, 1],
                    colors: [background, background.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: AlignmentDirectional.centerEnd,
                heightFactor: 1,
                child: Semantics(
                  button: true,
                  label: label,
                  hint: context.loc.transcriptStickyPromptJumpHint,
                  onTap: jump,
                  excludeSemantics: true,
                  // Translucent over an ignored bubble, so a drag or a wheel
                  // that starts on the prompt still scrolls the rows beneath; a
                  // tap goes to the prompt, whose recognizer joins the arena
                  // before the band's.
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: jump,
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.xs),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(maxWidth: (constraints.maxWidth - PregoSpacing.xl * 2) * 0.76),
                        decoration: BoxDecoration(
                          color: prego.colors.bgSurface2,
                          borderRadius: BorderRadius.circular(PregoRadius.xl),
                        ),
                        child: markdown == null
                            ? Text(
                                label,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: styleSheet.p,
                              )
                            : _cutMarkdown(
                                context: context,
                                markdown: markdown,
                                maxHeight: _threeLineHeight(context: context, styleSheet: styleSheet, prego: prego),
                                styleSheet: styleSheet,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The start of the prompt's Markdown, rendered as the user bubble renders
  /// it, cut off at the bubble's height so no code fence, table or image can
  /// make the pinned row grow.
  Widget _cutMarkdown({
    required BuildContext context,
    required String markdown,
    required double maxHeight,
    required MarkdownStyleSheet styleSheet,
  }) {
    return _CutToHeight(
      maxHeight: maxHeight,
      child: MarkdownBody(
        data: _boundedSource(markdown: markdown),
        selectable: false,
        softLineBreak: true,
        styleSheet: styleSheet,
        // The user bubble's own image rule, so a pinned prompt discloses no
        // more to a remote host than the prompt's own bubble does: nothing.
        imageBuilder: (uri, _, alt) => buildUserPromptMarkdownImage(context: context, uri: uri, semanticLabel: alt),
        blockSyntaxes: sessionMarkdownBlockSyntaxes,
        builders: buildSessionMarkdownBuilders(highlightEnabled: true, copyTooltip: context.loc.sessionDetailCopy),
      ),
    );
  }

  /// As much of the prompt as the row could ever paint, and no more. A pasted
  /// document can be megabytes long; building and laying out all of its tables,
  /// fences and images to paint three lines of it would make every scroll that
  /// pins a prompt cost as much as that prompt is long. Well over three lines'
  /// worth, so the paint-level cut, not this one, is what the reader sees.
  ///
  /// Cutting mid-document can leave a code fence open, which the Markdown
  /// parser reads as a fenced block running to the end of the prefix: a code
  /// block, never bare backticks.
  static String _boundedSource({required String markdown}) {
    return markdown.length <= _sourceCharacterBudget ? markdown : markdown.substring(0, _sourceCharacterBudget);
  }

  /// Around twenty-five lines of prose at the bubble's width, so the three
  /// painted lines are unaffected at any text scale the cut can face.
  static const _sourceCharacterBudget = 2000;

  /// About three lines of the bubble's body text at the reader's text scale.
  /// Markdown blocks have their own metrics, so the cut is approximate; what
  /// matters is that it does not depend on what a prompt contains, so the band
  /// keeps its height as the Markdown renders and as the pinned turn changes.
  static double _threeLineHeight({
    required BuildContext context,
    required MarkdownStyleSheet styleSheet,
    required PregoDesignSystem prego,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: "0\n0\n0", style: styleSheet.p ?? prego.textTheme.textSm.regular),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// The prompt's text, or null when it has only attachments.
  static String? _markdownOf({required MessageWithParts opener}) {
    final text = opener.parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    return text.isEmpty ? null : text;
  }

  /// The name of the first attachment of a prompt that has no text.
  static String _attachmentLabelOf({required AppLocalizations loc, required MessageWithParts opener}) {
    final attachment = opener.parts.whereType<MessagePartFile>().map((part) => part.attachment).firstOrNull;
    final filename = switch (attachment) {
      MessageAttachmentInlineImage(:final filename) ||
      MessageAttachmentRemoteUrl(:final filename) ||
      MessageAttachmentStoredImage(:final filename) ||
      MessageAttachmentMetadata(:final filename) => filename?.trim(),
      MessageAttachmentUnknown() || null => null,
    };
    return filename == null || filename.isEmpty ? loc.transcriptStickyPromptAttachment : filename;
  }
}

/// Paints the band at the top, slid up by as much as the next turn's opener
/// overlaps it. Measured at paint, so the push uses the band's own height.
final class _PushOutDelegate({required final double? nextOpenerTop}) extends FlowDelegate {
  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) => constraints.loosen();

  @override
  void paintChildren(FlowPaintingContext context) {
    final height = context.getChildSize(0)?.height ?? 0;
    final nextOpenerTop = this.nextOpenerTop;
    final dy = nextOpenerTop == null ? 0.0 : (nextOpenerTop - height).clamp(-height, 0.0);
    context.paintChild(0, transform: Matrix4.translationValues(0, dy, 0));
  }

  @override
  bool shouldRepaint(_PushOutDelegate oldDelegate) => oldDelegate.nextOpenerTop != nextOpenerTop;
}

/// Gives its child all the height it asks for, takes at most [maxHeight] of it
/// and clips the rest. The stock ways of cutting a Markdown body fall short: a
/// height constraint makes its column report an overflow instead of being cut,
/// and a scroll view would send its metrics to the transcript's own list, which
/// reads them as a scroll near the older edge.
class const _CutToHeight({required final double maxHeight, required super.child})
    extends SingleChildRenderObjectWidget {
  @override
  _RenderCutToHeight createRenderObject(BuildContext context) => _RenderCutToHeight(maxHeight: maxHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderCutToHeight renderObject) {
    renderObject.maxHeight = maxHeight;
  }
}

final class _RenderCutToHeight({required double maxHeight}) extends RenderProxyBox {
  double _maxHeight = maxHeight;
  double get maxHeight => _maxHeight;
  set maxHeight(double value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.widthConstraints(), parentUsesSize: true);
    size = constraints.constrain(Size(child.size.width, min(child.size.height, _maxHeight)));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint);
  }
}
