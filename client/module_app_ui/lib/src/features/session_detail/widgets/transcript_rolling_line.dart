import "dart:math";
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show listEquals;
import "package:material_ui/material_ui.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_motion.dart";

/// One keyed piece of a [TranscriptRollingLine], such as " · read 2 files".
typedef TranscriptLineSegment = ({Enum key, String text});

/// One line of text that animates its changes, like a group summary's
/// counts. At rest it is a plain [Text]. When a segment changes, only the
/// part that differs rolls: the old characters slide up and out as the new
/// ones slide in from below, so "read 2 files" rolls only its digit. A new
/// segment wipes in from the start as it fades in. The line's width eases with
/// it, so the text after it moves instead of jumping. Reduced motion shows the
/// new line at once.
class const TranscriptRollingLine({
  super.key,
  required final List<TranscriptLineSegment> segments,
  required final TextStyle style,
  required final TextOverflow overflow,
}) extends StatefulWidget {
  /// How far rolling characters travel, as a fraction of the line height.
  static const double rollDistance = 0.6;

  @override
  State<TranscriptRollingLine> createState() => _TranscriptRollingLineState();
}

class _TranscriptRollingLineState() extends State<TranscriptRollingLine> with SingleTickerProviderStateMixin {
  /// The line the running change started from.
  List<TranscriptLineSegment> _from = const [];
  AnimationController? _controller;
  CurvedAnimation? _curve;
  final Map<String, Size> _sizes = {};

  @override
  void didUpdateWidget(TranscriptRollingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.segments, widget.segments)) return;
    if (context.isReducedMotion) {
      _controller?.stop();
      return;
    }
    // A change during a change starts from the line the first was heading to.
    _from = oldWidget.segments;
    _sizes.clear();
    _animation().forward(from: 0);
  }

  AnimationController _animation() {
    final existing = _controller;
    if (existing != null) return existing;
    final controller = _controller = AnimationController(vsync: this, duration: transcriptMotionDuration);
    _curve = CurvedAnimation(parent: controller, curve: transcriptMotionCurve);
    // Every tick redraws only this line; the last one returns it to rest.
    controller.addListener(() => setState(() {}));
    return controller;
  }

  @override
  void dispose() {
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.segments.map((segment) => segment.text).join();
    final curve = _curve;
    if (curve == null || !curve.parent.isAnimating) {
      return Text(line, style: widget.style, maxLines: 1, overflow: widget.overflow);
    }
    final t = curve.value;
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    // Screen readers hear the line it is heading to, not the rolling pieces.
    return Semantics(
      label: line,
      child: ExcludeSemantics(
        child: UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          alignment: AlignmentDirectional.centerStart,
          clipBehavior: Clip.hardEdge,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final segment in widget.segments)
                ..._segment(
                  from: _from.where((candidate) => candidate.key == segment.key).firstOrNull?.text,
                  to: segment.text,
                  style: style,
                  t: t,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _segment({required String? from, required String to, required TextStyle style, required double t}) {
    if (from == null) {
      // A new segment wipes in from the start while it fades in.
      return [
        ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            heightFactor: 1,
            child: Opacity(
              opacity: t,
              child: _text(text: to, style: style),
            ),
          ),
        ),
      ];
    }
    if (from == to) return [_text(text: to, style: style)];
    // Word by word when the shape holds, so "1 file" to "2 files" rolls the
    // digit and the new "s" apart.
    final fromWords = _words(text: from);
    final toWords = _words(text: to);
    final pairs = fromWords.length == toWords.length
        ? [for (var i = 0; i < toWords.length; i++) (from: fromWords[i], to: toWords[i])]
        : [(from: from, to: to)];
    final widgets = <Widget>[];
    final still = StringBuffer();
    void flush() {
      if (still.isEmpty) return;
      widgets.add(_text(text: still.toString(), style: style));
      still.clear();
    }

    for (final pair in pairs) {
      final (:from, :to) = pair;
      if (from == to) {
        still.write(to);
        continue;
      }
      var prefix = 0;
      while (prefix < from.length && prefix < to.length && from[prefix] == to[prefix]) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < from.length - prefix &&
          suffix < to.length - prefix &&
          from[from.length - 1 - suffix] == to[to.length - 1 - suffix]) {
        suffix++;
      }
      still.write(to.substring(0, prefix));
      flush();
      widgets.add(
        _roll(
          from: from.substring(prefix, from.length - suffix),
          to: to.substring(prefix, to.length - suffix),
          style: style,
          t: t,
        ),
      );
      still.write(to.substring(to.length - suffix));
    }
    flush();
    return widgets;
  }

  /// [from] slides up and out as [to] slides in from below, in a box whose
  /// width eases from one to the other.
  Widget _roll({required String from, required String to, required TextStyle style, required double t}) {
    final fromSize = _measure(text: from, style: style);
    final toSize = _measure(text: to, style: style);
    final direction = Directionality.of(context);
    Widget rolling({required String text, required double offset, required double opacity}) => Positioned.directional(
      textDirection: direction,
      start: 0,
      top: 0,
      child: FractionalTranslation(
        translation: Offset(0, offset),
        child: Opacity(
          opacity: opacity,
          child: _text(text: text, style: style),
        ),
      ),
    );
    return ClipRect(
      child: SizedBox(
        width: lerpDouble(fromSize.width, toSize.width, t),
        height: max(fromSize.height, toSize.height),
        child: Stack(
          children: [
            rolling(text: from, offset: -TranscriptRollingLine.rollDistance * t, opacity: 1 - t),
            rolling(text: to, offset: TranscriptRollingLine.rollDistance * (1 - t), opacity: t),
          ],
        ),
      ),
    );
  }

  /// [text] split into its words and the spaces between them.
  static List<String> _words({required String text}) => [
    for (final match in _wordPattern.allMatches(text)) text.substring(match.start, match.end),
  ];

  static final RegExp _wordPattern = RegExp(r"\S+|\s+");

  Size _measure({required String text, required TextStyle style}) => _sizes[text] ??= () {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }();

  static Widget _text({required String text, required TextStyle style}) =>
      Text(text, style: style, maxLines: 1, softWrap: false);
}
