import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../utils/markdown_plain_text.dart";
import "../../../widgets/markdown_styles.dart";
import "transcript_sticky_layout.dart";
import "user_message_card.dart";
import "user_prompt_markdown_image.dart";

/// The prompts pinned over the transcript's top edge, as
/// [layOutTranscriptStickyPrompts] places them. It holds a copy of the bubble
/// content of every prompt in [turns] that could pin next, and paints only
/// the pinned ones, on a surface of the bubble's own shape and colour, so a
/// pin is pixel-identical to the bubble it takes over from.
///
/// The transcript positions the pins while it lays out its rows: [onLayout]
/// runs once this has laid out the copies, and the transcript sets
/// [RenderTranscriptStickyPrompts.stickyLayout]. A tap on a pinned bubble, or a
/// screen reader's activation, calls [onTap] with its prompt.
class const TranscriptStickyPromptOverlay({
  super.key,
  required final List<TranscriptPromptTurn> turns,

  /// The side padding that centres the transcript's rows, as the list has it.
  required final double horizontalInset,
  required final VoidCallback onLayout,
  required final void Function({required String openerMessageId}) onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return _StickyPrompts(
      openerIds: [for (final turn in turns) turn.opener.info.id],
      compactHeight: _compactHeight(
        context: context,
        style: buildChatMessageMarkdownStyleSheet(prego: prego).p,
      ),
      horizontalInset: horizontalInset,
      bubbleColor: prego.colors.bgSurface2,
      haloColor: Theme.of(context).scaffoldBackgroundColor,
      onLayout: onLayout,
      onTap: onTap,
      children: [
        for (final turn in turns) _copy(loc: loc, opener: turn.opener),
      ],
    );
  }

  Widget _copy({required AppLocalizations loc, required MessageWithParts opener}) {
    final id = opener.info.id;
    final markdown = UserMessageCard.markdownOf(message: opener);
    return RepaintBoundary(
      key: ValueKey((pinnedPrompt: id)),
      child: Semantics(
        container: true,
        button: true,
        label: markdown == null
            ? _attachmentLabelOf(loc: loc, opener: opener)
            : _spokenLabelOf(
                loc: loc,
                source: _cut(markdown: markdown, budget: _spokenCharacterBudget),
              ),
        hint: loc.transcriptStickyPromptJumpHint,
        onTap: () => onTap(openerMessageId: id),
        excludeSemantics: true,
        // Hit tests never reach the copy and focus never enters it, so nothing
        // in it can be pressed, selected or scrolled.
        child: ExcludeFocus(
          child: UserMessageBubbleContent(
            markdown: markdown == null ? null : _cut(markdown: markdown, budget: _copyCharacterBudget),
            attachments: [UserMessageCard.attachmentsOf(message: opener)],
          ),
        ),
      ),
    );
  }

  /// As much of a prompt as a pin can show, and no more. A pasted document
  /// can be megabytes long, and a copy of it all would double the cost of
  /// laying out that bubble. Several screens' worth, so the part of a pin in
  /// view always matches its bubble. Cutting mid-document can leave a code
  /// fence open, which the parser reads as a code block running to the end.
  static const _copyCharacterBudget = 10000;

  /// What a screen reader hears of a pin: a few paragraphs, enough to name the
  /// prompt. Activating the pin brings the reader to the prompt's own bubble.
  static const _spokenCharacterBudget = 2000;

  static String _cut({required String markdown, required int budget}) =>
      markdown.length <= budget ? markdown : markdown.substring(0, budget);

  /// A pin's words as a screen reader hears them: what the Markdown renders,
  /// without its `**markers**`, backticks and whole URLs.
  static String _spokenLabelOf({required AppLocalizations loc, required String source}) {
    final plain = markdownPlainText(
      markdown: source,
      nameImage: ({required altText}) => userPromptMarkdownImageName(loc: loc, altText: altText),
    );
    // A prompt of nothing but a horizontal rule renders no words; its own
    // short source beats an unlabelled button.
    return plain.isEmpty ? source : plain;
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

  /// A bubble holding three lines of body text at the reader's text scale: the
  /// height a longer prompt compacts to.
  static double _compactHeight({required BuildContext context, required TextStyle? style}) {
    final painter = TextPainter(
      text: TextSpan(text: "0\n0\n0", style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height + UserMessageBubble.padding * 2;
  }
}

class const _StickyPrompts({
  required final List<String> openerIds,
  required final double compactHeight,
  required final double horizontalInset,
  required final Color bubbleColor,
  required final Color haloColor,
  required final VoidCallback onLayout,
  required final void Function({required String openerMessageId}) onTap,
  required super.children,
}) extends MultiChildRenderObjectWidget {
  @override
  MultiChildRenderObjectElement createElement() => _StickyPromptsElement(this);

  @override
  RenderTranscriptStickyPrompts createRenderObject(BuildContext context) => RenderTranscriptStickyPrompts(
    openerIds: openerIds,
    compactHeight: compactHeight,
    horizontalInset: horizontalInset,
    bubbleColor: bubbleColor,
    haloColor: haloColor,
    onLayout: onLayout,
    onTap: onTap,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTranscriptStickyPrompts renderObject) {
    renderObject
      ..openerIds = openerIds
      ..compactHeight = compactHeight
      ..horizontalInset = horizontalInset
      ..bubbleColor = bubbleColor
      ..haloColor = haloColor
      ..onLayout = onLayout
      ..onTap = onTap;
  }
}

/// Reports only the pinned copies as onstage, as a reader sees them; the rest
/// are laid out ahead of time but never paint.
class _StickyPromptsElement(super.widget) extends MultiChildRenderObjectElement {
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (renderObject case final RenderTranscriptStickyPrompts pins) {
      final pinnedIds = {for (final pin in pins.stickyLayout.pinned) pin.openerId};
      for (final (index, child) in children.indexed) {
        if (pinnedIds.contains(pins.openerIds.elementAtOrNull(index))) visitor(child);
      }
    }
  }
}

/// Lays out one copy of bubble content per opener in [openerIds], and paints
/// the ones [stickyLayout] pins. Hit testing is translucent: a pinned band claims a
/// tap, so a tap beside the bubble does nothing rather than reaching a row the
/// pin hides, while a drag or a wheel that starts on it still scrolls the rows.
class RenderTranscriptStickyPrompts({
  required List<String> openerIds,

  /// The height a pinned prompt compacts to.
  required var double compactHeight,
  required double horizontalInset,
  required Color bubbleColor,
  required Color haloColor,
  required var VoidCallback onLayout,
  required var void Function({required String openerMessageId}) onTap,
}) extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CopyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CopyParentData> {
  List<String> _openerIds = openerIds;
  List<String> get openerIds => _openerIds;
  set openerIds(List<String> value) {
    if (listEquals(value, _openerIds)) return;
    _openerIds = value;
    markNeedsLayout();
  }

  double _horizontalInset = horizontalInset;
  double get horizontalInset => _horizontalInset;
  set horizontalInset(double value) {
    if (value == _horizontalInset) return;
    _horizontalInset = value;
    markNeedsLayout();
  }

  Color _bubbleColor = bubbleColor;
  Color get bubbleColor => _bubbleColor;
  set bubbleColor(Color value) {
    if (value == _bubbleColor) return;
    _bubbleColor = value;
    markNeedsPaint();
  }

  Color _haloColor = haloColor;
  Color get haloColor => _haloColor;
  set haloColor(Color value) {
    if (value == _haloColor) return;
    _haloColor = value;
    markNeedsPaint();
  }

  TranscriptStickyLayout _layout = TranscriptStickyLayout.empty;
  TranscriptStickyLayout get stickyLayout => _layout;

  /// Set while the transcript lays out, so the pins move in the frame the
  /// rows do.
  set stickyLayout(TranscriptStickyLayout value) {
    if (value == _layout) return;
    _layout = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  late final TapGestureRecognizer _tap = TapGestureRecognizer(debugOwner: this)..onTap = _handleTap;
  String? _tapTarget;
  final List<LayerHandle<ClipRRectLayer>> _clipLayers = [];

  /// Each copy's whole bubble height, once laid out.
  Map<String, double> get fullHeights => {
    for (final (index, child) in getChildrenAsList().indexed)
      if (child.hasSize && index < _openerIds.length)
        _openerIds[index]: child.size.height + UserMessageBubble.padding * 2,
  };

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CopyParentData) child.parentData = _CopyParentData();
  }

  @override
  void performLayout() {
    final maxWidth = UserMessageBubble.maxContentWidth(rowWidth: size.width - _horizontalInset * 2);
    final contentConstraints = BoxConstraints(maxWidth: max(0, maxWidth));
    for (final child in getChildrenAsList()) {
      child.layout(contentConstraints, parentUsesSize: true);
    }
    invokeLayoutCallback<BoxConstraints>((_) => onLayout());
  }

  RenderBox? _childFor({required String openerId}) {
    final index = _openerIds.indexOf(openerId);
    return index < 0 ? null : getChildrenAsList().elementAtOrNull(index);
  }

  TranscriptPinnedPrompt? _pinOf({required RenderBox child}) {
    final openerId = _openerIds.elementAtOrNull(getChildrenAsList().indexOf(child));
    return _layout.pinned.where((pin) => pin.openerId == openerId).firstOrNull;
  }

  /// Where [pin]'s bubble is, sized for its laid-out [child]: against the
  /// row's right edge, as the bubble's own row aligns it.
  Rect _bubbleOf({required TranscriptPinnedPrompt pin, required RenderBox child}) {
    final width = child.size.width + UserMessageBubble.padding * 2;
    final right = size.width - _horizontalInset - UserMessageBubble.margin.right;
    return Rect.fromLTWH(right - width, pin.top, width, pin.height);
  }

  /// The front-most pin whose bubble, or whole band across the row with [band],
  /// holds [position].
  TranscriptPinnedPrompt? _pinAt({required Offset position, required bool band}) {
    for (final pin in _layout.pinned.reversed) {
      final child = _childFor(openerId: pin.openerId);
      if (child == null || !child.hasSize) continue;
      final rect = band
          ? Rect.fromLTWH(_horizontalInset, pin.top, size.width - _horizontalInset * 2, pin.height)
          : _bubbleOf(pin: pin, child: child);
      if (rect.contains(position)) return pin;
    }
    return null;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_pinAt(position: position, band: true) == null) return false;
    result.add(BoxHitTestEntry(this, position));
    return false;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) return;
    _tapTarget = _pinAt(position: entry.localPosition, band: false)?.openerId;
    _tap.addPointer(event);
  }

  void _handleTap() {
    if (_tapTarget case final openerId?) onTap(openerMessageId: openerId);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final pinned = _layout.pinned;
    while (_clipLayers.length < pinned.length) {
      _clipLayers.add(LayerHandle<ClipRRectLayer>());
    }
    for (final (index, handle) in _clipLayers.indexed) {
      final pin = pinned.elementAtOrNull(index);
      final child = pin == null ? null : _childFor(openerId: pin.openerId);
      if (pin == null || child == null || !child.hasSize) {
        handle.layer = null;
        continue;
      }
      final bubble = _bubbleOf(pin: pin, child: child);
      final shape = RRect.fromRectAndRadius(bubble, const Radius.circular(UserMessageBubble.radius));
      if (pin.elevation > 0) {
        // A halo of the page's own background, so the pin lifts off the rows
        // sliding under it without the glyphs its edge cuts through crowding
        // it. Unclipped, so above the pin line it melts into the bar's fade.
        // Judge it with shadows enabled: `flutter_test` disables the blur.
        final halo = BoxShadow(
          color: _haloColor.withValues(alpha: _haloColor.a * pin.elevation),
          blurRadius: 28,
          spreadRadius: 14,
        );
        context.canvas.drawRRect(shape.shift(offset).inflate(halo.spreadRadius), halo.toPaint());
      }
      context.canvas.drawRRect(shape.shift(offset), Paint()..color = _bubbleColor);
      handle.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        bubble,
        shape,
        (context, offset) {
          context.paintChild(
            child,
            offset + bubble.topLeft.translate(UserMessageBubble.padding, UserMessageBubble.padding),
          );
          _paintCut(canvas: context.canvas, bubble: bubble.shift(offset), pin: pin);
        },
        oldLayer: handle.layer,
      );
    }
  }

  /// Fades a compacted pin's content out above its bottom padding, which it
  /// keeps clear, as the bubble's own does.
  void _paintCut({required Canvas canvas, required Rect bubble, required TranscriptPinnedPrompt pin}) {
    final cut = pin.fullHeight - pin.height;
    if (cut <= 0) return;
    final contentBottom = bubble.bottom - UserMessageBubble.padding;
    final fade = Rect.fromLTRB(bubble.left, contentBottom - min(16, cut), bubble.right, contentBottom);
    canvas
      ..drawRect(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bubbleColor.withValues(alpha: 0), _bubbleColor],
          ).createShader(fade),
      )
      ..drawRect(Rect.fromLTRB(bubble.left, contentBottom, bubble.right, bubble.bottom), Paint()..color = _bubbleColor);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pin = _pinOf(child: child);
    if (pin == null) return;
    final bubble = _bubbleOf(pin: pin, child: child);
    transform.translateByDouble(
      bubble.left + UserMessageBubble.padding,
      bubble.top + UserMessageBubble.padding,
      0,
      1,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (child is! RenderBox) return null;
    final pin = _pinOf(child: child);
    return pin == null ? null : _bubbleOf(pin: pin, child: child);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final pin in _layout.pinned) {
      if (_childFor(openerId: pin.openerId) case final child? when child.hasSize) visitor(child);
    }
  }

  @override
  void dispose() {
    for (final handle in _clipLayers) {
      handle.layer = null;
    }
    _tap.dispose();
    super.dispose();
  }
}

final class _CopyParentData() extends ContainerBoxParentData<RenderBox>;
