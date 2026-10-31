import "dart:async" show Timer;
import "dart:math" as math;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show ValueListenable, clampDouble;
import "package:flutter/scheduler.dart" show SchedulerBinding, Ticker;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show wrapDictatedText;
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "sent_bubble_landing.dart";
import "transcript_live_row.dart";
import "user_message_card.dart";

/// The words of a live dictation, in a layer of their own over the screen.
/// Nothing under the layer moves or resizes for them, and they take no gestures,
/// so the hold on the pill carries on undisturbed.
///
/// [child] is the composer's body, the part of the composer the layer stays clear
/// of.
class const ComposerLiveWords({
  super.key,

  /// How far the hold has slid out of the pill. Fades the words with the finger.
  required final ValueListenable<double> cancelProgress,

  /// How much of the room above the body the composer's release hint takes. The
  /// words keep clear of it, and stay put when it goes.
  required final double hintHeight,

  /// Where words that aren't sent land.
  required final ComposerWordsBox box,
  required final TextStyle boxStyle,

  /// Whether the session is working. Words sent to an idle one wake it, and its
  /// working row comes in under them.
  required final bool isBusy,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<ComposerLiveWords> createState() => _ComposerLiveWordsState();
}

/// Neighbouring words at one opacity.
typedef _WordsRun = ({String text, double opacity});

/// What the layer shows, which outlives the dictation long enough to fade it.
sealed class const _Layer();

final class const _Hidden() extends _Layer;

final class const _Live({
  required final LiveWords words,

  /// The user has released: the words stop being tentative.
  required final bool finishing,
}) extends _Layer;

/// Fading out, showing the [last] words. Only a cancel drops them as they go.
final class const _Leaving({required final _Live last, required final bool cancelled}) extends _Layer;

/// On their way from where they stood, [from], to the [destination].
final class _Gliding({
  required final _Live last,
  required final Rect from,

  /// Where the glide last knew it was going, for when that place goes away.
  required var Rect target,
  required final _Destination destination,

  /// The words as bright as they each were when they set off. They carry on from
  /// there to fully bright, as they do when the user releases.
  required final List<_WordsRun> runs,

  /// Holds the bubble back for as long as the words are on their way to it.
  required final SentBubbleLandingController landing,
}) extends _Layer;

sealed class const _Destination();

/// Standing still until it's known where they go, which takes a frame or two.
final class const _Undecided() extends _Destination;

/// The bubble the landing holds. [text] is what it shows.
final class const _Bubble({required final String text}) extends _Destination;

/// The box, which [text] is now in, along with whatever it already held.
final class const _Box({required final String text}) extends _Destination;

/// A send whose bubble isn't being built, as when the list is scrolled away from
/// its end. The words go where it would have been and fade there. [text] is what
/// it would show.
final class const _Estimate({required final Rect rect, required final String text}) extends _Destination;

/// Nowhere to go: the words fade where they stand.
final class const _InPlace() extends _Destination;

/// How words appear at either end of a glide.
typedef _WordsLook = ({TextStyle style, EdgeInsets padding, BoxDecoration decoration});

/// The composer's box, for words landing in it. Works before the field is built:
/// a voice-first composer only brings it up once it has the words.
final class ComposerWordsBox({required final TextEditingController controller}) {
  /// Around the text inside the field.
  static const contentPadding = EdgeInsets.symmetric(vertical: PregoSpacing.md);

  /// What an [EditableText] keeps free at the end of each line for its caret.
  static const double _caretMargin = 3;

  final TextEditingController _controller = controller;
  RenderLandingSlot? _slot;
  bool _held = false;

  /// Keeps the field from showing its text until the words have arrived.
  void _hold({required bool held}) {
    _held = held;
    _slot?.hidden = held;
  }

  void _attach(RenderLandingSlot slot) {
    _slot = slot;
    slot.hidden = _held;
  }

  void _detach(RenderLandingSlot slot) {
    if (identical(_slot, slot)) _slot = null;
  }
}

/// Wraps the composer's field, as the place the [box]'s words land on. The field
/// fades in and out with the composer's layouts, so two can be up for a moment.
class const ComposerWordsBoxSlot({super.key, required final ComposerWordsBox box, required super.child})
    extends SingleChildRenderObjectWidget {
  @override
  RenderLandingSlot createRenderObject(BuildContext context) =>
      RenderLandingSlot(onAttach: box._attach, onDetach: box._detach);
}

class _ComposerLiveWordsState() extends State<ComposerLiveWords> with TickerProviderStateMixin {
  /// How long the layer takes to come in and to go.
  static const _enterDuration = Duration(milliseconds: 260);
  static const _exitDuration = Duration(milliseconds: 240);

  /// How far a cancelled dictation's words drop as they leave.
  static const double _cancelDrop = 12;

  /// How far the panel rises as it opens.
  static const double _panelRise = 6;

  /// How much of the words is left when the hold has slid all the way out.
  static const double _slideOutFade = 0.6;

  /// Words dimmed by a slide coming back when the release finishes the dictation.
  static const _slideBackDuration = Duration(milliseconds: 180);

  /// Between the words and whatever sits under them.
  static const double _wordsGap = PregoSpacing.md;

  /// The gap above the composer's body that its hint sits on.
  static const double _hintBaseline = 8;

  static const double _panelRadius = 18;
  static const int _panelLines = 5;

  static const _glideDuration = Duration(milliseconds: 340);
  static const _glideCurve = Cubic(.2, .8, .2, 1);

  /// How long the words stay over what they landed on, once it shows, to soften
  /// what differs between them: images in the bubble, or Markdown in the words.
  static const _handOverDuration = Duration(milliseconds: 90);
  static final double _handOverAt = _glideDuration.inMicroseconds / (_glideDuration + _handOverDuration).inMicroseconds;

  /// How far along its travel the text takes its final style and wrap.
  static const double _rewrapAt = 0.5;

  /// How many frames a sent bubble gets to be built before the words stop
  /// waiting for it. A list scrolled up a little builds it as its glide back
  /// begins, by when a few frames have gone: one that opens from nothing isn't
  /// kept until it comes within the list's cache.
  static const int _bubbleFrames = 5;

  /// From the composer's body up to the foot of a bubble still being sent: the
  /// selectors above the body and their gap (52), the list's end padding (8), and
  /// the row's margin (xs).
  static const double _estimatedSlotGap = 52 + 8 + PregoSpacing.xs;

  /// How far the composer keeps in from the sides of its column.
  static const double _composerSideInset = 16;

  final _portal = OverlayPortalController();
  final _wordsKey = GlobalKey();
  final _liveTextKey = GlobalKey<_LiveWordsTextState>();
  late final AnimationController _presence;
  late final CurvedAnimation _presenceCurve;
  late final AnimationController _glide;
  _Layer _layer = const _Hidden();

  /// Where the composer's body last was during the dictation. Words on their way
  /// out stay put even as they land in the box and the body grows.
  Rect? _composerRect;

  @override
  void initState() {
    super.initState();
    _presence = AnimationController(vsync: this, duration: _enterDuration, reverseDuration: _exitDuration)
      ..addStatusListener((status) {
        if (!status.isDismissed || _layer is! _Leaving) return;
        _portal.hide();
        setState(() => _layer = const _Hidden());
      });
    _presenceCurve = CurvedAnimation(parent: _presence, curve: Curves.ease);
    _glide = AnimationController(vsync: this, duration: _glideDuration + _handOverDuration)
      ..addListener(_handleGlideTick)
      ..addStatusListener((status) {
        if (status.isCompleted) _endGlide();
      });
    // A listener skips the current state, and a composer can remount mid-dictation.
    _handleVoiceState(state: context.read<VoiceInputCubit>().state);
  }

  @override
  void dispose() {
    // The owner going mid-glide leaves the bubble with nothing coming to it.
    if (_layer case _Gliding(:final landing)) landing.handOver();
    _glide.dispose();
    _presenceCurve.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _handleVoiceState({required VoiceInputState state}) {
    switch (state) {
      case VoiceInputLiveRecording(:final words):
        _showLive(
          live: _Live(words: words, finishing: false),
        );
      case VoiceInputLiveFinishing(:final words):
        _showLive(
          live: _Live(words: words, finishing: true),
        );
      case VoiceInputCancelling():
        _leave(cancelled: true);
      case VoiceInputCompleted(:final transcript):
        _land(transcript: transcript);
      case VoiceInputIdle() ||
          VoiceInputStarting() ||
          VoiceInputRecording() ||
          VoiceInputTranscribing() ||
          VoiceInputRetryPending() ||
          VoiceInputRetrying() ||
          VoiceInputRetryCancelling() ||
          VoiceInputDiscarding() ||
          VoiceInputStartFailed() ||
          VoiceInputTranscriptionFailed():
        _leave(cancelled: false);
    }
  }

  void _showLive({required _Live live}) {
    // Another hold starting this soon doesn't wait for the last words to arrive.
    if (_layer is _Gliding) _endGlide();
    setState(() => _layer = live);
    // The panel has nothing to show until there are words.
    if (live.words.text.isEmpty) return;
    if (!_portal.isShowing) _portal.show();
    _presence.forward();
  }

  void _leave({required bool cancelled}) {
    final layer = _layer;
    if (layer is! _Live) return;
    // Nothing to fade: a panel that never got a word. Reversing wouldn't fire the
    // status listener, and a portal still open from an earlier dictation would stay.
    if (_presence.isDismissed) {
      _portal.hide();
      setState(() => _layer = const _Hidden());
      return;
    }
    _liveTextKey.currentState?.stopSettling();
    setState(() => _layer = _Leaving(last: layer, cancelled: cancelled));
    _presence.reverse();
  }

  /// A dictation is done and its words were just sent or put in the box: this
  /// runs after the composer has handled the same state. Whatever the composer
  /// expects is settled here, the one place that knows when there is nothing to
  /// glide, as after a recording, whose words were never on screen.
  void _land({required String transcript}) {
    final layer = _layer;
    final landing = SentBubbleLanding.of(context: context);
    final from = layer is _Live && transcript.trim().isNotEmpty && !context.isReducedMotion ? _wordsRect() : null;
    if (layer is! _Live || from == null) {
      landing.handOver();
      _leave(cancelled: false);
      return;
    }

    setState(() {
      _layer = _Gliding(
        last: layer,
        from: from,
        target: from,
        destination: const _Undecided(),
        runs:
            _liveTextKey.currentState?.runsOf(words: layer.words, settled: layer.finishing) ??
            [(text: layer.words.text, opacity: 1)],
        landing: landing,
      );
    });
    _presence.reverse();
    if (landing.isExpecting) {
      _awaitBubble(landing: landing, frames: _bubbleFrames, transcript: transcript, wakesSession: !widget.isBusy);
    } else {
      widget.box._hold(held: true);
      SchedulerBinding.instance.addPostFrameCallback((_) => _glideToBox());
    }
  }

  Rect? _wordsRect() {
    final overlay = Overlay.of(context).context.findRenderObject();
    final words = _wordsKey.currentContext?.findRenderObject();
    if (overlay == null || words is! RenderBox) return null;
    return MatrixUtils.transformRect(words.getTransformTo(overlay), Offset.zero & words.size);
  }

  void _awaitBubble({
    required SentBubbleLandingController landing,
    required int frames,
    required String transcript,
    required bool wakesSession,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _layer is! _Gliding) return;
      final text = landing.heldText;
      if (text != null) {
        _startGlide(destination: _Bubble(text: text));
      } else if (frames > 1) {
        _awaitBubble(landing: landing, frames: frames - 1, transcript: transcript, wakesSession: wakesSession);
        SchedulerBinding.instance.scheduleFrame();
      } else {
        landing.handOver();
        _startGlide(
          destination: _estimatedSlot(transcript: transcript, wakesSession: wakesSession),
        );
      }
    });
  }

  void _glideToBox() {
    if (!mounted || _layer is! _Gliding) return;
    final box = widget.box;
    if (box._slot == null) {
      box._hold(held: false);
      _startGlide(destination: const _InPlace());
    } else {
      _startGlide(destination: _Box(text: box._controller.text));
    }
  }

  void _startGlide({required _Destination destination}) {
    final layer = _layer;
    if (layer is! _Gliding) return;
    setState(() {
      _layer = _Gliding(
        last: layer.last,
        from: layer.from,
        target: layer.target,
        destination: destination,
        runs: layer.runs,
        landing: layer.landing,
      );
    });
    _glide.forward(from: 0);
  }

  void _handleGlideTick() {
    if (_glide.value >= _handOverAt) {
      if (_layer case _Gliding(:final landing)) landing.showBubble();
      widget.box._hold(held: false);
    }
    // Runs the layer's builder again, which reads where the destination is now.
    // It lays out ahead of the list, so it follows a moving row a frame behind.
    setState(() {});
  }

  void _handOver() {
    if (_layer case _Gliding(:final landing)) landing.handOver();
    widget.box._hold(held: false);
  }

  void _endGlide() {
    _handOver();
    _glide.reset();
    _portal.hide();
    setState(() => _layer = const _Hidden());
  }

  /// Right-aligned above the composer, where the bubble goes when the list is at
  /// its end. The [transcript], with the marker a bubble adds, is what there is to
  /// size it by. A message that [wakesSession] comes to rest above the working row
  /// it brings, wherever that row has got to by now: words aimed there meet the
  /// bubble as it rises, where words aimed below would be left behind.
  _Destination _estimatedSlot({required String transcript, required bool wakesSession}) {
    final layer = _layer;
    final composer = _composerRect;
    if (layer is! _Gliding || composer == null) return const _InPlace();
    final text = wrapDictatedText(text: transcript.trim());
    final sideInset = _composerSideInset + SentBubbleRowReach.of(context: context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: _bubbleLook().style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: UserMessageBubble.maxContentWidth(rowWidth: composer.width + sideInset * 2));
    final right = composer.right + sideInset - UserMessageBubble.margin.right;
    final bottom =
        composer.top - _estimatedSlotGap - (wakesSession ? TranscriptWorkingRow.heightAsFirstRow(context: context) : 0);
    final rect = Rect.fromLTRB(
      right - painter.width - UserMessageBubble.padding * 2,
      bottom - painter.height - UserMessageBubble.padding * 2,
      right,
      bottom,
    );
    painter.dispose();
    return _Estimate(rect: rect, text: text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceInputCubit, VoiceInputState>(
      listener: (context, state) => _handleVoiceState(state: state),
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: (context, info) => _buildOverlay(context: context, info: info),
        child: widget.child,
      ),
    );
  }

  Widget _buildOverlay({required BuildContext context, required OverlayChildLayoutInfo info}) {
    final layer = _layer;
    final _Live live;
    switch (layer) {
      case _Hidden():
        return const SizedBox.shrink();
      case _Live():
        live = layer;
      case _Leaving(:final last) || _Gliding(:final last):
        live = last;
    }

    final measured = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final composer = layer is _Live ? (_composerRect = measured) : _composerRect ?? measured;
    final overlay = info.overlaySize;

    return IgnorePointer(
      // A screen reader would talk over the user's own dictation; the words
      // reach it once they land in the box or the bubble.
      child: ExcludeSemantics(
        child: Stack(
          children: [
            if (layer is _Gliding)
              _buildGlide(layer: layer)
            else
              Positioned(
                left: composer.left,
                right: overlay.width - composer.right,
                top: math.max(_paneTop(context: context), MediaQuery.paddingOf(context).top) + _wordsGap,
                bottom: overlay.height - composer.top + _hintBaseline + widget.hintHeight + _wordsGap,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: _buildWords(context: context, live: live),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The top of the nearest [Scaffold] within the overlay, which is the chat pane.
  /// On a touch shell that is the one `PregoGlassScaffold` wraps its page in.
  double _paneTop({required BuildContext context}) {
    final pane = Scaffold.of(context).context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (pane is! RenderBox || overlay == null) return 0;
    return math.max(MatrixUtils.transformPoint(pane.getTransformTo(overlay), Offset.zero).dy, 0);
  }

  /// How live words look. The card stays solid so the slide never lets the chat
  /// show through words.
  _WordsLook _liveLook() {
    final prego = context.prego;
    return (
      style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.md),
      decoration: pregoComposerSurfaceDecoration(
        prego: prego,
        style: PregoComposerSurfaceStyle.emphasized,
        borderRadius: BorderRadius.circular(_panelRadius),
      ).copyWith(boxShadow: prego.shadows.lg),
    );
  }

  /// The bubble's surface, and its Markdown body's paragraph.
  _WordsLook _bubbleLook() {
    final prego = context.prego;
    return (
      style: buildChatMessageMarkdownStyleSheet(prego: prego).p ?? prego.textTheme.textSm.regular,
      padding: const EdgeInsets.all(UserMessageBubble.padding),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        borderRadius: BorderRadius.circular(UserMessageBubble.radius),
      ),
    );
  }

  Widget _buildGlide({required _Gliding layer}) {
    final last = layer.last;
    final start = _liveLook();
    final overlay = Overlay.of(context).context.findRenderObject();
    final (_WordsLook end, Rect? target) = switch (layer.destination) {
      _Undecided() || _InPlace() => (start, layer.from),
      _Bubble() => (_bubbleLook(), _bubbleTarget(layer: layer, overlay: overlay)),
      _Box() => (
        (
          style: widget.boxStyle,
          padding: ComposerWordsBox.contentPadding.copyWith(right: ComposerWordsBox._caretMargin),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(UserMessageBubble.radius)),
        ),
        overlay == null ? null : widget.box._slot?.rectIn(ancestor: overlay),
      ),
      _Estimate(:final rect) => (_bubbleLook(), rect),
    };
    if (target != null) layer.target = target;

    final flight = math.min(_glide.value / _handOverAt, 1.0);
    final t = _glideCurve.transform(flight);
    // The style and the wrap change once, while the words move fastest; from there
    // the final paragraph only scales, and can't wrap again as it lands.
    final rewrapped = t >= _rewrapAt;
    final fontSize = lerpDouble(start.style.fontSize, end.style.fontSize, t);
    final endFontSize = end.style.fontSize;
    final TextStyle style = rewrapped
        ? end.style.copyWith(color: Color.lerp(start.style.color, end.style.color, t))
        : TextStyle.lerp(start.style, end.style, t) ?? end.style;
    final double opacity = switch (layer.destination) {
      _Undecided() => 1,
      _Bubble() || _Box() => 1 - (_glide.value - _handOverAt) / (1 - _handOverAt),
      _Estimate() || _InPlace() => 1 - flight,
    };

    return Positioned.fromRect(
      key: composerLiveWordsGlideKey,
      rect: Rect.lerp(layer.from, layer.target, t) ?? layer.from,
      child: Opacity(
        opacity: clampDouble(opacity, 0, 1),
        child: DecoratedBox(
          decoration: _glideSurface(start: start.decoration, end: end.decoration, t: t),
          child: Padding(
            padding: EdgeInsets.lerp(start.padding, end.padding, t) ?? end.padding,
            child: _GlidingText(
              text: _glideSpan(
                words: last.words,
                runs: layer.runs,
                brightened: _glideBrightened(),
                destination: layer.destination,
                style: style,
                t: t,
                grows: !rewrapped,
              ),
              topFade: _wordsTopFade * (1 - t),
              scale: rewrapped && fontSize != null && endFontSize != null ? fontSize / endFontSize : 1,
              wrapWidth: rewrapped ? layer.target.width - end.padding.horizontal : null,
            ),
          ),
        ),
      ),
    );
  }

  /// [BoxDecoration.lerp] shrinks a shadow with nothing to lerp to at full strength,
  /// which draws a hard plate under a clear surface. This one fades where it is.
  BoxDecoration _glideSurface({required BoxDecoration start, required BoxDecoration end, required double t}) {
    final surface = BoxDecoration.lerp(start.copyWith(boxShadow: const []), end, t) ?? end;
    return surface.copyWith(
      boxShadow: [
        for (final shadow in start.boxShadow ?? const <BoxShadow>[])
          shadow.copyWith(color: shadow.color.withValues(alpha: shadow.color.a * (1 - t))),
      ],
    );
  }

  Rect? _bubbleTarget({required _Gliding layer, required RenderObject? overlay}) {
    if (overlay == null) return null;
    final row = layer.landing.heldRect(ancestor: overlay);
    return row == null ? null : UserMessageBubble.margin.deflateRect(row);
  }

  /// How far along the words are to fully bright: the same fade as a release's,
  /// on the glide's clock.
  double _glideBrightened() {
    final elapsed = (_glideDuration + _handOverDuration) * _glide.value;
    final fade = math.min(elapsed.inMicroseconds / _LiveWordsTextState._brightenFade.inMicroseconds, 1.0);
    return Curves.ease.transform(fade);
  }

  /// [runs], each that much of the way from where it set off to fully bright.
  List<TextSpan> _spansOfRuns({
    required List<_WordsRun> runs,
    required double brightened,
    required Color color,
  }) => [
    for (final run in runs)
      TextSpan(
        text: run.text,
        style: TextStyle(color: color.withValues(alpha: color.a * (run.opacity + (1 - run.opacity) * brightened))),
      ),
  ];

  /// [runs] without the spacing around the words as a whole.
  List<_WordsRun> _trimmedRuns({required List<_WordsRun> runs}) {
    final whole = runs.map((run) => run.text).join();
    final start = whole.length - whole.trimLeft().length;
    final end = whole.trimRight().length;
    final trimmed = <_WordsRun>[];
    var offset = 0;
    for (final run in runs) {
      final from = math.max(start, offset);
      final to = math.min(end, offset + run.text.length);
      if (from < to) trimmed.add((text: whole.substring(from, to), opacity: run.opacity));
      offset += run.text.length;
    }
    return trimmed;
  }

  /// The words, with whatever else ends up around them: the marker a bubble adds
  /// and what the box already held. That grows from nothing as they fly, which
  /// keeps the words from shifting on the glide's first frame.
  TextSpan _glideSpan({
    required LiveWords words,
    required List<_WordsRun> runs,
    required double brightened,
    required _Destination destination,
    required TextStyle style,
    required double t,
    required bool grows,
  }) {
    final String? landed = switch (destination) {
      _Bubble(:final text) || _Box(:final text) || _Estimate(:final text) => text,
      _Undecided() || _InPlace() => null,
    };
    final color = style.color ?? const Color(0xFF000000);
    if (landed == null) {
      return TextSpan(
        style: style,
        children: _spansOfRuns(runs: runs, brightened: brightened, color: color),
      );
    }

    final core = words.text.trim();
    final at = landed.lastIndexOf(core);
    if (at < 0) return TextSpan(text: landed, style: style);

    final grown = TextStyle(
      fontSize: grows ? (style.fontSize ?? 0) * t : null,
      color: color.withValues(alpha: color.a * t),
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: landed.substring(0, at), style: grown),
        ..._spansOfRuns(
          runs: _trimmedRuns(runs: runs),
          brightened: brightened,
          color: color,
        ),
        TextSpan(text: landed.substring(at + core.length), style: grown),
      ],
    );
  }

  Widget _buildWords({required BuildContext context, required _Live live}) {
    final look = _liveLook();
    final text = _buildFadingWithSlide(
      child: LiveWordsText(
        key: _liveTextKey,
        words: live.words,
        settled: live.finishing,
        maxLines: _panelLines,
        style: look.style,
      ),
    );
    final Widget words = KeyedSubtree(
      key: _wordsKey,
      child: DecoratedBox(
        decoration: look.decoration,
        child: Padding(padding: look.padding, child: text),
      ),
    );

    final reducedMotion = context.isReducedMotion;
    return AnimatedBuilder(
      animation: _presenceCurve,
      builder: (context, child) {
        final away = 1 - _presenceCurve.value;
        final double travel = switch (_layer) {
          _Leaving(cancelled: true) => _cancelDrop,
          _Live() => _panelRise,
          _Hidden() || _Leaving() || _Gliding() => 0,
        };
        return Transform.translate(
          offset: Offset(0, reducedMotion ? 0 : travel * away),
          child: Opacity(opacity: _presenceCurve.value, child: child),
        );
      },
      child: words,
    );
  }

  /// Fades [child] with the finger: at the spec's 1 - 0.6 x progress.
  Widget _buildFadingWithSlide({required Widget child}) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.cancelProgress,
      builder: (context, progress, child) {
        // The slide scrubs the words away, so coming back restores them. A
        // release that isn't a cancel brings them back to read as they finish.
        final bool tracksSlide = switch (_layer) {
          _Live(:final finishing) => !finishing,
          _Leaving(:final cancelled) => cancelled,
          _Hidden() || _Gliding() => false,
        };
        return AnimatedOpacity(
          opacity: tracksSlide ? 1 - _slideOutFade * progress : 1,
          duration: tracksSlide ? Duration.zero : _slideBackDuration,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Finds the words on their way to where they land, for a test to measure.
@visibleForTesting
const composerLiveWordsGlideKey = Key("composer_live_words_glide");

/// How much of the top fades away once the words outgrow their room.
const double _wordsTopFade = 26;

/// Words in a box changing shape around them: a paragraph held to the box's
/// bottom edge, the newest in view, as [LiveWordsText] holds them.
class const _GlidingText({
  required final TextSpan text,
  required final double topFade,
  required final double scale,

  /// What the paragraph wraps to before scaling; null for the room it has.
  required final double? wrapWidth,
}) extends StatelessWidget {
  /// Lets the last frames' width fit the paragraph that gave it, whatever it
  /// rounded to, so the words don't wrap a line early as they land.
  static const double _widthTolerance = 0.5;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (wrapWidth ?? constraints.maxWidth) + _widthTolerance;
        final painter = TextPainter(text: text, textDirection: textDirection, textScaler: textScaler)
          ..layout(maxWidth: width);
        final overflow = painter.height * scale - constraints.maxHeight;
        painter.dispose();
        final fade = clampDouble(overflow, 0, topFade);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.transparent, Colors.white],
            stops: [0, constraints.maxHeight > 0 ? math.min(fade / constraints.maxHeight, 1) : 0],
          ).createShader(bounds),
          child: ClipRect(
            child: Transform.scale(
              scale: scale,
              alignment: AlignmentDirectional.bottomStart,
              child: OverflowBox(
                alignment: AlignmentDirectional.bottomStart,
                minWidth: 0,
                maxWidth: width,
                minHeight: 0,
                maxHeight: double.infinity,
                child: RichText(text: text, textDirection: textDirection, textScaler: textScaler),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The words themselves: anchored at the bottom with the newest always in view,
/// rising a line at a time as they wrap, the oldest fading away at the top once
/// they run out of room.
@visibleForTesting
class const LiveWordsText({
  super.key,
  required final LiveWords words,

  /// Treats the tentative words as final: they brighten where they stand.
  required final bool settled,

  /// How many lines show before the oldest fade away.
  required final int maxLines,
  required final TextStyle style,
}) extends StatefulWidget {
  @override
  State<LiveWordsText> createState() => _LiveWordsTextState();
}

/// One word's opacity, on its way to where its standing says it belongs.
final class _FadingWord({required String text, required double target}) {
  String text = text;

  /// Runs out once a dim word has stayed the same for long enough to brighten.
  Timer? settling;
  double _from = 0;
  double _to = target;
  Duration _duration = _LiveWordsTextState._newWordFade;
  Duration _elapsed = Duration.zero;
  Curve _curve = Curves.easeOut;

  double get target => _to;

  double get opacity {
    if (_elapsed >= _duration) return _to;
    return _from + (_to - _from) * _curve.transform(_elapsed.inMicroseconds / _duration.inMicroseconds);
  }

  bool get isFading => _elapsed < _duration;

  void fadeTo({required double target}) {
    _from = opacity;
    _to = target;
    _duration = _LiveWordsTextState._brightenFade;
    _elapsed = Duration.zero;
    _curve = Curves.ease;
  }

  void advance({required Duration by}) => _elapsed += by;
}

class _LiveWordsTextState() extends State<LiveWordsText> with SingleTickerProviderStateMixin {
  static const _newWordFade = Duration(milliseconds: 170);
  static const _brightenFade = Duration(milliseconds: 280);
  static const _riseDuration = Duration(milliseconds: 200);
  static const _riseCurve = Cubic(.2, .8, .2, 1);
  static const double _tentativeOpacity = 0.46;

  /// How long a tentative word has to stay the same to read as solid. The server
  /// takes far longer than this to confirm it, and it can still change after.
  static const _settleAfter = Duration(milliseconds: 500);

  /// A word and its spacing. Tokens line up by index between updates, so a word
  /// keeps its place when it turns final, or when the server changes its mind.
  static final _tokens = RegExp(r"\s*\S+\s*|\s+");

  final List<_FadingWord> _words = [];

  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWords(words: widget.words, settled: widget.settled);
  }

  @override
  void didUpdateWidget(LiveWordsText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWords(words: widget.words, settled: widget.settled);
  }

  @override
  void dispose() {
    stopSettling();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// The dictation is over: dim words stay dim as they go.
  void stopSettling() {
    for (final word in _words) {
      word.settling?.cancel();
    }
  }

  /// [words] as they stand right now, which a build may not have got to yet.
  List<_WordsRun> runsOf({required LiveWords words, required bool settled}) {
    _syncWords(words: words, settled: settled);
    return _runs();
  }

  void _syncWords({required LiveWords words, required bool settled}) {
    final tentative = settled ? 1.0 : _tentativeOpacity;
    var index = 0;
    // The first word to differ and all those after it have changed. Spacing
    // doesn't count: a word gains its space when the next one comes.
    var changed = false;
    // Split as one text, as the server can confirm a word partway through.
    for (final match in _tokens.allMatches(words.confirmed + words.provisional)) {
      final token = match.group(0) ?? "";
      final isConfirmed = match.start + token.trimRight().length <= words.confirmed.length;
      final target = isConfirmed ? 1.0 : tentative;
      if (index == _words.length) {
        final word = _FadingWord(text: token, target: target);
        _words.add(word);
        _restartSettling(word: word);
      } else {
        final word = _words[index];
        changed = changed || word.text.trim() != token.trim();
        word.text = token;
        // A tentative word that hasn't changed stands wherever it has got to.
        if (target == 1 || changed) {
          if (word.target != target) word.fadeTo(target: target);
          _restartSettling(word: word);
        }
      }
      index++;
    }
    for (final word in _words.skip(index)) {
      word.settling?.cancel();
    }
    _words.length = index;
    _showFades();
  }

  void _restartSettling({required _FadingWord word}) {
    word.settling?.cancel();
    if (word.target == 1) return;
    word.settling = Timer(_settleAfter, () {
      word.fadeTo(target: 1);
      _showFades();
    });
  }

  void _showFades() {
    if (!_ticker.isActive && _words.any((word) => word.isFading)) _ticker.start();
    _frame.value++;
  }

  void _handleTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    for (final word in _words) {
      word.advance(by: delta);
    }
    _frame.value++;
    if (!_words.any((word) => word.isFading)) {
      _ticker.stop();
      _lastTick = Duration.zero;
    }
  }

  /// Neighbouring words at one opacity share a run, which leaves one long run for
  /// everything final however long the dictation runs.
  List<_WordsRun> _runs() {
    final runs = <_WordsRun>[];
    final run = StringBuffer();
    double? runOpacity;

    void flush() {
      final opacity = runOpacity;
      if (opacity == null) return;
      runs.add((text: run.toString(), opacity: opacity));
      run.clear();
    }

    for (final word in _words) {
      final opacity = word.opacity;
      if (opacity != runOpacity) {
        flush();
        runOpacity = opacity;
      }
      run.write(word.text);
    }
    flush();
    return runs;
  }

  TextSpan _buildSpan() {
    final base = widget.style.color ?? const Color(0xFF000000);
    return TextSpan(
      style: widget.style,
      children: [
        for (final run in _runs())
          TextSpan(
            text: run.text,
            style: TextStyle(color: base.withValues(alpha: base.a * run.opacity)),
          ),
      ],
    );
  }

  /// The words' full height at [width] and one line's. Colours never change the
  /// layout, so plain text measures what the spans will paint.
  ({double words, double line}) _measure({required double width}) {
    final painter = TextPainter(
      text: TextSpan(text: _words.map((word) => word.text).join(), style: widget.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final line = painter.preferredLineHeight;
    final words = _words.isEmpty ? 0.0 : painter.height;
    painter.dispose();
    return (words: words, line: line);
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final (:words, :line) = _measure(width: constraints.maxWidth);
        final room = math.min(constraints.maxHeight, line * widget.maxLines);

        // One value carries the rise: how much of the words' height shows. A new
        // line starts below the clip and comes up as the lines above it do.
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: words),
          duration: context.isReducedMotion ? Duration.zero : _riseDuration,
          curve: _riseCurve,
          child: ListenableBuilder(
            listenable: _frame,
            builder: (context, _) => RichText(text: _buildSpan(), textDirection: textDirection, textScaler: textScaler),
          ),
          builder: (context, shown, child) {
            final visible = math.min(shown, room);
            final fade = math.min(shown - visible, _wordsTopFade);
            return SizedBox(
              width: constraints.maxWidth,
              height: visible,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Colors.transparent, Colors.white],
                  stops: [0, visible > 0 ? math.min(fade / visible, 1) : 0],
                ).createShader(bounds),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: AlignmentDirectional.topStart,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Transform.translate(offset: Offset(0, visible - shown), child: child),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
