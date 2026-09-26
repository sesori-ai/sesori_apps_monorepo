import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../widgets/markdown_styles.dart";
import "transcript_sticky_position.dart";

/// The prompt of the turn being read, pinned over the transcript's top edge
/// in the user bubble's style and clamped to three lines. The next turn's
/// prompt pushes it out. A tap, or a screen reader's activation, jumps to the
/// prompt; in a long turn the prompt's own row is not built, so this is the
/// only place it can be reached from.
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
    final text = _textOf(loc: context.loc, opener: turn.opener);
    final background = Theme.of(context).scaffoldBackgroundColor;
    void jump() => onJumpToTurn(openerMessageId: turn.opener.info.id);
    return Semantics(
      button: true,
      label: text,
      hint: context.loc.transcriptStickyPromptJumpHint,
      onTap: jump,
      excludeSemantics: true,
      // Translucent over an ignored band, so a drag or a wheel that starts on
      // the prompt still scrolls the rows beneath; a tap goes to the prompt,
      // whose recognizer joins the arena first.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: jump,
        child: IgnorePointer(
          // The page's background fades out below the bubble, so the rows it
          // covers do not read as part of it.
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.78, 1],
                colors: [background, background.withValues(alpha: 0)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: AlignmentDirectional.centerEnd,
                  heightFactor: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.xs),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(maxWidth: (constraints.maxWidth - PregoSpacing.xl * 2) * 0.76),
                    decoration: BoxDecoration(
                      color: prego.colors.bgSurface2,
                      borderRadius: BorderRadius.circular(PregoRadius.xl),
                    ),
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: buildChatMessageMarkdownStyleSheet(prego: prego).p,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The prompt's text, or its first attachment's name when it has no text.
  static String _textOf({required AppLocalizations loc, required MessageWithParts opener}) {
    final text = opener.parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    if (text.isNotEmpty) return text;
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
