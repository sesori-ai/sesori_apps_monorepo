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
import "invocation_card.dart";
import "transcript_motion.dart";
import "transcript_sticky_layout.dart";
import "user_message_card.dart";
import "user_prompt_markdown_image.dart";

/// The user messages, prompts and steers alike, pinned over the transcript's
/// top edge, as [layOutTranscriptStickyPrompts] places them. It holds a copy
/// of the bubble content of every message in [messages], those that could pin
/// next, and paints only the pinned ones, on a surface of the bubble's own
/// shape and colour, so a pin is pixel-identical to the bubble it takes over
/// from. A command, skill or MCP prompt the user ran pins as its card instead,
/// at the row's leading edge, as [promptTurnShapes] has its row draw it.
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

  /// Whether each of [messages] is a card or a bubble, as its row shows it.
  required final PromptTurnShapes promptTurnShapes,

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

  /// The text a message's copy speaks and shows, or null when it has none: a
  /// card's arguments, else the bubble's text. A message's [shape] follows
  /// from the message alone, so the cut stays right for it.
  static _CopyText? _textOf({required MessageWithParts message, required PromptTurnShape shape}) {
    final cached = _texts[message];
    if (cached != null) return cached;
    final markdown = switch (shape) {
      InvocationPromptTurnShape(:final arguments) => arguments,
      BubblePromptTurnShape() => UserMessageCard.markdownOf(message: message),
    };
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

  /// A line of body text at the reader's text scale, which a longer prompt's
  /// compact height counts in.
  static double _bodyLineHeight({required BuildContext context, required TextStyle? style}) {
    final painter = TextPainter(
      text: TextSpan(text: "0", style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
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

  /// Each card copy's header height, by opener, as the copy last laid out.
  final Map<String, double> _cardHeaderHeights = {};

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
          if (TranscriptStickyPromptOverlay._textOf(
                message: message,
                shape: _shapeOf(message: message),
              )?.cut ??
              false)
            message.info.id,
      },
      bodyLineHeight: TranscriptStickyPromptOverlay._bodyLineHeight(
        context: context,
        style: buildChatMessageMarkdownStyleSheet(prego: prego).p,
      ),
      cardHeaderHeights: _cardHeaderHeights,
      horizontalInset: widget.horizontalInset,
      bubbleColor: _bubbleFill(
        prego: prego,
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
      ),
      cardFill: InvocationCard.fill(prego: prego),
      cardBorder: InvocationCard.border(prego: prego),
      haloColor: Theme.of(context).scaffoldBackgroundColor,
      // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
      fadesTopEdge: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
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

  PromptTurnShape _shapeOf({required MessageWithParts message}) =>
      widget.promptTurnShapes.ofMessage(messageId: message.info.id);

  Widget _copy({required AppLocalizations loc, required MessageWithParts opener}) {
    final id = opener.info.id;
    final shape = _shapeOf(message: opener);
    final text = TranscriptStickyPromptOverlay._textOf(message: opener, shape: shape);
    final key = ValueKey((pinnedPrompt: id));
    return switch (shape) {
      InvocationPromptTurnShape(:final name, :final source) => _cardCopy(
        key: key,
        loc: loc,
        id: id,
        name: name,
        source: source,
        spoken: text?.head,
        arguments: text?.end,
        attachments: UserMessageCard.cardAttachmentsOf(message: opener),
      ),
      BubblePromptTurnShape() => _pinnable(
        key: key,
        loc: loc,
        id: id,
        surface: _PinSurface.bubble,
        label: text == null
            // A prompt with no text is named by its first attachment.
            ? opener.promptText ?? loc.transcriptStickyPromptAttachment
            : TranscriptStickyPromptOverlay._spokenLabelOf(loc: loc, source: text.head),
        content: UserMessageBubbleContent(
          markdown: text?.end,
          attachments: [UserMessageCard.attachmentsOf(message: opener)],
          alignment: .end,
        ),
      ),
    };
  }

  /// An unloaded prompt's copy: the start of it the prompt index previews, or
  /// the card of what it ran.
  Widget _previewCopy({required AppLocalizations loc, required SessionPromptIndexEntry entry}) {
    final key = ValueKey((unloadedPrompt: entry.messageId));
    if (entry.invocation case CommandInvocation(:final name, :final source, :final arguments)) {
      String? cut({required int budget}) => switch (arguments) {
        final arguments? => TranscriptStickyPromptOverlay._cut(markdown: arguments, budget: budget),
        null => null,
      };
      return _cardCopy(
        key: key,
        loc: loc,
        id: entry.messageId,
        name: name,
        source: source,
        spoken: cut(budget: TranscriptStickyPromptOverlay._spokenCharacterBudget),
        arguments: cut(budget: TranscriptStickyPromptOverlay._copyCharacterBudget),
        attachments: const [],
      );
    }
    final preview = entry.preview;
    return _pinnable(
      key: key,
      loc: loc,
      id: entry.messageId,
      surface: _PinSurface.bubble,
      label: preview == null
          ? loc.transcriptStickyPromptAttachment
          : TranscriptStickyPromptOverlay._spokenLabelOf(loc: loc, source: preview),
      content: UserMessageBubbleContent(
        markdown: preview ?? loc.transcriptStickyPromptAttachment,
        attachments: const [],
        alignment: .end,
      ),
    );
  }

  /// A card's copy, which reports its header's height so its pin can keep the
  /// whole header as it compacts.
  Widget _cardCopy({
    required Key key,
    required AppLocalizations loc,
    required String id,
    required String name,
    required CommandSource source,
    required String? spoken,
    required String? arguments,
    required List<Widget> attachments,
  }) => _pinnable(
    key: key,
    loc: loc,
    id: id,
    surface: _PinSurface.card,
    label: [
      loc.invocationCardSemantics(source.name, name),
      if (spoken != null) TranscriptStickyPromptOverlay._spokenLabelOf(loc: loc, source: spoken),
    ].join("\n"),
    content: InvocationCardContent(
      name: name,
      source: source,
      arguments: arguments,
      attachments: attachments,
      onHeaderLayout: (height) => _cardHeaderHeights[id] = height,
    ),
  );

  Widget _pinnable({
    required Key key,
    required AppLocalizations loc,
    required String id,
    required _PinSurface surface,
    required String label,
    required Widget content,
  }) => _PinCopy(
    key: key,
    surface: surface,
    child: RepaintBoundary(
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
    ),
  );
}

/// A copy's text: the [head] a screen reader hears, the [end] it shows, and
/// whether [end] was [cut] from a longer message.
typedef _CopyText = ({String head, String end, bool cut});

/// The surface a copy stands on, drawn as its row draws it: a bubble against
/// the row's trailing edge, or an invocation card against its leading edge.
enum _PinSurface({required final double inset, required final double radius}) {
  bubble(inset: UserMessageBubble.padding, radius: UserMessageBubble.radius),
  card(inset: InvocationCard.inset, radius: InvocationCard.radius),
}

/// Which surface its copy stands on.
class const _PinCopy({super.key, required final _PinSurface surface, required super.child})
    extends ParentDataWidget<_CopyParentData> {
  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData;
    if (parentData is! _CopyParentData || parentData.surface == surface) return;
    parentData.surface = surface;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _StickyPrompts;
}

class const _StickyPrompts({
  required final List<String> openerIds,
  required final Set<String> cutOpenerIds,
  required final double bodyLineHeight,
  required final Map<String, double> cardHeaderHeights,
  required final double horizontalInset,
  required final Color bubbleColor,
  required final Color cardFill,
  required final BoxBorder cardBorder,
  required final Color haloColor,
  required final bool fadesTopEdge,
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
    bodyLineHeight: bodyLineHeight,
    cardHeaderHeights: cardHeaderHeights,
    horizontalInset: horizontalInset,
    bubbleColor: bubbleColor,
    cardFill: cardFill,
    cardBorder: cardBorder,
    haloColor: haloColor,
    fadesTopEdge: fadesTopEdge,
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
      ..bodyLineHeight = bodyLineHeight
      ..horizontalInset = horizontalInset
      ..bubbleColor = bubbleColor
      ..cardFill = cardFill
      ..cardBorder = cardBorder
      ..haloColor = haloColor
      ..fadesTopEdge = fadesTopEdge
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

  /// A line of body text, which a pinned prompt's compact height counts in.
  required var double bodyLineHeight,

  /// Each card copy's header height, by opener, as the copies report it.
  required final Map<String, double> cardHeaderHeights,
  required double horizontalInset,
  required Color bubbleColor,
  required Color cardFill,
  required BoxBorder cardBorder,
  required Color haloColor,

  /// Whether the rows fade out at the top edge, where a header rather than a
  /// glass bar with its own fade cuts them, so a line passing beside a pin is
  /// never cut there.
  required var bool fadesTopEdge,
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

  Color _cardFill = cardFill;
  Color get cardFill => _cardFill;
  set cardFill(Color value) {
    if (value == _cardFill) return;
    _cardFill = value;
    markNeedsPaint();
  }

  BoxBorder _cardBorder = cardBorder;
  BoxBorder get cardBorder => _cardBorder;
  set cardBorder(BoxBorder value) {
    if (value == _cardBorder) return;
    _cardBorder = value;
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

  /// The height a pinned bubble compacts to: three lines of body text.
  double get compactHeight => bodyLineHeight * 3 + UserMessageBubble.padding * 2;

  /// Each copy's whole surface height, once laid out, and the height its pin
  /// compacts to.
  Map<String, TranscriptPinHeights> get pinHeights => {
    for (final (index, child) in getChildrenAsList().indexed)
      if (child.hasSize && index < _openerIds.length)
        _openerIds[index]: _heightsOf(child: child, openerId: _openerIds[index]),
  };

  /// [child]'s heights, as the copy of [openerId]. A bubble compacts to
  /// [compactHeight]; a card to its whole header and two lines of what
  /// follows, so a pinned card still names what ran.
  TranscriptPinHeights _heightsOf({required RenderBox child, required String openerId}) {
    final surface = _surfaceOf(child: child);
    final full = child.size.height + surface.inset * 2;
    final compact = switch (surface) {
      _PinSurface.bubble => compactHeight,
      _PinSurface.card => switch (cardHeaderHeights[openerId]) {
        final header? => surface.inset * 2 + header + InvocationCardContent.bodyGap + bodyLineHeight * 2,
        null => full,
      },
    };
    return (full: full, compact: min(full, compact));
  }

  static _PinSurface _surfaceOf({required RenderBox child}) => switch (child.parentData) {
    _CopyParentData(:final surface) => surface,
    _ => _PinSurface.bubble,
  };

  /// [surface]'s fill.
  Color _fillOf({required _PinSurface surface}) => switch (surface) {
    _PinSurface.bubble => _bubbleColor,
    _PinSurface.card => _cardFill,
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
    final rowWidth = size.width - _horizontalInset * 2;
    for (final child in getChildrenAsList()) {
      final maxWidth = switch (_surfaceOf(child: child)) {
        _PinSurface.bubble => UserMessageBubble.maxContentWidth(rowWidth: rowWidth),
        _PinSurface.card => InvocationCard.maxContentWidth(rowWidth: rowWidth),
      };
      child.layout(BoxConstraints(maxWidth: max(0, maxWidth)), parentUsesSize: true);
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

  /// Where [pin]'s surface is, sized for its laid-out [child]: against the
  /// row's right edge for a bubble, its left for a card, as the row aligns it.
  Rect _bubbleOf({required TranscriptPinnedPrompt pin, required RenderBox child}) {
    final surface = _surfaceOf(child: child);
    final width = child.size.width + surface.inset * 2;
    final left = switch (surface) {
      _PinSurface.bubble => size.width - _horizontalInset - UserMessageBubble.margin.right - width,
      _PinSurface.card => _horizontalInset + UserMessageBubble.margin.left,
    };
    return Rect.fromLTWH(left, pin.top, width, pin.height);
  }

  /// Where [pin] paints its laid-out [child] within its [bubble]: from the
  /// bubble's top, or ending at its bottom when the pin shows the end.
  static Offset _contentOf({required TranscriptPinnedPrompt pin, required RenderBox child, required Rect bubble}) {
    final surface = _surfaceOf(child: child);
    final inset = surface.inset;
    return _showsStart(pin: pin, surface: surface)
        ? bubble.topLeft.translate(inset, inset)
        : Offset(bubble.left + inset, bubble.bottom - inset - child.size.height);
  }

  /// Whether [pin] shows its copy's start. A tall card takes over from its
  /// end, as a tall bubble does, but then turns over to its start through its
  /// own fill, so its pin still names what ran.
  static bool _showsStart({required TranscriptPinnedPrompt pin, required _PinSurface surface}) => switch (pin.view) {
    TranscriptPinStart() => true,
    TranscriptPinEnd(:final fade) => surface == _PinSurface.card && fade >= 0.5,
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
    if (fadesTopEdge) _paintTopEdge(canvas: context.canvas, offset: offset);
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

  /// Fades the rows out over the top edge's first few pixels, under the pins
  /// and their halos.
  void _paintTopEdge({required Canvas canvas, required Offset offset}) {
    final edge = offset & Size(size.width, 10);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_haloColor, _haloColor.withValues(alpha: 0)],
        ).createShader(edge),
    );
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
    final surface = _surfaceOf(child: child);
    final fill = _fillOf(surface: surface);
    final from = switch (leaving) {
      (:final child, :final progress) => (
        child: child,
        progress: progress,
        pin: switch (_heightsOf(child: child, openerId: pin.openerId)) {
          (:final full, :final compact) => (
            openerId: pin.openerId,
            top: pin.top,
            height: compact,
            fullHeight: full,
            elevation: pin.elevation,
            view: const TranscriptPinStart(),
          ),
        },
      ),
      null => null,
    };
    final fromBubble = switch (from) {
      (:final child, progress: _, :final pin) => _bubbleOf(pin: pin, child: child),
      null => entering,
    };
    final shown = switch (from) {
      (child: _, :final progress, pin: _) => Rect.lerp(fromBubble, entering, progress) ?? entering,
      null => entering,
    };
    final shape = RRect.fromRectAndRadius(shown, Radius.circular(surface.radius));
    if (pin.elevation > 0) {
      // Unclipped, so above the pin line it melts into the bar's fade.
      final halo = pregoPageHaloShadow(color: _haloColor.withValues(alpha: _haloColor.a * pin.elevation));
      context.canvas.drawRRect(shape.shift(offset).inflate(halo.spreadRadius), halo.toPaint());
    }
    context.canvas.drawRRect(shape.shift(offset), Paint()..color = fill);
    handle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      shown,
      shape,
      // Each copy stays where its own bubble holds it, so only the surface
      // moves while the words crossfade.
      (context, offset) {
        if (from == null) {
          return _paintContent(context: context, offset: offset, pin: pin, child: child, bubble: shown);
        }
        _leavingLayer.layer = context.pushOpacity(
          offset,
          ((1 - from.progress) * 255).round(),
          (context, offset) =>
              _paintContent(context: context, offset: offset, pin: from.pin, child: from.child, bubble: fromBubble),
          oldLayer: _leavingLayer.layer,
        );
        _enteringLayer.layer = context.pushOpacity(
          offset,
          (from.progress * 255).round(),
          (context, offset) =>
              _paintContent(context: context, offset: offset, pin: pin, child: child, bubble: entering),
          oldLayer: _enteringLayer.layer,
        );
      },
      oldLayer: handle.layer,
    );
    // Over the content and its cut edge, as the card's own border is.
    if (surface == _PinSurface.card) {
      _cardBorder.paint(context.canvas, shown.shift(offset), borderRadius: BorderRadius.circular(surface.radius));
    }
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
    final surface = _surfaceOf(child: child);
    final shown = bubble.shift(offset);
    switch (pin.view) {
      case TranscriptPinStart():
        _paintCut(canvas: canvas, bubble: shown, pin: pin, surface: surface);
      case TranscriptPinEnd(:final fade) when surface == _PinSurface.card:
        // The end fades out into the fill and the start fades in from it, so
        // the words never jump from one to the other.
        if (fade < 0.5) {
          _paintTopCut(canvas: canvas, bubble: shown, fade: fade * 2, surface: surface);
        } else {
          _paintCut(canvas: canvas, bubble: shown, pin: pin, surface: surface);
        }
        final fill = _fillOf(surface: surface);
        canvas.drawRect(shown, Paint()..color = fill.withValues(alpha: fill.a * (1 - (1 - fade * 2).abs())));
      case TranscriptPinEnd(:final fade):
        _paintTopCut(canvas: canvas, bubble: shown, fade: fade, surface: surface);
    }
  }

  /// Fades a compacted pin's content out above its bottom padding, which it
  /// keeps clear, as the bubble's own does.
  void _paintCut({
    required Canvas canvas,
    required Rect bubble,
    required TranscriptPinnedPrompt pin,
    required _PinSurface surface,
  }) {
    final cut = pin.fullHeight - pin.height;
    if (cut <= 0) return;
    final fill = _fillOf(surface: surface);
    final contentBottom = bubble.bottom - surface.inset;
    // The fade grows from nothing, so the pin still takes over from its bubble
    // pixel for pixel, but four times as fast as the cut: a line the cut has
    // reached fades out to it rather than showing sliced through, even where a
    // pin rests just past the pin line, as a first prompt barely above it does.
    final fade = Rect.fromLTRB(bubble.left, contentBottom - min(16, cut * 4), bubble.right, contentBottom);
    canvas
      ..drawRect(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fill.withValues(alpha: 0), fill],
          ).createShader(fade),
      )
      ..drawRect(Rect.fromLTRB(bubble.left, contentBottom, bubble.right, bubble.bottom), Paint()..color = fill);
  }

  /// Fades the cut top of a pin that shows its bubble's end, as [_paintCut]
  /// does its bottom. It fades in by [fade] from where the pin covers its
  /// bubble exactly, so the handover stays pixel-identical.
  void _paintTopCut({
    required Canvas canvas,
    required Rect bubble,
    required double fade,
    required _PinSurface surface,
  }) {
    if (fade <= 0) return;
    final fill = _fillOf(surface: surface);
    final color = fill.withValues(alpha: fill.a * fade);
    final contentTop = bubble.top + surface.inset;
    final edge = Rect.fromLTRB(bubble.left, contentTop, bubble.right, contentTop + 16);
    canvas
      ..drawRect(Rect.fromLTRB(bubble.left, bubble.top, bubble.right, contentTop), Paint()..color = color)
      ..drawRect(
        edge,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, fill.withValues(alpha: 0)],
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

final class _CopyParentData() extends ContainerBoxParentData<RenderBox> {
  _PinSurface surface = _PinSurface.bubble;
}

/// The bubble's own fill; the light desktop page is too near its usual one.
Color _bubbleFill({required PregoDesignSystem prego, required bool pointer}) =>
    pointer && prego.colors.brightness == .light ? prego.colors.bgSurface1 : prego.colors.bgSurface2;
