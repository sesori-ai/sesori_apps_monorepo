import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelOrbits, OrbitRing;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbit_geometry.dart";
import "orbit_metal.dart";

/// How long the orbits take to arrive and to leave.
abstract final class OrbitsMotion() {
  /// The ripple entry: the last ring settles at about 0.34 s, the ripple
  /// itself fades out a little later.
  static const open = Duration(milliseconds: 440);
  static const close = Duration(milliseconds: 180);

  /// The plain fade used under reduced motion, both ways.
  static const fade = Duration(milliseconds: 200);

  /// How long the dot under the finger takes to grow.
  static const grow = Duration(milliseconds: 120);

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

/// The neutral colours of the picker, from the Prego theme. The metal comes
/// from [OrbitMetal].
final class OrbitPalette({required PregoColors colors}) {
  final Color scrim = colors.bgSurface2.withValues(alpha: .87);
  final Color text = colors.textPrimary;
  final Color quietText = colors.textQuaternary;
  final Color line = colors.fgQuaternary;
  final Color track = colors.bgQuaternary;

  /// The fill of hollow dots and the "All" pill.
  final Color surface = colors.alphaWhite100;
}

/// Text laid out once and bent along an arc at paint time, one glyph at a
/// time.
final class ArcText({required List<(String, TextStyle)> spans}) {
  final List<(TextPainter glyph, double x, double baseline)> _glyphs = _layOut(spans: spans);

