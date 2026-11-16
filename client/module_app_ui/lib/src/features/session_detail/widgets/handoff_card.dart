import "dart:math";
import "dart:ui" show lerpDouble;

import "package:flutter/rendering.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "handoff_session_link.dart";
import "invocation_card.dart";
import "text_part_widget.dart";
import "transcript_row_hold.dart";
import "user_message_card.dart";

/// The card that takes the place of a handoff prompt's bubble in the target
/// session: "From `<source>`", which opens the source, the first lines of the
/// summary faded out over "Show all", and the path of the saved transcript.
///
/// "Show all" grows the card downward in place and "Show less" folds it back
/// up: the transcript scrolls with the card as it moves, so its top edge and
/// every row above it stay still. The choice outlives the row scrolling away.
class const HandoffCard({super.key, required final String messageId, required final TranscriptHandoffCard card})
    extends StatefulWidget {
  /// How much of a long summary shows before "Show all", about six lines.
  static const double collapsedSummaryHeight = 120;

  @override
  State<HandoffCard> createState() => _HandoffCardState();
}

class _HandoffCardState() extends State<HandoffCard> with SingleTickerProviderStateMixin {
  /// The disclosure's curve: this one moves the rows being read too.
  static const Curve _curve = Cubic(0.25, 0.55, 0.2, 1);

  late final AnimationController _expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _eased = CurvedAnimation(parent: _expansion, curve: _curve);

  /// The summary's whole height, as it last laid out; null before then.
  double? _summaryHeight;

  /// The summary height the transcript has already made room for.
  double _shownHeight = 0;

  /// Whether this toggle holds the card's top still. Show less from below a
  /// top scrolled away holds the toggle under the finger instead, the top
  /// coming down to it, so the card isn't thrown off screen.
  bool _holdsTop = true;

  /// The room a short transcript keeps above it for the growth still to come,
  /// given back once the card has grown.
  double _roomAhead = 0;

  String get _storageId => "handoff-card-expanded:${widget.messageId}";

  bool get _expanded => _expansion.isForwardOrCompleted;

  @override
  void initState() {
    super.initState();
    if (PageStorage.maybeOf(context)?.readState(context, identifier: _storageId) == true) _expansion.value = 1;
    _eased.addListener(_keepTopInPlace);
    _expansion.addStatusListener((status) {
      if (status.isCompleted && _roomAhead > 0) {
        giveBackTranscriptSpaceAbove(context: context, extent: _roomAhead);
        _roomAhead = 0;
      }
      if (status.isDismissed) releaseTranscriptSpaceAbove(context: context);
    });
  }

  @override
  void dispose() {
    _eased.dispose();
    _expansion.dispose();
    super.dispose();
  }

  void _toggle() {
    final expanding = !_expanded;
    _holdsTop = expanding || _topOnScreen();
    PageStorage.maybeOf(context)?.writeState(context, expanding, identifier: _storageId);
    final ahead = max(0.0, (_summaryHeight ?? 0) - HandoffCard.collapsedSummaryHeight);
    if (expanding && reserveTranscriptSpaceAbove(context: context, ahead: ahead)) {
      _roomAhead = ahead;
      // The room is there to scroll into once the transcript lays out with it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The toggle's label follows the motion it starts.
        if (mounted) setState(() => _move(expanding: true));
      });
    } else {
      _move(expanding: expanding);
    }
    setState(() {});
  }

  void _move({required bool expanding}) {
    if (context.isReducedMotion || pregoActivatedByKeyboard) {
      _expansion.value = expanding ? 1 : 0;
    } else if (expanding) {
      _expansion.forward();
    } else {
      _expansion.reverse();
    }
  }

  bool _topOnScreen() {
    final row = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (row is! RenderBox || viewport is! RenderBox) return true;
    return row.localToGlobal(Offset.zero).dy >= viewport.localToGlobal(Offset.zero).dy;
  }

  double _shownFor({required double summaryHeight}) => summaryHeight <= HandoffCard.collapsedSummaryHeight
      ? summaryHeight
      : lerpDouble(HandoffCard.collapsedSummaryHeight, summaryHeight, _eased.value) ?? summaryHeight;

  /// Runs on every tick, before layout, so the transcript scrolls by the
  /// card's growth in the frame the card grows.
  void _keepTopInPlace() {
    final summaryHeight = _summaryHeight;
    if (!mounted || summaryHeight == null) return;
    final shown = _shownFor(summaryHeight: summaryHeight);
    final growth = shown - _shownHeight;
    _shownHeight = shown;
    // A reversed transcript keeps a row's bottom still by itself.
    if (_holdsTop) holdTranscriptRowTop(context: context, growth: growth, roomBelowOnly: false);
  }

  /// The summary's height changed in a layout, not by a toggle: as the row
  /// first lays out, or the width changes. That moves nothing to hold.
  void _onSummaryMeasured(double height) {
    _summaryHeight = height;
    _shownHeight = _shownFor(summaryHeight: height);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final card = widget.card;
    final fill = InvocationCard.fill(prego: prego);
    final source = handoffSessionName(context: context, title: card.sourceTitle);
    final secondary = prego.colors.textSecondary;

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
              TextButton(
                key: const ValueKey("handoff-card.source"),
                onPressed: () => openHandoffSession(context: context, sessionId: card.sourceSessionId),
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
                        loc.transcriptHandoffFrom(source),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: prego.textTheme.textSm.medium.copyWith(color: secondary),
                      ),
                    ),
                    Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: secondary),
                  ],
                ),
              ),
              const SizedBox(height: PregoSpacing.sm),
              _CollapsibleSummary(
                expansion: _eased,
                collapsedHeight: HandoffCard.collapsedSummaryHeight,
                fadeColor: fill,
                onMeasured: _onSummaryMeasured,
                summary: MarkdownBody(
                  data: card.summary,
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
                ),
                toggle: TextButton(
                  key: const ValueKey("handoff-card.toggle"),
                  onPressed: _toggle,
                  style: TextButton.styleFrom(
                    foregroundColor: prego.colors.textBrandPrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  child: Text(
                    _expanded ? loc.transcriptHandoffShowLess : loc.transcriptHandoffShowAll,
                    style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textBrandPrimary),
                  ),
                ),
              ),
              const SizedBox(height: PregoSpacing.sm),
              SelectableText(
                card.transcriptPath,
                style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary).monospace,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SummarySlot() {
  summary,
  toggle,
}

