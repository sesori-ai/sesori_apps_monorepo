import "dart:math" as math;
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The metal the model and effort controls are struck in: silver at standard
/// speed, gold while fast mode is on. Colours run from the brightest
/// highlight ([m0]) to the deepest shade ([m3]), plus the engraved [edge].
enum OrbitMetal({
  required final Color m0,
  required final Color m1,
  required final Color m2,
  required final Color m3,
  required final Color edge,
}) {
  silver(
    m0: Color(0xFFFFFFFF),
    m1: Color(0xFFD9DCE2),
    m2: Color(0xFF8D939D),
    m3: Color(0xFF5F656F),
    edge: Color(0xFF3A3E45),
  ),
  gold(
    m0: Color(0xFFFFFAF0),
    m1: Color(0xFFEAD08F),
    m2: Color(0xFFA77D2F),
    m3: Color(0xFF76571C),
    edge: Color(0xFF46330F),
  );

  /// The dark enamel inside a medallion, top to bottom.
  static const enamelTop = Color(0xFF2E3038);
  static const enamelBottom = Color(0xFF0F1013);

  /// A polished rim that catches the light as it runs, for ring lines and the
  /// current choice's trail. The 200 pt sweep mirrors back, so the pattern
  /// repeats every 400 pt and any span shows a highlight.
  Shader rimShader() => ui.Gradient.linear(
    Offset.zero,
    const Offset(160, 120),
    [m0, m1, m2, m1, m0],
    const [0, .35, .6, .8, 1],
    TileMode.mirror,
  );

  /// A bright-to-dark diagonal for lit blades and monograms within [bounds].
  Shader bladeShader({required Rect bounds}) =>
      ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [m0, m1, m2], const [0, .55, 1]);

  /// A small polished bead, lit from the upper left.
  Shader beadShader({required Rect bounds}) => ui.Gradient.radial(
    bounds.topLeft + Offset(bounds.width * .35, bounds.height * .3),
    bounds.longestSide * .75,
    [m0, m1, m3],
    const [0, .45, 1],
  );
}

/// Paints a medallion of [radius] at [center]: a knurled metal rim around dark
/// enamel bearing a fan of [bladeCount] blades lit up to [litBlades], or the
/// [monogram] when the model has no levels.
void paintMedallion({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required OrbitMetal metal,
  required int bladeCount,
  required int litBlades,
  required String monogram,
}) {
  // Drawn at the reference size of 18.6 and scaled, like the agreed mock.
  final k = radius / 18.6;
  final box = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center + Offset(.6 * k, 1.6 * k),
    radius,
    Paint()
      ..color = const Color(0x520B0C10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 * k),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        [metal.m0, metal.m1, metal.m2, metal.m3, metal.m1, metal.m2],
        const [0, .22, .48, .56, .74, 1],
      ),
  );
  // A soft sheen across the face.
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = ui.Gradient.linear(
        box.topLeft,
        Offset(box.left + box.width * .45, box.bottom),
        const [Color(0x00FFFFFF), Color(0xA6FFFFFF), Color(0x00FFFFFF)],
        const [.36, .5, .64],
      ),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55 * k
      ..color = metal.edge,
  );
  // Knurling around the rim.
  for (var index = 0; index < 20; index++) {
    final angle = index / 20 * math.pi * 2;
    final knurl = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 2.3 * k);
    final knurlBox = Rect.fromCircle(center: knurl, radius: .78 * k);
    canvas.drawCircle(knurl, .78 * k, Paint()..shader = metal.beadShader(bounds: knurlBox));
  }
  canvas.drawCircle(
    center,
    radius - 4.1 * k,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 * k
      ..color = metal.edge,
  );
  final enamelRadius = radius - 4.5 * k;
  canvas.drawCircle(
    center,
    enamelRadius,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - enamelRadius),
        Offset(center.dx, center.dy + enamelRadius),
        const [OrbitMetal.enamelTop, OrbitMetal.enamelBottom],
      ),
  );
  // The enamel sits below the rim: a soft inner shadow from the top edge.
  canvas
    ..save()
    ..clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: enamelRadius)))
    ..drawCircle(
      center + Offset(0, 1.3 * k),
      enamelRadius + 1.5 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.3 * k),
    )
    ..restore();
  final glossCenter = Offset(center.dx, center.dy - radius * .32);
  final glossBox = Rect.fromCenter(center: glossCenter, width: radius * 1.08, height: radius * .64);
  canvas.drawOval(
    glossBox,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(glossBox.center.dx, glossBox.top + glossBox.height * .15),
        glossBox.width * .7,
        const [Color(0x61FFFFFF), Color(0x00FFFFFF)],
      ),
  );
  if (bladeCount == 0) {
    _paintMonogram(canvas: canvas, center: center, k: k, metal: metal, monogram: monogram);
  } else {
    _paintBlades(
      canvas: canvas,
      hub: center + Offset(0, 5.6 * k),
      length: (bladeCount >= 6 ? 13 : 12.5) * k,
      metal: metal,
      bladeCount: bladeCount,
      litBlades: litBlades,
    );
  }
}