  static List<(TextPainter, double, double)> _layOut({required List<(String, TextStyle)> spans}) {
    final line = TextPainter(
      text: TextSpan(
        children: [for (final (text, style) in spans) TextSpan(text: text, style: style)],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final glyphs = <(TextPainter, double, double)>[];
    var offset = 0;
    for (final (text, style) in spans) {
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
  required String fastTag,
  required String noEffortText,
  required String allModelsText,
}) {
  /// Each ring's name, with its FAST tag when it needs one.
  final List<ArcText> names = [
    for (final ring in orbits.rings)
      ArcText(
        spans: [
          (
            ring.name,
            textTheme.textXs.regular.copyWith(
              fontSize: 12,
              height: 1,
              letterSpacing: 0,
              color: palette.text,
              fontWeight: ring == orbits.current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (!orbits.allRingsFast && ring.hasFastMode)
            (
              " $fastTag",
              textTheme.textXs.bold.copyWith(fontSize: 8, height: 1, letterSpacing: 1, color: palette.quietText),
            ),
        ],
      ),
  ];
  final ArcText noEffort = ArcText(
    spans: [
      (
        noEffortText,
        textTheme.textXs.medium.copyWith(fontSize: 10, height: 1, letterSpacing: 0, color: palette.quietText),
      ),
    ],
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
            color: palette.quietText,
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
    for (final name in names) {
      name.dispose();
    }
    noEffort.dispose();
    for (final ray in rays) {
      ray.dispose();
    }
    allModels.dispose();
  }
}

extension OrbitRingFastMode on OrbitRing {
  /// Whether the model has fast mode, usable now or not.
  bool get hasFastMode => switch (fastMode) {
    FastModeAvailable() || FastModeUnavailable() => true,
    null || FastModeSupportUnknown() => false,
  };
}

/// Paints the scrim, the rings, their dots and the ripple. Repaints on its
/// own as [entry] and [hotGrow] tick.
final class OrbitsPainter({
  required final OrbitGeometry geometry,
  required final OrbitLabels labels,
  required final OrbitPalette palette,
  required final OrbitMetal metal,

  /// The chip the picker opened from, left clear of the scrim.
  required final Rect anchorRect,

  /// The route's animation: 0 closed, 1 open.
  required final Animation<double> entry,
  required final bool reducedMotion,

  /// What the finger is on, and what it just left.
  required final OrbitTarget? hot,
  required final OrbitTarget? previousHot,

  /// How far [hot] has grown, and [previousHot] shrunk back.
  required final Animation<double> hotGrow,
}) extends CustomPainter {
  this : super(repaint: Listenable.merge([entry, hotGrow]));

  static const double _dotRadius = 5.5;
  static const double _hotGrowth = .4;

  ModelOrbits get _orbits => geometry.orbits;
  Offset get _origin => geometry.origin;
  bool get _closing => entry.status == AnimationStatus.reverse;
  double get _openMs => entry.value * OrbitsMotion.open.inMilliseconds;

  @override
  void paint(Canvas canvas, Size size) {
    _paintScrim(canvas: canvas, size: size);
    _group(canvas: canvas, size: size, stagger: 0, paint: () => _paintRays(canvas));
    final ringCount = _orbits.rings.length;
    for (var ringIndex = 0; ringIndex < ringCount; ringIndex++) {
      _group(
        canvas: canvas,
        size: size,
        stagger: OrbitsMotion.ringStagger(ringCount: ringCount, ringIndex: ringIndex),
        paint: () => _paintRing(canvas: canvas, ringIndex: ringIndex),
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
      ..addRRect(RRect.fromRectAndRadius(anchorRect, const Radius.circular(PregoRadius.md)));
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

  void _paintRing({required Canvas canvas, required int ringIndex}) {
    final ring = _orbits.rings[ringIndex];
    final radius = geometry.ringRadii[ringIndex];
    final isCurrent = ring == _orbits.current;
    _arc(
      canvas: canvas,
      radius: radius,
      from: OrbitGeometry.ringLineFromAngle,
      to: OrbitGeometry.ringLineToAngle,
      paint: isCurrent
          ? (Paint()
              ..shader = metal.rimShader()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4)
          : (Paint()
              ..color = palette.line.withValues(alpha: .55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1),
    );
    labels.names[ringIndex].paint(
      canvas: canvas,
      center: _origin,
      radius: radius - OrbitGeometry.nameInset,
      startAngle: OrbitGeometry.nameStartAngle,
    );
    if (ring.levels.isEmpty) {
      final center = geometry.levellessDotCenter(ringIndex: ringIndex);
      final target = OrbitNameTarget(ringIndex: ringIndex);
      if (isCurrent) {
        _paintMedallion(canvas: canvas, ring: ring, center: center, radius: 11, target: target, litBlades: 0);
      } else {
        _paintHollowDot(canvas: canvas, center: center, target: target);
      }
      labels.noEffort.paint(canvas: canvas, center: _origin, radius: radius + 4, startAngle: 46);
      return;
    }
    final first = geometry.levelAngle(ringIndex: ringIndex, levelIndex: 0);
    final last = geometry.levelAngle(ringIndex: ringIndex, levelIndex: ring.levels.length - 1);
    _arc(
      canvas: canvas,
      radius: radius,
      from: first + 4,
      to: last - 4,
      paint: Paint()
        ..color = palette.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    _arc(
      canvas: canvas,
      radius: radius + .8,
      from: first + 4,
      to: last - 4,
      paint: Paint()
        ..color = palette.surface.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    final currentLevel = isCurrent ? ring.levels.indexWhere((level) => level.level == _orbits.currentLevel) : -1;
    if (currentLevel >= 0) {
      // The polished trail from the weakest level up to the current one.
      _arc(
        canvas: canvas,
        radius: radius,
        from: first + 4,
        to: geometry.levelAngle(ringIndex: ringIndex, levelIndex: currentLevel),
        paint: Paint()
          ..shader = metal.rimShader()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var levelIndex = 0; levelIndex < ring.levels.length; levelIndex++) {
      final center = geometry.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex);
      final target = OrbitLevelTarget(ringIndex: ringIndex, levelIndex: levelIndex);
      if (levelIndex == currentLevel) {
        _paintMedallion(
          canvas: canvas,
          ring: ring,
          center: center,
          radius: 12.5,
          target: target,
          litBlades: levelIndex + 1,
        );
      } else {
        _paintHollowDot(canvas: canvas, center: center, target: target);
      }
    }
  }

  /// How much the dot of [target] has grown under the finger.
  double _growth(OrbitTarget target) {
    final grown = Curves.easeOut.transform(hotGrow.value);
    if (target == hot) return grown;
    if (target == previousHot) return 1 - grown;
    return 0;
  }

  void _paintHollowDot({required Canvas canvas, required Offset center, required OrbitTarget target}) {
    final radius = _dotRadius * (1 + _hotGrowth * _growth(target));
    canvas
      ..drawCircle(center, radius, Paint()..color = palette.surface)
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = palette.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  void _paintMedallion({
    required Canvas canvas,
    required OrbitRing ring,
    required Offset center,
    required double radius,
    required OrbitTarget target,
    required int litBlades,
  }) {
    // The current choice grows less than a hollow dot: it is already large.
    final grown = radius * (1 + _hotGrowth * .4 * _growth(target));
    canvas.drawCircle(
      center,
      grown + 2.5,
      Paint()
        ..color = metal.m1.withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    paintMedallion(
      canvas: canvas,
      center: center,
      radius: grown,
      metal: metal,
      bladeCount: ring.levels.length,
      litBlades: litBlades,
      monogram: ring.name.characters.first,
    );
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
      ..drawRRect(pill, Paint()..color = isHot ? palette.track : palette.surface)
      ..drawRRect(
        pill,
        Paint()
          ..color = palette.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final text = labels.allModels;
    text.paint(canvas, pill.center - Offset(text.width / 2, text.height / 2));
  }

  /// One ripple leaves the medallion as the rings arrive.
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
          ..shader = metal.rimShader()
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
      oldDelegate.metal != metal ||
      oldDelegate.anchorRect != anchorRect ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.hot != hot ||
      oldDelegate.previousHot != previousHot;
}
