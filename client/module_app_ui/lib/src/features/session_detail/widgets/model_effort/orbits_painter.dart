import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelOrbits, OrbitRing;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbit_geometry.dart";

/// How long the orbits take to arrive and to leave.
abstract final class OrbitsMotion() {
  /// The ripple entry: the last ring settles at about 0.34 s, the ripple
  /// itself fades out a little later.
  static const open = Duration(milliseconds: 440);
  static const close = Duration(milliseconds: 180);

  /// The plain fade used under reduced motion, both ways.
  static const fade = Duration(milliseconds: 200);

  /// How long the picture takes to follow the finger to a new target.
  static const hotFade = Duration(milliseconds: 120);

  static const _staggerMs = 24.0;
  static const _settleMs = 240.0;
  static const _fadeInMs = 160.0;
  static const _scrimMs = 300.0;

  /// Rings grow only the last few percent, with no overshoot.
  static const _closedScale = .84;
  static const _settle = Cubic(.15, .75, .25, 1);

  /// How far the ripple has delayed a ring: the innermost ring settles first,
  /// the outermost last. Rays and the All pill use a stagger of 0.
  static int ringStagger({required int ringCount, required int ringIndex}) => ringCount - ringIndex;

  /// The scale about the origin that a group staggered by [stagger] is drawn
  /// at, so hit testing can follow the rings while they settle.
  static double scaleOf({required Animation<double> entry, required bool reducedMotion, required int stagger}) {
    if (reducedMotion) return 1;
    final double progress;
    if (entry.status == AnimationStatus.reverse) {
      progress = entry.value;
    } else {
      final elapsed = entry.value * open.inMilliseconds - stagger * _staggerMs;
      progress = _settle.transform((elapsed / _settleMs).clamp(0, 1));
    }
    return _closedScale + (1 - _closedScale) * progress;
  }
}

/// The neutral colours of the picker, from the Prego theme.
final class OrbitPalette({required PregoColors colors}) {
  /// The colour behind the rings, also the gap around the current choice.
  final Color background = colors.bgSurface2;

  /// Strong enough that the transcript and composer behind read as
  /// background and never compete with ring names and level words. Light
  /// text on dark shows through a scrim more, so dark takes a little more.
  final Color scrim = colors.bgSurface2.withValues(alpha: colors.brightness == Brightness.dark ? .97 : .96);

  /// Full contrast: ring names, and the ring marking the current choice.
  final Color text = colors.textPrimary;
  final Color quietText = colors.textQuaternary;
  final Color line = colors.fgQuaternary;
  final Color track = colors.bgQuaternary;

  /// The current ring's line, the trail up to the current level and the
  /// ripple: a step stronger than the track.
  final Color trail = colors.brightness == Brightness.dark ? colors.fgSecondary : colors.fgQuaternary;

  /// The fill of the fast toggle and the thin highlight along each track.
  final Color surface = colors.alphaWhite100;

  /// The fill and edge of hollow dots and the "All" pill. In dark the light
  /// theme's fill would read as a hole in the track, so they are tinted beads
  /// a little lighter than it.
  final Color bead = colors.brightness == Brightness.dark ? colors.fgQuaternary : colors.alphaWhite100;
  final Color beadEdge = colors.brightness == Brightness.dark ? colors.fgSecondary : colors.fgQuaternary;

  /// The level words along the rays.
  final Color levelText = colors.brightness == Brightness.dark ? colors.textTertiary : colors.textQuaternary;

  /// The solid dots the trail passes on its way up to the choice: full
  /// contrast against the trail, white in dark and ink in light.
  final Color trailDot = colors.textPrimary;
}

/// Text laid out once and bent along an arc at paint time, one glyph at a
/// time.
final class ArcText({required String text, required TextStyle style}) {
  final List<(TextPainter glyph, double x, double baseline)> _glyphs = _layOut(text: text, style: style);

  /// How long the text runs along its arc.
  final double length = _measure(text: text, style: style);

  static double _measure({required String text, required TextStyle style}) {
    final line = _line(text: text, style: style);
    final width = line.width;
    line.dispose();
    return width;
  }