void _paintBlades({
  required Canvas canvas,
  required Offset hub,
  required double length,
  required OrbitMetal metal,
  required int bladeCount,
  required int litBlades,
}) {
  final widthFactor = bladeCount >= 6
      ? .74
      : bladeCount >= 4
      ? .9
      : 1.0;
  final step = bladeCount > 1 ? math.min(24, 112 / (bladeCount - 1)) : 0.0;
  final blade = _bladePath(length: length, widthFactor: widthFactor);
  final bladeBox = blade.getBounds();
  final middle = (bladeCount - 1) / 2;
  // Outer blades first, so the middle ones overlap them.
  final order = [for (var index = 0; index < bladeCount; index++) index]
    ..sort((a, b) => (b - middle).abs().compareTo((a - middle).abs()));
  for (final index in order) {
    canvas
      ..save()
      ..translate(hub.dx, hub.dy)
      ..rotate((index - middle) * step * math.pi / 180);
    if (index < litBlades) {
      canvas
        ..drawPath(blade, Paint()..shader = metal.bladeShader(bounds: bladeBox))
        ..drawPath(
          blade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = length * .026
            ..color = metal.edge,
        );
    } else {
      canvas
        ..drawPath(blade, Paint()..color = const Color(0x21FFFFFF))
        ..drawPath(
          blade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = length * .04
            ..color = const Color(0x9EFFFFFF),
        );
    }
    canvas.restore();
  }
  final c = length * .36;
  final hubPath = Path()
    ..moveTo(hub.dx - c, hub.dy - length * .1)
    ..quadraticBezierTo(hub.dx, hub.dy + length * .34, hub.dx + c, hub.dy - length * .1)
    ..quadraticBezierTo(hub.dx, hub.dy + length * .14, hub.dx - c, hub.dy - length * .1)
    ..close();
  canvas
    ..drawPath(hubPath, Paint()..shader = metal.beadShader(bounds: hubPath.getBounds()))
    ..drawPath(
      hubPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = length * .024
        ..color = metal.edge,
    );
}

/// One blade pointing up from the origin.
Path _bladePath({required double length, required double widthFactor}) {
  final l = length;
  final w = widthFactor;
  return Path()
    ..moveTo(0, -l * .02)
    ..cubicTo(l * .19 * w, -l * .34, l * .15 * w, -l * .76, 0, -l)
    ..cubicTo(-l * .15 * w, -l * .76, -l * .19 * w, -l * .34, 0, -l * .02)
    ..close();
}

void _paintMonogram({
  required Canvas canvas,
  required Offset center,
  required double k,
  required OrbitMetal metal,
  required String monogram,
}) {
  final size = 15 * k;
  final bounds = Rect.fromCircle(center: center, radius: size / 2);
  final painter = TextPainter(
    text: TextSpan(
      text: monogram,
      style: TextStyle(
        fontFamily: PregoTextTheme.fontFamily,
        fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1,
        foreground: Paint()..shader = metal.bladeShader(bounds: bounds),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}
