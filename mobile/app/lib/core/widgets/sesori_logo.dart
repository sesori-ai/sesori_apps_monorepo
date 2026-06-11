import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:vector_graphics/vector_graphics.dart";

/// The Sesori app icon: the wave artwork (rendered from the compiled SVG) plus
/// the drop shadow and inset bevel highlight that `vector_graphics` drops when
/// it compiles the SVG's filter effects. Shadow and bevel values are taken
/// verbatim from the Figma "Logo" layer effects.
///
/// The source SVG is a 151x177 frame holding a 120x120 squircle whose top-left
/// corner sits at (15.333, 2.667) with a 30.667 corner radius; the leftover
/// frame space is where the drop shadow extends.
class SesoriLogo extends StatelessWidget {
  const SesoriLogo({super.key, this.squareSize = _svgSquare});

  /// Shared [Hero] tag so the logo flies between screens that show it
  /// (splash → login) during route transitions.
  static const String heroTag = "sesori-logo";

  /// Edge length of the rounded square, in logical pixels. Everything else
  /// (frame, shadow, bevel) scales relative to this.
  final double squareSize;

  /// Rendered frame height for this [squareSize], including the shadow
  /// space the SVG frame reserves below the squircle.
  double get frameHeight => _svgHeight * (squareSize / _svgSquare);

  static const double _svgSquare = 120;
  static const double _svgWidth = 151;
  static const double _svgHeight = 177;
  static const Offset _squareOrigin = Offset(15.3334, 2.66663);
  static const double _squareRadius = 30.6667;

  @override
  Widget build(BuildContext context) {
    final scale = squareSize / _svgSquare;
    final radius = _squareRadius * scale;
    final squareRect = Rect.fromLTWH(
      _squareOrigin.dx * scale,
      _squareOrigin.dy * scale,
      squareSize,
      squareSize,
    );

    return SizedBox(
      width: _svgWidth * scale,
      height: _svgHeight * scale,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: squareRect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x40000000),
                    offset: Offset(0, 2.6667 * scale),
                    blurRadius: 5.3333 * scale,
                  ),
                  BoxShadow(
                    color: const Color(0x38000000),
                    offset: Offset(0, 10 * scale),
                    blurRadius: 10 * scale,
                  ),
                  BoxShadow(
                    color: const Color(0x21000000),
                    offset: Offset(0, 22 * scale),
                    blurRadius: 13.3333 * scale,
                  ),
                  BoxShadow(
                    color: const Color(0x0A000000),
                    offset: Offset(0, 38.6667 * scale),
                    blurRadius: 15.3333 * scale,
                  ),
                ],
              ),
            ),
          ),
          SvgPicture(
            const AssetBytesLoader(
              "assets/images/sesori_icon_with_shadow.svg.vec",
            ),
            width: _svgWidth * scale,
            height: _svgHeight * scale,
          ),
          Positioned.fromRect(
            rect: squareRect,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BevelPainter(radius: radius, scale: scale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BevelPainter extends CustomPainter {
  const _BevelPainter({required this.radius, required this.scale});

  final double radius;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas
      ..save()
      ..clipRRect(rrect);
    // Inset shadows, drawn outer→inner to match the Figma layer order.
    _inset(canvas, size: size, offset: Offset(3.3333 * scale, 3.3333 * scale), blur: 1.3333 * scale, spread: -4 * scale, color: const Color(0x99FFFFFF));
    _inset(canvas, size: size, offset: Offset(-2 * scale, -2 * scale), blur: 2.6667 * scale, spread: -3 * scale, color: const Color(0x99FFFFFF));
    _inset(canvas, size: size, offset: Offset(0, -3.3333 * scale), blur: 8.5333 * scale, spread: 0, color: const Color(0x40FFFFFF));
    _inset(canvas, size: size, offset: Offset(0, 2.6667 * scale), blur: 2.6667 * scale, spread: 0, color: const Color(0x40FFFFFF));
    canvas.restore();
  }

  /// Draws a single CSS-style inset shadow: paint everything outside the
  /// spread/offset-adjusted hole, blur it, and let the surrounding clip keep
  /// only the soft edge that bleeds back inside the squircle.
  void _inset(
    Canvas canvas, {
    required Size size,
    required Offset offset,
    required double blur,
    required double spread,
    required Color color,
  }) {
    final paint = Paint()..color = color;
    final sigma = blur / 2; // CSS blur radius ≈ 2σ
    if (sigma > 0) {
      paint.maskFilter = ui.MaskFilter.blur(BlurStyle.normal, sigma);
    }
    final holeRect = (Offset.zero & size).deflate(spread).shift(offset);
    final holeRadius = (radius - spread).clamp(0.0, double.infinity);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)));
    final field = Path()
      ..addRect((Offset.zero & size).inflate(size.longestSide));
    canvas.drawPath(
      Path.combine(PathOperation.difference, field, hole),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BevelPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.scale != scale;
}
