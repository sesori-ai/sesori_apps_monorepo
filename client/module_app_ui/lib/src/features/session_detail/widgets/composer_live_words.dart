import "dart:math" as math;

import "package:flutter/foundation.dart" show ValueListenable;
import "package:flutter/scheduler.dart" show Ticker;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../composer_presentation_scope.dart";

/// The words of a live dictation, in a layer of their own over the screen.
/// Nothing under the layer moves or resizes for them, and they take no gestures,
/// so the hold on the pill carries on undisturbed.
///
/// [child] is the composer's body, the part of the composer the layer stays clear
/// of. Which presentation shows comes from the dictation's own state.
class const ComposerLiveWords({
  super.key,

  /// How far the hold has slid out of the pill. Fades the words with the finger.
  required final ValueListenable<double> cancelProgress,

  /// What a release does. The focus dim covers the composer's own hint, so the
  /// layer draws this one in its place. The panel only keeps clear of it.
  required final Widget hint,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<ComposerLiveWords> createState() => _ComposerLiveWordsState();
}

/// What the layer shows, which outlives the dictation long enough to fade it.
sealed class const _Layer();

final class const _Hidden() extends _Layer;

final class const _Live({
  required final LiveWords words,
  required final VoiceLivePresentation presentation,

  /// The user has released: the words stop being tentative and the hint goes.
  required final bool finishing,
}) extends _Layer;

/// Fading out, showing the [last] words. Only a cancel drops them as they go.
final class const _Leaving({required final _Live last, required final bool cancelled}) extends _Layer;

class _ComposerLiveWordsState() extends State<ComposerLiveWords> with SingleTickerProviderStateMixin {
  /// How long the layer takes to come in, dim and all, and to go.
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
  static const _hintFadeDuration = Duration(milliseconds: 150);

  static const double _dimOpacity = 0.98;

  /// Between the words and whatever sits under them.
  static const double _wordsGap = PregoSpacing.md;

  /// The gap above the composer's body that its hint sits on.
  static const double _hintBaseline = 8;

  static const double _panelRadius = 18;
  static const int _panelLines = 5;

  final _portal = OverlayPortalController();
  late final AnimationController _presence;
  late final CurvedAnimation _presenceCurve;
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
  }

  @override
  void dispose() {
    _presenceCurve.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _handleVoiceState({required VoiceInputState state}) {
    switch (state) {
      case VoiceInputLiveRecording(:final words, :final presentation):
        _showLive(
          live: _Live(words: words, presentation: presentation, finishing: false),
        );
      case VoiceInputLiveFinishing(:final words, :final presentation):
        _showLive(
          live: _Live(words: words, presentation: presentation, finishing: true),
        );
      case VoiceInputCancelling():
        _leave(cancelled: true);
      case VoiceInputIdle() ||
          VoiceInputStarting() ||
          VoiceInputRecording() ||
          VoiceInputTranscribing() ||
          VoiceInputRetryPending() ||
          VoiceInputRetrying() ||
          VoiceInputRetryCancelling() ||
          VoiceInputDiscarding() ||
          VoiceInputCompleted() ||
          VoiceInputStartFailed() ||
          VoiceInputTranscriptionFailed():
        _leave(cancelled: false);
    }
  }

  void _showLive({required _Live live}) {
    setState(() => _layer = live);
    // Focus clears the screen as soon as the dictation starts; the panel has
    // nothing to show until there are words.
    if (live.presentation == VoiceLivePresentation.panel && live.words.text.isEmpty) return;
    if (!_portal.isShowing) _portal.show();
    _presence.forward();
  }

  void _leave({required bool cancelled}) {
    final layer = _layer;
    if (layer is! _Live) return;
    setState(() => _layer = _Leaving(last: layer, cancelled: cancelled));
    _presence.reverse();
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
      case _Leaving(:final last):
        live = last;
    }

    final measured = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final composer = layer is _Live ? (_composerRect = measured) : _composerRect ?? measured;
    final pane = _paneRect(context: context, overlaySize: info.overlaySize);
    final focus = live.presentation == VoiceLivePresentation.focus;
    final overlay = info.overlaySize;

    return IgnorePointer(
      // A screen reader would talk over the user's own dictation; the words
      // reach it once they land in the box or the bubble.
      child: ExcludeSemantics(
        child: Stack(
          children: [
            if (focus)
              Positioned.fromRect(
                key: composerLiveWordsDimKey,
                rect: pane,
                child: FadeTransition(
                  opacity: _presenceCurve,
                  child: CustomPaint(
                    painter: _FocusDimPainter(
                      color: _paneBackground(context: context).withValues(alpha: _dimOpacity),
                      composer: composer.shift(-pane.topLeft),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: composer.left,
              right: overlay.width - composer.right,
              top: math.max(pane.top, MediaQuery.paddingOf(context).top) + _wordsGap,
              bottom: overlay.height - composer.top + _hintBaseline,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: _buildWords(context: context, live: live),
                    ),
                  ),
                  const SizedBox(height: _wordsGap),
                  // Laid out in both presentations, so the words sit above the
                  // hint's place without measuring it, and stay put when it goes.
                  FadeTransition(
                    opacity: _presenceCurve,
                    child: AnimatedOpacity(
                      opacity: focus && layer is _Live && !live.finishing ? 1 : 0,
                      duration: _hintFadeDuration,
                      child: widget.hint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The nearest [Scaffold] within the overlay, which is the chat pane. On a
  /// touch shell that is the one `PregoGlassScaffold` wraps its page in, so
  /// removing that wrapper would make the dim cover the sidebar on a wide layout.
  Rect _paneRect({required BuildContext context, required Size overlaySize}) {
    final whole = Offset.zero & overlaySize;
    final pane = Scaffold.of(context).context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (pane is! RenderBox || overlay == null) return whole;
    return MatrixUtils.transformRect(pane.getTransformTo(overlay), Offset.zero & pane.size).intersect(whole);
  }

  Color _paneBackground({required BuildContext context}) =>
      Scaffold.of(context).widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

  Widget _buildWords({required BuildContext context, required _Live live}) {
    final prego = context.prego;
    final desktop = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;
    final style = switch (live.presentation) {
      VoiceLivePresentation.focus => prego.textTheme.displayXs.medium.copyWith(
        fontSize: desktop ? 25 : 23,
        height: 1.32,
        color: prego.colors.textPrimary,
      ),
      VoiceLivePresentation.panel => prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
    };
    final text = _buildFadingWithSlide(
      child: LiveWordsText(
        words: live.words,
        settled: live.finishing,
        maxLines: switch (live.presentation) {
          VoiceLivePresentation.focus => null,
          VoiceLivePresentation.panel => _panelLines,
        },
        style: style,
      ),
    );
    final Widget words = switch (live.presentation) {
      VoiceLivePresentation.focus => Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md),
        child: text,
      ),
      // The card stays solid so the slide never lets the chat show through words.
      VoiceLivePresentation.panel => DecoratedBox(
        decoration: pregoComposerSurfaceDecoration(
          prego: prego,
          style: PregoComposerSurfaceStyle.emphasized,
          borderRadius: BorderRadius.circular(_panelRadius),
        ).copyWith(boxShadow: prego.shadows.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.md),
          child: text,
        ),
      ),
    };

    final reducedMotion = context.isReducedMotion;
    return AnimatedBuilder(
      animation: _presenceCurve,
      builder: (context, child) {
        final away = 1 - _presenceCurve.value;
        final double travel = switch (_layer) {
          _Leaving(cancelled: true) => _cancelDrop,
          _Live(presentation: VoiceLivePresentation.panel) => _panelRise,
          _Hidden() || _Leaving() || _Live() => 0,
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
          _Hidden() => false,
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

/// Dims the pane under the words, all but the column down from the composer's
/// body. The pill stays in full view there, and the composer's own halo already
/// hides whatever would pass behind it.
class const _FocusDimPainter({required final Color color, required final Rect composer}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pane = Offset.zero & size;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(pane)
      ..addRect(Rect.fromLTRB(composer.left, composer.top, composer.right, size.height).intersect(pane));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FocusDimPainter oldDelegate) => oldDelegate.color != color || oldDelegate.composer != composer;
}

/// Finds the focus dim, for a test to measure.
@visibleForTesting
const composerLiveWordsDimKey = Key("composer_live_words_dim");

/// The words themselves: anchored at the bottom with the newest always in view,
/// rising a line at a time as they wrap, the oldest fading away at the top once
/// they run out of room.
@visibleForTesting
class const LiveWordsText({
  super.key,
  required final LiveWords words,

  /// Treats the tentative words as final: they brighten where they stand.
  required final bool settled,

  /// How many lines show before the oldest fade away; null fills the height
  /// given.
  required final int? maxLines,
  required final TextStyle style,
}) extends StatefulWidget {
  @override
  State<LiveWordsText> createState() => _LiveWordsTextState();
}

/// One word's opacity, on its way to where its standing says it belongs.
final class _FadingWord({required String text, required double target, required Duration duration}) {
  String text = text;
  double _from = 0;
  double _to = target;
  Duration _duration = duration;
  Duration _elapsed = Duration.zero;
  Curve _curve = Curves.easeOut;

  double get target => _to;

  double get opacity {
    if (_elapsed >= _duration) return _to;
    return _from + (_to - _from) * _curve.transform(_elapsed.inMicroseconds / _duration.inMicroseconds);
  }

  bool get isFading => _elapsed < _duration;

  void fadeTo({required double target, required Duration duration}) {
    _from = opacity;
    _to = target;
    _duration = duration;
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

  /// How much of the top fades away once the words outgrow their room.
  static const double _topFade = 26;

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
    _syncWords();
  }

  @override
  void didUpdateWidget(LiveWordsText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWords();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _syncWords() {
    final instant = context.isReducedMotion;
    final tentative = widget.settled ? 1.0 : _tentativeOpacity;
    final parts = [(text: widget.words.confirmed, target: 1.0), (text: widget.words.provisional, target: tentative)];
    var index = 0;
    for (final part in parts) {
      for (final match in _tokens.allMatches(part.text)) {
        final token = match.group(0) ?? "";
        if (index == _words.length) {
          _words.add(
            _FadingWord(text: token, target: part.target, duration: instant ? Duration.zero : _newWordFade),
          );
        } else {
          final word = _words[index]..text = token;
          if (word.target != part.target) {
            word.fadeTo(target: part.target, duration: instant ? Duration.zero : _brightenFade);
          }
        }
        index++;
      }
    }
    _words.length = index;
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

  /// Neighbouring words at one opacity share a span, which leaves one long span
  /// for everything final however long the dictation runs.
  TextSpan _buildSpan() {
    final base = widget.style.color ?? const Color(0xFF000000);
    final spans = <InlineSpan>[];
    final run = StringBuffer();
    double? runOpacity;

    void flush() {
      final opacity = runOpacity;
      if (opacity == null) return;
      spans.add(
        TextSpan(
          text: run.toString(),
          style: TextStyle(color: base.withValues(alpha: base.a * opacity)),
        ),
      );
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
    return TextSpan(style: widget.style, children: spans);
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
        final maxLines = widget.maxLines;
        final room = maxLines == null ? constraints.maxHeight : math.min(constraints.maxHeight, line * maxLines);

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
            final fade = math.min(shown - visible, _topFade);
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
