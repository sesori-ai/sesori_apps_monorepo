import "dart:math" as math;
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelOrbits;
import "package:theme_prego/module_prego.dart";

import "orbit_metal.dart";

/// The touch composer's model and effort control: a metal plate with the
/// medallion at its leading end, the model's name with its level word under
/// it, and an end diamond that becomes a glowing bolt in fast mode. Silver at
/// standard speed, gold while fast.
///
/// The medallion is as wide as the chip is tall, which is where the orbits
/// picker centres its rings. A new model, level or speed cross-fades in while
/// the plate eases to its new width.
class const MedallionChip({
  super.key,
  required final ModelOrbits orbits,
  required final bool fast,
}) extends StatefulWidget {
  /// The height of the composer's touch pills, so the row never jumps.
  static const double height = 36;

  @override
  State<MedallionChip> createState() => _MedallionChipState();
}

/// What the chip shows. Records compare by value, so an unchanged choice
/// never restarts the cross-fade.
typedef _Face = ({String name, String? word, int bladeCount, int litBlades, String monogram, bool fast});

_Face _faceOf({required ModelOrbits orbits, required bool fast}) {
  final ring = orbits.current;
  final level = orbits.currentLevel;
  return (
    name: ring.name,
    word: level?.wireId.toUpperCase(),
    bladeCount: ring.levels.length,
    litBlades: level == null ? 0 : ring.levels.indexWhere((entry) => entry.level == level) + 1,
    monogram: ring.name.characters.take(1).toString(),
    fast: fast,
  );
}

class _MedallionChipState() extends State<MedallionChip> with SingleTickerProviderStateMixin {
  static const _fade = Duration(milliseconds: 220);

  late final AnimationController _change = AnimationController(vsync: this, duration: _fade, value: 1);
  late final CurvedAnimation _curve = CurvedAnimation(parent: _change, curve: Curves.easeInOut);