/// The summary clipped to [collapsedHeight] and faded into [fadeColor] at the
/// bottom, over [toggle], or opened to its whole height as [expansion] runs to
/// one. A summary that fits shows whole, without the toggle. The clip and the
/// toggle are decided in one layout, so the row has its final height from its
/// first frame.
class const _CollapsibleSummary({
  required final Animation<double> expansion,
  required final double collapsedHeight,
  required final Color fadeColor,
  required final ValueSetter<double> onMeasured,
  required final Widget summary,
  required final Widget toggle,
}) extends SlottedMultiChildRenderObjectWidget<_SummarySlot, RenderBox> {
  @override
  Iterable<_SummarySlot> get slots => _SummarySlot.values;

  @override
  Widget? childForSlot(_SummarySlot slot) => switch (slot) {
    _SummarySlot.summary => summary,
    _SummarySlot.toggle => toggle,
  };

  @override
  _RenderCollapsibleSummary createRenderObject(BuildContext context) => _RenderCollapsibleSummary(
    expansion: expansion,
    collapsedHeight: collapsedHeight,
    fadeColor: fadeColor,
    onMeasured: onMeasured,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderCollapsibleSummary renderObject) {
    renderObject
      ..expansion = expansion
      ..collapsedHeight = collapsedHeight
      ..fadeColor = fadeColor
      ..onMeasured = onMeasured;
  }
}

class _RenderCollapsibleSummary({
  required Animation<double> expansion,
  required double collapsedHeight,
  required Color fadeColor,
  required ValueSetter<double> onMeasured,
}) extends RenderBox with SlottedContainerRenderObjectMixin<_SummarySlot, RenderBox> {
  /// How far up from the clip's bottom the summary fades out.
  static const double _fadeHeight = 40;

  Animation<double> _expansion = expansion;
  double _collapsedHeight = collapsedHeight;
  Color _fadeColor = fadeColor;
  ValueSetter<double> onMeasured = onMeasured;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle();

  /// The summary's shown height and whether it overflows, from the last layout.
  double _shown = 0;
  bool _overflows = false;

  Animation<double> get expansion => _expansion;
  set expansion(Animation<double> value) {
    if (identical(value, _expansion)) return;
    if (attached) _expansion.removeListener(markNeedsLayout);
    _expansion = value;
    if (attached) _expansion.addListener(markNeedsLayout);
    markNeedsLayout();
  }

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
  RenderBox? get _toggle => childForSlot(_SummarySlot.toggle);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _expansion.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _expansion.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final summary = _summary;
    final toggle = _toggle;
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    var width = 0.0;
    var height = 0.0;
    if (summary != null) {
      summary.layout(childConstraints, parentUsesSize: true);
      final whole = summary.size.height;
      onMeasured(whole);
      _overflows = whole > _collapsedHeight;
      _shown = _overflows ? lerpDouble(_collapsedHeight, whole, _expansion.value) ?? whole : whole;
      width = summary.size.width;
      height = _shown;
    }
    if (toggle != null) {
      toggle.layout(childConstraints, parentUsesSize: true);
      if (_overflows) {
        if (toggle.parentData case final BoxParentData data) data.offset = Offset(0, _shown);
        width = width < toggle.size.width ? toggle.size.width : width;
        height += toggle.size.height;
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
          Offset.zero & Size(size.width, _shown),
          (context, offset) => context.paintChild(summary, offset),
          oldLayer: _clip.layer,
        );
        final fade = 1 - _expansion.value;
        if (fade > 0) {
          final rect = Rect.fromLTWH(offset.dx, offset.dy + _shown - _fadeHeight, size.width, _fadeHeight);
          context.canvas.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _fadeColor.withValues(alpha: 0),
                  _fadeColor.withValues(alpha: _fadeColor.a * fade),
                ],
              ).createShader(rect),
          );
        }
      } else {
        _clip.layer = null;
        context.paintChild(summary, offset);
      }
    }
    final toggle = _toggle;
    if (toggle != null && _overflows) context.paintChild(toggle, offset + Offset(0, _shown));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final toggle = _toggle;
    if (toggle != null && _overflows) {
      final hit = result.addWithPaintOffset(
        offset: Offset(0, _shown),
        position: position,
        hitTest: (result, transformed) => toggle.hitTest(result, position: transformed),
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
    if (_toggle case final toggle? when _overflows) visitor(toggle);
  }
}
