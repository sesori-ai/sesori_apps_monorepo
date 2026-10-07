import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../utils/markdown_plain_text.dart";
import "../../../widgets/markdown_styles.dart";
import "transcript_motion.dart";
import "transcript_sticky_layout.dart";
import "user_message_card.dart";
import "user_prompt_markdown_image.dart";

/// The user messages, prompts and steers alike, pinned over the transcript's
/// top edge, as [layOutTranscriptStickyPrompts] places them. It holds a copy
/// of the bubble content of every message in [messages], those that could pin
/// next, and paints only the pinned ones, on a surface of the bubble's own
/// shape and colour, so a pin is pixel-identical to the bubble it takes over
/// from.
///
/// The transcript positions the pins while it lays out its rows: [onLayout]
/// runs once this has laid out the copies, and the transcript sets
/// [RenderTranscriptStickyPrompts.stickyLayout]. A tap on a pinned bubble, or a
/// screen reader's activation, calls [onTap] with its message.
///
/// The [unloaded] prompt pins its index preview in the same bubble. Its pin
/// fades in as it first shows, and over to its message's own copy once that
/// message loads, so the swap never snaps.
class const TranscriptStickyPromptOverlay({
  super.key,
  required final List<MessageWithParts> messages,

  /// The prompt that pins above the loaded messages without being loaded
  /// itself; null when none does.
  required final SessionPromptIndexEntry? unloaded,

  /// The side padding that centres the transcript's rows, as the list has it.
  required final double horizontalInset,
  required final VoidCallback onLayout,
  required final void Function({required String openerMessageId}) onTap,
}) extends StatefulWidget {
  @override
  State<TranscriptStickyPromptOverlay> createState() => _TranscriptStickyPromptOverlayState();

  /// As much of a message as a pin can show, and no more. A pasted document
  /// can be megabytes long, and a copy of it all would double the cost of
  /// laying out that bubble. Several screens' worth, so the part of a pin in
  /// view always matches its bubble: a message this long is taller than the
  /// screen, so its pin shows its end.
  static const _copyCharacterBudget = 10000;

  /// Each message's copy text, cut once rather than on every build: messages
  /// are immutable, and the transcript rebuilds while an answer streams.
  static final _texts = Expando<_CopyText>();

  /// The text a message's copy speaks and shows, or null when it has none.
  static _CopyText? _textOf({required MessageWithParts message}) {
    final cached = _texts[message];
    if (cached != null) return cached;
    final markdown = UserMessageCard.markdownOf(message: message);
    if (markdown == null) return null;
    return _texts[message] = (
      head: _cut(markdown: markdown, budget: _spokenCharacterBudget),
      end: _endOf(markdown: markdown),
      cut: markdown.length > _copyCharacterBudget,
    );
  }

  /// The last [_copyCharacterBudget] characters or so of [markdown], from the
  /// start of a line unless that would drop most of them. A code fence the cut
  /// lands inside opens again, so the end renders as its bubble renders it
  /// rather than as backticks closing nothing.
  static String _endOf({required String markdown}) {
    if (markdown.length <= _copyCharacterBudget) return markdown;
    final from = markdown.length - _copyCharacterBudget;
    final newline = markdown.indexOf("\n", from);
    final start = newline < 0 || newline - from > _copyCharacterBudget ~/ 2 ? from : newline + 1;
    // Walks the lines in place, as copying the prefix would cost as much as
    // the whole document.
    ({int char, int length, int start, int end})? open;
    for (var lineStart = 0; lineStart < start;) {
      final lineBreak = markdown.indexOf("\n", lineStart);
      final lineEnd = lineBreak < 0 || lineBreak > start ? start : lineBreak;
      final fence = _fenceIn(text: markdown, start: lineStart, end: lineEnd);
      if (fence != null) {
        if (open == null) {
          open = (char: fence.char, length: fence.length, start: lineStart, end: lineEnd);
        } else if (fence.bare && fence.char == open.char && fence.length >= open.length) {
          open = null;
        }
      }
      lineStart = lineEnd + 1;
    }
    final end = markdown.substring(start);
    return open == null ? end : "${markdown.substring(open.start, open.end)}\n$end";
  }

  /// The code fence marker the line from [start] to [end] of [text] begins
  /// with: its character, its run length and whether nothing follows it, as
  /// a closing fence needs. Null for any other line.
  static ({int char, int length, bool bare})? _fenceIn({
    required String text,
    required int start,
    required int end,
  }) {
    var at = start;
    while (at < end && at - start < 3 && text.codeUnitAt(at) == _space) {
      at++;
    }
    if (at == end) return null;
    final char = text.codeUnitAt(at);
    if (char != _backtick && char != _tilde) return null;
    var run = at;
    while (run < end && text.codeUnitAt(run) == char) {
      run++;
    }
    if (run - at < 3) return null;
    return (char: char, length: run - at, bare: text.substring(run, end).trim().isEmpty);
  }

  static const _space = 0x20;
  static const _backtick = 0x60;
  static const _tilde = 0x7E;

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

class _TranscriptStickyPromptOverlayState()
    extends State<TranscriptStickyPromptOverlay>
    with SingleTickerProviderStateMixin {
  /// Runs the unloaded prompt's pin in, from nothing or from its preview; it
  /// rests at 1.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: transcriptMotionDuration,
    value: 1,
  )..addStatusListener(_dropLeaving);
  late final CurvedAnimation _curvedFade = CurvedAnimation(parent: _fade, curve: Curves.easeInOut);

  /// The prompt whose pin [_fade] runs in.
  String? _fadingId;

  /// The preview a just-loaded prompt's pin fades over from.
  SessionPromptIndexEntry? _leaving;

  void _dropLeaving(AnimationStatus status) {
    if (status.isCompleted && _leaving != null) setState(() => _leaving = null);
  }

  @override
  void didUpdateWidget(TranscriptStickyPromptOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.unloaded;
    final now = widget.unloaded;
    if (was?.messageId == now?.messageId || context.isReducedMotion) return;
    if (was != null && widget.messages.any((message) => message.info.id == was.messageId)) {
      _leaving = was;
      _fadingId = was.messageId;
    } else if (now != null) {
      _leaving = null;
      _fadingId = now.messageId;
    } else {
      return;
    }
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _curvedFade.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final messages = widget.messages;
    final unloaded = widget.unloaded;
    final leaving = _leaving;
    return _StickyPrompts(
      openerIds: [for (final message in messages) message.info.id, ?unloaded?.messageId],
      cutOpenerIds: {
        for (final message in messages)
          if (TranscriptStickyPromptOverlay._textOf(message: message)?.cut ?? false) message.info.id,
      },
      compactHeight: TranscriptStickyPromptOverlay._compactHeight(
        context: context,
        style: buildChatMessageMarkdownStyleSheet(prego: prego).p,
      ),
      horizontalInset: widget.horizontalInset,
      bubbleColor: prego.colors.bgSurface2,
      haloColor: Theme.of(context).scaffoldBackgroundColor,
      fade: _curvedFade,
      fadingOpenerId: _fadingId,
      hasLeavingCopy: leaving != null,
      onLayout: widget.onLayout,
      onTap: widget.onTap,
      children: [
        for (final message in messages) _copy(loc: loc, opener: message),
        if (unloaded != null) _previewCopy(loc: loc, entry: unloaded),
        if (leaving != null) _previewCopy(loc: loc, entry: leaving),
      ],
    );
  }

  Widget _copy({required AppLocalizations loc, required MessageWithParts opener}) {
    final text = TranscriptStickyPromptOverlay._textOf(message: opener);
    return _pinnable(
      key: ValueKey((pinnedPrompt: opener.info.id)),
      loc: loc,
      id: opener.info.id,
      label: text == null
          // A prompt with no text is named by its first attachment.
          ? opener.promptText ?? loc.transcriptStickyPromptAttachment
          : TranscriptStickyPromptOverlay._spokenLabelOf(loc: loc, source: text.head),
      content: UserMessageBubbleContent(
        markdown: text?.end,
        attachments: [UserMessageCard.attachmentsOf(message: opener)],
      ),
    );
  }

  /// An unloaded prompt's copy: the start of it the prompt index previews.
  Widget _previewCopy({required AppLocalizations loc, required SessionPromptIndexEntry entry}) {
    final preview = entry.preview;
    return _pinnable(
      key: ValueKey((unloadedPrompt: entry.messageId)),
      loc: loc,
      id: entry.messageId,
      label: preview == null
          ? loc.transcriptStickyPromptAttachment
          : TranscriptStickyPromptOverlay._spokenLabelOf(loc: loc, source: preview),
      content: UserMessageBubbleContent(
        markdown: preview ?? loc.transcriptStickyPromptAttachment,
        attachments: const [],
      ),
    );
  }

  Widget _pinnable({
    required Key key,
    required AppLocalizations loc,
    required String id,
    required String label,
    required Widget content,
  }) => RepaintBoundary(
    key: key,
    child: Semantics(
      container: true,
      button: true,
      label: label,
      hint: loc.transcriptStickyPromptJumpHint,
      onTap: () => widget.onTap(openerMessageId: id),
      excludeSemantics: true,
      // Hit tests never reach the copy and focus never enters it, so nothing
      // in it can be pressed, selected or scrolled.
      child: ExcludeFocus(child: content),
    ),
  );
}

