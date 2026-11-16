import "dart:async";

import "package:flutter/rendering.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/defer_until_route_open.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "handoff_session_link.dart";
import "invocation_card.dart";
import "text_part_widget.dart";
import "user_message_card.dart";

/// The card that takes the place of a handoff prompt's bubble in the target
/// session: "From `<source>`", which opens the source, the first lines of the
/// summary faded out over "Show all", and the path of the saved transcript.
///
/// "Show all" opens the whole summary in a sheet on touch or a dialog under a
/// pointer. The card keeps its height, so the transcript never moves.
class const HandoffCard({super.key, required final TranscriptHandoffCard card}) extends StatelessWidget {
  /// How much of a long summary shows before "Show all", about six lines.
  static const double collapsedSummaryHeight = 120;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final fill = InvocationCard.fill(prego: prego);

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: UserMessageBubble.margin,
          padding: const EdgeInsets.all(PregoSpacing.lg),
          constraints: BoxConstraints(
            maxWidth: InvocationCard.maxContentWidth(rowWidth: constraints.maxWidth) + InvocationCard.inset * 2,
          ),
          decoration: BoxDecoration(
            color: fill,
            border: InvocationCard.border(prego: prego),
            borderRadius: BorderRadius.circular(InvocationCard.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceLink(
                key: const ValueKey("handoff-card.source"),
                sourceTitle: card.sourceTitle,
                onPressed: () => openHandoffSession(context: context, sessionId: card.sourceSessionId),
              ),
              const SizedBox(height: PregoSpacing.sm),
              _ClippedSummary(
                collapsedHeight: collapsedSummaryHeight,
                fadeColor: fill,
                summary: _SummaryMarkdown(summary: card.summary),
                showAll: TextButton(
                  key: const ValueKey("handoff-card.show-all"),
                  onPressed: () => unawaited(_showSummary(context: context)),
                  style: TextButton.styleFrom(
                    foregroundColor: prego.colors.textBrandPrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  child: Text(
                    context.loc.transcriptHandoffShowAll,
                    style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textBrandPrimary),
                  ),
                ),
              ),
              const SizedBox(height: PregoSpacing.sm),
              _TranscriptPath(path: card.transcriptPath),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the whole summary over the page, which stays as it is under it.
  /// Its "From" link closes it and opens the source, as the card's does.
  Future<void> _showSummary({required BuildContext context}) async {
    final scope = SessionDetailPresentationScope.read(context);
    final openSource = await showPregoModal<bool>(
      context: context,
      title: context.loc.transcriptHandoffSummaryTitle,
      width: PregoModalWidth.reading,
      // The sheet's route does not inherit the page's scope, which the
      // summary's links, images and their viewer read.
      builder: (modalContext) => scope.around(
        openSession: scope.openSession,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceLink(
                key: const ValueKey("handoff-sheet.source"),
                sourceTitle: card.sourceTitle,
                onPressed: () => modalContext.pop(true),
              ),
              const SizedBox(height: PregoSpacing.sm),
              DeferUntilRouteOpen(
                contentLength: card.summary.length,
                child: PregoReadableSelectionArea(child: _SummaryMarkdown(summary: card.summary)),
              ),
              const SizedBox(height: PregoSpacing.md),
              _TranscriptPath(path: card.transcriptPath),
            ],
          ),
        ),
      ),
    );
    if ((openSource ?? false) && context.mounted) {
      await openHandoffSession(context: context, sessionId: card.sourceSessionId);
    }
  }
}

/// "From `<source>` ›", which opens the session the handoff came from.
class const _SourceLink({super.key, required final String? sourceTitle, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final secondary = prego.colors.textSecondary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: secondary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: AlignmentDirectional.centerStart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerRegular.arrow_forward_up, size: PregoIconSize.sm, color: secondary),
          const SizedBox(width: PregoSpacing.sm),
          Flexible(
            child: Text(
              context.loc.transcriptHandoffFrom(handoffSessionName(context: context, title: sourceTitle)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: prego.textTheme.textSm.medium.copyWith(color: secondary),
            ),
          ),
          Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: secondary),
        ],
      ),
    );
  }
}

/// The summary as the card and its sheet both render it.
class const _SummaryMarkdown({required final String summary}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return MarkdownBody(
      data: summary,
      selectable: false,
      blockSyntaxes: sessionMarkdownBlockSyntaxes,
      imageBuilder: (uri, title, alt) => MarkdownMessageImage(uri: uri, semanticLabel: alt),
      onTapLink: buildMarkdownLinkTapHandler(
        openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
      ),
      styleSheet: buildSessionMarkdownStyleSheet(
        prego: prego,
        paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
      ),
    );
  }
}