  late _Face _to = _faceOf(orbits: widget.orbits, fast: widget.fast);
  late _Face _from = _to;
  _ChipText? _fromText;
  _ChipText? _toText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _relayText();
  }

  @override
  void didUpdateWidget(MedallionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final face = _faceOf(orbits: widget.orbits, fast: widget.fast);
    if (face == _to) return;
    _from = _to;
    _to = face;
    _relayText();
    _change.forward(from: 0);
  }

  void _relayText() {
    final prego = context.prego;
    _fromText?.dispose();
    _toText?.dispose();
    _fromText = _ChipText(face: _from, prego: prego);
    _toText = _ChipText(face: _to, prego: prego);
  }

  @override
  void dispose() {
    _curve.dispose();
    _change.dispose();
    _fromText?.dispose();
    _toText?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromText = _fromText;
    final toText = _toText;
    if (fromText == null || toText == null) return const SizedBox(height: MedallionChip.height);
    final prego = context.prego;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _curve,
        builder: (context, _) => SizedBox(
          width: math.min(
            constraints.maxWidth,
            ui.lerpDouble(fromText.naturalWidth, toText.naturalWidth, _curve.value) ?? toText.naturalWidth,
          ),
          height: MedallionChip.height,
          child: CustomPaint(
            painter: _MedallionChipPainter(
              from: _from,
              to: _to,
              fromText: fromText,
              toText: toText,
              progress: _curve.value,
              colors: prego.colors,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip's text for one face, laid out once.
final class _ChipText({required _Face face, required PregoDesignSystem prego}) {
  static const double textStart = 45;
  static const double endSpace = 22;

  final TextPainter name = _painter(
    text: face.name,
    style: prego.textTheme.textXs.medium.copyWith(
      fontSize: face.word == null ? 15 : 13.5,
      height: 1,
      letterSpacing: 0,
      color: prego.colors.textPrimary,
    ),
  );
  final TextPainter? word = switch (face.word) {
    null => null,
    final word => _painter(
      text: word,
      style: prego.textTheme.textXs.bold.copyWith(
        fontSize: 7.5,
        height: 1,
        letterSpacing: 1,
        color: prego.colors.textTertiary,
      ),
    ),
  };

  /// The chip's width when nothing caps it. Read before the first paint,
  /// which may lay the text out narrower.
  late final double naturalWidth = textStart + math.max(name.width, word?.width ?? 0) + endSpace;

  static TextPainter _painter({required String text, required TextStyle style}) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: "…",
  )..layout();

  /// Paints the text left-aligned in a chip of [width], ellipsized to fit.
  void paint({required Canvas canvas, required double width}) {
    final maxWidth = math.max(0.0, width - textStart - endSpace);
    final name = this.name;
    final word = this.word;
    name.layout(maxWidth: maxWidth);
    // Baselines from the agreed mock: the name above the small-caps level, or
    // the name alone, larger, on the plate's centre line.
    final nameBaseline = word == null ? 23.4 : 17.4;
    name.paint(canvas, Offset(textStart, nameBaseline - name.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    if (word == null) return;
    word
      ..layout(maxWidth: maxWidth)
      ..paint(canvas, Offset(textStart + .3, 28 - word.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  void dispose() {
    name.dispose();
    word?.dispose();
  }
}

/// Paints the previous face, then the new one fading in over it, so the plate
/// never thins out mid-change.
final class _MedallionChipPainter({
  required final _Face from,
  required final _Face to,
  required final _ChipText fromText,
  required final _ChipText toText,
  required final double progress,
  required final PregoColors colors,
}) extends CustomPainter {
  static const double _radius = MedallionChip.height / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 1) _paintFace(canvas: canvas, size: size, face: from, text: fromText);
    if (progress <= 0) return;
    if (progress < 1) canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, progress));
    _paintFace(canvas: canvas, size: size, face: to, text: toText);
    if (progress < 1) canvas.restore();
  }

  void _paintFace({required Canvas canvas, required Size size, required _Face face, required _ChipText text}) {
    final metal = face.fast ? OrbitMetal.gold : OrbitMetal.silver;
    final w = size.width;
    final h = size.height;
    final dark = colors.brightness == Brightness.dark;
    // The plate starts under the medallion and ends in a chamfered point.
    final plate = Path()
      ..moveTo(_radius, 0)
      ..lineTo(w - 10, 0)
      ..lineTo(w - 1, 9)
      ..lineTo(w - 1, h - 9)
      ..lineTo(w - 10, h)
      ..lineTo(_radius, h)
      ..close();
    canvas
      ..drawPath(
        plate.shift(const Offset(0, 5)),
        Paint()
          ..color = const Color(0x1A1B1430)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawPath(
        plate.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0x290B0C10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      )
      ..drawPath(
        plate,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
            colors.bgSurface2,
            Color.lerp(colors.bgSurface2, colors.textPrimary, .045) ?? colors.bgSurface2,
          ]),
      );
    // The polished rim: a dark edge, the metal, and a sheen across it.
    canvas
      ..drawPath(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = metal.edge.withValues(alpha: .75),
      )
      ..drawPath(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            [metal.m0, metal.m1, metal.m2, metal.m3, metal.m1, metal.m2],
            const [0, .22, .48, .56, .74, 1],
          ),
      )
      ..drawPath(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..shader = ui.Gradient.linear(
            Offset(w * .1, 0),
            Offset(w * .55, h),
            const [Color(0x00FFFFFF), Color(0x94FFFFFF), Color(0x00FFFFFF)],
            const [.36, .5, .64],
          ),
      );
    // An engraved line inside the rim: a shade with a highlight under it.
    final engraving = Path()
      ..moveTo(_radius, 2.9)
      ..lineTo(w - 11.2, 2.9)
      ..lineTo(w - 3.9, 10.2)
      ..lineTo(w - 3.9, h - 10.2)
      ..lineTo(w - 11.2, h - 2.9)
      ..lineTo(_radius, h - 2.9);
    canvas
      ..drawPath(
        engraving,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = Color.fromRGBO(0, 0, 0, dark ? .35 : .1),
      )
      ..drawPath(
        engraving.shift(const Offset(0, .7)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = Color.fromRGBO(255, 255, 255, dark ? .08 : 1),
      );
    _paintEndMark(canvas: canvas, center: Offset(w - 9.5, h / 2), metal: metal, fast: face.fast);
    text.paint(canvas: canvas, width: w);
    paintMedallion(
      canvas: canvas,
      center: const Offset(_radius, _radius),
      radius: _radius,
      metal: metal,
      bladeCount: face.bladeCount,
      litBlades: face.litBlades,
      monogram: face.monogram,
    );
  }

  /// A small diamond at standard speed; a bolt with a glow while fast.
  void _paintEndMark({required Canvas canvas, required Offset center, required OrbitMetal metal, required bool fast}) {
    final Path mark;
    if (fast) {
      canvas.drawCircle(
        center,
        4.6,
        Paint()
          ..color = metal.m1.withValues(alpha: .75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      mark = Path()
        ..moveTo(center.dx + 1.3, center.dy - 5.6)
        ..lineTo(center.dx - 3.2, center.dy + .9)
        ..lineTo(center.dx - .1, center.dy + .9)
        ..lineTo(center.dx - 1.3, center.dy + 5.6)
        ..lineTo(center.dx + 3.2, center.dy - .9)
        ..lineTo(center.dx + .1, center.dy - .9)
        ..close();
    } else {
      mark = Path()
        ..moveTo(center.dx, center.dy - 2.8)
        ..lineTo(center.dx + 2.8, center.dy)
        ..lineTo(center.dx, center.dy + 2.8)
        ..lineTo(center.dx - 2.8, center.dy)
        ..close();
    }
    canvas
      ..drawPath(mark, Paint()..shader = metal.beadShader(bounds: mark.getBounds()))
      ..drawPath(
        mark,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fast ? .45 : .4
          ..strokeJoin = StrokeJoin.round
          ..color = metal.edge,
      );
  }

  @override
  bool shouldRepaint(_MedallionChipPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.fromText != fromText ||
      oldDelegate.toText != toText ||
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors;
}