/// A copy's text: the [head] a screen reader hears, the [end] it shows, and
/// whether [end] was [cut] from a longer message.
typedef _CopyText = ({String head, String end, bool cut});

class const _StickyPrompts({
  required final List<String> openerIds,
  required final Set<String> cutOpenerIds,
  required final double compactHeight,
  required final double horizontalInset,
  required final Color bubbleColor,
  required final Color haloColor,
  required final Animation<double> fade,
  required final String? fadingOpenerId,
  required final bool hasLeavingCopy,
  required final VoidCallback onLayout,
  required final void Function({required String openerMessageId}) onTap,
  required super.children,
}) extends MultiChildRenderObjectWidget {
  @override
  MultiChildRenderObjectElement createElement() => _StickyPromptsElement(this);

  @override
  RenderTranscriptStickyPrompts createRenderObject(BuildContext context) => RenderTranscriptStickyPrompts(
    openerIds: openerIds,
    cutOpenerIds: cutOpenerIds,
    compactHeight: compactHeight,
    horizontalInset: horizontalInset,
    bubbleColor: bubbleColor,
    haloColor: haloColor,
    fade: fade,
    fadingOpenerId: fadingOpenerId,
    hasLeavingCopy: hasLeavingCopy,
    onLayout: onLayout,
    onTap: onTap,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTranscriptStickyPrompts renderObject) {
    renderObject
      ..openerIds = openerIds
      ..cutOpenerIds = cutOpenerIds
      ..compactHeight = compactHeight
      ..horizontalInset = horizontalInset
      ..bubbleColor = bubbleColor
      ..haloColor = haloColor
      ..fade = fade
      ..fadingOpenerId = fadingOpenerId
      ..hasLeavingCopy = hasLeavingCopy
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
///
/// While [fade] runs, [fadingOpenerId]'s pin fades in: over from the copy
/// after [openerIds]' when [hasLeavingCopy], the bubble moving between the
/// two copies' sizes, or else from nothing.
class RenderTranscriptStickyPrompts({
  required List<String> openerIds,

  /// The openers whose copy holds only the end of a longer message.
  required var Set<String> cutOpenerIds,

  /// The height a pinned prompt compacts to.
  required var double compactHeight,
  required double horizontalInset,
  required Color bubbleColor,
  required Color haloColor,
  required Animation<double> fade,
  required String? fadingOpenerId,
  required bool hasLeavingCopy,
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

  Animation<double> _fade = fade;
  Animation<double> get fade => _fade;
  set fade(Animation<double> value) {
    if (value == _fade) return;
    if (attached) {
      _fade.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _fade = value;
    markNeedsPaint();
  }

  String? _fadingOpenerId = fadingOpenerId;
  String? get fadingOpenerId => _fadingOpenerId;
  set fadingOpenerId(String? value) {
    if (value == _fadingOpenerId) return;
    _fadingOpenerId = value;
    markNeedsPaint();
  }

  bool _hasLeavingCopy = hasLeavingCopy;
  bool get hasLeavingCopy => _hasLeavingCopy;
  set hasLeavingCopy(bool value) {
    if (value == _hasLeavingCopy) return;
    _hasLeavingCopy = value;
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

  /// The fading pin's layers: the whole pin fading in, or its two copies
  /// crossfading.
  final _fadeLayer = LayerHandle<OpacityLayer>();
  final _enteringLayer = LayerHandle<OpacityLayer>();
  final _leavingLayer = LayerHandle<OpacityLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _fade.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _fade.removeListener(markNeedsPaint);
    super.detach();
  }

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

  /// Where [pin] paints its laid-out [child] within its [bubble]: from the
  /// bubble's top, or ending at its bottom when the pin shows the end.
  static Offset _contentOf({required TranscriptPinnedPrompt pin, required RenderBox child, required Rect bubble}) =>
      switch (pin.view) {
        TranscriptPinStart() => bubble.topLeft.translate(UserMessageBubble.padding, UserMessageBubble.padding),
        TranscriptPinEnd() => Offset(
          bubble.left + UserMessageBubble.padding,
          bubble.bottom - UserMessageBubble.padding - child.size.height,
        ),
      };

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
    final progress = _fade.value;
    var fading = false;
    for (final (index, handle) in _clipLayers.indexed) {
      final pin = pinned.elementAtOrNull(index);
      final child = pin == null ? null : _childFor(openerId: pin.openerId);
      if (pin == null || child == null || !child.hasSize) {
        handle.layer = null;
        continue;
      }
      if (progress >= 1 || pin.openerId != _fadingOpenerId) {
        _paintPin(context: context, offset: offset, handle: handle, pin: pin, child: child, leaving: null);
        continue;
      }
      fading = true;
      if (_hasLeavingCopy ? lastChild : null case final leaving? when leaving.hasSize) {
        _paintPin(
          context: context,
          offset: offset,
          handle: handle,
          pin: pin,
          child: child,
          leaving: (child: leaving, progress: progress),
        );
      } else {
        _fadeLayer.layer = context.pushOpacity(
          offset,
          (progress * 255).round(),
          (context, offset) =>
              _paintPin(context: context, offset: offset, handle: handle, pin: pin, child: child, leaving: null),
          oldLayer: _fadeLayer.layer,
        );
      }
    }
    if (!fading) _fadeLayer.layer = _enteringLayer.layer = _leavingLayer.layer = null;
  }

  /// Paints [pin]'s bubble and [child] in it, crossfading from [leaving]'s
  /// copy, shown from its start, as the bubble moves from that copy's size.
  void _paintPin({
    required PaintingContext context,
    required Offset offset,
    required LayerHandle<ClipRRectLayer> handle,
    required TranscriptPinnedPrompt pin,
    required RenderBox child,
    required ({RenderBox child, double progress})? leaving,
  }) {
    final entering = _bubbleOf(pin: pin, child: child);
    final from = switch (leaving) {
      (:final child, :final progress) => (
        child: child,
        progress: progress,
        pin: (
          openerId: pin.openerId,
          top: pin.top,
          height: min(child.size.height + UserMessageBubble.padding * 2, compactHeight),
          fullHeight: child.size.height + UserMessageBubble.padding * 2,
          elevation: pin.elevation,
          view: const TranscriptPinStart(),
        ),
      ),
      null => null,
    };
    final shown = switch (from) {
      (:final child, :final progress, :final pin) =>
        Rect.lerp(_bubbleOf(pin: pin, child: child), entering, progress) ?? entering,
      null => entering,
    };
    final shape = RRect.fromRectAndRadius(shown, const Radius.circular(UserMessageBubble.radius));
    if (pin.elevation > 0) {
      // Unclipped, so above the pin line it melts into the bar's fade.
      final halo = pregoPageHaloShadow(color: _haloColor.withValues(alpha: _haloColor.a * pin.elevation));
      context.canvas.drawRRect(shape.shift(offset).inflate(halo.spreadRadius), halo.toPaint());
    }
    context.canvas.drawRRect(shape.shift(offset), Paint()..color = _bubbleColor);
    handle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      shown,
      shape,
      (context, offset) {
        if (from == null) {
          return _paintContent(context: context, offset: offset, pin: pin, child: child, bubble: shown);
        }
        _leavingLayer.layer = context.pushOpacity(
          offset,
          ((1 - from.progress) * 255).round(),
          (context, offset) =>
              _paintContent(context: context, offset: offset, pin: from.pin, child: from.child, bubble: shown),
          oldLayer: _leavingLayer.layer,
        );
        _enteringLayer.layer = context.pushOpacity(
          offset,
          (from.progress * 255).round(),
          (context, offset) => _paintContent(context: context, offset: offset, pin: pin, child: child, bubble: shown),
          oldLayer: _enteringLayer.layer,
        );
      },
      oldLayer: handle.layer,
    );
  }

  /// Paints [child] where [pin] shows it in [bubble], with its cut edge.
  void _paintContent({
    required PaintingContext context,
    required Offset offset,
    required TranscriptPinnedPrompt pin,
    required RenderBox child,
    required Rect bubble,
  }) {
    context.paintChild(child, offset + _contentOf(pin: pin, child: child, bubble: bubble));
    final canvas = context.canvas;
    switch (pin.view) {
      case TranscriptPinStart():
        _paintCut(canvas: canvas, bubble: bubble.shift(offset), pin: pin);
      case TranscriptPinEnd(:final fade):
        _paintTopCut(canvas: canvas, bubble: bubble.shift(offset), fade: fade);
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

  /// Fades the cut top of a pin that shows its bubble's end, as [_paintCut]
  /// does its bottom. It fades in by [fade] from where the pin covers its
  /// bubble exactly, so the handover stays pixel-identical.
  void _paintTopCut({required Canvas canvas, required Rect bubble, required double fade}) {
    if (fade <= 0) return;
    final color = _bubbleColor.withValues(alpha: _bubbleColor.a * fade);
    final contentTop = bubble.top + UserMessageBubble.padding;
    final edge = Rect.fromLTRB(bubble.left, contentTop, bubble.right, contentTop + 16);
    canvas
      ..drawRect(Rect.fromLTRB(bubble.left, bubble.top, bubble.right, contentTop), Paint()..color = color)
      ..drawRect(
        edge,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, _bubbleColor.withValues(alpha: 0)],
          ).createShader(edge),
      );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pin = _pinOf(child: child);
    if (pin == null) return;
    final content = _contentOf(
      pin: pin,
      child: child,
      bubble: _bubbleOf(pin: pin, child: child),
    );
    transform.translateByDouble(content.dx, content.dy, 0, 1);
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
    for (final handle in [..._clipLayers, _fadeLayer, _enteringLayer, _leavingLayer]) {
      handle.layer = null;
    }
    _tap.dispose();
    super.dispose();
  }
}

final class _CopyParentData() extends ContainerBoxParentData<RenderBox>;