class const _TranscriptPath({required final String path}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return SelectableText(
      path,
      style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary).monospace,
    );
  }
}

enum _SummarySlot() {
  summary,
  showAll,
}

/// The summary clipped to [collapsedHeight] and faded into [fadeColor] at the
/// bottom, over [showAll]. A summary that fits shows whole, without
/// [showAll]. The clip and [showAll] are decided in one layout, so the row
/// has its final height from its first frame.
class const _ClippedSummary({
  required final double collapsedHeight,
  required final Color fadeColor,
  required final Widget summary,
  required final Widget showAll,
}) extends SlottedMultiChildRenderObjectWidget<_SummarySlot, RenderBox> {
  @override
  Iterable<_SummarySlot> get slots => _SummarySlot.values;

  @override
  Widget? childForSlot(_SummarySlot slot) => switch (slot) {
    _SummarySlot.summary => summary,
    _SummarySlot.showAll => showAll,
  };

  @override
  _RenderClippedSummary createRenderObject(BuildContext context) =>
      _RenderClippedSummary(collapsedHeight: collapsedHeight, fadeColor: fadeColor);

  @override
  void updateRenderObject(BuildContext context, _RenderClippedSummary renderObject) {
    renderObject
      ..collapsedHeight = collapsedHeight
      ..fadeColor = fadeColor;
  }
}

class _RenderClippedSummary({required double collapsedHeight, required Color fadeColor})
    extends RenderBox
    with SlottedContainerRenderObjectMixin<_SummarySlot, RenderBox> {
  /// How far up from the clip's bottom the summary fades out.
  static const double _fadeHeight = 48;

  /// The fade's share, from the clip's bottom, that is fully opaque: about a
  /// line, so the cut-off line under it never peeks out above "Show all".
  static const double _solidShare = 0.45;

  double _collapsedHeight = collapsedHeight;
  Color _fadeColor = fadeColor;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle();

  /// Whether the summary overflows [collapsedHeight], from the last layout.
  bool _overflows = false;

  double get collapsedHeight => _collapsedHeight;
  set collapsedHeight(double value) {
    if (value == _collapsedHeight) return;
    _collapsedHeight = value;
    markNeedsLayout();
  }

  Color get fadeColor => _fadeColor;
  set fadeColor(Color value) {
    if (value == _fadeColor) return;
    _fadeColor = value;
    markNeedsPaint();
  }

  RenderBox? get _summary => childForSlot(_SummarySlot.summary);
  RenderBox? get _showAll => childForSlot(_SummarySlot.showAll);

  double get _shown => _overflows ? _collapsedHeight : (_summary?.size.height ?? 0);

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final summary = _summary;
    final showAll = _showAll;
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    var width = 0.0;
    var height = 0.0;
    if (summary != null) {
      summary.layout(childConstraints, parentUsesSize: true);
      _overflows = summary.size.height > _collapsedHeight;
      width = summary.size.width;
      height = _shown;
    }
    if (showAll != null) {
      showAll.layout(childConstraints, parentUsesSize: true);
      if (_overflows) {
        if (showAll.parentData case final BoxParentData data) data.offset = Offset(0, height);
        width = width < showAll.size.width ? showAll.size.width : width;
        height += showAll.size.height;
      }
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final summary = _summary;
    if (summary != null) {
      if (_overflows) {
        _clip.layer = context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & Size(size.width, _collapsedHeight),
          (context, offset) => context.paintChild(summary, offset),
          oldLayer: _clip.layer,
        );
        final rect = Rect.fromLTWH(offset.dx, offset.dy + _collapsedHeight - _fadeHeight, size.width, _fadeHeight);
        context.canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_fadeColor.withValues(alpha: 0), _fadeColor, _fadeColor],
              stops: const [0, 1 - _solidShare, 1],
            ).createShader(rect),
        );
      } else {
        _clip.layer = null;
        context.paintChild(summary, offset);
      }
    }
    final showAll = _showAll;
    if (showAll != null && _overflows) context.paintChild(showAll, offset + Offset(0, _collapsedHeight));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final showAll = _showAll;
    if (showAll != null && _overflows) {
      final hit = result.addWithPaintOffset(
        offset: Offset(0, _collapsedHeight),
        position: position,
        hitTest: (result, transformed) => showAll.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    final summary = _summary;
    if (summary == null || position.dy > _shown) return false;
    return summary.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_summary case final summary?) visitor(summary);
    if (_showAll case final showAll? when _overflows) visitor(showAll);
  }
}