  static TextPainter _line({required String text, required TextStyle style}) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  static List<(TextPainter, double, double)> _layOut({required String text, required TextStyle style}) {
    final line = _line(text: text, style: style);
    final glyphs = <(TextPainter, double, double)>[];
    var offset = 0;
    for (final character in text.characters) {
      final x = line.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dx;
      offset += character.length;
      if (character.trim().isEmpty) continue;
      final glyph = TextPainter(
        text: TextSpan(text: character, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      glyphs.add((glyph, x, glyph.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    }
    line.dispose();
    return glyphs;
  }

  /// Paints the text clockwise along a circle of [radius] around [center],
  /// starting at [startAngle], with its baseline on the circle.
  void paint({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double startAngle,
  }) {
    for (final (glyph, x, baseline) in _glyphs) {
      final angle = (startAngle - (x + glyph.width / 2) / radius * 180 / math.pi) * math.pi / 180;
      canvas
        ..save()
        ..translate(center.dx + radius * math.cos(angle), center.dy - radius * math.sin(angle))
        ..rotate(math.pi / 2 - angle);
      glyph.paint(canvas, Offset(-glyph.width / 2, -baseline));
      canvas.restore();
    }
  }

  void dispose() {
    for (final (glyph, _, _) in _glyphs) {
      glyph.dispose();
    }
  }
}

/// Every piece of text the picker draws, laid out once per picker.
final class OrbitLabels({
  required ModelOrbits orbits,
  required PregoTextTheme textTheme,
  required OrbitPalette palette,
  required String noEffortText,
  required String allModelsText,
}) {
  /// Each ring's name, and its bolder face for the ring that holds the
  /// choice.
  final List<ArcText> names = _names(orbits: orbits, textTheme: textTheme, palette: palette, weight: FontWeight.w500);
  final List<ArcText> chosenNames = _names(
    orbits: orbits,
    textTheme: textTheme,
    palette: palette,
    weight: FontWeight.w700,
  );

  static List<ArcText> _names({
    required ModelOrbits orbits,
    required PregoTextTheme textTheme,
    required OrbitPalette palette,
    required FontWeight weight,
  }) => [
    for (final ring in orbits.rings)
      ArcText(
        text: ring.name,
        style: textTheme.textXs.regular.copyWith(
          fontSize: 12,
          height: 1,
          letterSpacing: 0,
          color: palette.text,
          fontWeight: weight,
        ),
      ),
  ];
  final ArcText noEffort = ArcText(
    text: noEffortText,
    style: textTheme.textXs.medium.copyWith(fontSize: 10, height: 1, letterSpacing: 0, color: palette.quietText),
  );

  /// Each ray's level word, by its index in [ModelOrbits.levels].
  final List<TextPainter> rays = [
    for (final level in orbits.levels)
      TextPainter(
        text: TextSpan(
          text: level.wireId.toUpperCase(),
          style: textTheme.textXs.bold.copyWith(
            fontSize: 9.5,
            height: 1,
            letterSpacing: 1.1,
            color: palette.levelText,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
  ];
  final TextPainter allModels = TextPainter(
    text: TextSpan(
      text: allModelsText,
      style: textTheme.textXs.medium.copyWith(fontSize: 11, height: 1, letterSpacing: 0, color: palette.text),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void dispose() {
    for (final name in [...names, ...chosenNames]) {
      name.dispose();
    }
    noEffort.dispose();
    for (final ray in rays) {
      ray.dispose();
    }
    allModels.dispose();
  }
}

/// What the picker draws as chosen: a ring, and the level marked on it, or
/// null when it marks none.
typedef OrbitChoice = ({int ringIndex, int? levelIndex});

/// The choice the picker draws while the finger is on [hot]: [hot] as if it
/// were already picked, so the picture shows what lifting the finger there
/// gives. Anywhere else, the committed choice.
OrbitChoice shownOrbitChoice({required ModelOrbits orbits, required OrbitTarget? hot}) {
  int? levelOn({required int ringIndex}) {
    final index = orbits.rings[ringIndex].levels.indexWhere((level) => level.level == orbits.currentLevel);
    return index < 0 ? null : index;
  }

  final ringIndex = switch (hot) {
    OrbitLevelTarget(:final ringIndex) || OrbitNameTarget(:final ringIndex) => ringIndex,
    OrbitAllModelsTarget() || OrbitFastToggleTarget() || null => orbits.rings.indexOf(orbits.current),
  };
  return switch (hot) {
    OrbitLevelTarget(:final levelIndex) => (ringIndex: ringIndex, levelIndex: levelIndex),
    // A name keeps the current level when its model offers it; otherwise the
    // model switch rule decides, so no level is marked.
    _ => (ringIndex: ringIndex, levelIndex: levelOn(ringIndex: ringIndex)),
  };
}

extension OrbitRingFastMode on OrbitRing {
  /// Whether the model has fast mode, usable now or not.
  bool get hasFastMode => switch (fastMode) {
    FastModeAvailable() || FastModeUnavailable() => true,
    null || FastModeSupportUnknown() => false,
  };
}

/// Paints the scrim, the rings, their dots and the ripple. Repaints on its
/// own as [entry] and [hotFade] tick.
final class OrbitsPainter({
  required final OrbitGeometry geometry,
  required final OrbitLabels labels,
  required final OrbitPalette palette,

  /// The chip the picker opened from, left clear of the scrim.
  required final Rect anchorRect,

  /// The route's animation: 0 closed, 1 open.
  required final Animation<double> entry,
  required final bool reducedMotion,

  /// What the finger is on, and what it just left. Each is drawn as if it
  /// were the choice, see [shownOrbitChoice].
  required final OrbitTarget? hot,
  required final OrbitTarget? previousHot,

  /// How far the picture has cross-faded from [previousHot] to [hot].
  required final Animation<double> hotFade,
}) extends CustomPainter {
  this : super(repaint: Listenable.merge([entry, hotFade]));

  static const double _dotRadius = 5.5;

  /// The current choice: an ink ring with a dot in it, in a thin gap.
  static const double _markerRadius = 7.5;
  static const double _markerStroke = 1.8;
  static const double _markerDotRadius = 3.4;
  static const double _markerGap = 2.5;

  ModelOrbits get _orbits => geometry.orbits;
  Offset get _origin => geometry.origin;
  bool get _closing => entry.status == AnimationStatus.reverse;
  double get _openMs => entry.value * OrbitsMotion.open.inMilliseconds;

  @override
  void paint(Canvas canvas, Size size) {
    _paintScrim(canvas: canvas, size: size);
    _group(canvas: canvas, size: size, stagger: 0, paint: () => _paintRays(canvas));
    final ringCount = _orbits.rings.length;
    final fade = Curves.easeOut.transform(hotFade.value);
    final shown = shownOrbitChoice(orbits: _orbits, hot: hot);
    final shownBefore = shownOrbitChoice(orbits: _orbits, hot: previousHot);
    for (var ringIndex = 0; ringIndex < ringCount; ringIndex++) {
      final now = shown.ringIndex == ringIndex ? shown : null;
      final before = shownBefore.ringIndex == ringIndex ? shownBefore : null;
      _group(
        canvas: canvas,
        size: size,
        stagger: OrbitsMotion.ringStagger(ringCount: ringCount, ringIndex: ringIndex),
        paint: () {
          if (now == before || fade >= 1) {
            _paintRing(canvas: canvas, ringIndex: ringIndex, choice: now);
            _paintName(canvas: canvas, ringIndex: ringIndex, chosen: now != null);
            return;
          }
          // The new picture fades in over the old one, so what both share
          // stays put.
          _paintRing(canvas: canvas, ringIndex: ringIndex, choice: before);
          _faded(
            canvas: canvas,
            opacity: fade,
            paint: () => _paintRing(canvas: canvas, ringIndex: ringIndex, choice: now),
          );
          if ((now == null) == (before == null)) {
            _paintName(canvas: canvas, ringIndex: ringIndex, chosen: now != null);
            return;
          }
          _faded(
            canvas: canvas,
            opacity: 1 - fade,
            paint: () => _paintName(canvas: canvas, ringIndex: ringIndex, chosen: before != null),
          );
          _faded(
            canvas: canvas,
            opacity: fade,
            paint: () => _paintName(canvas: canvas, ringIndex: ringIndex, chosen: now != null),
          );
        },
      );
    }
    if (geometry.showsAllModels) {
      _group(canvas: canvas, size: size, stagger: 0, paint: () => _paintAllModels(canvas));
    }
    _paintRipple(canvas);
  }

  void _paintScrim({required Canvas canvas, required Size size}) {
    final opacity = reducedMotion || _closing
        ? entry.value
        : Curves.ease.transform((_openMs / OrbitsMotion._scrimMs).clamp(0, 1));
    if (opacity <= 0) return;
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(anchorRect, Radius.circular(anchorRect.height / 2)));
    canvas.drawPath(scrim, Paint()..color = palette.scrim.withValues(alpha: palette.scrim.a * opacity));
  }

  /// Fades and scales one group about the origin, staggered by [stagger] steps
  /// on the way in.
  void _group({
    required Canvas canvas,
    required Size size,
    required int stagger,
    required VoidCallback paint,
  }) {
    final opacity = reducedMotion || _closing
        ? entry.value
        : Curves.easeOut.transform(
            ((_openMs - stagger * OrbitsMotion._staggerMs) / OrbitsMotion._fadeInMs).clamp(0, 1),
          );
    final scale = OrbitsMotion.scaleOf(entry: entry, reducedMotion: reducedMotion, stagger: stagger);
    if (opacity <= 0) return;
    canvas.save();
    if (opacity < 1) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    canvas
      ..translate(_origin.dx, _origin.dy)
      ..scale(scale)
      ..translate(-_origin.dx, -_origin.dy);
    paint();
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  void _paintRays(Canvas canvas) {
    final radii = geometry.ringRadii;
    if (radii.isEmpty) return;
    final inner = radii.last - OrbitGeometry.rayInset * geometry.scale;
    final outer = radii.first + OrbitGeometry.rayOverhang * geometry.scale;
    final dash = Paint()
      ..color = palette.line.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var levelIndex = 0; levelIndex < geometry.rayAngles.length; levelIndex++) {
      final angle = geometry.rayAngles[levelIndex];
      for (var radius = inner; radius < outer; radius += 7) {
        canvas.drawLine(
          geometry.pointAt(radius: radius, angle: angle),
          geometry.pointAt(radius: math.min(radius + 2, outer), angle: angle),
          dash,
        );
      }
      final label = labels.rays[levelIndex];
      final start = geometry.pointAt(radius: radii.first + OrbitGeometry.labelGap * geometry.scale, angle: angle);
      canvas
        ..save()
        ..translate(start.dx, start.dy)
        ..rotate(-angle * math.pi / 180);
      label.paint(canvas, Offset(0, -label.height / 2));
      canvas.restore();
    }
  }

  void _faded({required Canvas canvas, required double opacity, required VoidCallback paint}) {
    if (opacity <= 0) return;
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    paint();
    canvas.restore();
  }

  void _paintName({required Canvas canvas, required int ringIndex, required bool chosen}) {
    (chosen ? labels.chosenNames : labels.names)[ringIndex].paint(
      canvas: canvas,
      center: _origin,
      radius: geometry.ringRadii[ringIndex] - OrbitGeometry.nameInset,
      startAngle: OrbitGeometry.nameStartAngle,
    );
  }

  /// One ring and its dots, holding [choice] when it is non-null.
  void _paintRing({required Canvas canvas, required int ringIndex, required OrbitChoice? choice}) {
    final ring = _orbits.rings[ringIndex];
    final radius = geometry.ringRadii[ringIndex];
    final isCurrent = choice != null;
    _arc(
      canvas: canvas,
      radius: radius,
      from: OrbitGeometry.ringLineFromAngle,
      to: OrbitGeometry.ringLineToAngle,
      paint: isCurrent
          ? (Paint()
              ..color = palette.trail
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4)
          : (Paint()
              ..color = palette.line.withValues(alpha: .55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1),
    );
    if (ring.levels.isEmpty) {
      final center = geometry.levellessDotCenter(ringIndex: ringIndex);
      if (isCurrent) {
        _paintMarker(canvas: canvas, center: center);
      } else {
        _paintHollowDot(canvas: canvas, center: center);
      }
      labels.noEffort.paint(canvas: canvas, center: _origin, radius: radius + 4, startAngle: 46);
      return;
    }
    final weakest = geometry.levelAngle(ringIndex: ringIndex, levelIndex: 0);
    final strongest = geometry.levelAngle(ringIndex: ringIndex, levelIndex: ring.levels.length - 1);
    _arc(
      canvas: canvas,
      radius: radius,
      from: strongest + 4,
      to: weakest - 4,
      paint: Paint()
        ..color = palette.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    _arc(
      canvas: canvas,
      radius: radius + .8,
      from: strongest + 4,
      to: weakest - 4,
      paint: Paint()
        ..color = palette.surface.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    final chosenLevel = choice?.levelIndex;
    if (chosenLevel != null) {
      // The trail from the weakest level up to the chosen one.
      _arc(
        canvas: canvas,
        radius: radius,
        from: geometry.levelAngle(ringIndex: ringIndex, levelIndex: chosenLevel),
        to: weakest - 4,
        paint: Paint()
          ..color = palette.trail
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var levelIndex = 0; levelIndex < ring.levels.length; levelIndex++) {
      final center = geometry.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex);
      if (chosenLevel == null || levelIndex > chosenLevel) {
        _paintHollowDot(canvas: canvas, center: center);
      } else if (levelIndex == chosenLevel) {
        _paintMarker(canvas: canvas, center: center);
      } else {
        // A level the trail passes on its way up to the choice.
        canvas.drawCircle(center, _dotRadius, Paint()..color = palette.trailDot);
      }
    }
  }

  void _paintHollowDot({required Canvas canvas, required Offset center}) {
    canvas
      ..drawCircle(center, _dotRadius, Paint()..color = palette.bead)
      ..drawCircle(
        center,
        _dotRadius,
        Paint()
          ..color = palette.beadEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  /// The current choice, like a selected radio button: an ink ring with an
  /// ink dot in it, set apart from the trail by a gap in the background.
  void _paintMarker({required Canvas canvas, required Offset center}) {
    final ink = palette.text;
    canvas
      ..drawCircle(center, _markerRadius + _markerGap, Paint()..color = palette.background)
      ..drawCircle(
        center,
        _markerRadius - _markerStroke / 2,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _markerStroke,
      )
      ..drawCircle(center, _markerDotRadius, Paint()..color = ink);
  }

  void _paintAllModels(Canvas canvas) {
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: geometry.allModelsCenter,
        width: OrbitGeometry.allModelsPillSize.width,
        height: OrbitGeometry.allModelsPillSize.height,
      ),
      Radius.circular(OrbitGeometry.allModelsPillSize.height / 2),
    );
    final isHot = hot == const OrbitAllModelsTarget();
    canvas
      ..drawRRect(pill, Paint()..color = isHot ? palette.track : palette.bead)
      ..drawRRect(
        pill,
        Paint()
          ..color = palette.beadEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final text = labels.allModels;
    text.paint(canvas, pill.center - Offset(text.width / 2, text.height / 2));
  }

  /// One ripple leaves the chip as the rings arrive.
  void _paintRipple(Canvas canvas) {
    if (reducedMotion || _closing) return;
    final progress = (_openMs / OrbitsMotion.open.inMilliseconds).clamp(0.0, 1.0);
    if (progress >= 1) return;
    final spread = Curves.easeOut.transform(progress);
    final opacity = .6 * (1 - spread);
    canvas
      ..saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity))
      ..drawCircle(
        _origin,
        330 * geometry.scale * (.12 + .92 * spread),
        Paint()
          ..color = palette.trail
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      )
      ..restore();
  }

  /// A clockwise arc of [radius] around the origin from angle [from] down to
  /// [to].
  void _arc({
    required Canvas canvas,
    required double radius,
    required double from,
    required double to,
    required Paint paint,
  }) {
    canvas.drawArc(
      Rect.fromCircle(center: _origin, radius: radius),
      -from * math.pi / 180,
      (from - to) * math.pi / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(OrbitsPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.labels != labels ||
      oldDelegate.palette != palette ||
      oldDelegate.anchorRect != anchorRect ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.hot != hot ||
      oldDelegate.previousHot != previousHot;
}
